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

/*
 * See draft-ietf-netconf-restconf-13.txt [draft]

 * sudo apt-get install libfcgi-dev
 * gcc -o fastcgi fastcgi.c -lfcgi

 * sudo su -c "/www-data/clixon_restconf -Df /usr/local/etc/example.xml " -s /bin/sh www-data

 * This is the interface:
 * api/data/profile=<name>/metric=<name> PUT data:enable=<flag>
 * api/test
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>
#include <time.h>

#include <signal.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <libgen.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include <fcgi_stdio.h> /* Need to be after clixon_xml-h due to attribute format */

/* restconf */
#include "restconf_lib.h"
#include "restconf_methods.h"

/* Command line options to be passed to getopt(3) */
#define RESTCONF_OPTS "hDf:p:y:"

/* RESTCONF enables deployments to specify where the RESTCONF API is 
   located.  The client discovers this by getting the "/.well-known/host-meta"
   resource 
*/
#define RESTCONF_WELL_KNOWN  "/.well-known/host-meta"

#define RESTCONF_API       "restconf"
#define RESTCONF_API_ROOT "/restconf"

/*! Generic REST method, GET, PUT, DELETE, etc
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input daat
 */
static int
api_data(clicon_handle h,
	 FCGX_Request *r, 
	 char         *api_path, 
	 cvec         *pcvec, 
	 int           pi,
	 cvec         *qvec, 
	 char         *data)
{
    int     retval = -1;
    char   *request_method;
    int     pretty;
    char   *media_content_type;
    int     parse_xml = 0; /* By default expect and parse JSON */
    char   *media_accept;
    int     use_xml = 0; /* By default use JSON */

    clicon_debug(1, "%s", __FUNCTION__);
    request_method = FCGX_GetParam("REQUEST_METHOD", r->envp);
    clicon_debug(1, "%s method:%s", __FUNCTION__, request_method);
    pretty = clicon_option_bool(h, "CLICON_RESTCONF_PRETTY");
    media_accept = FCGX_GetParam("HTTP_ACCEPT", r->envp);
    if (strcmp(media_accept, "application/yang-data+xml")==0)
	use_xml++;
    media_content_type = FCGX_GetParam("HTTP_CONTENT_TYPE", r->envp);
    if (media_content_type &&
	strcmp(media_content_type, "application/yang-data+xml")==0)
	parse_xml++;

    if (strcmp(request_method, "OPTIONS")==0)
	retval = api_data_options(h, r);
    else if (strcmp(request_method, "HEAD")==0)
	retval = api_data_head(h, r, pcvec, pi, qvec, pretty, use_xml);
    else if (strcmp(request_method, "GET")==0)
	retval = api_data_get(h, r, pcvec, pi, qvec, pretty, use_xml);
    else if (strcmp(request_method, "POST")==0)
	retval = api_data_post(h, r, api_path, pcvec, pi, qvec, data, pretty, use_xml, parse_xml);
    else if (strcmp(request_method, "PUT")==0)
	retval = api_data_put(h, r, api_path, pcvec, pi, qvec, data, pretty, use_xml, parse_xml);
    else if (strcmp(request_method, "PATCH")==0)
	retval = api_data_patch(h, r, api_path, pcvec, pi, qvec, data);
    else if (strcmp(request_method, "DELETE")==0)
	retval = api_data_delete(h, r, api_path, pi, pretty, use_xml);
    else
	retval = notfound(r);
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Operations REST method, POST
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  path   According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 */
static int
api_operations(clicon_handle h,
	       FCGX_Request *r, 
	       char         *path,
	       cvec         *pcvec, 
	       int           pi,
	       cvec         *qvec, 
	       char         *data)
{
    int     retval = -1;
    char   *request_method;
    int     pretty;
    char   *media_content_type;
    int     parse_xml = 0; /* By default expect and parse JSON */
    char   *media_accept;
    int     use_xml = 0; /* By default use JSON */

    clicon_debug(1, "%s", __FUNCTION__);
    request_method = FCGX_GetParam("REQUEST_METHOD", r->envp);
    clicon_debug(1, "%s method:%s", __FUNCTION__, request_method);
    pretty = clicon_option_bool(h, "CLICON_RESTCONF_PRETTY");
    media_accept = FCGX_GetParam("HTTP_ACCEPT", r->envp);
    if (strcmp(media_accept, "application/yang-data+xml")==0)
	use_xml++;
        media_content_type = FCGX_GetParam("HTTP_CONTENT_TYPE", r->envp);
    if (media_content_type &&
	strcmp(media_content_type, "application/yang-data+xml")==0)
	parse_xml++;
    
    if (strcmp(request_method, "GET")==0)
	retval = api_operations_get(h, r, path, pcvec, pi, qvec, data, pretty, use_xml);
    else if (strcmp(request_method, "POST")==0)
	retval = api_operations_post(h, r, path, pcvec, pi, qvec, data,
				     pretty, use_xml, parse_xml);
    else
	retval = notfound(r);
    return retval;
}

/*! Determine the root of the RESTCONF API
 * @param[in]  h        Clicon handle
 * @param[in]  r        Fastcgi request handle
 * @note Hardcoded to "/restconf"
 * Return see RFC8040 3.1 and RFC7320
 * In line with the best practices defined by [RFC7320], RESTCONF
 * enables deployments to specify where the RESTCONF API is located.
 */
static int
api_well_known(clicon_handle h,
	       FCGX_Request *r)
{
    clicon_debug(1, "%s", __FUNCTION__);
    FCGX_FPrintF(r->out, "Content-Type: application/xrd+xml\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>\n");
    FCGX_FPrintF(r->out, "   <Link rel='restconf' href='/restconf'/>\n");
    FCGX_FPrintF(r->out, "</XRD>\r\n");

    return 0;
}

/*! Retrieve the Top-Level API Resource
 * @param[in]  h        Clicon handle
 * @param[in]  r        Fastcgi request handle
 * @note Only returns null for operations and data,...
 * See RFC8040 3.3
 */
static int
api_root(clicon_handle h,
	 FCGX_Request *r)
{
    int    retval = -1;
    char  *media_accept;
    int   use_xml = 0; /* By default use JSON */
    cxobj *xt = NULL;
    cbuf  *cb = NULL;
    int    pretty;
    
    clicon_debug(1, "%s", __FUNCTION__);
    pretty = clicon_option_bool(h, "CLICON_RESTCONF_PRETTY");
    media_accept = FCGX_GetParam("HTTP_ACCEPT", r->envp);
    if (strcmp(media_accept, "application/yang-data+xml")==0)
	use_xml++;
    clicon_debug(1, "%s use-xml:%d media-accept:%s", __FUNCTION__, use_xml, media_accept);
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: application/yang-data+%s\r\n", use_xml?"xml":"json");
    FCGX_FPrintF(r->out, "\r\n");

    if (xml_parse_string("<restconf><data></data><operations></operations><yang-library-version>2016-06-21</yang-library-version></restconf>", NULL, &xt) < 0)
	goto done;
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_XML, errno, "cbuf_new");
	goto done;
    }
    if (xml_rootchild(xt, 0, &xt) < 0)
	goto done;
    if (use_xml){
	if (clicon_xml2cbuf(cb, xt, 0, pretty) < 0)
	    goto done;
    }
    else
	if (xml2json_cbuf(cb, xt, pretty) < 0)
	    goto done;
    FCGX_FPrintF(r->out, "%s", cb?cbuf_get(cb):"");
    FCGX_FPrintF(r->out, "\r\n\r\n");
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    if (xt)
	xml_free(xt);
    return retval;
}

/*!
 * See https://tools.ietf.org/html/rfc7895
 */
static int
api_yang_library_version(clicon_handle h,
			 FCGX_Request *r)
{
    int    retval = -1;
    char  *media_accept;
    int    use_xml = 0; /* By default use JSON */
    cxobj *xt = NULL;
    cbuf  *cb = NULL;
    int    pretty;

    clicon_debug(1, "%s", __FUNCTION__);
    pretty = clicon_option_bool(h, "CLICON_RESTCONF_PRETTY");
    media_accept = FCGX_GetParam("HTTP_ACCEPT", r->envp);
    if (strcmp(media_accept, "application/yang-data+xml")==0)
	use_xml++;
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: application/yang-data+%s\r\n", use_xml?"xml":"json");
    FCGX_FPrintF(r->out, "\r\n");
    if (xml_parse_string("<yang-library-version>2016-06-21</yang-library-version>", NULL, &xt) < 0)
	goto done;
    if (xml_rootchild(xt, 0, &xt) < 0)
	goto done;
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_XML, errno, "cbuf_new");
	goto done;
    }
    if (use_xml){
	if (clicon_xml2cbuf(cb, xt, 0, pretty) < 0)
	    goto done;
    }
    else{
	if (xml2json_cbuf(cb, xt, pretty) < 0)
	    goto done;
    }
    clicon_debug(1, "%s cb%s", __FUNCTION__, cbuf_get(cb));
    FCGX_FPrintF(r->out, "%s\n", cb?cbuf_get(cb):"");
    FCGX_FPrintF(r->out, "\n\n");
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    if (xt)
	xml_free(xt);
    return retval;
}

/*! Process a FastCGI request
 * @param[in]  r        Fastcgi request handle
 */
static int
api_restconf(clicon_handle h,
		FCGX_Request *r)
{
    int    retval = -1;
    char  *path;
    char  *query;
    char  *method;
    char **pvec = NULL;
    int    pn;
    cvec  *qvec = NULL;
    cvec  *dvec = NULL;
    cvec  *pcvec = NULL; /* for rest api */
    cbuf  *cb = NULL;
    char  *data;
    int    authenticated = 0;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("REQUEST_URI", r->envp);
    query = FCGX_GetParam("QUERY_STRING", r->envp);
    if ((pvec = clicon_strsep(path, "/", &pn)) == NULL)
	goto done;
    /* Sanity check of path. Should be /restconf/ */
    if (pn < 2){
	retval = notfound(r);
	goto done;
    }
    if (strlen(pvec[0]) != 0){
	retval = notfound(r);
	goto done;
    }
    if (strcmp(pvec[1], RESTCONF_API)){
	retval = notfound(r);
	goto done;
    }
    test(r, 1);

    if (pn == 2){
	retval = api_root(h, r);
	goto done;
    }
    if ((method = pvec[2]) == NULL){
	retval = notfound(r);
	goto done;
    }
    clicon_debug(1, "method=%s", method);
    if (str2cvec(query, '&', '=', &qvec) < 0)
      goto done;
    if (str2cvec(path, '/', '=', &pcvec) < 0) /* rest url eg /album=ricky/foo */
      goto done;
    /* data */
    if ((cb = readdata(r)) == NULL)
	goto done;
    data = cbuf_get(cb);
    clicon_debug(1, "DATA=%s", data);
    if (str2cvec(data, '&', '=', &dvec) < 0)
      goto done;

    /* If present, check credentials. See "plugin_credentials" in plugin  
     * See RFC 8040 section 2.5
     */
    if ((authenticated = clixon_plugin_auth(h, r)) < 0)
	goto done;
    /* If set but no user, we set a dummy user */
    if (authenticated){
	if (clicon_username_get(h) == NULL)
	    clicon_username_set(h, "none");
    }
    else{
	unauthorized(r);
	goto ok;
    }
    if (strcmp(method, "yang-library-version")==0){
	if (api_yang_library_version(h, r) < 0)
	    goto done;
    }
    else if (strcmp(method, "data") == 0){ /* restconf, skip /api/data */
	if (api_data(h, r, path, pcvec, 2, qvec, data) < 0)
	    goto done;
    }
    else if (strcmp(method, "operations") == 0){ /* rpc */
	if (api_operations(h, r, path, pcvec, 2, qvec, data) < 0)
	    goto done;
    }
    else if (strcmp(method, "test") == 0)
	test(r, 0);
    else
	notfound(r);
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (pvec)
	free(pvec);
    if (dvec)
	cvec_free(dvec);
    if (qvec)
	cvec_free(qvec);
    if (pcvec)
	cvec_free(pcvec);
    if (cb)
	cbuf_free(cb);
    return retval;
}


static int
restconf_terminate(clicon_handle h)
{
    yang_spec      *yspec;

    clicon_debug(0, "%s", __FUNCTION__);
    clicon_rpc_close_session(h);
    if ((yspec = clicon_dbspec_yang(h)) != NULL)
	yspec_free(yspec);
    clicon_handle_exit(h);
    return 0;
}

/* Need global variable to for signal handler */
static clicon_handle _CLICON_HANDLE = NULL;

/*! Signall terminates process
 */
static void
restconf_sig_term(int arg)
{
    static int i=0;

    if (i++ == 0)
	clicon_log(LOG_NOTICE, "%s: %s: pid: %u Signal %d", 
		   __PROGRAM__, __FUNCTION__, getpid(), arg);
    else
	exit(-1);
    if (_CLICON_HANDLE)
	restconf_terminate(_CLICON_HANDLE);
    clicon_exit_set(); /* checked in event_loop() */
    exit(-1);
}

/*! Usage help routine
 * @param[in]  argv0  command line
 * @param[in]  h      Clicon handle
 */
static void
usage(clicon_handle h,
      char         *argv0)

{
    fprintf(stderr, "usage:%s [options]\n"
	    "where options are\n"
            "\t-h \t\tHelp\n"
    	    "\t-D \t\tDebug. Log to syslog\n"
    	    "\t-f <file>\tConfiguration file (mandatory)\n"
	    "\t-d <dir>\tSpecify restconf plugin directory dir (default: %s)\n"
	    "\t-y <file>\tOverride yang spec file (dont include .yang suffix)\n",
	    argv0,
	    clicon_restconf_dir(h)
	    );
    exit(0);
}

/*! Main routine for grideye fastcgi API
 */
int 
main(int    argc, 
     char **argv) 
{
    int           retval = -1;
    int           sock;
    FCGX_Request  request;
    FCGX_Request *r = &request;
    char          c;
    char         *sockpath;
    char         *path;
    clicon_handle h;
    char         *yangspec=NULL;
    char         *dir;

    /* In the startup, logs to stderr & debug flag set later */
    clicon_log_init(__PROGRAM__, LOG_INFO, CLICON_LOG_SYSLOG); 
    /* Create handle */
    if ((h = clicon_handle_init()) == NULL)
	goto done;
    _CLICON_HANDLE = h; /* for termination handling */
    while ((c = getopt(argc, argv, RESTCONF_OPTS)) != -1)
	switch (c) {
	case 'h':
	    usage(h, argv[0]);
	    break;
	case 'D' : /* debug */
	    debug = 1;
	    break;
	 case 'f': /* override config file */
	    if (!strlen(optarg))
		usage(h, argv[0]);
	    clicon_option_str_set(h, "CLICON_CONFIGFILE", optarg);
	    break;
	case 'd':  /* Plugin directory */
	    if (!strlen(optarg))
		usage(h, argv[0]);
	    clicon_option_str_set(h, "CLICON_RESTCONF_DIR", optarg);
	    break;
	case 'y' : /* yang module */
	    yangspec = optarg;
	    break;
	default:
	    usage(h, argv[0]);
	     break;
	}
    argc -= optind;
    argv += optind;

    clicon_log_init(__PROGRAM__, debug?LOG_DEBUG:LOG_INFO, CLICON_LOG_SYSLOG); 
    clicon_debug_init(debug, NULL); 
    clicon_log(LOG_NOTICE, "%s: %u Started", __PROGRAM__, getpid());
    if (set_signal(SIGTERM, restconf_sig_term, NULL) < 0){
	clicon_err(OE_DEMON, errno, "Setting signal");
	goto done;
    }
    if (set_signal(SIGINT, restconf_sig_term, NULL) < 0){
	clicon_err(OE_DEMON, errno, "Setting signal");
	goto done;
    }

    /* Find and read configfile */
    if (clicon_options_main(h) < 0)
	goto done;

    /* Overwrite yang module with -y option */
    if (yangspec)
	clicon_option_str_set(h, "CLICON_YANG_MODULE_MAIN", yangspec);

    /* Initialize plugins group */
    if ((dir = clicon_restconf_dir(h)) != NULL)
	if (clixon_plugins_load(h, CLIXON_PLUGIN_INIT, dir) < 0)
	    return -1;

    /* Parse yang database spec file */
    if (yang_spec_main(h) == NULL)
	goto done;

    if ((sockpath = clicon_option_str(h, "CLICON_RESTCONF_PATH")) == NULL){
	clicon_err(OE_CFG, errno, "No CLICON_RESTCONF_PATH in clixon configure file");
	goto done;
    }
    if (FCGX_Init() != 0){
	clicon_err(OE_CFG, errno, "FCGX_Init");
	goto done;
    }
    if ((sock = FCGX_OpenSocket(sockpath, 10)) < 0){
	clicon_err(OE_CFG, errno, "FCGX_OpenSocket");
	goto done;
    }

    if (FCGX_InitRequest(r, sock, 0) != 0){
	clicon_err(OE_CFG, errno, "FCGX_InitRequest");
	goto done;
    }
    while (1) {
	if (FCGX_Accept_r(r) < 0) {
	    clicon_err(OE_CFG, errno, "FCGX_Accept_r");
	    goto done;
	}
	clicon_debug(1, "------------");
	if ((path = FCGX_GetParam("REQUEST_URI", r->envp)) != NULL){
	    clicon_debug(1, "path:%s", path);
	    if (strncmp(path, RESTCONF_API_ROOT, strlen(RESTCONF_API_ROOT)) == 0)
		api_restconf(h, r); /* This is the function */
	    else if (strncmp(path, RESTCONF_WELL_KNOWN, strlen(RESTCONF_WELL_KNOWN)) == 0) {
		api_well_known(h, r); /*  */
	    }
	    else{
		clicon_debug(1, "top-level %s not found", path);
		notfound(r);
	    }
	    
	}
	else
	    clicon_debug(1, "NULL URI");
	FCGX_Finish_r(r);
    }
    retval = 0;
 done:
    clixon_plugin_exit(h);
    restconf_terminate(h);
    return retval;
}
