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
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

  * The example have the following optional arguments that you can pass as 
  * argc/argv after -- in clixon_backend:
  *  -a <..> Register callback for this yang action
  *  -m <yang> Mount this yang on mountpoint
  *  -M <namespace> Namespace of mountpoint, note both -m and -M must exist
  *  -n  Notification streams example
  *  -r  enable the reset function 
  *  -s  enable the state function
  *  -S <file>  read state data from file, otherwise construct it programmatically (requires -s)
  *  -i  read state file on init not by request for optimization (requires -sS <file>)
  *  -u  enable upgrade function - auto-upgrade testing
  *  -U  general-purpose upgrade
  *  -t  enable transaction logging (call syslog for every transaction)
  *  -V <xpath> Failing validate and commit if <xpath> is present (synthetic error)
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <syslog.h>
#include <fcntl.h>
#include <sys/time.h>

/* cligen */
#include <cligen/cligen.h>

/* Clixon library functions. */
#include <clixon/clixon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clixon/clixon_backend.h>

/* Command line options to be passed to getopt(3) */
#define BACKEND_EXAMPLE_OPTS "a:m:M:n:rsS:x:iuUtV:"

/* Enabling this improves performance in tests, but there may trigger the "double XPath"
 * problem.
 * Disabling it makes perf go down but makes it safe for "double XPath"
 */
#define _STATEFILTER

/*! Yang action
 *
 * Start backend with -- -a <instance-id>
 * where instance-id points to an action node in some YANG
 * Hard-coded to action "reset" from RFC7950 7.15
 */
static char *_action_instanceid = NULL;

/*! Yang schema mount
 *
 * Start backend with -- -m <yang> -M <namespace>
 * Mount this yang on mountpoint
 * Note module-set hard-coded to "mylabel"
 */
static char *_mount_yang = NULL;
static char *_mount_namespace = NULL;

/*! Notification stream
 *
 * Enable notification streams for netconf/restconf 
 * Start backend with -- -n <sec>
 * where <sec> is period of stream
 */
static int _notification_stream_s = 0;

/*! Variable to control if reset code is run.
 *
 * The reset code inserts "extra XML" which assumes ietf-interfaces is
 * loaded, and this is not always the case.
 * Start backend with -- -r
 */
static int _reset = 0;

/*! Variable to control if state code is run
 *
 * The state code adds extra non-config data
 * Start backend with -- -s
 */
static int _state = 0;

/*! File where state XML is read from, if _state is true -- -sS <file>
 *
 * Primarily for testing
 * Start backend with -- -sS <file>
 */
static char *_state_file = NULL;

/*! XPath to register for pagination state XML from file,
 *
 * if _state is true -- -sS <file> -x <xpath>
 * Primarily for testing
 * Start backend with -- -sS <file> -x <xpath>
 */
static char *_state_xpath = NULL;

/*! Read state file init on startup instead of on request
 *
 * Primarily for testing: -i
 * Start backend with -- -siS <file>
 */
static int _state_file_cached = 0;

/*! Cache control of read state file pagination example,
 *
 * keep xml tree cache as long as db is locked
 */
static cxobj *_state_xml_cache = NULL; /* XML cache */
static int _state_file_transaction = 0;

/*! Variable to control module-specific upgrade callbacks.
 *
 * If set, call test-case for upgrading ietf-interfaces, otherwise call 
 * auto-upgrade
 * Start backend with -- -u
 */
static int _module_upgrade = 0;

/*! Variable to control general-purpose upgrade callbacks.
 *
 * Start backend with -- -U
 */
static int _general_upgrade = 0;

/*! Variable to control transaction logging (for debug)
 *
 * If set, call syslog for every transaction callback 
 * Start backend with -- -t
 */
static int _transaction_log = 0;

/*! Variable to trigger validation/commit errors (synthetic errors) for tests
 *
 * XPath to trigger validation error, ie if the XPath matches, then validate fails
 * This is to make tests where a transaction fails midway and aborts/reverts the transaction.
 * Start backend with -- -V <xpath>
 * Note that the second backend plugin has a corresponding -v <xpath> to do the same thing
 */
static char *_validate_fail_xpath = NULL;

/*! Sub state variable to fail on validate/commit (not configured)
 *
 * Obscure, but a way to first trigger a validation error, next time to trigger a commit error
 */
static int   _validate_fail_toggle = 0; /* fail at validate and commit */

/* forward */
static int example_stream_timer_setup(clixon_handle h, int sec);

int
main_begin(clixon_handle    h,
           transaction_data td)
{
    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

/*! This is called on validate (and commit). Check validity of candidate
 */
int
main_validate(clixon_handle    h,
              transaction_data td)
{
    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    if (_validate_fail_xpath){
        if (_validate_fail_toggle==0 &&
            xpath_first(transaction_target(td), NULL, "%s", _validate_fail_xpath)){
            _validate_fail_toggle = 1; /* toggle if triggered */
            clixon_err(OE_XML, 0, "User error");
            return -1; /* induce fail */
        }
    }
    return 0;
}

int
main_complete(clixon_handle    h,
              transaction_data td)
{
    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

/*! This is called on commit. Identify modifications and adjust machine state
 */
int
main_commit(clixon_handle    h,
            transaction_data td)
{
    cxobj  *target = transaction_target(td); /* wanted XML tree */
    cxobj **vec = NULL;
    int     i;
    size_t  len;
    cvec   *nsc = NULL;

    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    if (_validate_fail_xpath){
        if (_validate_fail_toggle==1 &&
            xpath_first(transaction_target(td), NULL, "%s", _validate_fail_xpath)){
            _validate_fail_toggle = 0; /* toggle if triggered */
            clixon_err(OE_XML, 0, "User error");
            return -1; /* induce fail */
        }
    }

    /* Create namespace context for xpath */
    if ((nsc = xml_nsctx_init(NULL, "urn:ietf:params:xml:ns:yang:ietf-interfaces")) == NULL)
        goto done;

    /* Get all added i/fs */
    if (xpath_vec_flag(target, nsc, "//interface", XML_FLAG_ADD, &vec, &len) < 0)
        return -1;
    if (clixon_debug_get())
        for (i=0; i<len; i++)             /* Loop over added i/fs */
            xml_print(stdout, vec[i]); /* Print the added interface */
  done:
    if (nsc)
        xml_nsctx_free(nsc);
    if (vec)
        free(vec);
    return 0;
}

int
main_commit_done(clixon_handle    h,
                 transaction_data td)
{
    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
main_revert(clixon_handle    h,
            transaction_data td)
{
    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
main_end(clixon_handle    h,
         transaction_data td)
{
    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
main_abort(clixon_handle    h,
           transaction_data td)
{
    if (_transaction_log)
        transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

/*! Routing example notification timer handler. Here is where the periodic action is 
 */
static int
example_stream_timer(int   fd,
                     void *arg)
{
    int                    retval = -1;
    clixon_handle          h = (clixon_handle)arg;

    /* XXX Change to actual netconf notifications and namespace */
    if (stream_notify(h, "EXAMPLE", "<event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>") < 0)
        goto done;
    if (example_stream_timer_setup(h, _notification_stream_s) < 0)
        goto done;
    retval = 0;
 done:
    return retval;
}

/*! Set up example stream notification timer 
 *
 * @param[in]  h  Clixon handle
 * @param[in]  s  Timeout period in seconds
 */
static int
example_stream_timer_setup(clixon_handle h,
                           int           sec)
{
    struct timeval t;

    gettimeofday(&t, NULL);
    t.tv_sec += sec;
    return clixon_event_reg_timeout(t, example_stream_timer, h, "example stream timer");
}

/*! Smallest possible RPC declaration for test 
 *
 * Yang/XML:
 * If the RPC operation invocation succeeded and no output parameters
 * are returned, the <rpc-reply> contains a single <ok/> element defined
 * in [RFC6241].
 */
static int
empty_rpc(clixon_handle h,            /* Clixon handle */
          cxobj        *xe,           /* Request: <rpc><xn></rpc> */
          cbuf         *cbret,        /* Reply eg <rpc-reply>... */
          void         *arg,          /* client_entry */
          void         *regarg)       /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply xmlns=\"%s\"><ok/></rpc-reply>", NETCONF_BASE_NAMESPACE);
    return 0;
}

/*! More elaborate example RPC for testing
 *
 * The RPC returns the incoming parameters
 */
static int
example_rpc(clixon_handle h,            /* Clixon handle */
            cxobj        *xe,           /* Request: <rpc><xn></rpc> */
            cbuf         *cbret,        /* Reply eg <rpc-reply>... */
            void         *arg,          /* client_entry */
            void         *regarg)       /* Argument given at register */
{
    int    retval = -1;
    cxobj *x = NULL;
    cxobj *xp;
    char  *namespace;
    char  *msgid;

    /* get namespace from rpc name, return back in each output parameter */
    if ((namespace = xml_find_type_value(xe, NULL, "xmlns", CX_ATTR)) == NULL){
        clixon_err(OE_XML, ENOENT, "No namespace given in rpc %s", xml_name(xe));
        goto done;
    }
    cprintf(cbret, "<rpc-reply xmlns=\"%s\"", NETCONF_BASE_NAMESPACE);
    if ((xp = xml_parent(xe)) != NULL &&
        (msgid = xml_find_value(xp, "message-id"))){
        cprintf(cbret, " message-id=\"%s\"", msgid);
    }
    cprintf(cbret, ">");
    if (!xml_child_nr_type(xe, CX_ELMNT))
        cprintf(cbret, "<ok/>");
    else {
        while ((x = xml_child_each(xe, x, CX_ELMNT)) != NULL) {
            if (xmlns_set(x, NULL, namespace) < 0)
                goto done;
        }
        if (clixon_xml2cbuf(cbret, xe, 0, 0, NULL, -1, 1) < 0)
            goto done;
    }
    cprintf(cbret, "</rpc-reply>");
    retval = 0;
 done:
    return retval;
}

/*! This will be called as a hook right after the original system copy-config
 */
static int
example_copy_extra(clixon_handle h,            /* Clixon handle */
                   cxobj        *xe,           /* Request: <rpc><xn></rpc> */
                   cbuf         *cbret,        /* Reply eg <rpc-reply>... */
                   void         *arg,          /* client_entry */
                   void         *regarg)       /* Argument given at register */
{
    int    retval = -1;

    //    fprintf(stderr, "%s\n", __FUNCTION__);
    retval = 0;
    // done:
    return retval;
}

/*! Action callback, example from RFC7950 7.15
 *
 * @note callback is hardcoded C, while registration is controlled by -- -a option
 */
static int
example_action_reset(clixon_handle h,            /* Clixon handle */
                     cxobj        *xe,           /* Request: <rpc><xn></rpc> */
                     cbuf         *cbret,        /* Reply eg <rpc-reply>... */
                     void         *arg,          /* client_entry */
                     void         *regarg)       /* Argument given at register */
{
    int    retval = -1;
    char *reset_at;

    if ((reset_at = xml_find_body(xe, "reset-at")) != NULL)
        /* Just copy input to output */
        cprintf(cbret, "<rpc-reply xmlns=\"%s\"><reset-finished-at xmlns=\"urn:example:server-farm\">%s</reset-finished-at></rpc-reply>",
                NETCONF_BASE_NAMESPACE, reset_at);
    retval = 0;
    // done:
    return retval;
}

/*! Called to get state data from plugin by programmatically adding state
 *
 * @param[in]    h        Clixon handle
 * @param[in]    nsc      External XML namespace context, or NULL
 * @param[in]    xpath    String with XPATH syntax. or NULL for all
 * @param[out]   xstate   XML tree, <config/> on entry. 
 * @retval       0        OK
 * @retval      -1        Error
 * @see xmldb_get
 * @note this example code returns requires this yang snippet:
       container state {
         config false;
         description "state data for example application";
         leaf-list op {
            type string;
         }
       }
 * This yang snippet is present in clixon-example.yang for example.
 * @see example_statefile  where state is read from file and also pagination
 */
int
example_statedata(clixon_handle   h,
                  cvec           *nsc,
                  char           *xpath,
                  cxobj          *xstate)
{
    int        retval = -1;
    cxobj    **xvec = NULL;
    size_t     xlen = 0;
    cbuf      *cb = NULL;
    int        i;
    cxobj     *xt = NULL;
    char      *name;
    cvec      *nsc1 = NULL;
    yang_stmt *yspec = NULL;
    int        ret;

    if (!_state)
        goto ok;
    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    yspec = clicon_dbspec_yang(h);
    /* Example of statedata, in this case merging state data with 
     * state information. In this case adding dummy interface operation state
     * to configured interfaces.
     * Get config according to xpath */
    if ((nsc1 = xml_nsctx_init(NULL, "urn:ietf:params:xml:ns:yang:ietf-interfaces")) == NULL)
        goto done;
    if ((ret = xmldb_get0(h, "running", YB_MODULE, nsc1, "/interfaces/interface/name", 1, 0, &xt, NULL, NULL)) < 0)
        goto done;
    if (ret == 0){
        clixon_err(OE_DB, 0, "Error when reading from running, unknown error");
        goto done;
    }
    if (xpath_vec(xt, nsc1, "/interfaces/interface/name", &xvec, &xlen) < 0)
        goto done;
    if (xlen){
        cprintf(cb, "<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">");
        for (i=0; i<xlen; i++){
            name = xml_body(xvec[i]);
            cprintf(cb, "<interface xmlns:ex=\"urn:example:clixon\"><name>%s</name><type>ex:eth</type><oper-status>up</oper-status>", name);
            cprintf(cb, "<ex:my-status><ex:int>42</ex:int><ex:str>foo</ex:str></ex:my-status>");
            cprintf(cb, "</interface>");
        }
        cprintf(cb, "</interfaces>");
        if (clixon_xml_parse_string(cbuf_get(cb), YB_NONE, NULL, &xstate, NULL) < 0)
            goto done;
    }
    /* State in test_yang.sh , test_restconf.sh and test_order.sh */
    if (yang_find_module_by_namespace(yspec, "urn:example:clixon") != NULL){
        if (clixon_xml_parse_string("<state xmlns=\"urn:example:clixon\">"
                                    "<op>42</op>"
                                    "<op>41</op>"
                                    "<op>43</op>" /* should not be ordered */
                                    "</state>",
                                    YB_NONE,
                                    NULL, &xstate, NULL) < 0)
            goto done; /* For the case when urn:example:clixon is not loaded */
    }
    /* Event state from RFC8040 Appendix B.3.1 
     * Note: (1) order is by-system so is different, 
     *       (2) event-count is XOR on name, so is not 42 and 4
     */
    if (yang_find_module_by_namespace(yspec, "urn:example:events") != NULL){
        cbuf_reset(cb);
        cprintf(cb, "<events xmlns=\"urn:example:events\">");
        cprintf(cb, "<event><name>interface-down</name><event-count>90</event-count></event>");
        cprintf(cb, "<event><name>interface-up</name><event-count>77</event-count></event>");
        cprintf(cb, "</events>");
        if (clixon_xml_parse_string(cbuf_get(cb), YB_NONE, NULL, &xstate, NULL) < 0)
            goto done;
    }
 ok:
    retval = 0;
 done:
    if (nsc1)
        xml_nsctx_free(nsc1);
    if (xt)
        xml_free(xt);
    if (cb)
        cbuf_free(cb);
    if (xvec)
        free(xvec);
    return retval;
}

/*! Called to get state data from plugin by reading a file, also pagination
 *
 * The example shows how to read and parse a state XML file, (which is cached in the -i case).
 * Return the requested xpath / pagination xstate by copying from the parsed state XML file
 * @param[in]    h        Clixon handle
 * @param[in]    nsc      External XML namespace context, or NULL
 * @param[in]    xpath    String with XPATH syntax. or NULL for all
 * @param[out]   xstate   XML tree, <config/> on entry. Copy to this
 * @retval       0        OK
 * @retval      -1        Error
 * @see xmldb_get
 * @see example_statefile  where state is programmatically added
 */
int
example_statefile(clixon_handle     h,
                  cvec             *nsc,
                  char             *xpath,
                  cxobj            *xstate)
{
    int        retval = -1;
    cxobj    **xvec = NULL;
    cxobj     *xt = NULL;
    yang_stmt *yspec = NULL;
    FILE      *fp = NULL;
    int        ret;
#ifdef _STATEFILTER
    size_t     xlen = 0;
    int        i;
    cxobj     *x1;
#endif

    /* If -S is set, then read state data from file */
    if (!_state || !_state_file)
        goto ok;
    yspec = clicon_dbspec_yang(h);
    /* Read state file if either not cached, or the cache is NULL */
    if (_state_file_cached == 0 ||
        _state_xml_cache == NULL){
        if ((fp = fopen(_state_file, "r")) == NULL){
            clixon_err(OE_UNIX, errno, "open(%s)", _state_file);
            goto done;
        }
        if ((xt = xml_new("config", NULL, CX_ELMNT)) == NULL)
            goto done;
        if ((ret = clixon_xml_parse_file(fp, YB_MODULE, yspec, &xt, NULL)) < 0)
            goto done;
        if (_state_file_cached)
            _state_xml_cache = xt;
    }
    if (_state_file_cached)
        xt = _state_xml_cache;
#ifdef _STATEFILTER
    if (xpath_vec(xt, nsc, "%s", &xvec, &xlen, xpath) < 0)
        goto done;
    /* Mark elements to copy:
     * For every node found in x0, mark the tree as changed 
     */
    for (i=0; i<xlen; i++){
        if ((x1 = xvec[i]) == NULL)
            break;
        xml_flag_set(x1, XML_FLAG_MARK);
        xml_apply_ancestor(x1, (xml_applyfn_t*)xml_flag_set, (void*)XML_FLAG_CHANGE);
    }
    /* Copy the marked elements: 
     * note is yang-aware for copying of keys which means XML must be bound 
     */
    if (xml_copy_marked(xt, xstate) < 0)
        goto done;
    /* Unmark original tree */
    if (xml_apply(xt, CX_ELMNT, (xml_applyfn_t*)xml_flag_reset, (void*)(XML_FLAG_MARK|XML_FLAG_CHANGE)) < 0)
        goto done;
    /* Unmark returned state tree */
    if (xml_apply(xstate, CX_ELMNT, (xml_applyfn_t*)xml_flag_reset, (void*)(XML_FLAG_MARK|XML_FLAG_CHANGE)) < 0)
        goto done;
#else
    if (xml_copy(xt, xstate) < 0)
        goto done;
#endif
    if (_state_file_cached)
        xt = NULL; /* ensure cache is not cleared */
 ok:
    retval = 0;
 done:
    if (fp)
        fclose(fp);
    if (xt)
        xml_free(xt);
    if (xvec)
        free(xvec);
    return retval;
}

/*! Example of state pagination callback and how to use pagination_data
 *
 * @param[in]  h        Generic handler
 * @param[in]  xpath    Registered XPath using canonical prefixes
 * @param[in]  userargs Per-call user arguments
 * @param[in]  arg      Per-path user argument (at register time)
 */
int
example_pagination(void            *h0,
                   char            *xpath,
                   pagination_data  pd,
                   void            *arg)
{
    int           retval = -1;
    clixon_handle h = (clixon_handle)h0;
    int           locked;
    uint32_t      offset;
    uint32_t      limit;
    cxobj        *xstate;
    cxobj       **xvec = NULL;
    size_t        xlen = 0;
    int           i;
    cxobj        *xt = NULL;
    yang_stmt    *yspec = NULL;
    FILE         *fp = NULL;
    cxobj        *x1;
    uint32_t      lower;
    uint32_t      upper;
    int           ret;
    cvec         *nsc = NULL;

    /* If -S is set, then read state data from file */
    if (!_state || !_state_file)
        goto ok;

    locked = pagination_locked(pd);
    offset = pagination_offset(pd);
    limit = pagination_limit(pd);
    xstate = pagination_xstate(pd);

    /* Get canonical namespace context */
    if (xml_nsctx_yangspec(yspec, &nsc) < 0)
        goto done;
    yspec = clicon_dbspec_yang(h);
    /* Read state file if either not cached, or the cache is NULL */
    if (_state_file_cached == 0 ||
        _state_xml_cache == NULL){
        if ((fp = fopen(_state_file, "r")) == NULL){
            clixon_err(OE_UNIX, errno, "open(%s)", _state_file);
            goto done;
        }
        if ((xt = xml_new("config", NULL, CX_ELMNT)) == NULL)
            goto done;
        if ((ret = clixon_xml_parse_file(fp, YB_MODULE, yspec, &xt, NULL)) < 0)
            goto done;
        if (_state_file_cached)
            _state_xml_cache = xt;
    }
    if (_state_file_cached)
        xt = _state_xml_cache;
    if (xpath_vec(xt, nsc, "%s", &xvec, &xlen, xpath) < 0)
        goto done;
    lower = offset;
    if (limit == 0)
        upper = xlen;
    else{
        if ((upper = offset+limit) > xlen)
            upper = xlen;
    }
    /* Mark elements to copy:
     * For every node found in x0, mark the tree as changed 
     */
    for (i=lower; i<upper; i++){
        if ((x1 = xvec[i]) == NULL)
            break;
        xml_flag_set(x1, XML_FLAG_MARK);
        xml_apply_ancestor(x1, (xml_applyfn_t*)xml_flag_set, (void*)XML_FLAG_CHANGE);
    }
    /* Copy the marked elements: 
     * note is yang-aware for copying of keys which means XML must be bound 
     */
    if (xml_copy_marked(xt, xstate) < 0) /* Copy the marked elements */
        goto done;
    /* Unmark original tree */
    if (xml_apply(xt, CX_ELMNT, (xml_applyfn_t*)xml_flag_reset, (void*)(XML_FLAG_MARK|XML_FLAG_CHANGE)) < 0)
        goto done;
    /* Unmark returned state tree */
    if (xml_apply(xstate, CX_ELMNT, (xml_applyfn_t*)xml_flag_reset, (void*)(XML_FLAG_MARK|XML_FLAG_CHANGE)) < 0)
        goto done;
    if (_state_file_cached){
        xt = NULL; /* ensure cache is not cleared */
    }
    if (locked)
        _state_file_transaction++;
 ok:
    retval = 0;
 done:
    if (fp)
        fclose(fp);
    if (xt)
        xml_free(xt);
    if (xvec)
        free(xvec);
    if (nsc)
        cvec_free(nsc);
    return retval;
}

/*! Lock databse status has changed status
 *
 * @param[in]  h    Clixon handle
 * @param[in]  db   Database name (eg "running")
 * @param[in]  lock Lock status: 0: unlocked, 1: locked
 * @param[in]  id   Session id (of locker/unlocker)
 * @retval     0    OK
 * @retval    -1    Fatal error
*/
int
example_lockdb(clixon_handle h,
               char         *db,
               int           lock,
               int           id)
{
    int retval = -1;

    clixon_debug(CLIXON_DBG_DEFAULT, "Lock callback: db%s: locked:%d", db, lock);
    /* Part of cached pagination example
     */
    if (strcmp(db, "running") == 0 && lock == 0 &&
        _state && _state_file && _state_file_cached && _state_file_transaction){
        if (_state_xml_cache){
            xml_free(_state_xml_cache);
            _state_xml_cache = NULL;
        }
        _state_file_transaction = 0;
    }
    retval = 0;
    // done:
    return retval;
}

/*! Callback for yang extensions example:e4
 *
 * @param[in] h    Clixon handle
 * @param[in] yext Yang node of extension 
 * @param[in] ys   Yang node of (unknown) statement belonging to extension
 * @retval    0    OK, all callbacks executed OK
 * @retval   -1    Error in one callback
 */
int
example_extension(clixon_handle h,
                  yang_stmt    *yext,
                  yang_stmt    *ys)
{
    int        retval = -1;
    char      *extname;
    char      *modname;
    yang_stmt *ymod;
    yang_stmt *yc;
    yang_stmt *yn = NULL;

    ymod = ys_module(yext);
    modname = yang_argument_get(ymod);
    extname = yang_argument_get(yext);
    if (strcmp(modname, "example") != 0 || strcmp(extname, "e4") != 0)
        goto ok;
    clixon_debug(CLIXON_DBG_DEFAULT, "Enabled extension:%s:%s", modname, extname);
    if ((yc = yang_find(ys, 0, NULL)) == NULL)
        goto ok;
    if ((yn = ys_dup(yc)) == NULL)
        goto done;
    if (yn_insert(yang_parent_get(ys), yn) < 0)
        goto done;
 ok:
    retval = 0;
 done:
    return retval;
}

/* Here follows code for general-purpose datastore upgrade
 * Nodes affected are identified by paths.
 * In this example nodes' namespaces are changed, or they are removed altogether
 * @note Order is significant, the rules are traversed in the order stated here, which means that if
 *       namespaces changed, or objects are removed in one rule, you have to take that into account
 *       in the next rule.
 */
/* Remove these paths */
static const char *remove_map[] = {
    "/a:remove_me",
    /* add more paths to be deleted here */
    NULL
};

/* Rename the namespaces of these paths. 
 * That is, paths (on the left) should get namespaces (to the right) 
 */
static const map_str2str namespace_map[] = {
    {"/a:x/a:y/a:z/descendant-or-self::node()", "urn:example:b"},
    /* add more paths to be renamed here */
    {NULL,                          NULL}
};

/*! General-purpose datastore upgrade callback called once on startup
 *
 * Gets called on startup after initial XML parsing, but before module-specific upgrades
 * and before validation. 
 * @param[in] h    Clixon handle
 * @param[in] db   Name of datastore, eg "running", "startup" or "tmp"
 * @param[in] xt   XML tree. Upgrade this "in place"
 * @param[in] msd  Info on datastore module-state, if any
 * @retval    0    OK
 * @retval   -1    Error
 */
int
example_upgrade(clixon_handle    h,
                const char      *db,
                cxobj           *xt,
                modstate_diff_t *msd)
{
    int                       retval = -1;
    cvec                     *nsc = NULL;    /* Canonical namespace */
    yang_stmt                *yspec;
    const struct map_str2str *ms;            /* map iterator */
    cxobj                   **xvec = NULL;   /* vector of result nodes */
    size_t                    xlen;
    int                       i;
    const char              **pp;

    if (_general_upgrade == 0)
        goto ok;
    if (strcmp(db, "startup") != 0) /* skip other than startup datastore */
        goto ok;
    if (msd && msd->md_status) /* skip if there is proper module-state in datastore */
        goto ok;
    yspec = clicon_dbspec_yang(h);     /* Get all yangs */
    /* Get canonical namespaces for using "normalized" prefixes */
    if (xml_nsctx_yangspec(yspec, &nsc) < 0)
        goto done;
    /* 1. Remove paths */
    for (pp = remove_map; *pp; ++pp){
        /* Find all nodes matching n */
        if (xpath_vec(xt, nsc, "%s", &xvec, &xlen, *pp) < 0)
            goto done;
        /* Remove them */
        /* Loop through all nodes matching mypath and change theoir namespace */
        for (i=0; i<xlen; i++){
            if (xml_purge(xvec[i]) < 0)
                goto done;
        }
        if (xvec){
            free(xvec);
            xvec = NULL;
        }
    }
    /* 2. Rename namespaces of the paths declared in the namespace map
     */
    for (ms = &namespace_map[0]; ms->ms_s0; ms++){
        char *mypath;
        char *mynamespace;
        char *myprefix = NULL;

        mypath = ms->ms_s0;
        mynamespace = ms->ms_s1;
        if (xml_nsctx_get_prefix(nsc, mynamespace, &myprefix) == 0){
            clixon_err(OE_XML, ENOENT, "Namespace %s not found in canonical namespace map",
                       mynamespace);
            goto done;
        }
        /* Find all nodes matching mypath */
        if (xpath_vec(xt, nsc, "%s", &xvec, &xlen, mypath) < 0)
            goto done;
        /* Loop through all nodes matching mypath and change theoir namespace */
        for (i=0; i<xlen; i++){
            /* Change namespace of this node (using myprefix) */
            if (xml_namespace_change(xvec[i], mynamespace, myprefix) < 0)
                goto done;
        }
        if (xvec){
            free(xvec);
            xvec = NULL;
        }
    }
 ok:
    retval = 0;
 done:
    if (xvec)
        free(xvec);
    if (nsc)
        cvec_free(nsc);
    return retval;
}

/*! Example YANG schema mount
 *
 * Given an XML mount-point xt, return XML yang-lib modules-set
 * @param[in]  h       Clixon handle
 * @param[in]  xt      XML mount-point in XML tree
 * @param[out] config  If '0' all data nodes in the mounted schema are read-only
 * @param[out] validate Do or dont do full RFC 7950 validation
 * @param[out] yanglib XML yang-lib module-set tree
 * @retval     0       OK
 * @retval    -1       Error
 * XXX hardcoded to clixon-example@2022-11-01.yang regardless of xt
 * @see RFC 8528
 */
int
main_yang_mount(clixon_handle   h,
                cxobj          *xt,
                int            *config,
                validate_level *vl,
                cxobj         **yanglib)
{
    int   retval = -1;
    cbuf *cb = NULL;

    if (config)
        *config = 1;
    if (vl)
        *vl = VL_FULL;
    if (yanglib && _mount_yang){
        if ((cb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            goto done;
        }
        cprintf(cb, "<yang-library xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\">");
        cprintf(cb, "<module-set>");
        cprintf(cb, "<name>mylabel</name>"); // XXX label in test_yang_schema_mount
        cprintf(cb, "<module>");
        /* In yang name+namespace is mandatory, but not revision */
        cprintf(cb, "<name>%s</name>", _mount_yang); // mandatory
        cprintf(cb, "<namespace>%s</namespace>", _mount_namespace); // mandatory
        //        cprintf(cb, "<revision>2022-11-01</revision>");
        cprintf(cb, "</module>");
        cprintf(cb, "</module-set>");
        cprintf(cb, "</yang-library>");
        if (clixon_xml_parse_string(cbuf_get(cb), YB_NONE, NULL, yanglib, NULL) < 0)
            goto done;
        if (xml_rootchild(*yanglib, 0, yanglib) < 0)
            goto done;
    }
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
}

/*! Testcase module-specific upgrade function moving interfaces-state to interfaces
 *
 * @param[in]  h       Clixon handle 
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module (for info)
 * @param[in]  op      One of XML_FLAG_ADD, _DEL, _CHANGE
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..  if retval = 0
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2014_to_2016
 * This example shows a two-step upgrade where the 2014 function does:
 * - Move /if:interfaces-state/if:interface/if:admin-status to 
 *        /if:interfaces/if:interface/
 * - Move /if:interfaces-state/if:interface/if:statistics to
 *        /if:interfaces/if:interface/
 * - Rename /interfaces/interface/description to descr 
 */
static int
upgrade_2014_to_2016(clixon_handle h,
                     cxobj        *xt,
                     char         *ns,
                     uint16_t      op,
                     uint32_t      from,
                     uint32_t      to,
                     void         *arg,
                     cbuf         *cbret)
{
    int        retval = -1;
    yang_stmt *yspec;
    yang_stmt *ym;
    cxobj    **vec = NULL;
    cxobj     *xc;
    cxobj     *xi;  /* xml /interfaces-states/interface node */
    cxobj     *x;
    cxobj     *xif; /* xml /interfaces/interface node */
    size_t     vlen;
    int        i;
    char      *name;

    clixon_debug(CLIXON_DBG_DEFAULT, "from:%d to:%d", from, to);
    if (op != XML_FLAG_CHANGE) /* Only treat fully present modules */
        goto ok;
    /* Get Yang module for this namespace. Note it may not exist (if obsolete) */
    yspec = clicon_dbspec_yang(h);
    if ((ym = yang_find_module_by_namespace(yspec, ns)) == NULL)
        goto ok; /* shouldnt happen */
    /* Get all XML nodes with that namespace */
    if (xml_namespace_vec(h, xt, ns, &vec, &vlen) < 0)
        goto done;
    for (i=0; i<vlen; i++){
        xc = vec[i];
        /* Iterate through interfaces-state */
        if (strcmp(xml_name(xc),"interfaces-state") == 0){
            /* Note you cannot delete or move xml objects directly under xc
             * in the loop (eg xi objects) but you CAN move children of xi
             */
            xi = NULL;
            while ((xi = xml_child_each(xc, xi, CX_ELMNT)) != NULL) {
                if (strcmp(xml_name(xi), "interface"))
                    continue;
                if ((name = xml_find_body(xi, "name")) == NULL)
                    continue; /* shouldnt happen */
                /* Get corresponding /interfaces/interface entry */
                xif = xpath_first(xt, NULL, "/interfaces/interface[name=\"%s\"]", name);
                /* - Move /if:interfaces-state/if:interface/if:admin-status to
                 *        /if:interfaces/if:interface/ */
                if ((x = xml_find(xi, "admin-status")) != NULL && xif){
                    if (xml_addsub(xif, x) < 0)
                        goto done;
                }
                /* - Move /if:interfaces-state/if:interface/if:statistics to
                 *        /if:interfaces/if:interface/*/
                if ((x = xml_find(xi, "statistics")) != NULL){
                    if (xml_addsub(xif, x) < 0)
                        goto done;
                }
            }
        }
        else if (strcmp(xml_name(xc),"interfaces") == 0){
            /* Iterate through interfaces */
            xi = NULL;
            while ((xi = xml_child_each(xc, xi, CX_ELMNT)) != NULL) {
                if (strcmp(xml_name(xi), "interface"))
                    continue;
                /* Rename /interfaces/interface/description to descr */
                if ((x = xml_find(xi, "description")) != NULL)
                    if (xml_name_set(x, "descr") < 0)
                        goto done;
            }
        }
    }
 ok:
    retval = 1;
 done:
    if (vec)
        free(vec);
    return retval;
}

/*! Testcase upgrade function removing interfaces-state
 *
 * @param[in]  h       Clixon handle 
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module (for info)
 * @param[in]  op      One of XML_FLAG_ADD, _DEL, _CHANGE
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..  if retval = 0
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2016_to_2018
 * The 2016 function does:
 * - Delete /if:interfaces-state
 * - Wrap /interfaces/interface/descr to /interfaces/interface/docs/descr
 * - Change type /interfaces/interface/statistics/in-octets to decimal64 with
 *   fraction-digits 3 and divide all values with 1000
 */
static int
upgrade_2016_to_2018(clixon_handle h,
                     cxobj        *xt,
                     char         *ns,
                     uint16_t      op,
                     uint32_t      from,
                     uint32_t      to,
                     void         *arg,
                     cbuf         *cbret)
{
    int        retval = -1;
    yang_stmt *yspec;
    yang_stmt *ym;
    cxobj    **vec = NULL;
    cxobj     *xc;
    cxobj     *xi;
    cxobj     *x;
    cxobj     *xb;
    size_t     vlen;
    int        i;

    clixon_debug(CLIXON_DBG_DEFAULT, "from:%d to:%d", from, to);
    if (op != XML_FLAG_CHANGE) /* Only treat fully present modules */
        goto ok;
    /* Get Yang module for this namespace. Note it may not exist (if obsolete) */
    yspec = clicon_dbspec_yang(h);
    if ((ym = yang_find_module_by_namespace(yspec, ns)) == NULL)
        goto ok; /* shouldnt happen */
    clixon_debug(CLIXON_DBG_DEFAULT, "module %s", ym?yang_argument_get(ym):"none");
    /* Get all XML nodes with that namespace */
    if (xml_namespace_vec(h, xt, ns, &vec, &vlen) < 0)
        goto done;
    for (i=0; i<vlen; i++){
        xc = vec[i];
        /* Delete /if:interfaces-state */
        if (strcmp(xml_name(xc), "interfaces-state") == 0)
            xml_purge(xc);
        /* Iterate through interfaces */
        else if (strcmp(xml_name(xc),"interfaces") == 0){
            /* Iterate through interfaces */
            xi = NULL;
            while ((xi = xml_child_each(xc, xi, CX_ELMNT)) != NULL) {
                if (strcmp(xml_name(xi), "interface"))
                    continue;
                /* Wrap /interfaces/interface/descr to /interfaces/interface/docs/descr */
                if ((x = xml_find(xi, "descr")) != NULL)
                    if (xml_wrap(x, "docs") < 0)
                        goto done;
                /* Change type /interfaces/interface/statistics/in-octets to 
                 * decimal64 with fraction-digits 3 and divide values with 1000 
                 */
                if ((x = xpath_first(xi, NULL, "statistics/in-octets")) != NULL){
                    if ((xb = xml_body_get(x)) != NULL){
                        uint64_t u64;
                        cbuf *cb;

                        if ((cb = cbuf_new()) == NULL){
                            clixon_err(OE_UNIX, errno, "cbuf_new");
                            goto done;
                        }

                        parse_uint64(xml_value(xb), &u64, NULL);
                        cprintf(cb, "%" PRIu64 ".%03d", u64/1000, (int)(u64%1000));
                        xml_value_set(xb, cbuf_get(cb));
                        cbuf_free(cb);
                    }
                }
            }
        }
    }
 ok:
    retval = 1;
 done:
    if (vec)
        free(vec);
    return retval;
}

/*! Testcase module-specific upgrade function moving interfaces-state to interfaces
 *
 * @param[in]  h       Clixon handle
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module (for info)
 * @param[in]  op      One of XML_FLAG_ADD, _DEL, _CHANGE
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..  if retval = 0
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2014_to_2016
 * This example shows a two-step upgrade where the 2014 function does:
 * - Move /if:interfaces-state/if:interface/if:admin-status to 
 *        /if:interfaces/if:interface/
 * - Move /if:interfaces-state/if:interface/if:statistics to
 *        /if:interfaces/if:interface/
 * - Rename /interfaces/interface/description to descr 
 */
static int
upgrade_interfaces(clixon_handle h,
                   cxobj        *xt,
                   char         *ns,
                   uint16_t      op,
                   uint32_t      from,
                   uint32_t      to,
                   void         *arg,
                   cbuf         *cbret)
{
    int retval = -1;

    if (_module_upgrade) /* For testing */
        clixon_log(h, LOG_NOTICE, "%s %s op:%s from:%d to:%d",
                   __FUNCTION__, ns,
                   (op&XML_FLAG_ADD)?"ADD":(op&XML_FLAG_DEL)?"DEL":"CHANGE",
                   from, to);
    if (from <= 20140508){
        if ((retval = upgrade_2014_to_2016(h, xt, ns, op, from, to, arg, cbret)) < 0)
            goto done;
        if (retval == 0)
            goto done;
    }
    if (from <= 20160101){
        if ((retval = upgrade_2016_to_2018(h, xt, ns, op, from, to, arg, cbret)) < 0)
            goto done;
        if (retval == 0)
            goto done;
    }
    // ok:
    retval = 1;
 done:
    return retval;
}

/*! Plugin state reset. Add xml or set state in backend machine.
 *
 * Add xml or set state in backend system.
 * plugin_reset in each backend plugin after all plugins have been initialized. 
 * This gives the application a chance to reset system state back to a base state. 
 * This is generally done when a system boots up to make sure the initial system state
 * is well defined. 
 * This involves creating default configuration files for various daemons, set interface
 * flags etc.
 * @param[in] h   Clixon handle
 * @param[in] db  Name of database. Not3 may be other than "running"
 * @retval    0   OK
 * @retval   -1   Error
 * In this example, a loopback parameter is added
 */
int
example_reset(clixon_handle h,
              const char   *db)
{
    int        retval = -1;
    cxobj     *xt = NULL;
    int        ret;
    cbuf      *cbret = NULL;
    yang_stmt *yspec;
    cxobj     *xerr = NULL;

    if (!_reset)
        goto ok; /* Note not enabled by default */
    yspec = clicon_dbspec_yang(h);
    /* Parse extra XML */
    if ((ret = clixon_xml_parse_string("<table xmlns=\"urn:example:clixon\">"
                                       "<parameter><name>loopback</name><value>99</value></parameter>"
                                       "</table>", YB_MODULE, yspec, &xt, &xerr)) < 0)
        goto done;
    if (ret == 0){
        clixon_debug_xml(CLIXON_DBG_DEFAULT, xerr, "Error when parsing XML");
        goto ok;
    }
    /* xmldb_put requires modification tree to be: <config>... */
    xml_name_set(xt, "config");
    if ((cbret = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    /* Merge user reset state */
    if ((ret = xmldb_put(h, (char*)db, OP_MERGE, xt, clicon_username_get(h), cbret)) < 0)
        goto done;
    if (ret == 0){
        clixon_err(OE_XML, 0, "Error when writing to XML database: %s",
                   cbuf_get(cbret));
        goto done;
    }
 ok:
    retval = 0;
 done:
    if (cbret)
        cbuf_free(cbret);
    if (xerr)
        xml_free(xerr);
    if (xt != NULL)
        xml_free(xt);
    return retval;
}

/*! Plugin start.
 *
 * Called when application is "started", (almost) all initialization is complete 
 * Backend: daemon is in the background. If daemon privileges are dropped 
 * this callback is called *before* privileges are dropped.
 * @param[in]  h    Clixon handle
 * @retval     0    OK
 * @retval    -1    Error
 */
int
example_start(clixon_handle h)
{
    int        retval = -1;
    yang_stmt *yspec;
    yang_stmt *ya = NULL;

    /* Register action callback, example from RFC7950 7.15
     * Can not be made in _init since YANG is not loaded
     * Note that callback is hardcoded here since it is C, but YANG and name of action
     * is not. It is enough to point via an schema-node id to the correct action,
     * such as "/sfarm:server/sfarm:reset"
     */
    if (_action_instanceid){
        if ((yspec = clicon_dbspec_yang(h)) == NULL){
            clixon_err(OE_FATAL, 0, "No DB_SPEC");
            goto done;
        }
        if (yang_abs_schema_nodeid(yspec, _action_instanceid, &ya) == 0){
            if (ya && action_callback_register(h, ya, example_action_reset, NULL) < 0)
                goto done;
        }
    }
    retval = 0;
 done:
    return retval;
}

/*! Plugin daemon.
 *
 * @param[in]  h    Clixon handle
 * @retval     0    OK
 * @retval    -1    Error
 * plugin_daemon is called once after daemonization has been made but before lowering of privileges
 * the main event loop is entered. 
 */
int
example_daemon(clixon_handle h)
{
    int        retval = -1;
    int        ret;
    FILE      *fp = NULL;
    yang_stmt *yspec;
    cxobj     *xerr = NULL;

    /* Read state file (or should this be in init/start?) */
    if (_state && _state_file && _state_file_cached){
        yspec = clicon_dbspec_yang(h);
        if ((fp = fopen(_state_file, "r")) == NULL){
            clixon_err(OE_UNIX, errno, "open(%s)", _state_file);
            goto done;
        }
        /* Need to be yang bound for eg xml_copy_marked() in example_pagination
         */
        if ((ret = clixon_xml_parse_file(fp, YB_MODULE, yspec, &_state_xml_cache, &xerr)) < 0)
            goto done;
        if (ret == 0){
            xml_print(stderr, xerr);
            goto done;
        }
    }
    retval = 0;
 done:
    if (xerr)
        xml_free(xerr);
    if (fp)
        fclose(fp);
    return retval;
}

int
example_exit(clixon_handle h)
{
    if (_state_xml_cache){
        xml_free(_state_xml_cache);
        _state_xml_cache = NULL;
    }
    return 0;
}

/* Forward declaration */
clixon_plugin_api *clixon_plugin_init(clixon_handle h);

static clixon_plugin_api api = {
    "example",                              /* name */
    clixon_plugin_init,                     /* init - must be called clixon_plugin_init */
    example_start,                          /* start */
    example_exit,                           /* exit */
    example_extension,                      /* yang extensions */
    .ca_daemon=example_daemon,              /* daemon */
    .ca_reset=example_reset,                /* reset */
    .ca_statedata=example_statedata,        /* statedata : Note fn is switched if -sS <file> */
    .ca_lockdb=example_lockdb,              /* Database lock changed state */
    .ca_trans_begin=main_begin,             /* trans begin */
    .ca_trans_validate=main_validate,       /* trans validate */
    .ca_trans_complete=main_complete,       /* trans complete */
    .ca_trans_commit=main_commit,           /* trans commit */
    .ca_trans_commit_done=main_commit_done, /* trans commit done */
    .ca_trans_revert=main_revert,           /* trans revert */
    .ca_trans_end=main_end,                 /* trans end */
    .ca_trans_abort=main_abort,             /* trans abort */
    .ca_datastore_upgrade=example_upgrade,  /* general-purpose upgrade. */
    .ca_yang_mount=main_yang_mount          /* RFC 8528 schema mount */
};

/*! Backend plugin initialization
 *
 * @param[in]  h    Clixon handle
 * @retval     NULL Error
 * @retval     api  Pointer to API struct
 * In this example, you can pass -r, -s, -u to control the behaviour, mainly 
 * for use in the test suites.
 */
clixon_plugin_api *
clixon_plugin_init(clixon_handle h)
{
    struct timeval retention = {0,0};
    int            argc; /* command-line options (after --) */
    char         **argv;
    int            c;

    clixon_debug(CLIXON_DBG_INIT, "backend");

    /* Get user command-line options (after --) */
    if (clicon_argv_get(h, &argc, &argv) < 0)
        goto done;
    opterr = 0;
    optind = 1;
    while ((c = getopt(argc, argv, BACKEND_EXAMPLE_OPTS)) != -1)
        switch (c) {
        case 'a':
            _action_instanceid = optarg;
            break;
        case 'm':
            _mount_yang = optarg;
            break;
        case 'M':
            _mount_namespace = optarg;
            break;
        case 'n':
            _notification_stream_s = atoi(optarg);
            break;
        case 'r':
            _reset = 1;
            break;
        case 's': /* state callback */
            _state = 1;
            break;
        case 'S': /* state file (requires -s) */
            _state_file = optarg;
            break;
        case 'x': /* state xpath (requires -sS) */
            _state_xpath = optarg;
            break;
        case 'i': /* read state file on init not by request (requires -sS <file> */
            _state_file_cached = 1;
            break;
       case 'u': /* module-specific upgrade */
           _module_upgrade = 1;
           break;
       case 'U': /* general-purpose upgrade */
           _general_upgrade = 1;
           break;
        case 't': /* transaction log */
            _transaction_log = 1;
            break;
        case 'V': /* validate fail */
            _validate_fail_xpath = optarg;
            break;
        }
    if ((_mount_yang && !_mount_namespace) || (!_mount_yang && _mount_namespace)){
        clixon_err(OE_PLUGIN, EINVAL, "Both -m and -M must be given for mounts");
        goto done;
    }
    if (_state_file){
        api.ca_statedata = example_statefile; /* Switch state data callback */
        if (_state_xpath){
            /* State pagination callbacks */
            if (clixon_pagination_cb_register(h,
                                              example_pagination,
                                              _state_xpath,
                                              NULL) < 0)
                goto done;
        }
    }

    if (_notification_stream_s){
        /* Example stream initialization:
         * 1) Register EXAMPLE stream 
         * 2) setup timer for notifications, so something happens on stream
         * 3) setup stream callbacks for notification to push channel
         */
        if (clicon_option_exists(h, "CLICON_STREAM_RETENTION"))
            retention.tv_sec = clicon_option_int(h, "CLICON_STREAM_RETENTION");
        if (stream_add(h, "EXAMPLE", "Example event stream", 1, &retention) < 0)
            goto done;
        /* Enable nchan pub/sub streams
         * assumes: CLIXON_PUBLISH_STREAMS, eg configure --enable-publish
         */
        if (clicon_option_exists(h, "CLICON_STREAM_PUB") &&
            stream_publish(h, "EXAMPLE") < 0)
            goto done;
        if (example_stream_timer_setup(h, _notification_stream_s) < 0)
            goto done;
    }
    /* Register callback for routing rpc calls 
     */
    /* From example.yang (clicon) */
    if (rpc_callback_register(h, empty_rpc,
                              NULL,
                              "urn:example:clixon",
                              "empty"/* Xml tag when callback is made */
                              ) < 0)
        goto done;
    /* Same as example but with optional input/output */
    if (rpc_callback_register(h, example_rpc,
                              NULL,
                              "urn:example:clixon",
                              "optional"/* Xml tag when callback is made */
                              ) < 0)
        goto done;
        /* Same as example but with optional input/output */
    if (rpc_callback_register(h, example_rpc,
                              NULL,
                              "urn:example:clixon",
                              "example"/* Xml tag when callback is made */
                              ) < 0)
        goto done;
    /* Called before the regular system copy_config callback 
     * If you want to have it called _after_ the system callback, place this call in 
     * the _start function.
     */
    if (rpc_callback_register(h, example_copy_extra,
                              NULL,
                              NETCONF_BASE_NAMESPACE,
                              "copy-config"
                              ) < 0)
        goto done;

    /* Upgrade callback: if you start the backend with -- -u you will get the
     * test interface example. Otherwise the auto-upgrade feature is enabled.
     */
    if (_module_upgrade){
        if (upgrade_callback_register(h, upgrade_interfaces, "urn:example:interfaces", NULL) < 0)
            goto done;
    }
    else
        if (upgrade_callback_register(h, xml_changelog_upgrade, NULL, NULL) < 0)
            goto done;
    /* Return plugin API */
    return &api;
 done:
    return NULL;
}
