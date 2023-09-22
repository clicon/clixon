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
  * The example have the following optional arguments that you can pass as 
  * argc/argv after -- in clixon_cli:
  *  -m <yang> Mount this yang on mountpoint
  *  -M <namespace> Namespace of mountpoint, note both -m and -M must exist
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/param.h>
#include <netinet/in.h>
#include <signal.h> /* matching strings */

/* clicon */
#include <cligen/cligen.h>
#include <clixon/clixon.h>
#include <clixon/clixon_cli.h>
#include <clixon/cli_generate.h>

/*! Yang schema mount
 *
 * Start backend with -- -m <yang> -M <namespace>
 * Mount this yang on mountpoint
 */
static char *_mount_yang = NULL;
static char *_mount_namespace = NULL;

/*! Example cli function */
int
mycallback(clicon_handle h, cvec *cvv, cvec *argv)
{
    int      retval = -1;
    cxobj   *xret = NULL;
    cg_var  *myvar;
    cvec    *nsc = NULL;

    /* Access cligen callback variables */
    myvar = cvec_find(cvv, "var"); /* get a cligen variable from vector */
    fprintf(stderr, "%s: %d\n", __FUNCTION__, cv_int32_get(myvar)); /* get int value */
    fprintf(stderr, "arg = %s\n", cv_string_get(cvec_i(argv,0))); /* get string value */

    if ((nsc = xml_nsctx_init(NULL, "urn:example:clixon")) == NULL)
        goto done;
    /* Show eth0 interfaces config using XPATH */
    if (clicon_rpc_get_config(h, NULL, "running",
                              "/interfaces/interface[name='eth0']",
                              nsc, NULL, 
                              &xret) < 0)
        goto done;
    if (clixon_xml2file(stdout, xret, 0, 1, NULL, cligen_output, 0, 1) < 0)
        goto done;
    retval = 0;
 done:
    if (nsc)
        xml_nsctx_free(nsc);
    if (xret)
        xml_free(xret);
    return retval;
}

/*! Example "downcall", ie initiate an RPC to the backend */
int
example_client_rpc(clicon_handle h, 
                   cvec         *cvv, 
                   cvec         *argv)
{
    int        retval = -1;
    cg_var    *cva;
    cxobj     *xtop = NULL;
    cxobj     *xrpc;
    cxobj     *xret = NULL;
    cxobj     *xerr;

    /* User supplied variable in CLI command */
    cva = cvec_find(cvv, "a"); /* get a cligen variable from vector */
    /* Create XML for example netconf RPC */
    if (clixon_xml_parse_va(YB_NONE, NULL, &xtop, NULL,
                            "<rpc xmlns=\"%s\" username=\"%s\" %s>"
                            "<example xmlns=\"urn:example:clixon\"><x>%s</x></example></rpc>",
                            NETCONF_BASE_NAMESPACE,
                            clicon_username_get(h),
                            NETCONF_MESSAGE_ID_ATTR,
                            cv_string_get(cva)) < 0)
        goto done;
    /* Skip top-level */
    xrpc = xml_child_i(xtop, 0);
    /* Send to backend */
    if (clicon_rpc_netconf_xml(h, xrpc, &xret, NULL) < 0)
        goto done;
    if ((xerr = xpath_first(xret, NULL, "//rpc-error")) != NULL){
        clixon_netconf_error(xerr, "Get configuration", NULL);
        goto done;
    }
    /* Print result */
    if (clixon_xml2file(stdout, xml_child_i(xret, 0), 0, 0, NULL, cligen_output, 0, 1) < 0)
        goto done;
    fprintf(stdout,"\n");

    /* pretty-print:
       clixon_text2file(stdout, xml_child_i(xret, 0), 0, cligen_output, 0);
    */
    retval = 0;
 done:
    if (xret)
        xml_free(xret);
    if (xtop)
        xml_free(xtop);
    return retval;
}

/*! Translate function from an original value to a new.
 * In this case, assume string and increment characters, eg HAL->IBM
 */
int
cli_incstr(cligen_handle h,
           cg_var       *cv)
{
    char *str;
    int i;
    
    /* Filter out other than strings 
     * this is specific to this example, one can do translation */
    if (cv == NULL || cv_type_get(cv) != CGV_STRING)
        return 0;
    if ((str = cv_string_get(cv)) == NULL){
        clicon_err(OE_PLUGIN, EINVAL, "cv string is NULL");
        return -1;
    }
    for (i=0; i<strlen(str); i++)
        str[i]++;
    return 0;
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
example_cli_yang_mount(clicon_handle   h,
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
            clicon_err(OE_UNIX, errno, "cbuf_new");
            goto done;
        }
        cprintf(cb, "<yang-library xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\">");
        cprintf(cb, "<module-set>");
        cprintf(cb, "<name>mount</name>");
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

#ifndef CLIXON_STATIC_PLUGINS
static clixon_plugin_api api = {
    "example",          /* name */
    clixon_plugin_init, /* init */
    NULL,               /* start */
    NULL,               /* exit */
    .ca_prompt=NULL,    /* cli_prompthook_t */
    .ca_suspend=NULL,   /* cligen_susp_cb_t */
    .ca_interrupt=NULL, /* cligen_interrupt_cb_t */
    .ca_yang_mount=example_cli_yang_mount          /* RFC 8528 schema mount */
};

/*! CLI plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    struct timeval tv;
    int            c;
    int            argc; /* command-line options (after --) */
    char         **argv;

    gettimeofday(&tv, NULL);
    srandom(tv.tv_usec);
    /* Get user command-line options (after --) */
    if (clicon_argv_get(h, &argc, &argv) < 0)
        goto done;
    opterr = 0;
    optind = 1;
    while ((c = getopt(argc, argv, "m:M:")) != -1)
        switch (c) {
        case 'm':
            _mount_yang = optarg;
            break;
        case 'M':
            _mount_namespace = optarg;
            break;
        }
    if ((_mount_yang && !_mount_namespace) || (!_mount_yang && _mount_namespace)){
        clicon_err(OE_PLUGIN, EINVAL, "Both -m and -M must be given for mounts");
        goto done;
    }
    return &api;
 done:
    return NULL;
}
#endif /* CLIXON_STATIC_PLUGINS */

