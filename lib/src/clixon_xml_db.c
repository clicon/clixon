/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Alternatively, the contents of this file may be used under the terms of
  the GNU General Public License Version 3 or later (the "GPL"),
  in which case the provisions of the GPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of the GPL, and not to allow others to
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <time.h>
#include <signal.h>
#include <libgen.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <sys/param.h>


/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_plugin.h"
#include "clixon_options.h"
#include "clixon_xml_db.h"

/* Set to log get and put requests */
#define DEBUG 0

/*! Load an xmldb storage plugin according to filename
 * If init function fails (not found, wrong version, etc) print a log and dont
 * add it.
 * @param[in]  h         CLicon handle
 * @param[in]  filename  Actual filename including path
 */
int 
xmldb_plugin_load(clicon_handle h,
		  char         *filename)
{
    int                      retval = -1;
    char                    *dlerrcode;
    plugin_init_t           *initfun;
    plghndl_t                handle = NULL;
    char                    *error;
    struct xmldb_api        *xa = NULL;

    dlerror();    /* Clear any existing error */
    if ((handle = dlopen(filename, RTLD_NOW|RTLD_GLOBAL)) == NULL) {
        error = (char*)dlerror();
	clicon_err(OE_PLUGIN, errno, "dlopen: %s", error ? error : "Unknown error");	
	goto done;
    }
    /* Try v1 */
    initfun = dlsym(handle, XMLDB_PLUGIN_INIT_FN);
    if ((dlerrcode = (char*)dlerror()) != NULL) {
	clicon_log(LOG_WARNING, "Error when loading init function %s: %s",
		   XMLDB_PLUGIN_INIT_FN, dlerrcode); 
	goto fail;
    }
    if ((xa = initfun(XMLDB_API_VERSION)) == NULL) {
	clicon_log(LOG_WARNING, "%s: failed when running init function %s: %s", 
		   filename, XMLDB_PLUGIN_INIT_FN, errno?strerror(errno):"");
	goto fail;
    }
    if (xa->xa_version != XMLDB_API_VERSION){
	clicon_log(LOG_WARNING, "%s: Unexpected plugin version number: %d", 
		   filename, xa->xa_version);
	goto fail;
    }
    if (xa->xa_magic != XMLDB_API_MAGIC){
	clicon_log(LOG_WARNING, "%s: Wrong plugin magic number: %x", 
		   filename, xa->xa_magic);
	goto fail;
    }
    /* Add plugin */
    if (clicon_xmldb_plugin_set(h, handle) < 0)
	goto done;
    /* Add API */
    if (clicon_xmldb_api_set(h, xa) < 0)
	goto done;
    clicon_log(LOG_DEBUG, "xmldb plugin %s loaded", filename);
    retval = 0;
 done:
    if (retval < 0 && handle)
	dlclose(handle);
    return retval;
 fail: /* plugin load failed, continue */
    retval = 0;
    goto done;
}

/*! Unload the xmldb storage plugin 
 * @param[in]  h    Clicon handle
 * @retval     0    OK
 * @retval    -1    Error
 */
int
xmldb_plugin_unload(clicon_handle h)
{
    int               retval = -1;
    plghndl_t         handle;
    struct xmldb_api *xa;
    xmldb_handle      xh;
    char             *error;

    if ((handle = clicon_xmldb_plugin_get(h)) == NULL)
	goto ok; /* OK, may not have been initialized */
    /* If connected storage handle then disconnect */
    if ((xh = clicon_xmldb_handle_get(h)) != NULL)
	xmldb_disconnect(h); /* sets xmldb handle to NULL */
    /* Deregister api */
    if ((xa = clicon_xmldb_api_get(h)) != NULL){
	/* Call plugin_exit */
	if (xa->xa_plugin_exit_fn != NULL)
	    xa->xa_plugin_exit_fn();
	/* Deregister API (it is allocated in plugin) */
	clicon_xmldb_api_set(h, NULL);
    }
    /* Unload plugin */
    dlerror();    /* Clear any existing error */
    if (dlclose(handle) != 0) {
	error = (char*)dlerror();
	clicon_err(OE_PLUGIN, errno, "dlclose: %s", error ? error : "Unknown error");
	/* Just report no -1 return*/
    }    
 ok:
    retval = 0;
    // done:
    return retval;
}

/*! Validate database name
 * @param[in]   db     Name of database 
 * @param[out] xret   Return value as cligen buffer containing xml netconf return
 * @retval  0   OK
 * @retval  -1  Failed validate, xret set to error
 */
int
xmldb_validate_db(const char *db)
{
    if (strcmp(db, "running") != 0 && 
	strcmp(db, "candidate") != 0 && 
	strcmp(db, "startup") != 0 && 
	strcmp(db, "tmp") != 0)
	return -1;
    return 0;
}

/*! Connect to a datastore plugin, allocate handle to be used in API calls
 * @param[in]  h    Clicon handle
 * @retval     0    OK
 * @retval    -1    Error
 * @note You can do several connects, and have multiple connections to the same
 *       datastore. Note also that the xmldb handle is hidden in the clicon 
 *       handle, the clixon user does not need to handle it. Note also that
 *       typically only the backend invokes the datastore.
 */
int
xmldb_connect(clicon_handle h)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_connect_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = xa->xa_connect_fn()) == NULL)
	goto done;
    clicon_xmldb_handle_set(h, xh);
    retval = 0;
 done:
    return retval;
}

/*! Disconnect from a datastore plugin and deallocate handle
 * @param[in]  handle  Disconect and deallocate from this handle
 * @retval     0       OK
 * @retval    -1    Error
 */
int
xmldb_disconnect(clicon_handle h)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_disconnect_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Already disconnected from datastore plugin");
	goto done;
    }
    if (xa->xa_disconnect_fn(xh) < 0)
	goto done;
    clicon_xmldb_handle_set(h, NULL);
    retval = 0;
 done:
    return retval;
}

/*! Get value of generic plugin option. Type of value is givenby context
 * @param[in]  h       Clicon handle
 * @param[in]  optname Option name
 * @param[out] value   Pointer to Value of option
 * @retval     0       OK
 * @retval    -1       Error
 */
int
xmldb_getopt(clicon_handle h, 
	     char         *optname,
	     void        **value)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_getopt_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_getopt_fn(xh, optname, value);
 done:
    return retval;
}

/*! Set value of generic plugin option. Type of value is givenby context
 * @param[in]  h       Clicon handle
 * @param[in]  optname Option name
 * @param[in]  value   Value of option
 * @retval     0       OK
 * @retval    -1       Error
  */
int
xmldb_setopt(clicon_handle h, 
	     char         *optname,
	     void         *value)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_setopt_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_setopt_fn(xh, optname, value);
 done:
    return retval;
}

/*! Get content of database using xpath. return a set of matching sub-trees
 * The function returns a minimal tree that includes all sub-trees that match
 * xpath.
 * @param[in]  h      Clicon handle
 * @param[in]  dbname Name of database to search in (filename including dir path
 * @param[in]  xpath  String with XPATH syntax. or NULL for all
 * @param[in]  config If set only configuration data, else also state
 * @param[out] xret   Single return XML tree. Free with xml_free()
 * @retval     0      OK
 * @retval     -1     Error
 * @code
 *   cxobj   *xt;
 *   if (xmldb_get(xh, "running", "/interfaces/interface[name="eth"]", 1, &xt) < 0)
 *      err;
 *   xml_free(xt);
 * @endcode
 * @note if xvec is given, then purge tree, if not return whole tree.
 * @see xpath_vec
 */
int 
xmldb_get(clicon_handle h, 
	  const char   *db, 
	  char         *xpath,
	  int           config,
	  cxobj       **xret)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_get_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_get_fn(xh, db, xpath, config, xret);
#if DEBUG
    if (retval == 0) { 
	 cbuf *cb = cbuf_new();
	 clicon_xml2cbuf(cb, *xret, 0, 0);
	 clicon_log(LOG_WARNING, "%s: db:%s xpath:%s xml:%s", 
		    __FUNCTION__, db, xpath, cbuf_get(cb));
	 cbuf_free(cb);
    }
#endif
 done:
    return retval;
}

/*! Modify database given an xml tree and an operation
 *
 * @param[in]  h      CLICON handle
 * @param[in]  db     running or candidate
 * @param[in]  op     Top-level operation, can be superceded by other op in tree
 * @param[in]  xt     xml-tree. Top-level symbol is dummy
 * @param[out] cbret  Initialized cligen buffer or NULL. On exit contains XML or "".
 * @retval     0      OK
 * @retval     -1     Error
 * The xml may contain the "operation" attribute which defines the operation.
 * @code
 *   cxobj     *xt;
 *   cxobj     *xret = NULL;
 *   if (xml_parse_string("<a>17</a>", yspec, &xt) < 0)
 *     err;
 *   if (xmldb_put(xh, "running", OP_MERGE, xt, cbret) < 0)
 *     err;
 * @endcode
 * @note that you can add both config data and state data. In comparison,
 *  xmldb_get has a parameter to get config data only.
 * @note if xret is non-null, it may contain error message
 *
 */
int 
xmldb_put(clicon_handle       h, 
	  const char         *db, 
	  enum operation_type op, 
	  cxobj              *xt,
	  cbuf               *cbret)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_put_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
#if DEBUG
    {
	cbuf *cb = cbuf_new();
	if (xt)
	    if (clicon_xml2cbuf(cb, xt, 0, 0) < 0)
		goto done;

	clicon_log(LOG_WARNING, "%s: db:%s op:%d xml:%s", __FUNCTION__, 
	       db, op, cbuf_get(cb));
	cbuf_free(cb);
    }
#endif
    retval = xa->xa_put_fn(xh, db, op, xt, cbret);
 done:
    return retval;
}

/*! Copy database from db1 to db2
 * @param[in]  h     Clicon handle
 * @param[in]  from  Source database
 * @param[in]  to    Destination database
 * @retval -1  Error
 * @retval  0  OK
  */
int 
xmldb_copy(clicon_handle h, 
	   const char   *from, 
	   const char   *to)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_copy_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_copy_fn(xh, from, to);
 done:
    return retval;
}

/*! Lock database
 * @param[in]  h    Clicon handle
 * @param[in]  db   Database
 * @param[in]  pid  Process id
 * @retval -1  Error
 * @retval  0  OK
  */
int 
xmldb_lock(clicon_handle h, 
	   const char   *db, 
	   int           pid)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_lock_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_lock_fn(xh, db, pid);
 done:
    return retval;
}

/*! Unlock database
 * @param[in]  h   Clicon handle
 * @param[in]  db  Database
 * @param[in]  pid  Process id
 * @retval -1  Error
 * @retval  0  OK
 * Assume all sanity checks have been made
 */
int 
xmldb_unlock(clicon_handle h, 
	     const char   *db)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_unlock_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_unlock_fn(xh, db);
 done:
    return retval;
}

/*! Unlock all databases locked by pid (eg process dies) 
 * @param[in]    h   Clicon handle
 * @param[in]    pid Process / Session id
 * @retval -1    Error
 * @retval  0   OK
 */
int
xmldb_unlock_all(clicon_handle h, 
		 int           pid)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_unlock_all_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_unlock_all_fn(xh, pid);
 done:
    return retval;
}

/*! Check if database is locked
 * @param[in]    h   Clicon handle
 * @param[in]    db  Database
 * @retval -1    Error
 * @retval   0   Not locked
 * @retval  >0   Id of locker
  */
int 
xmldb_islocked(clicon_handle h, 
	       const char   *db)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_islocked_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_islocked_fn(xh, db);
 done:
    return retval;
}

/*! Check if db exists 
 * @param[in]  h   Clicon handle
 * @param[in]  db  Database
 * @retval -1  Error
 * @retval  0  No it does not exist
 * @retval  1  Yes it exists
 */
int 
xmldb_exists(clicon_handle h, 
	     const char   *db)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_exists_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_exists_fn(xh, db);
 done:
    return retval;
}

/*! Delete database. Remove file 
 * @param[in]  h   Clicon handle
 * @param[in]  db  Database
 * @retval -1  Error
 * @retval  0  OK
 */
int 
xmldb_delete(clicon_handle h, 
	     const char   *db)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_delete_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_delete_fn(xh, db);
 done:
    return retval;
}

/*! Create a database. Open database for writing.
 * @param[in]  h   Clicon handle
 * @param[in]  db  Database
 * @retval  0  OK
 * @retval -1  Error
 */
int 
xmldb_create(clicon_handle h, 
	     const char   *db)
{
    int               retval = -1;
    xmldb_handle      xh;
    struct xmldb_api *xa;

    if ((xa = clicon_xmldb_api_get(h)) == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (xa->xa_create_fn == NULL){
	clicon_err(OE_DB, 0, "No xmldb function");
	goto done;
    }
    if ((xh = clicon_xmldb_handle_get(h)) == NULL){
	clicon_err(OE_DB, 0, "Not connected to datastore plugin");
	goto done;
    }
    retval = xa->xa_create_fn(xh, db);
 done:
    return retval;
}
