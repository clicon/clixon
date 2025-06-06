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

 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdarg.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <time.h>
#include <pwd.h>
#include <libgen.h>
#include <syslog.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/in.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

#include "netconf_rpc.h"

/* Command line options to be passed to getopt(3) */
#define NETCONF_OPTS "hVD:f:E:l:C:q01ca:u:d:p:y:U:t:eo:"

#define NETCONF_LOGFILE "/tmp/clixon_netconf.log"

/* clixon-data value to save buffer between invocations.
 * Saving data may be necessary if socket buffer contains partial netconf messages, such as:
 * <foo/> ..wait 1min  ]]>]]>
 * XXX move to data
 */
/* Unfinished frame  */
#define NETCONF_FRAME_MSG "netconf-frame-msg"

#define NETCONF_FRAME_STATE "netconf-input-frame-state"
#define NETCONF_FRAME_SIZE "netconf-input-frame-size"

/*! Ignore errors on packet errors: continue */
static int ignore_packet_errors = 1;

/* Hello request received */
static int _netconf_hello_nr = 0;

/*! Copy attributes from incoming request to reply. Skip already present (dont overwrite)
 *
 * RFC 6241:
 * If additional attributes are present in an <rpc> element, a NETCONF
 * peer MUST return them unmodified in the <rpc-reply> element.  This
 * includes any "xmlns" attributes.
 * @param[in]     xrpc  Incoming message on the form <rpc>...
 * @param[in,out] xrep  Reply message on the form <rpc-reply>...
 * @retval        0     OK
 * @retval       -1     Error
 */
static int
netconf_add_request_attr(cxobj *xrpc,
                         cxobj *xrep)
{
    int    retval = -1;
    cxobj *xa;
    cxobj *xa2 = NULL;

    xa = NULL;
    while ((xa = xml_child_each(xrpc, xa, CX_ATTR)) != NULL){
        /* If attribute already exists, dont copy it */
        if (xml_find_type(xrep, NULL, xml_name(xa), CX_ATTR) != NULL)
            continue; /* Skip already present (dont overwrite) */
        /* Filter all clixon-lib attributes and namespace declaration
         * to avoid leaking internal attributes to external NETCONF
         * note this is only done on top-level.
         */
        if (xml_prefix(xa) && strcmp(xml_prefix(xa), CLIXON_LIB_PREFIX) == 0)
            continue;
        if (xml_prefix(xa) && strcmp(xml_prefix(xa), "xmlns") == 0 &&
            strcmp(xml_name(xa), CLIXON_LIB_PREFIX) == 0)
            continue;
        if ((xa2 = xml_dup(xa)) ==NULL)
            goto done;
        if (xml_addsub(xrep, xa2) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Process netconf hello message
 *
 * A server receiving a <hello> message with a <session-id> element MUST
 * terminate the NETCONF session.
 * @param[in]   h    Clixon handle
 * @param[in]   xn
 * @param[out]  eof  Request termination
 * @retval      0    OK
 * @retval     -1    Error
 */
static int
netconf_hello_msg(clixon_handle h,
                  cxobj        *xn,
                  int          *eof)
{
    int     retval = -1;
    cvec   *nsc = NULL; // namespace context
    cxobj **vec = NULL;
    size_t  veclen;
    cxobj  *x;
    cxobj  *xcap;
    int     foundbase_10 = 0;
    int     foundbase_11 = 0;
    char   *body;

    clixon_debug(CLIXON_DBG_NETCONF, "");
    _netconf_hello_nr++;
    if (xml_find_type(xn, NULL, "session-id", CX_ELMNT) != NULL) {
        clixon_err(OE_XML, errno, "Server received hello with session-id from client, terminating (see RFC 6241 Sec 8.1");
        goto done;
    }
    if (xpath_vec(xn, nsc, "capabilities/capability", &vec, &veclen) < 0)
        goto done;
    /* Each peer MUST send at least the base NETCONF capability, "urn:ietf:params:netconf:base:1.1"*/
    if ((xcap = xml_find_type(xn, NULL, "capabilities", CX_ELMNT)) != NULL) {
        x = NULL;
        while ((x = xml_child_each(xcap, x, CX_ELMNT)) != NULL) {
            if (strcmp(xml_name(x), "capability") != 0)
                continue;
            if ((body = xml_body(x)) == NULL)
                continue;
            /* When comparing protocol version capability URIs, only the base part is used, in the
             * event any parameters are encoded at the end of the URI string. */
            if (strncmp(body, NETCONF_BASE_CAPABILITY_1_0, strlen(NETCONF_BASE_CAPABILITY_1_0)) == 0){ /* RFC 4741 */
                foundbase_10++;
                clixon_debug(CLIXON_DBG_NETCONF, "foundbase10");
            }
            else if (strncmp(body, NETCONF_BASE_CAPABILITY_1_1, strlen(NETCONF_BASE_CAPABILITY_1_1)) == 0 &&
                     clicon_option_int(h, "CLICON_NETCONF_BASE_CAPABILITY") > 0){ /* RFC 6241 */
                foundbase_11++;
                clixon_debug(CLIXON_DBG_NETCONF, "foundbase11");
                clicon_data_int_set(h, NETCONF_FRAMING_TYPE, NETCONF_SSH_CHUNKED); /* enable chunked enc */
            }
        }
    }
    if (foundbase_10 == 0 && foundbase_11 == 0){
        clixon_err(OE_XML, errno, "Server received hello without matching netconf base capability, terminating (see RFC 6241 Sec 8.1");
        *eof = 1;
        goto done;
    }
    retval = 0;
 done:
    if (vec)
        free(vec);
    return retval;
}

/*! Process incoming Netconf RPC netconf message
 *
 * @param[in]   h     Clixon handle
 * @param[in]   xreq  XML tree containing netconf RPC message
 * @param[in]   yspec YANG spec
 * @param[out]  eof   Set to 1 if pending close socket
 * @retval      0     OK
 * @retval     -1     Error
 */
static int
netconf_rpc_message(clixon_handle h,
                    cxobj        *xrpc,
                    yang_stmt    *yspec,
                    int          *eof)
{
    int                  retval = -1;
    cxobj               *xret = NULL; /* Return (out) */
    int                  ret;
    cbuf                *cbret = NULL;
    cxobj               *xc;
    netconf_framing_type framing;

    framing = clicon_data_int_get(h, NETCONF_FRAMING_TYPE);
    if (_netconf_hello_nr == 0 &&
        clicon_option_bool(h, "CLICON_NETCONF_HELLO_OPTIONAL") == 0){
        if (netconf_operation_failed_xml(&xret, "rpc", "Client must send an hello element before any RPC")< 0)
            goto done;
        /* Copy attributes from incoming request to reply. Skip already present (dont overwrite) */
        if (netconf_add_request_attr(xrpc, xret) < 0)
            goto done;
        if ((cbret = cbuf_new()) == NULL){
            clixon_err(OE_XML, errno, "cbuf_new");
            goto done;
        }
        if (clixon_xml2cbuf(cbret, xret, 0, 0, NULL, -1, 0) < 0)
            goto done;
        if (netconf_output_encap(framing, cbret) < 0)
            goto done;
        if (netconf_output(1, cbret, "rpc-error") < 0)
            goto done;
        *eof = 1;
        goto ok;
    }
    if ((ret = xml_bind_yang_rpc(h, xrpc, yspec, &xret)) < 0)
        goto done;
    if (ret > 0 &&
        (ret = xml_yang_validate_rpc(h, xrpc, 0, &xret)) < 0)
        goto done;
    if (ret == 0){
        if (netconf_add_request_attr(xrpc, xret) < 0)
            goto done;
        if ((cbret = cbuf_new()) == NULL){
            clixon_err(OE_XML, errno, "cbuf_new");
            goto done;
        }
        if (clixon_xml2cbuf(cbret, xret, 0, 0, NULL, -1, 0) < 0)
            goto done;
        if (netconf_output_encap(framing, cbret) < 0)
            goto done;
        if (netconf_output(1, cbret, "rpc-error") < 0)
            goto done;
        goto ok;
    }
    if (netconf_rpc_dispatch(h, xrpc, &xret, eof) < 0)
        goto done;

    /* Is there a return message in xret? */
    if (xret == NULL){
        if (netconf_operation_failed_xml(&xret, "rpc", "Internal error: no xml return")< 0)
            goto done;
        if (netconf_add_request_attr(xrpc, xret) < 0)
            goto done;
        if ((cbret = cbuf_new()) == NULL){
            clixon_err(OE_XML, errno, "cbuf_new");
            goto done;
        }
        if (clixon_xml2cbuf(cbret, xret, 0, 0, NULL, -1, 0) < 0)
            goto done;
        if (netconf_output_encap(framing, cbret) < 0)
            goto done;
        if (netconf_output(1, cbret, "rpc-error") < 0)
            goto done;
        goto ok;
    }
    if ((xc = xml_child_i(xret, 0))!=NULL){
        /* Copy attributes from incoming request to reply. Skip already present (dont overwrite) */
        if (netconf_add_request_attr(xrpc, xc) < 0)
            goto done;
        if ((cbret = cbuf_new()) == NULL){
            clixon_err(OE_XML, errno, "cbuf_new");
            goto done;
        }
        if (clixon_xml2cbuf(cbret, xml_child_i(xret,0), 0, 0, NULL, -1, 0) < 0)
            goto done;
        if (netconf_output_encap(framing, cbret) < 0)
            goto done;
        if (netconf_output(1, cbret, "rpc-reply") < 0)
            goto done;
    }
 ok:
    retval = 0;
 done:
    if (cbret)
        cbuf_free(cbret);
    if (xret)
        xml_free(xret);
    return retval;
}

/*! Process incoming a single netconf message parsed as XML
 *
 * Identify what netconf message it is
 * @param[in]   h     Clixon handle
 * @param[in]   xreq  XML tree containing netconf
 * @param[in]   yspec YANG spec
 * @param[out]  eof   Set to 1 if pending close socket
 * @retval      0     OK
 * @retval     -1     Error
 */
static int
netconf_input_packet(clixon_handle h,
                     cxobj        *xreq,
                     yang_stmt    *yspec,
                     int          *eof)
{
    int     retval = -1;
    cbuf   *cbret = NULL;
    char   *rpcname;
    char   *rpcprefix;
    char   *namespace = NULL;
    cxobj  *xret = NULL;
    netconf_framing_type framing;

    clixon_debug(CLIXON_DBG_NETCONF, "");
    clixon_debug_xml(CLIXON_DBG_NETCONF, xreq, "");
    rpcname = xml_name(xreq);
    rpcprefix = xml_prefix(xreq);
    framing = clicon_data_int_get(h, NETCONF_FRAMING_TYPE);
    if (xml2ns(xreq, rpcprefix, &namespace) < 0)
        goto done;
    if (strcmp(rpcname, "rpc") == 0){
        /* Only accept resolved NETCONF base namespace */
        if (namespace == NULL || strcmp(namespace, NETCONF_BASE_NAMESPACE) != 0){
            if (netconf_unknown_namespace_xml(&xret, "protocol", rpcprefix, "No appropriate namespace associated with prefix")< 0)
                goto done;
            if (netconf_add_request_attr(xreq, xret) < 0)
                goto done;
            if ((cbret = cbuf_new()) == NULL){
                clixon_err(OE_XML, errno, "cbuf_new");
                goto done;
            }
            if (clixon_xml2cbuf(cbret, xret, 0, 0, NULL, -1, 0) < 0)
                goto done;
            if (netconf_output_encap(framing, cbret) < 0)
                goto done;
            if (netconf_output(1, cbret, "rpc-error") < 0)
                goto done;
            goto ok;
        }
        if (netconf_rpc_message(h, xreq, yspec, eof) < 0)
            goto done;
    }
    else if (strcmp(rpcname, "hello") == 0){
        /* Only accept resolved NETCONF base namespace -> terminate*/
        if (namespace == NULL || strcmp(namespace, NETCONF_BASE_NAMESPACE) != 0){
            *eof = 1;
            clixon_err(OE_XML, EFAULT, "No appropriate namespace associated with namespace:%s",
                       namespace);
            goto done;
        }
        if (netconf_hello_msg(h, xreq, eof) < 0)
            goto done;
    }
    else{ /* Shouldnt happen should be caught by yang bind check in netconf_input_frame */
        *eof = 1;
        clixon_err(OE_NETCONF, 0, "Unrecognized netconf operation %s", rpcname);
        goto done;
    }
 ok:
    retval = 0;
 done:
    if (xret)
        xml_free(xret);
    if (cbret)
        cbuf_free(cbret);
    return retval;
}

/*! Get netconf message: detect end-of-msg
 *
 * @param[in]  s    Socket where input arrived. read from this.
 * @param[in]  arg  Clixon handle.
 * @retval     0    OK
 * @retval    -1    Error
 * This routine continuously reads until no more data on s. There could
 * be risk of starvation, but the netconf client does little else than
 * read data so I do not see a danger of true starvation here.
 * @note data is saved in clicon-handle at NETCONF_FRAME_MSG since there is a potential issue if data
 * is not completely present on the s, ie if eg:
 *   <a>foo ..pause.. </a>]]>]]>
 * then only "</a>" would be delivered to netconf_input_frame().
 */
static int
netconf_input_cb(int   s,
                 void *arg)
{
    int            retval = -1;
    clixon_handle  h = arg;
    cbuf          *cbmsg=NULL;
    cbuf          *cberr = NULL;
    void          *ptr;
    yang_stmt     *yspec;
    clicon_hash_t *cdat = clicon_data(h); /* Save cbuf between calls if not done */
    size_t         cdatlen = 0;
    int            frame_state;
    size_t         frame_size;
    int            i32;
    int            eom = 0;
    int            eof = 0;
    netconf_framing_type framing_type;
    cxobj         *xtop = NULL;
    cxobj         *xreq;
    cxobj         *xerr = NULL;
    int            ret;
    unsigned char  buf[BUFSIZ]; /* from stdio.h, typically 8K */
    ssize_t        buflen = sizeof(buf);
    unsigned char *p = buf;
    ssize_t        len;
    size_t         plen;

    yspec = clicon_dbspec_yang(h);
    /* Get unfinished frame */
    if ((ptr = clicon_hash_value(cdat, NETCONF_FRAME_MSG, &cdatlen)) != NULL){
        if (cdatlen != sizeof(cbmsg)){
            clixon_err(OE_XML, errno, "size mismatch %lu %lu",
                       (unsigned long)cdatlen, (unsigned long)sizeof(cbmsg));
            goto done;
        }
        cbmsg = *(cbuf**)ptr;
        clicon_hash_del(cdat, NETCONF_FRAME_MSG);
    }
    else{
        if ((cbmsg = cbuf_new()) == NULL){
            clixon_err(OE_XML, errno, "cbuf_new");
            goto done;
        }
    }
    if ((frame_state = clicon_data_int_get(h, NETCONF_FRAME_STATE)) < 0)
        frame_state = 0;
    if ((i32 = clicon_data_int_get(h, NETCONF_FRAME_SIZE)) < 0)
        frame_size = 0;
    else
        frame_size = i32;
    /* Read input data from socket and append to cbuf */
    if ((len = netconf_input_read2(s, buf, buflen, &eof)) < 0)
        goto done;
    p = buf;
    plen = len;
    while (!eof  && plen > 0){
        framing_type = clicon_data_int_get(h, NETCONF_FRAMING_TYPE); /* Can be set in frame handler */
        if (netconf_input_msg2(&p, &plen,
                               cbmsg,
                               framing_type,
                               &frame_state,
                               &frame_size,
                               &eom) < 0)
            goto done;
        if (eom == 0){ /* frame not complete */
            clixon_debug(CLIXON_DBG_NETCONF | CLIXON_DBG_DETAIL, "frame: %lu", cbuf_len(cbmsg));
            /* Extra data to read, save data and continue on next round */
            if (clicon_hash_add(cdat, NETCONF_FRAME_MSG, &cbmsg, sizeof(cbmsg)) == NULL)
                goto done;
            cbmsg = NULL;
            break;
        }
        if (clixon_debug_detail())
            clixon_debug(CLIXON_DBG_MSG | CLIXON_DBG_DETAIL, "Recv ext: %s", cbuf_get(cbmsg));
        else
            clixon_debug(CLIXON_DBG_MSG, "Recv ext len: %lu", cbuf_len(cbmsg));
        if ((ret = netconf_input_frame2(cbmsg, YB_RPC, yspec, &xtop, &xerr)) < 0)
            goto done;
        cbuf_reset(cbmsg);
        if (ret == 0){ /* Invalid frame, parse error, etc */
            if ((cberr = cbuf_new()) == NULL){
                clixon_err(OE_XML, errno, "cbuf_new");
                goto done;
            }
            if (clixon_xml2cbuf(cberr, xerr, 0, 0, NULL, -1, 0) < 0)
                goto done;
            if (xerr){
                xml_free(xerr);
                xerr = NULL;
            }
            if (netconf_output_encap(framing_type, cberr) < 0)
                goto done;
            if (netconf_output(1, cberr, "rpc-error") < 0)
                goto done;
        }
        else {
            if ((xreq = xml_child_i_type(xtop, 0, CX_ELMNT)) == NULL){
                clixon_err(OE_XML, EFAULT, "No xml req (shouldnt happen)");
                goto done;
            }
            if (netconf_input_packet(h, xreq, yspec, &eof) < 0){
                goto done;
            }
            if (xtop){
                xml_free(xtop);
                xtop = NULL;
            }
        }
    }
    if (eof){ /* socket closed / read returns 0 */
        clixon_debug(CLIXON_DBG_NETCONF, "len==0, closing");
        clixon_event_unreg_fd(s, netconf_input_cb);
        close(s);
        clixon_exit_set(1);
    }
    else {
        clicon_data_int_set(h, NETCONF_FRAME_STATE, frame_state);
        clicon_data_int_set(h, NETCONF_FRAME_SIZE, frame_size);
    }
    retval = 0;
 done:
    if (cbmsg)
        cbuf_free(cbmsg);
    if (cberr)
        cbuf_free(cberr);
    if (xtop)
        xml_free(xtop);
    if (xerr)
        xml_free(xerr);
    return retval;
}

/*! Send netconf hello message
 *
 * @param[in]   h   Clixon handle
 * @param[in]   s   File descriptor to write on (eg 1 - stdout)
 * @retval     0    OK
 * @retval    -1    Error
 */
static int
send_hello(clixon_handle h,
           int           s,
           uint32_t      id)
{
    int                  retval = -1;
    cbuf                *cb;
    netconf_framing_type framing;

    if ((cb = cbuf_new()) == NULL){
        clixon_log(h, LOG_ERR, "%s: cbuf_new", __func__);
        goto done;
    }
    if (netconf_hello_server(h, cb, id) < 0)
        goto done;
    framing = clicon_data_int_get(h, NETCONF_FRAMING_TYPE);
    if (netconf_output_encap(framing, cb) < 0)
        goto done;
    if (netconf_output(s, cb, "hello") < 0)
        goto done;
    retval = 0;
  done:
    if (cb)
        cbuf_free(cb);
    return retval;
}

/*! Clean and close all state of netconf process (but dont exit).
 *
 * Cannot use h after this
 * @param[in]  h  Clixon handle
 */
static int
netconf_terminate(clixon_handle h)
{
    cvec  *nsctx;
    cxobj *x;

    if (clixon_exit_get() == 0)
        clixon_exit_set(1);
    /* Delete all plugins, and RPC callbacks */
    clixon_plugin_module_exit(h);
    clicon_rpc_close_session(h);
    yang_exit(h);
    if ((nsctx = clicon_nsctx_global_get(h)) != NULL)
        cvec_free(nsctx);
    if ((x = clicon_conf_xml(h)) != NULL)
        xml_free(x);
    xpath_optimize_exit();
    clixon_event_exit();
    clixon_handle_exit(h);
    clixon_err_exit();
    clixon_log_exit();
    return 0;
}

/*! Setup signal handlers
 */
static int
netconf_signal_init(clixon_handle h)
{
    int retval = -1;

    if (set_signal(SIGPIPE, SIG_IGN, NULL) < 0){
        clixon_err(OE_UNIX, errno, "Setting DIGPIPE signal");
        goto done;
    }
    retval = 0;
 done:
    return retval;
}

static int
timeout_fn(int   s,
           void *arg)
{
    clixon_err(OE_EVENTS, ETIMEDOUT, "User request timeout");
    return -1;
}

/*! Usage help routine
 *
 * @param[in]  h      Clixon handle
 * @param[in]  argv0  command line
 */
static void
usage(clixon_handle h,
      char         *argv0)
{
    fprintf(stderr, "usage:%s\n"
            "where options are\n"
            "\t-h\t\tHelp\n"
            "\t-V \t\tPrint version and exit\n"
            "\t-D <level>\tDebug level (see available levels below)\n"
            "\t-f <file>\tConfiguration file (mandatory)\n"
            "\t-E <dir> \tExtra configuration file directory\n"
            "\t-l <s|e|o|n|f<file>> \tLog on (s)yslog, std(e)rr, std(o)ut, (n)one or (f)ile (syslog is default)\n"
            "\t-C <format>\tDump configuration options on stdout after loading and exit. Format is xml|json|text\n"
            "\t-q\t\tServer does not send hello message on startup\n"
            "\t-0 \t\tSet netconf base capability to 0, server does not expect hello, force EOM framing\n"
            "\t-1 \t\tSet netconf base capability to 1, server does not expect hello, force chunked framing\n"
            "\t-a UNIX|IPv4|IPv6 Internal backend socket family\n"
            "\t-u <path|addr>\tInternal socket domain path or IP addr (see -a)\n"
            "\t-d <dir>\tSpecify netconf plugin directory dir (default: %s)\n"
            "\t-p <dir>\tAdd Yang directory path (see CLICON_YANG_DIR)\n"
            "\t-y <file>\tLoad yang spec file (override yang main module)\n"
            "\t-U <user>\tOver-ride unix user with a pseudo user for NACM.\n"
            "\t-t <sec>\tTimeout in seconds. Quit after this time.\n"
            "\t-e \t\tDont ignore errors on packet input.\n"
            "\t-o \"<option>=<value>\"\tGive configuration option overriding config file (see clixon-config.yang)\n",
            argv0,
            clicon_netconf_dir(h)
            );
    fprintf(stderr, "Debug keys: ");
    clixon_debug_key_dump(stderr);
    fprintf(stderr, "\n");
    exit(0);
}

int
main(int    argc,
     char **argv)
{
    int              retval = -1;
    int              c;
    char            *argv0 = argv[0];
    int              quiet = 0;
    clixon_handle    h;
    char            *dir;
    int              logdst = CLIXON_LOG_SYSLOG;
    struct passwd   *pw;
    struct timeval   tv = {0,}; /* timeout */
    yang_stmt       *yspec = NULL;
    char            *str;
    uint32_t         id;
    cvec            *nsctx_global = NULL; /* Global namespace context */
    size_t           cligen_buflen;
    size_t           cligen_bufthreshold;
    int              dbg = 0;
    size_t           sz;
    int              config_dump = 0;
    enum format_enum config_dump_format = FORMAT_XML;
    int              print_version = 0;
    int32_t          d;

    /* Create handle */
    if ((h = clixon_handle_init()) == NULL)
        return -1;
    /* In the startup, logs to stderr & debug flag set later */
    if (clixon_log_init(h, __PROGRAM__, LOG_INFO, logdst) < 0)
        return -1;
    if (clixon_err_init(h) < 0)
        return -1;
    /* Set username to clixon handle. Use in all communication to backend */
    if ((pw = getpwuid(getuid())) == NULL){
        clixon_err(OE_UNIX, errno, "getpwuid");
        goto done;
    }
    if (clicon_username_set(h, pw->pw_name) < 0)
        goto done;
    while ((c = getopt(argc, argv, NETCONF_OPTS)) != -1) {
        switch (c) {
        case 'h' : /* help */
            usage(h, argv[0]);
            break;
        case 'V': /* version */
            cligen_output(stdout, "Clixon version: %s\n", CLIXON_VERSION);
            print_version++; /* plugins may also print versions w ca-version callback */
            break;
        case 'D' :  /* debug */
            /* Try first symbolic, then numeric match */
            if ((d = clixon_debug_str2key(optarg)) < 0 &&
                sscanf(optarg, "%u", &d) != 1){
                usage(h, argv[0]);
            }
            dbg |= d;
            break;
        case 'f': /* override config file */
            if (!strlen(optarg))
                usage(h, argv[0]);
            clicon_option_str_set(h, "CLICON_CONFIGFILE", optarg);
            break;
        case 'E': /* extra config directory */
            if (!strlen(optarg))
                usage(h, argv[0]);
            clicon_option_str_set(h, "CLICON_CONFIGDIR", optarg);
            break;
        case 'l': /* Log destination: s|e|o */
            d = 0;
            if ((d = clixon_logdst_str2key(optarg)) < 0){
                if (optarg[0] == 'f'){ /* Check for special -lf<file> syntax */
                    d = CLIXON_LOG_FILE;
                    if (strlen(optarg) > 1 &&
                        clixon_log_file(optarg+1) < 0)
                        goto done;
                }
                else
                    usage(h, argv[0]);
            }
            logdst = d;
            break;
        }
    }

    /*
     * Logs, error and debug to stderr or syslog, set debug level
     */
    clixon_log_init(h, __PROGRAM__, dbg?LOG_DEBUG:LOG_INFO, logdst);
    clixon_debug_init(h, dbg);
    yang_init(h);

    /* Find, read and parse configfile */
    if (clicon_options_main(h) < 0)
        goto done;

    /* Now rest of options */
    optind = 1;
    opterr = 0;
    while ((c = getopt(argc, argv, NETCONF_OPTS)) != -1)
        switch (c) {
        case 'h' : /* help */
        case 'V' : /* version */
        case 'D' : /* debug */
        case 'f' :  /* config file */
        case 'E' : /* extra config dir */
        case 'l' :  /* log  */
            break; /* see above */
        case 'C' : /* Explicitly dump configuration */
            if ((config_dump_format = format_str2int(optarg)) ==  (enum format_enum)-1){
                fprintf(stderr, "Unrecognized dump format: %s(expected: xml|json|text)\n", argv[0]);
                usage(h, argv[0]);
            }
            config_dump++;
            break;
        case 'q':  /* quiet: dont write hello */
            quiet++;
            break;
        case 'a': /* internal backend socket address family */
            clicon_option_str_set(h, "CLICON_SOCK_FAMILY", optarg);
            break;
        case 'u': /* internal backend socket unix domain path or ip host */
            if (!strlen(optarg))
                usage(h, argv[0]);
            clicon_option_str_set(h, "CLICON_SOCK", optarg);
            break;
        case 'd':  /* Plugin directory */
            if (!strlen(optarg))
                usage(h, argv[0]);
            if (clicon_option_add(h, "CLICON_NETCONF_DIR", optarg) < 0)
                goto done;
            break;
        case 'p' : /* yang dir path */
            if (clicon_option_add(h, "CLICON_YANG_DIR", optarg) < 0)
                goto done;
            break;
        case 'y' : /* Load yang spec file (override yang main module) */
            if (clicon_option_add(h, "CLICON_YANG_MAIN_FILE", optarg) < 0)
                goto done;
            break;
        case 'U': /* Clixon 'pseudo' user */
            if (!strlen(optarg))
                usage(h, argv[0]);
            if (clicon_username_set(h, optarg) < 0)
                goto done;
            break;
        case 't': /* timeout in seconds */
            tv.tv_sec = atoi(optarg);
            break;
        case 'e': /* dont ignore packet errors */
            ignore_packet_errors = 0;
            break;
        case '0': /* Force EOM */
            clicon_option_int_set(h, "CLICON_NETCONF_BASE_CAPABILITY", 0);
            clicon_option_bool_set(h, "CLICON_NETCONF_HELLO_OPTIONAL", 1);
            break;
        case '1': /* Hello messages are optional */
            clicon_option_int_set(h, "CLICON_NETCONF_BASE_CAPABILITY", 1);
            clicon_option_bool_set(h, "CLICON_NETCONF_HELLO_OPTIONAL", 1);
            break;
        case 'o':{ /* Configuration option */
            char          *val;
            if ((val = index(optarg, '=')) == NULL)
                usage(h, argv0);
            *val++ = '\0';
            if (clicon_option_add(h, optarg, val) < 0)
                goto done;
            break;
        }
        default:
            usage(h, argv[0]);
            break;
        }
    argc -= optind;
    argv += optind;

    /* Read debug and log options from config file if not given by command-line */
    if (clixon_options_main_helper(h, dbg, logdst, __PROGRAM__) < 0)
        goto done;
    /* Access the remaining argv/argc options (after --) w clicon-argv_get() */
    clicon_argv_set(h, argv0, argc, argv);

    /* Init cligen buffers */
    cligen_buflen = clicon_option_int(h, "CLICON_CLI_BUF_START");
    cligen_bufthreshold = clicon_option_int(h, "CLICON_CLI_BUF_THRESHOLD");
    cbuf_alloc_set(cligen_buflen, cligen_bufthreshold);

    if ((sz = clicon_option_int(h, "CLICON_LOG_STRING_LIMIT")) != 0)
        clixon_log_string_limit_set(sz);

    /* Init event handler */
    clixon_event_init(h);

    /* Set default namespace according to CLICON_NAMESPACE_NETCONF_DEFAULT */
    xml_nsctx_namespace_netconf_default(h);

    /* Add (hardcoded) netconf features in case ietf-netconf loaded here
     * Otherwise it is loaded in netconf_module_load below
     */
    if (netconf_module_features(h) < 0)
        goto done;

    /* Setup signal handlers, int particular PIPE that occurs if backend closes / restarts */
    if (netconf_signal_init(h) < 0)
        goto done;

    /* Initialize plugin module by creating a handle holding plugin and callback lists */
    if (clixon_plugin_module_init(h) < 0)
        goto done;
    yang_start(h);
    /* In case ietf-yang-metadata is loaded by application, handle annotation extension */
    if (yang_metadata_init(h) < 0)
        goto done;
    /* Create top-level yang spec and store as option */
    if ((yspec = yspec_new1(h, YANG_DOMAIN_TOP, YANG_DATA_TOP)) == NULL)
        goto done;

    /* Load netconf plugins before yangs are loaded (eg extension callbacks) */
    if ((dir = clicon_netconf_dir(h)) != NULL &&
        clixon_plugins_load(h, CLIXON_PLUGIN_INIT, dir, NULL) < 0)
        goto done;
    /* Print version, customized variant must wait for plugins to load */
    if (print_version){
        if (clixon_plugin_version_all(h, stdout) < 0)
            goto done;
        goto ok;
    }
    /* Load Yang modules
     * 1. Load a yang module as a specific absolute filename */
    if ((str = clicon_yang_main_file(h)) != NULL){
        if (yang_spec_parse_file(h, str, yspec) < 0)
            goto done;
    }
    /* 2. Load a (single) main module */
    if ((str = clicon_yang_module_main(h)) != NULL){
        if (yang_spec_parse_module(h, str, clicon_yang_module_revision(h),
                                   yspec) < 0)
            goto done;
    }
    /* 3. Load all modules in a directory */
    if ((str = clicon_yang_main_dir(h)) != NULL){
        if (yang_spec_load_dir(h, str, yspec) < 0)
            goto done;
    }
    /* Load clixon lib yang module */
    if (yang_spec_parse_module(h, "clixon-lib", NULL, yspec) < 0)
        goto done;
    /* Load yang module library, RFC7895 */
    if (yang_modules_init(h) < 0)
        goto done;
    /* Add netconf yang spec, used by netconf client and as internal protocol */
    if (netconf_module_load(h) < 0)
        goto done;
    /* Here all modules are loaded
     * Compute and set canonical namespace context
     */
    if (xml_nsctx_yangspec(yspec, &nsctx_global) < 0)
        goto done;
    if (clicon_nsctx_global_set(h, nsctx_global) < 0)
        goto done;

    /* Call start function is all plugins before we go interactive */
    if (clixon_plugin_start_all(h) < 0)
        goto done;

    /* Explicit dump of config (also debug dump below). */
    if (config_dump){
        if (clicon_option_dump1(h, stdout, config_dump_format, 1) < 0)
            goto done;
        goto ok;
    }
    /* Debug dump of config options */
    clicon_option_dump(h, CLIXON_DBG_INIT);

    /* Send hello request to backend to get session-id back
     * This is done once at the beginning of the session and then this is
     * used by the client, even though new TCP sessions are created for
     * each message sent to the backend.
     */
    if (clicon_hello_req(h, "cl:netconf", NULL, &id) < 0)
        goto done;
    clicon_session_id_set(h, id);

    /* Send hello to northbound client
     * Note that this is a violation of RDFC 6241 Sec 8.1:
     * When the NETCONF session is opened, each peer(both client and server) MUST send a <hello..
     */
    if (!quiet){
        if (send_hello(h, 1, id) < 0)
            goto done;
    }
#ifdef __AFL_HAVE_MANUAL_CONTROL
    /* American fuzzy loop deferred init, see CLICON_NETCONF_HELLO_OPTIONAL=true, see a speedup of x10 */
    __AFL_INIT();
#endif
    if (clixon_event_reg_fd(0, netconf_input_cb, h, "netconf socket") < 0)
        goto done;
    if (tv.tv_sec || tv.tv_usec){
        struct timeval t;
        gettimeofday(&t, NULL);
        timeradd(&t, &tv, &t);
        if (clixon_event_reg_timeout(t, timeout_fn, NULL, "timeout") < 0)
            goto done;
    }
    if (clixon_event_loop(h) < 0)
        goto done;
 ok:
    retval = 0;
 done:
    if (ignore_packet_errors)
        retval = 0;
    clixon_exit_set(1); /* This is to disable resend mechanism in close-session */
    clixon_log_init(h, __PROGRAM__, LOG_INFO, 0); /* Log on syslog no stderr */
    clixon_log(h, LOG_NOTICE, "%s: %u Terminated", __PROGRAM__, getpid());
    netconf_terminate(h);
    return retval;
}
