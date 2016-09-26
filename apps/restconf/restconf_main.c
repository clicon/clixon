/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.
  
 */

/*
 * See draft-ietf-netconf-restconf-13.txt [draft]

 * sudo apt-get install libfcgi-dev
 * gcc -o fastcgi fastcgi.c -lfcgi

 * sudo su -c "/www-data/clixon_restconf -Df /usr/local/etc/routing.conf " -s /bin/sh www-data

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
#include <fcgi_stdio.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <curl/curl.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include "restconf_lib.h"

/* Command line options to be passed to getopt(3) */
#define RESTCONF_OPTS "hDf:p:"

/* Should be discovered via  "/.well-known/host-meta"
   resource ([RFC6415]) */
#define RESTCONF_API_ROOT    "/restconf/"

/*! REST OPTIONS method
 * According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  head   Set if HEAD request instead of GET
 * @code
 *  curl -G http://localhost/restconf/data/interfaces/interface=eth0
 * @endcode                                     
 */
static int
api_data_options(clicon_handle h,
		 FCGX_Request *r,
		 cvec         *pcvec,
		 int           pi,
		 cvec         *qvec,
		 int           head)
{
    int        retval = -1;

    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    FCGX_FPrintF(r->out, "GET, HEAD, OPTIONS, PUT, POST, DELETE\r\n");
    retval = 0;
    return retval;
}

/*! Generic REST GET method
 * According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @code
 *  curl -G http://localhost/restconf/data/interfaces/interface=eth0
 * @endcode                                     
 * XXX: cant find a way to use Accept request field to choose Content-Type  
 *      I would like to support both xml and json.           
 * Request may contain                                        
 *     Accept: application/yang.data+json,application/yang.data+xml   
 * Response contains one of:                           
 *     Content-Type: application/yang.data+xml    
 *     Content-Type: application/yang.data+json  
 * NOTE: If a retrieval request for a data resource representing a YANG leaf-
 * list or list object identifies more than one instance, and XML
 * encoding is used in the response, then an error response containing a
 * "400 Bad Request" status-line MUST be returned by the server.
 */
static int
api_data_get(clicon_handle h,
	     FCGX_Request *r,
             cvec         *pcvec,
             int           pi,
             cvec         *qvec)
{
    int        retval = -1;
    cg_var    *cv;
    char      *val;
    char      *v;
    int        i;
    cbuf      *path = NULL;
    cbuf      *path1 = NULL;
    cxobj     *xt = NULL;
    cbuf      *cbx = NULL;
    cxobj    **vec = NULL;
    size_t     veclen;
    yang_spec *yspec;
    yang_stmt *y;
    yang_stmt *ykey;
    char      *name;
    cvec      *cvk = NULL; /* vector of index keys */
    cg_var    *cvi;

    clicon_debug(1, "%s", __FUNCTION__);
    yspec = clicon_dbspec_yang(h);
    if ((path = cbuf_new()) == NULL)
        goto done;
    if ((path1 = cbuf_new()) == NULL) /* without [] qualifiers */
        goto done;
    cv = NULL;
    cprintf(path1, "/");
    /* translate eg a/b=c -> a/[b=c] */
    for (i=pi; i<cvec_len(pcvec); i++){
        cv = cvec_i(pcvec, i);
	name = cv_name_get(cv);
	clicon_debug(1, "[%d] cvname:%s", i, name);
	clicon_debug(1, "cv2str%d", cv2str(cv, NULL, 0));
	if (i == pi){
	    if ((y = yang_find_topnode(yspec, name)) == NULL){
		clicon_err(OE_UNIX, errno, "No yang node found: %s", name);
		goto done;
	    }
	}
	else{
	    if ((y = yang_find_syntax((yang_node*)y, name)) == NULL){
		clicon_err(OE_UNIX, errno, "No yang node found: %s", name);
		goto done;
	    }
	}
	/* Check if has value, means '=' */
        if (cv2str(cv, NULL, 0) > 0){
            if ((val = cv2str_dup(cv)) == NULL)
                goto done;
	    v = val;
	    /* XXX sync with yang */
	    while((v=index(v, ',')) != NULL){
		*v = '\0';
		v++;
	    }
	    /* Find keys */
	    if ((ykey = yang_find((yang_node*)y, Y_KEY, NULL)) == NULL){
		clicon_err(OE_XML, errno, "%s: List statement \"%s\" has no key", 
			   __FUNCTION__, y->ys_argument);
		notfound(r);
		goto done;
	    }
	    clicon_debug(1, "ykey:%s", ykey->ys_argument);

	    /* The value is a list of keys: <key>[ <key>]*  */
	    if ((cvk = yang_arg2cvec(ykey, " ")) == NULL)
		goto done;
	    cvi = NULL;
	    /* Iterate over individual yang keys  */
	    cprintf(path, "/%s", name);
	    v = val;
	    while ((cvi = cvec_each(cvk, cvi)) != NULL){
		cprintf(path, "[%s=%s]", cv_string_get(cvi), v);
		v += strlen(v)+1;
	    }
	    if (val)
		free(val);
        }
        else{
            cprintf(path, "%s%s", (i==pi?"":"/"), name);
            cprintf(path1, "/%s", name);
        }
    }
    clicon_debug(1, "%s path:%s", __FUNCTION__, cbuf_get(path));
    if (xmldb_get(h, "running", cbuf_get(path), 1, &xt,  &vec, &veclen) < 0)
	goto done;

    if ((cbx = cbuf_new()) == NULL)
	goto done;
    if (veclen==0){
	notfound(r);
	goto done;
    }
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: application/yang.data+json\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    if (xml2json_cbuf_vec(cbx, vec, veclen, 0) < 0)
	goto done;
    FCGX_FPrintF(r->out, "[%s]", cbuf_get(cbx));
    FCGX_FPrintF(r->out, "\r\n\r\n");
    retval = 0;
 done:
    if (cbx)
        cbuf_free(cbx);
    if (xt)
        xml_free(xt);
    if (path)
	cbuf_free(path);
    if (path1)
	cbuf_free(path1);
    return retval;
}

/*! Generic REST DELETE method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pi     Offset, where path starts
 * Example:
 *  curl -X DELETE http://127.0.0.1/restconf/data/interfaces/interface=eth0
 */
static int
api_data_delete(clicon_handle h,
		FCGX_Request *r, 
		char         *api_path,
		int           pi)
{
    int        retval = -1;
    int        i;

    clicon_debug(1, "%s api_path:%s", __FUNCTION__, api_path);
    for (i=0; i<pi; i++)
	api_path = index(api_path+1, '/');
    /* Parse input data as json into xml */

    if (clicon_rpc_xmlput(h, "candidate", 
			  OP_REMOVE, 
			  api_path,
			  "") < 0)
	goto done;
    if (clicon_rpc_commit(h, "candidate", "running", 
			  0, 0) < 0)
	goto done;
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
   return retval;
}

/*! Generic REST PUT  method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
 * @param[in]  post   POST instead of PUT
 * Example:
      curl -X PUT -d {\"enabled\":\"false\"} http://127.0.0.1/restconf/data/interfaces/interface=eth1
 *
 PUT:
  if the PUT request creates a new resource,
   a "201 Created" status-line is returned.  If an existing resource is
   modified, a "204 No Content" status-line is returned.

 POST:
   If the POST method succeeds, a "201 Created" status-line is returned
   and there is no response message-body.  A "Location" header
   identifying the child resource that was created MUST be present in
   the response in this case.

   If the data resource already exists, then the POST request MUST fail
   and a "409 Conflict" status-line MUST be returned.
 */
static int
api_data_put(clicon_handle h,
	     FCGX_Request *r, 
	     char         *api_path, 
	     cvec         *pcvec, 
	     int           pi,
	     cvec         *qvec, 
	     char         *data,
	     int           post)
{
    int        retval = -1;
    int        i;
    cxobj     *xdata = NULL;
    cbuf      *cbx = NULL;
    cxobj     *x;

    clicon_debug(1, "%s api_path:%s json:%s",
		 __FUNCTION__, 
		 api_path, data);
    for (i=0; i<pi; i++)
	api_path = index(api_path+1, '/');
    /* Parse input data as json into xml */
    if (json_parse_str(data, &xdata) < 0){
	clicon_debug(1, "%s json fail", __FUNCTION__);
	goto done;
    }
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    x = NULL;
    while ((x = xml_child_each(xdata, x, -1)) != NULL) 
	if (clicon_xml2cbuf(cbx, x, 0, 0) < 0)
	    goto done;	
    if (clicon_rpc_xmlput(h, "candidate", 
			  OP_MERGE, 
			  api_path,
			  cbuf_get(cbx)) < 0)
	goto done;
    if (clicon_rpc_commit(h, "candidate", "running", 
			  0, 0) < 0)
	goto done;
    FCGX_SetExitStatus(201, r->out); /* Created */
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (xdata)
	xml_free(xdata);
     if (cbx)
	cbuf_free(cbx); 
   return retval;
}

/*! Generic REST method, GET, PUT, DELETE
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
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

    clicon_debug(1, "%s", __FUNCTION__);
    request_method = FCGX_GetParam("REQUEST_METHOD", r->envp);
    if (strcmp(request_method, "OPTIONS")==0)
	retval = api_data_options(h, r, pcvec, pi, qvec, 0);
    else if (strcmp(request_method, "GET")==0)
	retval = api_data_get(h, r, pcvec, pi, qvec);
    else if (strcmp(request_method, "PUT")==0)
	retval = api_data_put(h, r, api_path, pcvec, pi, qvec, data, 0);
    else if (strcmp(request_method, "POST")==0)
	retval = api_data_put(h, r, api_path, pcvec, pi, qvec, data, 1);
    else if (strcmp(request_method, "DELETE")==0)
	retval = api_data_delete(h, r, api_path, pi);
    else
	retval = notfound(r);
    return retval;
}

/*! Process a FastCGI request
 * @param[in]  r        Fastcgi request handle
 */
static int
request_process(clicon_handle h,
		FCGX_Request *r)
{
    int    retval = -1;
    char  *path;
    char  *query;
    char  *method;
    char **pvec;
    int    pn;
    cvec  *qvec = NULL;
    cvec  *dvec = NULL;
    cvec  *pcvec = NULL; /* for rest api */
    cbuf  *cb = NULL;
    char  *data;
    int    auth = 0;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    query = FCGX_GetParam("QUERY_STRING", r->envp);
    if ((pvec = clicon_strsplit(path, "/", &pn, __FUNCTION__)) == NULL)
	goto done;

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
    method = pvec[2];
    retval = 0;
    test(r, 1);
    /* If present, check credentials */
    if (plugin_credentials(h, r, &auth) < 0)
	goto done;
    clicon_debug(1, "%s credentials ok 1", __FUNCTION__);
    if (auth == 0)
	goto done;
    clicon_debug(1, "%s credentials ok 2", __FUNCTION__);

    if (strcmp(method, "data") == 0) /* restconf, skip /api/data */
	retval = api_data(h, r, path, pcvec, 2, qvec, data);
    else if (strcmp(method, "test") == 0)
	retval = test(r, 0);
    else
	retval = notfound(r);
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (dvec)
	cvec_free(dvec);
    if (qvec)
	cvec_free(qvec);
    if (pcvec)
	cvec_free(pcvec);
    if (cb)
	cbuf_free(cb);
    unchunk_group(__FUNCTION__);
    return retval;
}

/*! Usage help routine
 * @param[in]  argv0  command line
 * @param[in]  h      Clicon handle
 */
static void
usage(clicon_handle h,
      char         *argv0)

{
    char *restconfdir = clicon_restconf_dir(h);

    fprintf(stderr, "usage:%s [options]\n"
	    "where options are\n"
            "\t-h \t\tHelp\n"
    	    "\t-D \t\tDebug. Log to syslog\n"
    	    "\t-f <file>\tConfiguration file (mandatory)\n"
	    "\t-d <dir>\tSpecify restconf plugin directory dir (default: %s)\n",
	    argv0,
	    restconfdir
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

    /* In the startup, logs to stderr & debug flag set later */
    clicon_log_init(__PROGRAM__, LOG_INFO, CLICON_LOG_SYSLOG); 
    /* Create handle */
    if ((h = clicon_handle_init()) == NULL)
	goto done;

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
	default:
	    usage(h, argv[0]);
	     break;
	}
    argc -= optind;
    argv += optind;

    clicon_log_init(__PROGRAM__, debug?LOG_DEBUG:LOG_INFO, CLICON_LOG_SYSLOG); 
    clicon_debug_init(debug, NULL); 

    /* Find and read configfile */
    if (clicon_options_main(h) < 0)
	goto done;

    /* Initialize plugins group */
    if (restconf_plugin_load(h) < 0)
	return -1;

    /* Parse yang database spec file */
    if (yang_spec_main(h, NULL, 0) < 0)
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
	if ((path = FCGX_GetParam("DOCUMENT_URI", r->envp)) != NULL){
	    if (strncmp(path, RESTCONF_API_ROOT, strlen(RESTCONF_API_ROOT)) == 0 ||
		strncmp(path, RESTCONF_API_ROOT, strlen(RESTCONF_API_ROOT)-1) == 0)
		request_process(h, r);
	    else{
		clicon_debug(1, "top-level not found");
		notfound(r);
	    }
	}
	else
	    clicon_debug(1, "NULL URI");
        FCGX_Finish_r(r);
    }
    retval = 0;
 done:
    restconf_plugin_unload(h);
    return retval;
}
