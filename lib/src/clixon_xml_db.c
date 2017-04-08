/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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
#include <fcgi_stdio.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <curl/curl.h>
#include <libgen.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_xml.h"
#include "clixon_xml_db.h"

static struct xmldb_api *_xa_api = NULL;

/*! Load a specific plugin, call its init function and add it to plugins list
 * If init function fails (not found, wrong version, etc) print a log and dont
 * add it.
 * @param[in]  name      Name of plugin
 * @param[in]  filename  Actual filename with path
 * @param[out] plugin    Plugin data structure for invoking. Dealloc with free
 */
int 
xmldb_plugin_load(char *filename)
{
    int                      retval = -1;
    char                    *dlerrcode;
    plugin_init_t           *initfun;
    void                    *handle = NULL;
    char                    *error;

    dlerror();    /* Clear any existing error */
    if ((handle = dlopen(filename, RTLD_NOW|RTLD_GLOBAL)) == NULL) {
        error = (char*)dlerror();
	clicon_err(OE_PLUGIN, errno, "dlopen: %s\n", error ? error : "Unknown error");	
	goto done;
    }
    /* Try v1 */
    initfun = dlsym(handle, XMLDB_PLUGIN_INIT_FN);
    if ((dlerrcode = (char*)dlerror()) != NULL) {
	clicon_log(LOG_WARNING, "Error when loading init function %s: %s",
		   XMLDB_PLUGIN_INIT_FN, dlerrcode); 
	goto fail;
    }
    if ((_xa_api = initfun(XMLDB_API_VERSION)) == NULL) {
	clicon_log(LOG_WARNING, "%s: failed when running init function %s: %s", 
		   filename, XMLDB_PLUGIN_INIT_FN, errno?strerror(errno):"");
	goto fail;
    }
    if (_xa_api->xa_version != XMLDB_API_VERSION){
	clicon_log(LOG_WARNING, "%s: Unexpected plugin version number: %d", 
		   filename, _xa_api->xa_version);
	goto fail;
    }
    if (_xa_api->xa_magic != XMLDB_API_MAGIC){
	clicon_log(LOG_WARNING, "%s: Wrong plugin magic number: %x", 
		   filename, _xa_api->xa_magic);
	goto fail;
    }
    clicon_log(LOG_WARNING, "xmldb plugin %s loaded", filename);
    retval = 0;
 done:
    if (retval < 0 && handle)
	dlclose(handle);
    return retval;
 fail: /* plugin load failed, continue */
    retval = 0;
    goto done;
}

int 
xmldb_get(clicon_handle h, char *db, char *xpath,
	      cxobj **xtop, cxobj ***xvec, size_t *xlen)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_get_fn &&
	_xa_api->xa_get_fn(h, db, xpath, xtop, xvec, xlen) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_put(clicon_handle h, char *db, enum operation_type op, 
	      char *api_path, cxobj *xt)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_put_fn &&
	_xa_api->xa_put_fn(h, db, op, api_path, xt) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_dump(FILE *f, char *dbfilename, char *rxkey)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_dump_fn &&
	_xa_api->xa_dump_fn(f, dbfilename, rxkey) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_copy(clicon_handle h, char *from, char *to)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_copy_fn &&
	_xa_api->xa_copy_fn(h, from, to) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_lock(clicon_handle h, char *db, int pid)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_lock_fn &&
	_xa_api->xa_lock_fn(h, db, pid) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_unlock(clicon_handle h, char *db, int pid)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_unlock_fn &&
	_xa_api->xa_unlock_fn(h, db, pid) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int
xmldb_unlock_all(clicon_handle h, int pid)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_unlock_all_fn &&
	_xa_api->xa_unlock_all_fn(h, pid) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_islocked(clicon_handle h, char *db)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_islocked_fn &&
	_xa_api->xa_islocked_fn(h, db) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_exists(clicon_handle h, char *db)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_exists_fn &&
	_xa_api->xa_exists_fn(h, db) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_delete(clicon_handle h, char *db)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_delete_fn &&
	_xa_api->xa_delete_fn(h, db) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

int 
xmldb_init(clicon_handle h, char *db)
{
    int retval = -1;

    if (_xa_api == NULL){
	clicon_err(OE_DB, 0, "No xmldb plugin");
	goto done;
    }
    if (_xa_api->xa_init_fn &&
	_xa_api->xa_init_fn(h, db) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}
