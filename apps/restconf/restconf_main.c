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
 * See draft-ietf-netconf-restconf-13.txt

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
#define RESTCONF_OPTS "hDf:"

/* Should be discovered via  "/.well-known/host-meta"
   resource ([RFC6415]) */
#define RESTCONF_API_ROOT    "/restconf/"

/*! Generic REST GET method                                                     
 * @param[in]  r        Fastcgi request handle                                  
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element                    
 * @param[in]  pi     Offset, where to start pcvec                              
 * @param[in]  dvec   Stream input data                                         
 * @param[in]  qvec   Vector of query string (QUERY_STRING)                     
 * @code                                                                        
 *  curl -G http://localhost/api/data/profile/name=default/metric/rtt           
 * @endcode                                                                     
 * XXX: cant find a way to use Accept request field to choose Content-Type      
 *      I would like to support both xml and json.                              
 * Request may contain                                                          
 *     Accept: application/yang.data+json,application/yang.data+xml             
 * Response contains one of:                                                    
 *     Content-Type: application/yang.data+xml                                  
 *     Content-Type: application/yang.data+json                                 
 */
static int
api_data_get(clicon_handle h,
	     FCGX_Request *r,
             cvec         *pcvec,
             int           pi,
             cvec         *qvec)

{
    int     retval = -1;
    cg_var *cv;
    char   *val;
    int     i;
    cbuf   *path = NULL;
    cbuf   *path1 = NULL;
    cxobj  *xt = NULL;
    cxobj  *xg = NULL;
    cbuf   *cbx = NULL;
    cxobj **vec = NULL;
    size_t  veclen;

    clicon_debug(1, "%s", __FUNCTION__);
    if ((path = cbuf_new()) == NULL)
        goto done;
    if ((path1 = cbuf_new()) == NULL) /* without [] qualifiers */
        goto done;
    cv = NULL;
    cprintf(path1, "/");
    /* translate eg a/b=c -> a/[b=c] */
    for (i=pi; i<cvec_len(pcvec); i++){
        cv = cvec_i(pcvec, i);
        if (cv2str(cv, NULL, 0) > 0){
            if ((val = cv2str_dup(cv)) == NULL)
                goto done;
            cprintf(path, "[%s=%s]", cv_name_get(cv), val);
            free(val);
        }
        else{
            cprintf(path, "%s%s", (i==pi?"":"/"), cv_name_get(cv));
            cprintf(path1, "/%s", cv_name_get(cv));
        }
    }
    clicon_debug(1, "%s path:%s", __FUNCTION__, cbuf_get(path));
    clicon_debug(1, "%s path1:%s", __FUNCTION__, cbuf_get(path1));
    /* See netconf_rpc.c: 163 netconf_filter_xmldb() */

    if (xmldb_get(h, "running", cbuf_get(path), 0, &xt, NULL, NULL) < 0)
	goto done;
    {
	cbuf *cb;
	cb = cbuf_new();
	if (clicon_xml2cbuf(cb, xt, 0, 1) < 0)
	    goto done;
	clicon_debug(1, "%s xt: %s", __FUNCTION__, cbuf_get(cb));	
    }
    FCGX_SetExitStatus(200, r->out); /* OK */

    FCGX_FPrintF(r->out, "Content-Type: application/yang.data+xml\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    /* Iterate over result */
    if (xpath_vec(xt, cbuf_get(path1), &vec, &veclen) < 0)
            goto done;
    if ((cbx = cbuf_new()) == NULL)
        goto done;
    cprintf(cbx, "[\n");
    for (i=0; i<veclen; i++){
        xg = vec[i];
        if (1){ /* JSON */
            if (xml2json_cbuf(cbx, xg, 1) < 0)
                goto done;
            if (i<veclen-1)
                cprintf(cbx, ",");
        }
        else
            if (clicon_xml2cbuf(cbx, xg, 0, 0) < 0)
                goto done;
    }
    cprintf(cbx, "]");
    FCGX_FPrintF(r->out, "%s\r\n", cbuf_get(cbx));
    retval = 0;
 done:
    if (vec)
        free(vec);
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

/*! Generic REST PUT method 
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * Example:
 * curl -X PUT -d enable=true http://localhost/api/data/profile=default/metric=rtt
 */
static int
api_data_put(clicon_handle h,
	     FCGX_Request *r, 
	     cvec         *pcvec, 
	     int           pi,
	     cvec         *qvec, 
	     cvec         *dvec)
{
    int     retval = -1;
    cg_var *cv;
    int     i;
    char   *val;
    cbuf   *cmd = NULL;

    clicon_debug(1, "%s", __FUNCTION__);
    if ((cmd = cbuf_new()) == NULL)
	goto done;
    if (pi > cvec_len(pcvec)){
	retval = notfound(r);
	goto done;
    }
    cv = NULL;
    for (i=pi; i<cvec_len(pcvec); i++){
	cv = cvec_i(pcvec, i);
	cprintf(cmd, "%s ", cv_name_get(cv));
	if (cv2str(cv, NULL, 0) > 0){
	    if ((val = cv2str_dup(cv)) == NULL)
		goto done;
	    if (strlen(val))
		cprintf(cmd, "%s ", val);
	    free(val);
	}
    }
    if (cvec_len(dvec)==0)
	goto done;
    cv = cvec_i(dvec, 0);
    cprintf(cmd, "%s ", cv_name_get(cv));
    if (cv2str(cv, NULL, 0) > 0){
	if ((val = cv2str_dup(cv)) == NULL)
	    goto done;
	if (strlen(val))
	    cprintf(cmd, "%s ", val);
	free(val);
    }
    clicon_debug(1, "cmd:%s", cbuf_get(cmd));
    if (cli_cmd(r, "configure", cbuf_get(cmd)) < 0)
	goto done;
    if (cli_cmd(r, "configure", "commit") < 0)
	goto done;

    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
 done:
     if (cmd)
	cbuf_free(cmd);
    return retval;
}

/*! Generic REST DELETE method 
 * Example:
 * curl -X DELETE http://localhost/api/data/profile=default/metric/rtt
 * @note cant do leafs
 */
static int
api_data_delete(clicon_handle h,
		FCGX_Request *r, 
		cvec         *pcvec, 
		int           pi,
		cvec         *qvec)
{
    int     retval = -1;
    cg_var *cv;
    int     i;
    char   *val;
    cbuf   *cmd = NULL;

    clicon_debug(1, "%s", __FUNCTION__);
    if ((cmd = cbuf_new()) == NULL)
	goto done;
    if (pi >= cvec_len(pcvec)){
	retval = notfound(r);
	goto done;
    }
    cprintf(cmd, "no ");
    cv = NULL;
    for (i=pi; i<cvec_len(pcvec); i++){
	cv = cvec_i(pcvec, i);
	cprintf(cmd, "%s ", cv_name_get(cv));
	if (cv2str(cv, NULL, 0) > 0){
	    if ((val = cv2str_dup(cv)) == NULL)
		goto done;
	    if (strlen(val))
		cprintf(cmd, "%s ", val);
	    free(val);
	}
    }
    clicon_debug(1, "cmd:%s", cbuf_get(cmd));
    if (cli_cmd(r, "configure", cbuf_get(cmd)) < 0)
	goto done;
    if (cli_cmd(r, "configure", "commit") < 0)
	goto done;

    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
 done:
     if (cmd)
	cbuf_free(cmd);
    return retval;
}


/*! Generic REST method, GET, PUT, DELETE
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  dvec   Stream input data
 * @param[in]  qvec   Vector of query string (QUERY_STRING)

 * data - implement restconf
 * Eg:
 * curl -X PUT -d enable=true http://localhost/api/data/profile=default/metric=rtt
 * Uses cli, could have used netconf with some yang help.
 * XXX But really this module should be a restconf module to clixon
 */
static int
api_data(clicon_handle h,
	 FCGX_Request *r, 
	 cvec         *pcvec, 
	 int           pi,
	 cvec         *qvec, 
	 cvec         *dvec)
{
    int     retval = -1;
    char   *request_method;

    clicon_debug(1, "%s", __FUNCTION__);
    request_method = FCGX_GetParam("REQUEST_METHOD", r->envp);
    if (strcmp(request_method, "GET")==0)
	retval = api_data_get(h, r, pcvec, pi, qvec);
    else if (strcmp(request_method, "PUT")==0)
	retval = api_data_put(h, r, pcvec, pi, qvec, dvec);
    else if (strcmp(request_method, "DELETE")==0)
	retval = api_data_delete(h, r, pcvec, pi, qvec);
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
    if (strcmp(method, "data") == 0) /* restconf, skip /api/data */
	retval = api_data(h, r, pcvec, 2, qvec, dvec);
    else if (strcmp(method, "test") == 0)
	retval = test(r, 0);
    else
	retval = notfound(r);
 done:
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
    fprintf(stderr, "usage:%s [options]\n"
	    "where options are\n"
            "\t-h \t\tHelp\n"
    	    "\t-D \t\tDebug. Log to syslog\n"
    	    "\t-f <file>\tConfiguration file (mandatory)\n",
	    argv0
	    );
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
	default:
	    usage(h, argv[0]);
	     break;
	}
    argc -= optind;
    argv += optind;

    clicon_log_init(__PROGRAM__, LOG_INFO, CLICON_LOG_STDERR); 
    clicon_log_init(__PROGRAM__, debug?LOG_DEBUG:LOG_INFO, CLICON_LOG_SYSLOG); 
    clicon_debug_init(debug, NULL); 

    /* Find and read configfile */
    if (clicon_options_main(h) < 0)
	goto done;

    /* Parse yang database spec file */
    if (yang_spec_main(h, stdout, 0) < 0)
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
    return retval;
}
