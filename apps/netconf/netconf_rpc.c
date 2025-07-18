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
 * Code for handling netconf rpc messages according to RFC 4741,5277,6241
 *    All NETCONF protocol elements are defined in the following namespace:
 *      urn:ietf:params:xml:ns:netconf:base:1.0
 * YANG defines an XML namespace for NETCONF <edit-config> operations,
 *     <error-info> content, and the <action> element.  The name of this
 *      namespace is "urn:ietf:params:xml:ns:yang:1".
 *
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <syslog.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/param.h>
#include <grp.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

#include "netconf_filter.h"
#include "netconf_rpc.h"

/*
 * <rpc [attributes]>
 <!- - tag elements in a request from a client application - ->
 </rpc>
*/

static int
netconf_get_config_subtree(clixon_handle h,
                           cxobj        *xfilter,
                           cxobj       **xret)
{
    int    retval = -1;
    cxobj *xdata;

    /* a subtree filter is comprised of zero or more element subtrees*/
    if ((xdata = xpath_first(*xret, NULL, "/rpc-reply/data")) == NULL)
        goto ok;
    if (xml_filter(xfilter, xdata) < 0){
        clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                            "<error-tag>operation-failed</error-tag>"
                            "<error-type>application</error-type>"
                            "<error-severity>error</error-severity>"
                            "<error-info>filtering</error-info>"
                            "</rpc-error></rpc-reply>",
                            NETCONF_BASE_NAMESPACE
                            );
    }
 ok:
    retval = 0;
    // done:
    return retval;
}

/*! Get configuration
 *
 * @param[in]  h       Clixon handle
 * @param[in]  xn      Sub-tree (under xorig) at <rpc>...</rpc> level.
 * @param[out] xret    Return XML, error or OK
 * @retval     0       OK
 * @retval    -1       Error
 * @note filter type subtree and xpath is supported, but xpath is preferred, and
 *              better performance and tested. Please use xpath.
 *
 *     <get-config>
 *       <source>
 *         <candidate/> | <running/>
 *       </source>
 *     </get-config>
 *
 *     <get-config>
 *       <source>
 *         <candidate/> | <running/>
 *       </source>
 *       <filter type="subtree">
 *           <configuration>
 *               <!- - tag elements for each configuration element to return - ->
 *           </configuration>
 *       </filter>
 *     </get-config>
 *
 *  Example:
 *    <rpc><get-config><source><running /></source>
 *      <filter type="xpath" select="//SenderTwampIpv4"/>
 *    </get-config></rpc>]]>]]>
 * Variants of the functions where x-axis is the variants of the <filter> clause
 * and y-axis is whether a <filter><configuration> or <filter select=""> is present.
 *                  | no filter | filter subnet | filter xpath |
 * -----------------+-----------+---------------+--------------+
 * no config        |           |               |              |
 * -----------------+-----------+---------------+--------------+
 * config/select    |     -     |               |              |
 * -----------------+-----------+---------------+--------------+
 * Example requests of each:
 * no filter + no config
 <rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>
 * filter subnet + no config:
 <rpc><get-config><source><candidate/></source><filter/></get-config></rpc>]]>]]>
 * filter xpath + select all:
 <rpc><get-config><source><candidate/></source><filter type="xpath" select="/"/></get-config></rpc>]]>]]>
 * filter subtree + config:
 <rpc><get-config><source><candidate/></source><filter type="subtree"><configuration><interfaces><interface><ipv4><enabled/></ipv4></interface></interfaces></configuration></filter></get-config></rpc>]]>]]>
 * filter xpath + select:
 <rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface/ipv4"/></get-config></rpc>]]>]]>
*/
static int
netconf_get_config(clixon_handle h,
                   cxobj        *xn,
                   cxobj       **xret)
{
    int        retval = -1;
    cxobj     *xfilter; /* filter */
    char      *ftype = NULL;
    cvec      *nsc = NULL;
    char      *prefix = NULL;

    if(xml_nsctx_node(xn, &nsc) < 0)
        goto done;

    /* Get prefix of netconf base namespace in the incoming message */
    if (xml_nsctx_get_prefix(nsc, NETCONF_BASE_NAMESPACE, &prefix) == 0){
        goto done;
    }

    /* ie <filter>...</filter> */
    if ((xfilter = xpath_first(xn, nsc, "%s%sfilter", prefix ? prefix : "", prefix ? ":" : "")) != NULL)
        ftype = xml_find_value(xfilter, "type");
    if (xfilter == NULL || ftype == NULL || strcmp(ftype, "subtree") == 0) {
        /* Get whole config first, then filter. This is suboptimal
         */
        if (clicon_rpc_netconf_xml(h, xml_parent(xn), xret, NULL) < 0)
            goto done;
        /* Now filter on whole tree */
        if (netconf_get_config_subtree(h, xfilter, xret) < 0)
            goto done;
    } else if (strcmp(ftype, "xpath") == 0) {
        if (clicon_rpc_netconf_xml(h, xml_parent(xn), xret, NULL) < 0) {
            goto done;
        }
    } else {
        clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                            "<error-tag>operation-failed</error-tag>"
                            "<error-type>applicatio</error-type>"
                            "<error-severity>error</error-severity>"
                            "<error-message>filter type not supported</error-message>"
                            "<error-info>type</error-info>"
                            "</rpc-error></rpc-reply>",
                            NETCONF_BASE_NAMESPACE);
    }
    retval = 0;
 done:
    if (nsc)
        cvec_free(nsc);
    return retval;
}

/*! Get options from netconf edit-config
 *
 * @param[in]  xn      Sub-tree (under xorig) at <rpc>...</rpc> level.
 * @param[out] op      Operation type, eg merge,replace,...
 * @param[out] testopt test option, eg set, test
 * @param[out] erropt  Error option, eg stop-on-error
 * @retval     1       OK, op, testopt and erropt set
 * @retval     0       parameter error, xret returns error
 * @retval    -1       Fatal Error
 * @example
 *  <edit-config>
 *     <config>...</config>
 *     <default-operation>(merge | none | replace)</default-operation>
 *     <error-option>(stop-on-error | continue-on-error )</error-option>
 *     <test-option>(set | test-then-set | test-only)</test-option>
 *  </edit-config>
 */
static int
get_edit_opts(cxobj             *xn,
              enum test_option  *testopt,
              enum error_option *erropt,
              cxobj            **xret)
{
    int    retval = -1;
    cxobj *x;
    char  *optstr;

    if ((x = xpath_first(xn, NULL, "test-option")) != NULL){
        if ((optstr = xml_body(x)) != NULL){
            if (strcmp(optstr, "test-then-set") == 0)
                *testopt = TEST_THEN_SET;
            else if (strcmp(optstr, "set") == 0)
                *testopt = SET;
            else if (strcmp(optstr, "test-only") == 0)
                *testopt = TEST_ONLY;
            else
                goto parerr;
        }
    }
    if ((x = xpath_first(xn, NULL, "error-option")) != NULL){
        if ((optstr = xml_body(x)) != NULL){
            if (strcmp(optstr, "stop-on-error") == 0)
                *erropt = STOP_ON_ERROR;
            else
                if (strcmp(optstr, "continue-on-error") == 0)
                    *erropt = CONTINUE_ON_ERROR;
                else
                    goto parerr;
        }
    }
    retval = 1; /* hunky dory */
    return retval;
 parerr: /* parameter error, xret set */
    clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                        "<error-tag>invalid-value</error-tag>"
                        "<error-type>protocol</error-type>"
                        "<error-severity>error</error-severity>"
                        "</rpc-error></rpc-reply>",
                        NETCONF_BASE_NAMESPACE);
    return 0;
}

/*! Netconf edit configuration
 *
 Write the change on a tmp file, then load that into candidate configuration.
 <edit-config>
 <target>
 <candidate/>
 </target>

 <!- - EITHER - ->

 <config>
 <configuration>
 <!- - tag elements representing the data to incorporate - ->
 </configuration>
 </config>

 <!- - OR - ->

 <config-text>
 <configuration-text>
 <!- - tag elements inline configuration data in text format - ->
 </configuration-text>
 </config-text>

 <!- - OR - ->

 <url>
 <!- - location specifier for file containing data - ->
 </url>

 <default-operation>(merge | none | replace)</default-operation>
 <error-option>(stop-on-error | continue-on-error )</error-option>
 <test-option>(set | test-then-set | test-only)</test-option>
 <edit-config>

 CLIXON addition:
 <filter type="restconf" select="/data/profile=a" />

 *
 * @param[in]  h       clicon handle
 * @param[in]  xn      Sub-tree (under xorig) at <rpc>...</rpc> level.
 * @param[out] xret    Return XML, error or OK
 * @retval     0       OK, xret points to valid return, either ok or rpc-error
 * @retval    -1       Error
 * only 'config' supported
 * error-option: only stop-on-error supported
 * test-option:  not supported
 *
 * @note erropt, testopt only supports default
 */
static int
netconf_edit_config(clixon_handle h,
                    cxobj        *xn,
                    cxobj       **xret)
{
    int                 retval = -1;
    int                 optret;
    enum test_option    testopt = TEST_THEN_SET;/* only supports this */
    enum error_option   erropt = STOP_ON_ERROR; /* only supports this */

    if ((optret = get_edit_opts(xn, &testopt, &erropt, xret)) < 0)
        goto done;
    if (optret == 0) /* error in opt parameters */
        goto ok;
    /* These constraints are clixon-specific since :validate should
     * support all testopts, and erropts should be supported
     * And therefore extends the validation
     * (implement the features before removing these checks)
     */
    if (testopt!=TEST_THEN_SET || erropt!=STOP_ON_ERROR){
        clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                            "<error-tag>operation-not-supported</error-tag>"
                            "<error-type>protocol</error-type>"
                            "<error-severity>error</error-severity>"
                            "</rpc-error></rpc-reply>",
                            NETCONF_BASE_NAMESPACE);
        goto ok;
    }
    if (clicon_rpc_netconf_xml(h, xml_parent(xn), xret, NULL) < 0)
        goto done;
 ok:
    retval = 0;
 done:
    return retval;
}

/*! Get running configuration and device state information
 *
 * @param[in]  h       Clixon handle
 * @param[in]  xn      Sub-tree (under xorig) at <rpc>...</rpc> level.
 * @param[out] xret    Return XML, error or OK
 * @retval     0       OK
 * @retval    -1       Error
 * @note filter type subtree and xpath is supported, but xpath is preferred, and
 *              better performance and tested. Please use xpath.
 *
 * @example
 *    <rpc><get><filter type="xpath" select="//SenderTwampIpv4"/>
 *    </get></rpc>]]>]]>
 */
static int
netconf_get(clixon_handle h,
            cxobj        *xn,
            cxobj       **xret)
{
    int        retval = -1;
    cxobj     *xfilter; /* filter */
    char      *ftype = NULL;
    cvec      *nsc = NULL;
    char      *prefix = NULL;

    if(xml_nsctx_node(xn, &nsc) < 0)
        goto done;

    /* Get prefix of netconf base namespace in the incoming message */
    if (xml_nsctx_get_prefix(nsc, NETCONF_BASE_NAMESPACE, &prefix) == 0){
        goto done;
    }

    /* ie <filter>...</filter> */
    if ((xfilter = xpath_first(xn, nsc, "%s%sfilter", prefix ? prefix : "", prefix ? ":" : "")) != NULL)
        ftype = xml_find_value(xfilter, "type");
    if (xfilter == NULL || ftype == NULL || strcmp(ftype, "subtree") == 0) {
        /* Get whole config + state first, then filter. This is suboptimal
         */
        if (clicon_rpc_netconf_xml(h, xml_parent(xn), xret, NULL) < 0)
            goto done;
        /* Now filter on whole tree */
        if (netconf_get_config_subtree(h, xfilter, xret) < 0)
            goto done;
    } else if (strcmp(ftype, "xpath") == 0) {
        if (clicon_rpc_netconf_xml(h, xml_parent(xn), xret, NULL) < 0)
            goto done;
    } else {
        clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                            "<error-tag>operation-failed</error-tag>"
                            "<error-type>applicatio</error-type>"
                            "<error-severity>error</error-severity>"
                            "<error-message>filter type not supported</error-message>"
                            "<error-info>type</error-info>"
                            "</rpc-error></rpc-reply>",
                            NETCONF_BASE_NAMESPACE);
    }
    retval = 0;
 done:
    if(nsc)
        cvec_free(nsc);
    return retval;
}

/*! Called when a notification has happened on backend
 *
 * and this session has registered for that event.
 * Filter it and forward it.
 <notification>
 <eventTime>2007-07-08T00:01:00Z</eventTime>
 <event xmlns="http://example.com/event/1.0">
 <eventClass>fault</eventClass>
 <reportingEntity>
 <card>Ethernet0</card>
 </reportingEntity>
 <severity>major</severity>
 </event>
 </notification>
 * @see rfc5277:
 *  An event notification is sent to the client who initiated a
 *  <create-subscription> command asynchronously when an event of
 *  interest...
 *  Parameters: eventTime type dateTime and compliant to [RFC3339]
 *  Also contains notification-specific tagged content, if any.  With
 *  the exception of <eventTime>, the content of the notification is
 *  beyond the scope of this document.
 */
static int
netconf_notification_cb(int   s,
                        void *arg)
{
    int           eof;
    int           retval = -1;
    cbuf         *cb = NULL;
    cxobj        *xn = NULL; /* event xml */
    cxobj        *xt = NULL; /* top xml */
    clixon_handle h = (clixon_handle)arg;
    yang_stmt    *yspec = NULL;
    cvec         *nsc = NULL;
    int           ret;
    cxobj        *xerr = NULL;
    cbuf         *cbmsg = NULL;

    clixon_debug(CLIXON_DBG_NETCONF, "");
    yspec = clicon_dbspec_yang(h);
    if (clixon_msg_rcv11(s, NULL, 0, &cbmsg, &eof) < 0)
        goto done;
    /* handle close from remote end: this will exit the client */
    if (eof){
        clixon_err(OE_PROTO, ESHUTDOWN, "Socket unexpected close");
        close(s);
        errno = ESHUTDOWN;
        clixon_event_unreg_fd(s, netconf_notification_cb);
        goto done;
    }
    if ((ret = clixon_xml_parse_string(cbuf_get(cbmsg), YB_RPC, yspec, &xt, &xerr)) < 0)
        goto done;
    if (ret == 0){ /* XXX use xerr */
        clixon_err(OE_NETCONF, EFAULT, "Notification malformed");
        goto done;
    }
    if ((nsc = xml_nsctx_init(NULL, NETCONF_NOTIFICATION_NAMESPACE)) == NULL)
        goto done;
    if ((xn = xpath_first(xt, nsc, "notification")) == NULL)
        goto ok;
    /* create netconf message */
    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_PLUGIN, errno, "cbuf_new");
        goto done;
    }
    if (clixon_xml2cbuf1(cb, xn, 0, 0, NULL, -1, 0, 0) < 0)
        goto done;
    /* Send it to listening client on stdout */
    if (netconf_output_encap(clicon_data_int_get(h, NETCONF_FRAMING_TYPE), cb) < 0){
        goto done;
    }
    if (netconf_output(1, cb, "notification") < 0){
        clixon_err(OE_PROTO, ESHUTDOWN, "Socket unexpected close");
        close(s);
        errno = ESHUTDOWN;
        clixon_event_unreg_fd(s, netconf_notification_cb);
        goto done;
    }
    fflush(stdout);
 ok:
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_NETCONF, "retval:%d", retval);
    if (cb)
        cbuf_free(cb);
    if (nsc)
        xml_nsctx_free(nsc);
    if (xt != NULL)
        xml_free(xt);
    if (xerr != NULL)
        xml_free(xerr);
    if (cbmsg)
        cbuf_free(cbmsg);
    return retval;
}

/*
  <create-subscription>
  <stream>RESULT</stream> # If not present, events in the default NETCONF stream will be sent.
  <filter type="xpath" select="XPATHEXPR"/>
  <startTime/> # only for replay (NYI)
  <stopTime/>  # only for replay (NYI)
  </create-subscription>
  Dont support replay
  * @param[in]  h       clicon handle
  * @param[in]  xn      Sub-tree (under xorig) at <rpc>...</rpc> level.
  * @param[out] xret    Return XML, error or OK
  * @see netconf_notification_cb for asynchronous stream notifications
  */
static int
netconf_create_subscription(clixon_handle h,
                            cxobj        *xn,
                            cxobj       **xret)
{
    int              retval = -1;
    cxobj           *xfilter;
    int              s;
    char            *ftype;

    if ((xfilter = xpath_first(xn, NULL, "//filter")) != NULL){
        if ((ftype = xml_find_value(xfilter, "type")) != NULL){
            if (strcmp(ftype, "xpath") != 0){
                clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                                    "<error-tag>operation-failed</error-tag>"
                                    "<error-type>application</error-type>"
                                    "<error-severity>error</error-severity>"
                                    "<error-message>only xpath filter type supported</error-message>"
                                    "<error-info>type</error-info>"
                                    "</rpc-error></rpc-reply>",
                                    NETCONF_BASE_NAMESPACE);
                goto ok;
            }
        }
    }
    if (clicon_rpc_netconf_xml(h, xml_parent(xn), xret, &s) < 0)
        goto done;
    if (xpath_first(*xret, NULL, "rpc-reply/rpc-error") != NULL)
        goto ok;
    if (clixon_event_reg_fd(s,
                            netconf_notification_cb,
                            h,
                            "notification socket") < 0)
        goto done;
 ok:
    retval = 0;
  done:
    return retval;
}

/*! See if there is any application defined RPC for this tag
 *
 * This may either be local client-side or backend. If backend send as netconf
 * RPC.
 * Assume already bound and validated.
 * @param[in]  h       clicon handle
 * @param[in]  xn      Sub-tree (under xorig) at child of rpc: <rpc><xn></rpc>.
 * @param[out] xret    Return XML, error or OK
 * @retval  1   OK, handler called
 * @retval  0   OK, not found handler.
 * @retval -1   Error
 * @see netconf_input_packet  Assume bind and validation made there
 */
static int
netconf_application_rpc(clixon_handle h,
                        cxobj        *xn,
                        cxobj       **xret)
{
    int        retval = -1;
    yang_stmt *yspec = NULL; /* application yspec */
    yang_stmt *yrpc = NULL;
    yang_stmt *ymod = NULL;
    yang_stmt *youtput;
    cxobj     *xoutput;
    cxobj     *xerr = NULL;
    cbuf      *cb = NULL;
    cbuf      *cbret = NULL;
    int        nr = 0;
    int        ret;

    /* First check system / netconf RPC:s */
    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, 0, "cbuf_new");
        goto done;
    }
    if ((cbret = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, 0, "cbuf_new");
        goto done;
    }
    /* Find yang rpc statement, return yang rpc statement if found
       Check application RPC */
    if ((yspec =  clicon_dbspec_yang(h)) == NULL){
        clixon_err(OE_YANG, ENOENT, "No yang spec");
        goto done;
    }
    cbuf_reset(cb);
    if (ys_module_by_xml(yspec, xn, &ymod) < 0)
        goto done;
    if (ymod == NULL){
        clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                            "<error-tag>operation-failed</error-tag>"
                            "<error-type>rpc</error-type>"
                            "<error-severity>error</error-severity>"
                            "<error-message>%s</error-message>"
                            "<error-info>Not recognized module</error-info>"
                            "</rpc-error></rpc-reply>",
                            NETCONF_BASE_NAMESPACE, xml_name(xn));
        goto ok;
    }
    yrpc = yang_find(ymod, Y_RPC, xml_name(xn));
    /* Check if found */
    if (yrpc != NULL){
        /* No need to check xn arguments with input statement since already bound and validated. */
        /* Look for local (client-side) netconf plugins. */
        if ((ret = rpc_callback_call(h, xn, NULL, &nr, cbret)) < 0)
            goto done;
        if (ret == 0){
            if (clixon_xml_parse_string(cbuf_get(cbret), YB_NONE, NULL, xret, NULL) < 0)
                goto done;
        }
        else if (nr > 0){ /* Handled locally */
            if (clixon_xml_parse_string(cbuf_get(cbret), YB_NONE, NULL, xret, NULL) < 0)
                goto done;
        }
        else /* Send to backend */
            if (clicon_rpc_netconf_xml(h, xml_parent(xn), xret, NULL) < 0)
                goto done;
        /* Sanity check of outgoing XML
         * For now, skip outgoing checks.
         * (1) Does not handle <ok/> properly
         * (2) Uncertain how validation errors should be logged/handled
         */
        if (0)
        if ((youtput = yang_find(yrpc, Y_OUTPUT, NULL)) != NULL){
            xoutput=xpath_first(*xret, NULL, "/");
            xml_spec_set(xoutput, youtput); /* needed for xml_bind_yang */
            if ((ret = xml_bind_yang(h, xoutput, YB_MODULE, yspec, 0, &xerr)) < 0)
                goto done;
            if (ret > 0 && (ret = xml_yang_validate_all_top(h, xoutput, &xerr)) < 0)
                goto done;
            if (ret > 0 && (ret = xml_yang_validate_add(h, xoutput, &xerr)) < 0)
                goto done;
            if (ret == 0){
                if (clixon_xml2cbuf1(cbret, xerr, 0, 0, NULL, -1, 0, 0) < 0)
                    goto done;
                clixon_log(h, LOG_WARNING, "Errors in output netconf %s", cbuf_get(cbret));
                goto ok;
            }
        }
        retval = 1; /* handled by callback */
        goto done;
    }
 ok:
    retval = 0;
 done:
    if (xerr)
        xml_free(xerr);
    if (cb)
        cbuf_free(cb);
    if (cbret)
        cbuf_free(cbret);
    return retval;
}

/*! The central netconf rpc dispatcher. Look at first tag and dispach to sub-functions.
 *
 * Call plugin handler if tag not found. If not handled by any handler, return
 * error.
 * @param[in]  h       clicon handle
 * @param[in]  xn      Sub-tree (under xorig) at <rpc>...</rpc> level.
 * @param[out] xret    Return XML, error or OK
 * @param[out] eof     Set to 1 if pending close socket
 * @retval     0       OK, can also be netconf error
 * @retval    -1       Error, fatal
 */
int
netconf_rpc_dispatch(clixon_handle h,
                     cxobj        *xn,
                     cxobj       **xret,
                     int          *eof)
{
    int         retval = -1;
    cxobj      *xe;
    char       *username;
    cxobj      *xa;

    /* Tag username on all incoming requests in case they are forwarded as internal messages
     * This may be unecesary since not all are forwarded.
     * It may even be wrong if something else is done with the incoming message?
     */
    if ((username = clicon_username_get(h)) != NULL){
        if (xml_add_attr(xn, "username", username, CLIXON_LIB_PREFIX, CLIXON_LIB_NS) == NULL)
            goto done;
    }
    /* Many of these calls are now calling generic clicon_rpc_netconf_xml
     * directly, since the validation is generic and done before this place
     * in the call. Some call however need extra validation, such as the
     * filter parameter to get/get-config and tes- err-opts of edit-config.
     */
    xe = NULL;
    while ((xe = xml_child_each(xn, xe, CX_ELMNT)) != NULL) {
        if (strcmp(xml_name(xe), "copy-config") == 0 ||
            strcmp(xml_name(xe), "delete-config") == 0 ||
            strcmp(xml_name(xe), "lock") == 0 ||
            strcmp(xml_name(xe), "unlock") == 0 ||
            strcmp(xml_name(xe), "kill-session") == 0 ||
            strcmp(xml_name(xe), "validate") == 0 ||  /* :validate */
            strcmp(xml_name(xe), "commit") == 0 || /* :candidate */
            strcmp(xml_name(xe), "cancel-commit") == 0 ||
            strcmp(xml_name(xe), "discard-changes") == 0 ||
            strcmp(xml_name(xe), "action") == 0
            ){
            if (clicon_rpc_netconf_xml(h, xml_parent(xe), xret, NULL) < 0)
                goto done;
        }
        else if (strcmp(xml_name(xe), "get-config") == 0){
            if (netconf_get_config(h, xe, xret) < 0)
                goto done;
        }
        else if (strcmp(xml_name(xe), "edit-config") == 0){
            if (netconf_edit_config(h, xe, xret) < 0)
                goto done;
        }
        else if (strcmp(xml_name(xe), "get") == 0){
            if (netconf_get(h, xe, xret) < 0)
                goto done;
        }
        else if (strcmp(xml_name(xe), "close-session") == 0){
            *eof = 1; /* Pending close */
            if (clicon_rpc_netconf_xml(h, xml_parent(xe), xret, NULL) < 0)
                goto done;
        }
        /* RFC 5277 :notification */
        else if (strcmp(xml_name(xe), "create-subscription") == 0){
            if (netconf_create_subscription(h, xe, xret) < 0)
                goto done;
        }
        /* Others */
        else {
            /* Look for application-defined RPC. This may either be local
               client-side or backend. If backend send as netconf RPC. */
            if ((retval = netconf_application_rpc(h, xe, xret)) < 0)
                goto done;
            if (retval == 0){ /* not handled by callback */
                clixon_xml_parse_va(YB_NONE, NULL, xret, NULL, "<rpc-reply xmlns=\"%s\"><rpc-error>"
                                    "<error-tag>operation-failed</error-tag>"
                                    "<error-type>rpc</error-type>"
                                    "<error-severity>error</error-severity>"
                                    "<error-message>%s</error-message>"
                                    "<error-info>Not recognized</error-info>"
                                    "</rpc-error></rpc-reply>",
                                    NETCONF_BASE_NAMESPACE, xml_name(xe));
                goto done;
            }
        }
    }
    retval = 0;
 done:
    /* Username attribute added at top - otherwise it is returned to sender */
    if ((xa = xml_find(xn, "username")) != NULL)
        xml_purge(xa);
    return retval;

}
