/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * 
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <dlfcn.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <netinet/in.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

#include "clixon_backend_transaction.h"
#include "clixon_backend_plugin.h"
#include "clixon_backend_commit.h"

/*! Request plugins to reset system state
 *
 * The system 'state' should be the same as the contents of running_db
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @param[in]  db      Name of datastore
 * @retval     0       OK
 * @retval    -1       Error
 */
int
clixon_plugin_reset_one(clixon_plugin_t *cp,
                        clixon_handle  h,
                        char         *db)
{
    int         retval = -1;
    plgreset_t *fn;       /* callback */
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_reset) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, db) < 0) {
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (clixon_err_category() < 0)
                clixon_log(h, LOG_WARNING, "%s: Internal error: Reset callback in plugin: %s returned -1 but did not make a clixon_err call",
                           __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call all plugins reset callbacks
 *
 * The system 'state' should be the same as the contents of running_db
 * @param[in]  h       Clixon handle
 * @param[in]  db      Name of datastore
 * @retval     0       OK
 * @retval    -1       Error
 */
int
clixon_plugin_reset_all(clixon_handle h,
                        char         *db)
{
    int              retval = -1;
    clixon_plugin_t *cp = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    /* Loop through all plugins, call callbacks in each */
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (clixon_plugin_reset_one(cp, h, db) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call single plugin "pre-" daemonize callback
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @retval     0       OK
 * @retval    -1       Error
 */
static int
clixon_plugin_pre_daemon_one(clixon_plugin_t *cp,
                             clixon_handle  h)
{
    int          retval = -1;
    plgdaemon_t *fn;          /* Daemonize plugin callback function */
    void        *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_pre_daemon) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h) < 0) {
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (clixon_err_category() < 0)
                clixon_log(h, LOG_WARNING, "%s: Internal error: Pre-daemon callback in plugin:\
 %s returned -1 but did not make a clixon_err call",
                           __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call all plugins "pre-" daemonize callbacks
 *
 * This point in time is after "start" and before
 * before daemonization/fork,
 * It is not called if backend is started in daemon mode.
 * @param[in]  h       Clixon handle
 * @retval     0       OK
 * @retval    -1       Error
 */
int
clixon_plugin_pre_daemon_all(clixon_handle h)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    /* Loop through all plugins, call callbacks in each */
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (clixon_plugin_pre_daemon_one(cp, h) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call single plugin "post-" daemonize callback
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @retval     0       OK
 * @retval    -1       Error
 */
static int
clixon_plugin_daemon_one(clixon_plugin_t *cp,
                         clixon_handle  h)
{
    int          retval = -1;
    plgdaemon_t *fn;          /* Daemonize plugin callback function */
    void        *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_daemon) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h) < 0) {
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (clixon_err_category() < 0)
                clixon_log(h, LOG_WARNING, "%s: Internal error: Daemon callback in plugin: %s returned -1 but did not make a clixon_err call",
                           __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call all plugins "post-" daemonize callbacks
 *
 * This point in time is after "start" and after "pre-daemon" and
 * after daemonization/fork, ie when
 * daemon is in the background but before dropped privileges.
 * In case of foreground mode (-F) it is still called but no fork has occured.
 * @param[in]  h       Clixon handle
 * @retval     0       OK
 * @retval    -1       Error
 * @note Also called for non-background mode
 */
int
clixon_plugin_daemon_all(clixon_handle h)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    /* Loop through all plugins, call callbacks in each */
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (clixon_plugin_daemon_one(cp, h) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call single backend statedata callback
 *
 * Create an xml state tree (xret) for one callback only on the form:
 *   <config>...</config>,
 * call a user supplied function (ca_statedata) which can do two things:
 *  - Fill in state XML in the tree and return 0
 *  - Call cli_error() and return -1
 * In the former case, this function returns the state XML tree to the caller (which 
 * typically merges the tree with other state trees).
 * In the latter error case, this function returns 0 (invalid) to the caller with no tree
 * If a fatal error occurs in this function, -1 is returned.
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       clicon handle
 * @param[in]  nsc     namespace context for xpath
 * @param[in]  xpath   String with XPATH syntax. or NULL for all
 * @param[in]  pagmode List pagination mode
 * @param[in]  offset  Offset, for list pagination
 * @param[in]  limit   Limit, for list pagination
 * @param[out] remaining  Remaining elements (if limit is non-zero)
 * @param[out] xp      If retval=1, state tree created and returned: <config>...
 * @retval     1       OK if callback found (and called) xret is set
 * @retval     0       Statedata callback failed. no XML tree returned
 * @retval    -1       Fatal error
 */
static int
clixon_plugin_statedata_one(clixon_plugin_t *cp,
                            clixon_handle    h,
                            cvec            *nsc,
                            char            *xpath,
                            cxobj          **xp)
{
    int              retval = -1;
    plgstatedata_t  *fn;          /* Plugin statedata fn */
    cxobj           *x = NULL;
    void            *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_statedata) != NULL){
        if ((x = xml_new(DATASTORE_TOP_SYMBOL, NULL, CX_ELMNT)) == NULL)
            goto done;
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, nsc, xpath, x) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (clixon_err_category() < 0)
                clixon_log(h, LOG_WARNING, "%s: Internal error: State callback in plugin: %s returned -1 but did not make a clixon_err call",
                           __FUNCTION__, clixon_plugin_name_get(cp));
            goto fail;  /* Dont quit here on user callbacks */
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    if (xp && x)
        *xp = x;
    retval = 1;
 done:
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! Go through all backend statedata callbacks and collect state data
 *
 * This is internal system call, plugin is invoked (does not call) this function
 * Backend plugins can register 
 * @param[in]     h       clicon handle
 * @param[in]     yspec   Yang spec
 * @param[in]     nsc     Namespace context
 * @param[in]     xpath   String with XPATH syntax. or NULL for all
 * @param[in]     wdef    With-defaults parameter, see RFC 6243
 * @param[in,out] xret    State XML tree is merged with existing tree.
 * @retval        1       OK
 * @retval        0       Statedata callback failed (xret set with netconf-error)
 * @retval       -1       Error
 * @note xret can be replaced in this function
 */
int
clixon_plugin_statedata_all(clixon_handle   h,
                            yang_stmt      *yspec,
                            cvec           *nsc,
                            char           *xpath,
                            withdefaults_type wdef,
                            cxobj         **xret)
{
    int              retval = -1;
    int              ret;
    cxobj           *x = NULL;
    clixon_plugin_t *cp = NULL;
    cbuf            *cberr = NULL;
    cxobj           *xerr = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if ((ret = clixon_plugin_statedata_one(cp, h, nsc, xpath, &x)) < 0)
            goto done;
        if (ret == 0){
            if ((cberr = cbuf_new()) == NULL){
                clixon_err(OE_UNIX, errno, "cbuf_new");
                goto done;
            }
            /* error reason should be in clixon_err_reason */
            cprintf(cberr, "Internal error, state callback in plugin %s returned invalid XML: %s",
                    clixon_plugin_name_get(cp), clixon_err_reason());
            if (netconf_operation_failed_xml(&xerr, "application", cbuf_get(cberr)) < 0)
                goto done;
            xml_free(*xret);
            *xret = xerr;
            xerr = NULL;
            goto fail;
        }
        if (x == NULL)
            continue;
        if (xml_child_nr(x) == 0){
            xml_free(x);
            x = NULL;
            continue;
        }
        clixon_debug_xml(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, x, "%s %s STATE:", __FUNCTION__, clixon_plugin_name_get(cp));
        /* XXX: ret == 0 invalid yang binding should be handled as internal error */
        if ((ret = xml_bind_yang(h, x, YB_MODULE, yspec, &xerr)) < 0)
            goto done;
        if (ret == 0){
            if (clixon_netconf_internal_error(xerr,
                                              ". Internal error, state callback returned invalid XML from plugin: ",
                                              clixon_plugin_name_get(cp)) < 0)
                goto done;
            xml_free(*xret);
            *xret = xerr;
            xerr = NULL;
            goto fail;
        }
        if (xml_sort_recurse(x) < 0)
            goto done;
        /* Remove global defaults and empty non-presence containers */
        /* XXX: only for state data and according to with-defaults setting */
        if (xml_defaults_nopresence(x, 2) < 0)
            goto done;
        if (xpath_first(x, nsc, "%s", xpath) != NULL){
            if ((ret = netconf_trymerge(x, yspec, xret)) < 0)
                goto done;
            if (ret == 0)
                goto fail;
        }
        if (x){
            xml_free(x);
            x = NULL;
        }
    } /* while plugin */
    retval = 1;
 done:
    if (xerr)
        xml_free(xerr);
    if (cberr)
        cbuf_free(cberr);
    if (x)
        xml_free(x);
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! Lock database status has changed status
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h    Clixon handle
 * @param[in]  db   Database name (eg "running")
 * @param[in]  lock Lock status: 0: unlocked, 1: locked
 * @param[in]  id   Session id (of locker/unlocker)
 * @retval     0    OK
 * @retval    -1    Fatal error
 */
static int
clixon_plugin_lockdb_one(clixon_plugin_t *cp,
                         clixon_handle    h,
                         char            *db,
                         int              lock,
                         int              id)
{
    int          retval = -1;
    plglockdb_t *fn;          /* Plugin statedata fn */
    void        *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_lockdb) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, db, lock, id) < 0)
            goto done;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Lock database status has changed status
 *
 * @param[in]  h    Clixon handle
 * @param[in]  db   Database name (eg "running")
 * @param[in]  lock Lock status: 0: unlocked, 1: locked
 * @param[in]  id   Session id (of locker/unlocker)
 * @retval     0    OK
 * @retval    -1    Fatal error
*/
int
clixon_plugin_lockdb_all(clixon_handle h,
                         char         *db,
                         int           lock,
                         int           id
                         )

{
    int              retval = -1;
    clixon_plugin_t *cp = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (clixon_plugin_lockdb_one(cp, h, db, lock, id) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Traverse state data callbacks
 * 
 * @param[in]  h      Clixon handle
 * @param[in]  xpath  Registered XPath using canonical prefixes
 * @retval     1      OK
 * @retval    -1      Error
 */
int
clixon_pagination_cb_call(clixon_handle h,
                          char        *xpath,
                          int          locked,
                          uint32_t     offset,
                          uint32_t     limit,
                          cxobj       *xstate)
{
    int                 retval = -1;
    pagination_data_t   pd;
    dispatcher_entry_t *htable = NULL;

    pd.pd_offset = offset;
    pd.pd_limit = limit;
    pd.pd_locked = locked;
    pd.pd_xstate = xstate;
    clicon_ptr_get(h, "pagination-entries", (void**)&htable);
    if (htable && dispatcher_call_handlers(htable, h, xpath, &pd) < 0)
        goto done;
    retval = 1; // XXX 0?
 done:
    return retval;
}

/*! Register a state data callback
 *
 * @param[in]  h      Clixon handle
 * @param[in]  fn     Callback 
 * @param[in]  xpath  Registered XPath using canonical prefixes
 * @param[in]  arg    Domain-specific argument to send to callback
 * @retval     0      OK
 * @retval    -1      Error
 */
int
clixon_pagination_cb_register(clixon_handle    h,
                              handler_function fn,
                              char            *xpath,
                              void            *arg)
{
    int                       retval = -1;
    dispatcher_definition     x = {xpath, fn, arg};
    dispatcher_entry_t       *htable = NULL;

    clicon_ptr_get(h, "pagination-entries", (void**)&htable);
    if (dispatcher_register_handler(&htable, &x) < 0){
        clixon_err(OE_PLUGIN, errno, "dispatcher");
        goto done;
    }
    if (clicon_ptr_set(h, "pagination-entries", htable) < 0)
        goto done;
    retval = 0;
 done:
    return retval;
}

/*! Free pagination callback structure
 *
 * @param[in]  h      Clixon handle
 */
int
clixon_pagination_free(clixon_handle h)
{
    dispatcher_entry_t       *htable = NULL;

    clicon_ptr_get(h, "pagination-entries", (void**)&htable);
    if (htable)
        dispatcher_free(htable);
    return 0;
}

/*! Create and initialize a validate/commit transaction 
 *
 * @retval  td     New alloced transaction, 
 * @retval  NULL   Error
 * @see transaction_free  which deallocates the returned handle
 */
transaction_data_t *
transaction_new(void)
{
    transaction_data_t *td;
    static uint64_t     id = 0; /* Global transaction id */

    if ((td = malloc(sizeof(*td))) == NULL){
        clixon_err(OE_CFG, errno, "malloc");
        return NULL;
    }
    memset(td, 0, sizeof(*td));
    td->td_id = id++;
    return td;
}

/*! Free transaction structure 
 *
 * @param[in]  td      Transaction data will be deallocated after the call
 */
int
transaction_free(transaction_data_t *td)
{
    if (td->td_src)
        xml_free(td->td_src);
    if (td->td_target)
        xml_free(td->td_target);
    if (td->td_dvec)
        free(td->td_dvec);
    if (td->td_avec)
        free(td->td_avec);
    if (td->td_scvec)
        free(td->td_scvec);
    if (td->td_tcvec)
        free(td->td_tcvec);
    free(td);
    return 0;
}

/*! Call single plugin transaction_begin() before a validate/commit.
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_begin_one(clixon_plugin_t    *cp,
                             clixon_handle       h,
                             transaction_data_t *td)
{
    int         retval = -1;
    trans_cb_t *fn;
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_trans_begin) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, (transaction_data)td) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (!clixon_err_category()) /* sanity: log if clixon_err() is not called ! */
                clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' callback does not make clixon_err call on error",
                       __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/* The plugin_transaction routines need access to struct plugin which is local to this file */

/*! Call transaction_begin() in all plugins before a validate/commit.
 *
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error: one of the plugin callbacks returned error
 */
int
plugin_transaction_begin_all(clixon_handle       h,
                             transaction_data_t *td)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (plugin_transaction_begin_one(cp, h, td) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call single plugin transaction_validate() in a validate/commit transaction
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_validate_one(clixon_plugin_t    *cp,
                                clixon_handle       h,
                                transaction_data_t *td)
{
    int         retval = -1;
    trans_cb_t *fn;
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_trans_validate) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, (transaction_data)td) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (!clixon_err_category()) /* sanity: log if clixon_err() is not called ! */
                clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' callback does not make clixon_err call on error",
                       __FUNCTION__, clixon_plugin_name_get(cp));

            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call transaction_validate callbacks in all backend plugins
 *
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK. Validation succeeded in all plugins
 * @retval    -1       Error: one of the plugin callbacks returned validation fail
 */
int
plugin_transaction_validate_all(clixon_handle       h,
                                transaction_data_t *td)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (plugin_transaction_validate_one(cp, h, td) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call single plugin transaction_complete() in a validate/commit transaction
 *
 * complete is called after validate (before commit)
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_complete_one(clixon_plugin_t    *cp,
                                clixon_handle       h,
                                transaction_data_t *td)
{
    int         retval = -1;
    trans_cb_t *fn;
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_trans_complete) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, (transaction_data)td) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (!clixon_err_category()) /* sanity: log if clixon_err() is not called ! */
                clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' callback does not make clixon_err call on error",
                       __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call transaction_complete() in all plugins after validation (before commit)
 *
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error: one of the plugin callbacks returned error
 * @note Call plugins which have commit dependencies?
 * @note Rename to transaction_complete?
 */
int
plugin_transaction_complete_all(clixon_handle       h,
                                transaction_data_t *td)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (plugin_transaction_complete_one(cp, h, td) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Revert a commit
 *
 * @param[in]  h   CLICON handle
 * @param[in]  td  Transaction data
 * @param[in]  nr  The plugin where an error occured. 
 * @retval     0       OK
 * @retval    -1       Error
 * The revert is made in plugin before this one. Eg if error occurred in
 * plugin 2, then the revert will be made in plugins 1 and 0.
 */
static int
plugin_transaction_revert_all(clixon_handle       h,
                              transaction_data_t *td,
                              int                 nr)
{
    int                retval = 0;
    clixon_plugin_t     *cp = NULL;
    trans_cb_t        *fn;

    while ((cp = clixon_plugin_each_revert(h, cp, nr)) != NULL) {
        if ((fn = clixon_plugin_api_get(cp)->ca_trans_revert) == NULL)
            continue;
        if ((retval = fn(h, (transaction_data)td)) < 0){
            clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' trans_revert callback failed",
                           __FUNCTION__, clixon_plugin_name_get(cp));
                break;
        }
    }
    return retval; /* ignore errors */
}


/*! Call single plugin transaction_commit() in a commit transaction
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_commit_one(clixon_plugin_t      *cp,
                              clixon_handle       h,
                              transaction_data_t *td)
{
    int         retval = -1;
    trans_cb_t *fn;
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_trans_commit) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, (transaction_data)td) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (!clixon_err_category()) /* sanity: log if clixon_err() is not called ! */
                clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' callback does not make clixon_err call on error",
                       __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call transaction_commit callbacks in all backend plugins
 *
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error: one of the plugin callbacks returned error
 * If any of the commit callbacks fail by returning -1, a revert of the 
 * transaction is tried by calling the commit callbacsk with reverse arguments
 * and in reverse order.
 */
int
plugin_transaction_commit_all(clixon_handle       h,
                              transaction_data_t *td)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;
    int            i=0;

    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        i++;
        if (plugin_transaction_commit_one(cp, h, td) < 0){
            /* Make an effort to revert transaction */
            plugin_transaction_revert_all(h, td, i-1);
            goto done;
        }
    }
    retval = 0;
 done:
    return retval;
}

/*! Call single plugin transaction_commit_done() in a commit transaction
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_commit_done_one(clixon_plugin_t    *cp,
                                   clixon_handle       h,
                                   transaction_data_t *td)
{
    int         retval = -1;
    trans_cb_t *fn;
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_trans_commit_done) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, (transaction_data)td) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (!clixon_err_category()) /* sanity: log if clixon_err() is not called ! */
                clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' callback does not make clixon_err call on error",
                       __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call transaction_commit_done callbacks in all backend plugins
 *
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error: one of the plugin callbacks returned error
 * @note no revert is done
 */
int
plugin_transaction_commit_done_all(clixon_handle       h,
                                   transaction_data_t *td)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (plugin_transaction_commit_done_one(cp, h, td) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call single plugin transaction_end() in a commit/validate transaction
 *
 * @param[in]  cp      Plugin handle
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_end_one(clixon_plugin_t    *cp,
                           clixon_handle       h,
                           transaction_data_t *td)
{
    int         retval = -1;
    trans_cb_t *fn;
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_trans_end) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, (transaction_data)td) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (!clixon_err_category()) /* sanity: log if clixon_err() is not called ! */
                clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' callback does not make clixon_err call on error",
                       __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call transaction_end() in all plugins after a successful commit.
 *
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_end_all(clixon_handle h,
                           transaction_data_t *td)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (plugin_transaction_end_one(cp, h, td) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

int
plugin_transaction_abort_one(clixon_plugin_t    *cp,
                             clixon_handle       h,
                             transaction_data_t *td)
{
    int         retval = -1;
    trans_cb_t *fn;
    void       *wh = NULL;

    if ((fn = clixon_plugin_api_get(cp)->ca_trans_abort) != NULL){
        wh = NULL;
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
        if (fn(h, (transaction_data)td) < 0){
            if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
                goto done;
            if (!clixon_err_category()) /* sanity: log if clixon_err() is not called ! */
                clixon_log(h, LOG_NOTICE, "%s: Plugin '%s' callback does not make clixon_err call on error",
                       __FUNCTION__, clixon_plugin_name_get(cp));
            goto done;
        }
        if (clixon_resource_check(h, &wh, clixon_plugin_name_get(cp), __FUNCTION__) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Call transaction_abort() in all plugins after a failed validation/commit.
 *
 * @param[in]  h       Clixon handle
 * @param[in]  td      Transaction data
 * @retval     0       OK
 * @retval    -1       Error
 */
int
plugin_transaction_abort_all(clixon_handle       h,
                             transaction_data_t *td)
{
    int            retval = -1;
    clixon_plugin_t *cp = NULL;

    clixon_debug(CLIXON_DBG_CLIENT | CLIXON_DBG_DETAIL, "%s", __FUNCTION__);
    while ((cp = clixon_plugin_each(h, cp)) != NULL) {
        if (plugin_transaction_abort_one(cp, h, td) < 0)
            ; /* dont abort on error */
    }
    retval = 0;
    return retval;
}
