/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2026 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * Clixon gRPC/gNMI northbound interface - main entry point
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <syslog.h>
#include <fcntl.h>
#include <sys/time.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

#include "grpc_nghttp2.h"

/* Command line options */
#define GRPC_OPTS "hD:f:l:p:d1"

/*! Usage help routine
 *
 * @param[in]  h      Clixon handle
 * @param[in]  argv0  command line
 */
static int
usage(clixon_handle h,
      const char   *argv0)
{
    fprintf(stderr, "usage:%s [options]\n"
            "where options are\n"
            "\t-h \t\tHelp\n"
            "\t-D <level>\tDebug level\n"
            "\t-f <file>\tClixon config file\n"
            "\t-l <s|e|o|n|f<file>> \tLog on (s)yslog, std(e)rr, std(o)ut, (n)one or (f)ile\n"
            "\t-p <port>\tgRPC listen port (default: 9339)\n"
            "\t-d \t\tDaemonize\n"
            "\t-1 \t\tOneshot: connect to backend and exit\n",
            argv0);
    exit(0);
}

/*! Cleanup and terminate gRPC daemon
 *
 * @param[in]  h   Clixon handle
 * @retval     0   OK
 */
static int
grpc_terminate(clixon_handle h)
{
    cvec  *nsctx;
    cxobj *x;

    clicon_rpc_close_session(h);
    grpc_conns_free_all();
    xml_exit(h);
    yang_exit(h);
    if ((nsctx = clicon_nsctx_global_get(h)) != NULL)
        cvec_free(nsctx);
    if ((x = clicon_conf_xml(h)) != NULL)
        xml_free(x);
    xpath_optimize_exit();
    clixon_event_exit();
    clixon_err_exit();
    clixon_log_exit();
    clixon_debug_exit();
    clixon_handle_exit(h);
    return 0;
}

/*! Quit
 */
static void
grpc_sig_term(int arg)
{
    static int i=0;

    clixon_log(NULL, LOG_NOTICE, "%s: %s: pid: %u Signal %d",
               __PROGRAM__, __func__, getpid(), arg);
    if (i++ > 0) /* Allow one sigterm before proper exit */
        exit(-1);
    /* This should ensure no more accepts or incoming packets are processed because next time eventloop
     * is entered, it will terminate.
     * However there may be a case of sockets closing rather abruptly for clients
     */
    clixon_exit_set(1); /* checked in clixon_event_loop() */
}

int
main(int    argc,
     char **argv)
{
    int            retval = -1;
    int            c;
    clixon_handle  h;
    char          *argv0 = argv[0];
    int            logdst = CLIXON_LOG_STDERR;
    int            dbg = 0;
    int            daemonize = 0;
    int            oneshot = 0;
    uint16_t       port = 9339;
    uint32_t       id;
    yang_stmt     *yspec;
    cvec          *nsctx_global = NULL;
    char          *str;

    /* Create clixon handle */
    if ((h = clixon_handle_init()) == NULL)
        goto done;

    optind = 1;
    opterr = 0;
    while ((c = getopt(argc, argv, GRPC_OPTS)) != -1)
        switch (c){
        case 'h':
            usage(h, argv0);
            break;
        case 'D':
            if (sscanf(optarg, "%d", &dbg) != 1)
                usage(h, argv0);
            break;
        case 'f':
            if (!strlen(optarg))
                usage(h, argv0);
            clicon_option_str_set(h, "CLICON_CONFIGFILE", optarg);
            break;
        case 'l':
            if (clixon_log_opt(optarg[0]) < 0)
                goto done;
            logdst = clixon_log_opt(optarg[0]);
            if (logdst == CLIXON_LOG_FILE && strlen(optarg) > 1){
                if (clixon_log_file(optarg+1) < 0)
                    goto done;
            }
            break;
        case 'p':
            if (sscanf(optarg, "%hu", &port) != 1)
                usage(h, argv0);
            break;
        case 'd':
            daemonize = 1;
            break;
        case '1':
            oneshot = 1;
            break;
        default:
            usage(h, argv0);
            break;
        }

    /* Init log, debug */
    clixon_log_init(h, __PROGRAM__, dbg?LOG_DEBUG:LOG_INFO, logdst);
    clixon_debug_init(h, dbg);

    xml_init(h);
    yang_init(h);

    if (clicon_options_main(h) < 0)
        goto done;

    /* Read debug and log options from config file if not given by command-line */
    if (clixon_options_main_helper(h, dbg, logdst, __PROGRAM__) < 0)
        goto done;

    /* Init event handler */
    clixon_event_init(h);

    /* Set default namespace according to CLICON_NAMESPACE_NETCONF_DEFAULT */
    xml_nsctx_namespace_netconf_default(h);
    yang_start(h);

    /* Add netconf features */
    if (netconf_module_features(h) < 0)
        goto done;

    /* Create top-level yang spec */
    if ((yspec = yspec_new1(h, YANG_DOMAIN_TOP, YANG_DATA_TOP)) == NULL)
        goto done;

    /* Load Yang modules */
    if ((str = clicon_yang_main_file(h)) != NULL){
        if (yang_spec_parse_file(h, str, yspec) < 0)
            goto done;
    }
    if ((str = clicon_yang_module_main(h)) != NULL){
        if (yang_spec_parse_module(h, str, clicon_yang_module_revision(h),
                                   yspec) < 0)
            goto done;
    }
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
    /* Add netconf yang spec */
    if (netconf_module_load(h) < 0)
        goto done;

    /* Compute and set canonical namespace context */
    if (xml_nsctx_yangspec(yspec, &nsctx_global) < 0)
        goto done;
    if (clicon_nsctx_global_set(h, nsctx_global) < 0)
        goto done;

    /* Daemonize */
    if (daemonize){
        if (daemon(0, 0) < 0){
            clixon_err(OE_DAEMON, errno, "daemon");
            goto done;
        }
    }
    if (set_signal(SIGTERM, grpc_sig_term, NULL) < 0){
        clixon_err(OE_DAEMON, errno, "Setting signal");
        goto done;
    }
    if (set_signal(SIGINT, grpc_sig_term, NULL) < 0){
        clixon_err(OE_DAEMON, errno, "Setting signal");
        goto done;
    }
    /* Connect to backend */
    clicon_data_set(h, "session-transport", "cl:grpc");
    if (clicon_hello_req(h, "cl:grpc", NULL, &id) < 0){
        clixon_err(OE_PROTO, 0, "Failed to connect to Clixon backend");
        goto done;
    }
    clixon_debug(CLIXON_DBG_DEFAULT, "Connected to backend, session-id: %u", id);
    clicon_session_id_set(h, id);

    /* TODO: Set up nghttp2 + SSL listener on port */
    /* TODO: Register listen socket with clixon_event_reg_fd() */
    if (grpc_listen_init(h, port) < 0)
        goto done;

    clixon_log(h, LOG_NOTICE, "%s: gRPC/gNMI started on port %u", __PROGRAM__, port);

    if (oneshot){
        /* Oneshot mode: connect and exit (for testing) */
        retval = 0;
        goto done;
    }

    /* Main event loop */
    if (clixon_event_loop(h) < 0)
        goto done;

    retval = 0;
 done:
    clixon_log(h, LOG_NOTICE, "%s: gRPC/gNMI terminated", __PROGRAM__);
    if (h)
        grpc_terminate(h);
    return retval;
}
