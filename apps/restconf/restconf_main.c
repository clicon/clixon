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
 * This is the interface:
 * api/cli
 * api/netconf
 * api/login
 * api/logout
 * api/signup
 * api/settings nyi
 * api/callhome
 * api/metric_rules
 * api/metrics
 * api/metric_spec
 * api/data/profile=<name>/metric=<name> PUT data:enable=<flag>
 * api/user
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

/*=======================================================================
 * API code
 *=======================================================================*/
/*! Send a CLI command via GET, POST or PUT
 * POST or PUT:  
 *     URI:  /api/cli/configure
 *     data: show version
 * GET:
 *     URI: /api/cli/configure/show/version 
 * Yes, the GET syntax is ugly but it can be nice to have in eg a browser.
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  qn     Length of qvec
 * @param[in]  data   Stream input data
 */
static int
api_cli(FCGX_Request *r, 
	char        **pvec, 
	int           pn, 
	cvec         *qvec, 
	char         *data)
{
    int  retval = -1;
    char *cmd;
    char *mode;
    char *request;

    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n\r\n");
    mode = pvec[0];
    request = FCGX_GetParam("REQUEST_METHOD", r->envp);
    if (strcmp(request, "GET")==0){
	pvec++; pn--;
	if ((cmd = clicon_strjoin(pn, pvec, " ", __FUNCTION__)) == NULL)
	    goto done;
    }
    else
	if (strcmp(request, "PUT")==0 || strcmp(request, "POST")==0)
	    cmd = data;
	else
	    goto done;

    if (cli_cmd(r, mode, cmd) < 0)
	goto done;
    retval = 0;
 done:
    unchunk_group (__FUNCTION__);
    return retval;
}

/*!
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 */
static int
api_netconf(FCGX_Request *r, 
	    char        **pvec, 
	    int           pn, 
	    cvec         *qvec, 
	    char         *data)
{
    int   retval = -1;
    char *request;
    cbuf *cb = NULL;

    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n\r\n");
    request = FCGX_GetParam("REQUEST_METHOD", r->envp);
    if (strcmp(request, "PUT")!=0 && strcmp(request, "POST")!=0)
	goto done;
    if (netconf_cmd(r, data) < 0)
	goto done;
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Register new user
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
 * In: user, passwd [fullname, organization, sender-template]
 * Create: configuration user/passwd, influxdb database, user
 */
static int
api_signup(FCGX_Request *r, 
	   char        **pvec, 
	   int           pn, 
	   cvec         *qvec, 
	   cvec         *dvec)
{
    int    retval = -1;
    char  *request;
    char  *server_addr;
    char  *root;
    char  *name;
    char  *dashboard_db_name;
    char  *passw;
    char  *fullname;
    char  *organization;
    char  *profile;
    cbuf  *resbuf = NULL;
    cbuf  *cb = NULL;
    char  *id;
    cxobj *cx = NULL;
    cxobj *x;

    clicon_debug(1, "%s", __FUNCTION__);
    request = FCGX_GetParam("REQUEST_METHOD", r->envp);
    server_addr = FCGX_GetParam("SERVER_ADDR", r->envp);
    root = FCGX_GetParam("DOCUMENT_ROOT", r->envp);
    if (strcmp(request, "POST")!=0)
	goto done;
    FCGX_SetExitStatus(201, r->out);
    if ((name = cvec_find_str(dvec, "email")) == NULL)
	goto done; 
    clicon_debug(1, "%s name=%s", __FUNCTION__, name);
    if ((passw = cvec_find_str(dvec, "passw")) == NULL)
	goto done;
    fullname = cvec_find_str(dvec, "fullname");
    organization = cvec_find_str(dvec, "organization");
    profile = cvec_find_str(dvec, "profile");
    clicon_debug(1, "%s passw=%s", __FUNCTION__, passw);
    if (strlen(name)==0){
	errorfn(r, root, "No Name given");
	goto done;
    }
    if (strlen(passw)==0){
	errorfn(r, root, "No Password given");
	goto done;
    }
    if ((resbuf = cbuf_new()) == NULL)
	goto done;
    /* Create user in gridye/clicon */
    if (cli_rpc(resbuf, "configure", "user %s password %s", name, passw) < 0)
	goto done;
    if (fullname && strlen(fullname))
	if (cli_rpc(resbuf, "configure", "user %s fullname %s", name, fullname) < 0)
	    goto done;
    if (organization && strlen(organization))
	if (cli_rpc(resbuf, "configure", "user %s organization %s", name, organization) < 0)
	    goto done;
    if (profile && strlen(profile))
	if (cli_rpc(resbuf, "configure", "user %s profile %s", name, profile) < 0)
	    goto done;
    /* Create influxdb data database and user 
       (XXX create same user/passwd as server, may want to keep them separate) 
    */
    if (create_database(server_addr, name, WWW_USER, WWW_PASSWD) < 0)
	goto done;
    if (create_db_user(server_addr, name, name, passw, WWW_USER, WWW_PASSWD) < 0)
	goto done;
    /*  */
    if ((cb = cbuf_new()) == NULL)
	goto done;
    cprintf(cb, "%s_db", name);
    dashboard_db_name = cbuf_get(cb);
    /* Create influxdb dashboard database and user */
    if (create_database(server_addr, dashboard_db_name, WWW_USER, WWW_PASSWD) < 0)
	goto done;
    if (create_db_user(server_addr, dashboard_db_name, 
		       name, passw, WWW_USER, WWW_PASSWD) < 0)
	goto done;
    /* Create influxdb entry in gridye/clicon */
    if (cli_rpc(resbuf, "configure", "user %s resultdb url http://%s:8086/db/%s/series", 
		name, server_addr, name) < 0)
	goto done;
    if (cli_rpc(resbuf, "configure", "user %s resultdb minute true", name) < 0)
	goto done;
    if (cli_rpc(resbuf, "configure", "user %s resultdb username %s", name, name) < 0)
	goto done;
    if (cli_rpc(resbuf, "configure", "user %s resultdb password %s", name, passw) < 0)
	goto done;

    if (cli_rpc(resbuf, "configure", "commit") < 0)
	goto done;
    /* Get database entry for user from name to get id */
    if (get_db_entry("user", "name", name, &cx) < 0)
	goto done;
    if ((x = xpath_first(cx, "//user/id")) == NULL)
	goto done;
    id = xml_body(x);
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n");
    FCGX_FPrintF(r->out, "Location: /www/grideye.html\r\n");
    FCGX_FPrintF(r->out, "Set-Cookie: %s=%s; path=/; HttpOnly\r\n", 
		 USER_COOKIE, id);
    FCGX_FPrintF(r->out, "\r\n");

    retval = 0;
 done:
    clicon_debug(1, "%s end %d", __FUNCTION__, retval);
    if (resbuf)
	cbuf_free(resbuf);
    if (cb)
	cbuf_free(cb);
    return retval;
}

static int
api_settings(FCGX_Request *r, 
	     char        **pvec,
	     int           pn, 
	     cvec         *qvec, 
	     cvec         *dvec)
{
  /* NYI */
    return 0;
}

/*! User pressed login submit button -> check user/passwd and set connect session cookie
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
 */
static int
api_login(FCGX_Request *r, 
	  char        **pvec,
	  int           pn, 
	  cvec         *qvec, 
	  cvec         *dvec)
{
    int    retval = -1;
    char  *request;
    char  *root;
    char  *name;
    char  *passw;
    cxobj *cx = NULL;
    cxobj *x;
    char  *id;

    clicon_debug(1, "%s", __FUNCTION__);
    request = FCGX_GetParam("REQUEST_METHOD", r->envp);
    root = FCGX_GetParam("DOCUMENT_ROOT", r->envp);
    if (strcmp(request, "POST")!=0 && strcmp(request, "PUT")!=0)
	goto done;
    FCGX_SetExitStatus(201, r->out);

    if ((name = cvec_find_str(dvec, "email")) == NULL)
	goto done;
    clicon_debug(1, "%s name=%s", __FUNCTION__, name);
    if ((passw = cvec_find_str(dvec, "passw")) == NULL)
	goto done;
    clicon_debug(1, "%s passw=%s", __FUNCTION__, passw);
    if (strlen(name)==0){
	errorfn(r, root, "No Name given");
	goto done;
    }
    if (strlen(passw)==0){
	errorfn(r, root, "No Password given");
	goto done;
    }
    /* Get database entry for user from name */
    if (get_db_entry("user", "name", name, &cx) < 0)
	goto done;
    if (check_credentials(passw, cx) == 0){
	clicon_debug(1, "%s wrong password or user", __FUNCTION__);
	errorfn(r, root, "Wrong password or user");
	goto done;
    }
    clicon_debug(1, "%s login credentials ok", __FUNCTION__);
    if ((x = xpath_first(cx, "//user/id")) == NULL)
	goto done;
    id = xml_body(x);
    /* Set connected-user cookie */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n");
    FCGX_FPrintF(r->out, "Location: /www/grideye.html\r\n");
    FCGX_FPrintF(r->out, "Set-Cookie: %s=%s; path=/; HttpOnly\r\n", 
		 USER_COOKIE, id);
    FCGX_FPrintF(r->out, "\r\n");

    retval = 0;
 done:
    if (cx)
	xml_free(cx);
    return retval;
}

/*!
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
 */
static int
api_logout(FCGX_Request *r, 
	   char        **pvec, 
	   int           pn, 
	   cvec         *qvec, 
	   cvec         *dvec)
{
    int    retval = -1;

    clicon_debug(1, "%s", __FUNCTION__);
    /* Set connected-user cookie */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n");
    FCGX_FPrintF(r->out, "Location: /www/grideye.html\r\n");
    FCGX_FPrintF(r->out, "Set-Cookie: %s=; path=/; HttpOnly; Expires=Sun, 06 Nov 1994 08:49:37 GMT\r\n", 
		 USER_COOKIE);
    FCGX_FPrintF(r->out, "\r\n");

    retval = 0;

    return retval;
}

/*! Get remote-addr, get name as param, get project from config.
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
 * in: id, name, agent_address
 * create: sender and start it
 */
static int
api_callhome(FCGX_Request *r, 
	     char        **pvec, 
	     int           pn, 
	     cvec         *qvec, 
	     cvec         *dvec)
{
    int    retval = -1;
    cxobj *cx = NULL;
    cxobj *cs = NULL;
    cxobj *x;
    cxobj *y;
    char  *agent_addr;
    char  *agent_name;
    char  *request;
    char  *id;
    char  *template = DEFAULT_TEMPLATE; /* sender template */
    cbuf  *resbuf = NULL;

    clicon_debug(1, "%s", __FUNCTION__);
    request = FCGX_GetParam("REQUEST_METHOD", r->envp);
    if (strcmp(request, "POST")!=0 && strcmp(request, "PUT")!=0)
	goto done;
    agent_addr = FCGX_GetParam("REMOTE_ADDR", r->envp);
    clicon_debug(1, "%s agent_addr:%s", __FUNCTION__, agent_addr);
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    /* Get user id=<id>& agent name=<name> from POST data stream (required) */
    if ((id = cvec_find_str(dvec, "id")) == NULL)
	goto done;
    clicon_debug(1, "%s id:%s", __FUNCTION__, id);
    if ((agent_name = cvec_find_str(dvec, "name")) == NULL)
	goto done;
    clicon_debug(1, "%s agent_name:%s", __FUNCTION__, agent_name);
    /* Get user configuration from cookie (=id) */
    if (get_db_entry("user", "id", id, &cx) < 0)
	goto done;
    if (check_credentials(NULL, cx) == 0)
	goto done;
    if ((x = xpath_first(cx, "//user/template")) != NULL)
	template = xml_body(x);    
    clicon_debug(1, "%s: template=%s", __FUNCTION__, template);

    /* Check if sender = agent_name exists, if not create it using template, addr, name */
    if (get_db_entry("sender", "name", agent_name, &cs) < 0)
	goto done;
    if ((x = xpath_first(cx, "//sender/name")) == NULL){
	clicon_debug(1, "%s: create sender %s", __FUNCTION__, agent_name);
	if (cli_rpc(resbuf, "configure", "sender %s template %s", agent_name, template) < 0)
	    goto done;
	if (cli_rpc(resbuf, "configure", "sender %s ipv4_daddr %s", agent_name, agent_addr) < 0)
	    goto done;
	if (cli_rpc(resbuf, "configure", "sender %s userid %s", agent_name, id) < 0)
	    goto done;
	if (cli_rpc(resbuf, "configure", "sender %s start true", agent_name) < 0)
	    goto done;
	if (cli_rpc(resbuf, "configure", "commit") < 0)
	    goto done;
    }
    else {
	/* Check if userid exists */ 
	if ((y = xpath_first(x, "//sender/userid")) == NULL)
	    goto done;
	/* Check if userid matches our id */
	if (strcmp(id, xml_body(y)))
	    goto done;
	/* Check if started */
	if ((y = xpath_first(x, "//sender/start")) == NULL)
	    goto done;
	if (strcmp("true", xml_body(y)))
	    goto done;
	/* Check if IP address changed */
	if ((y = xpath_first(x, "//sender/ipv4_daddr")) == NULL)
	    goto done;
	if (strcmp(agent_addr, xml_body(y)))
	    goto done;
    }
    /* We should be hunky dory */

    FCGX_FPrintF(r->out, "template = '%s'\n", template?template:"(null)");
    FCGX_FPrintF(r->out, "agent_addr = '%s'\n", agent_addr);
    FCGX_FPrintF(r->out, "agent_name = '%s'\n", agent_name);

    retval = 0;
 done:
    if (cx)
	xml_free(cx);
    if (cs)
	xml_free(cs);
    if (resbuf)
	cbuf_free(resbuf);
    return retval;
}

/*! Get list of metric rules in a profile
 * GET api/metric_rules/<profile>[/<metric>]
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
 * @retval [
             {metric:"rtt", 
	      perc: 1, 
	      warningval:"john", 
	      errorval: "au",
	      op: "eq"}
	    ]; 
 * XXX a fifth element in this record type defined in java script contains sender/host list
 XXX Assume if anything in query_string, it is ?enable=true
 */
static int
api_metric_rules(FCGX_Request *r, 
		 char        **pvec, 
		 int           pn, 
		 cvec         *qvec, 
		 cvec         *dvec)
{
    int     retval = -1;
    char   *sender;
    char   *metric0 = NULL;
    cbuf   *resbuf = NULL;
    cxobj  *ax = NULL;
    cxobj  *x;
    char   *xmlstr;
    cxobj **xv = NULL;
    size_t  xlen;
    int     i;
    int     j;
    char    *metric;
    cxobj   *percentile;
    cxobj   *warningval;
    cxobj   *errorval; 
    cxobj   *enableval; 
    cxobj   *op; 

    clicon_debug(1, "%s", __FUNCTION__);
    if (pn < 1)
	goto done;
    sender = pvec[0];
    if (pn < 2)
	metric0 = pvec[1];
    if ((resbuf = cbuf_new()) == NULL)
	goto done;
    if (netconf_rpc(resbuf, 
		    "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"//profile[name=%s]\" /></get-config></rpc>]]>]]>", sender) < 0){
	clicon_debug(1, "%s error", __FUNCTION__);
	goto done;
    }

    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    xmlstr = cbuf_get(resbuf);
    if (clicon_xml_parse_string(&xmlstr, &ax) < 0){
	clicon_debug(1, "err:%d reason:%s", clicon_errno, clicon_err_reason);
	goto done;
    }
    if (cvec_len(qvec)){
	/* XXX Assume qvec == enable=true*/
	if (xpath_vec(ax, "//profile/metric/*[enable=true]", &xv, &xlen) < 0)
	    goto done;
    }
    else
	if (xpath_vec(ax, "//profile/metric/*", &xv, &xlen) < 0)
	    goto done;
    FCGX_FPrintF(r->out, "[");
    j = 0;
    for (i=0; i<xlen; i++){
	x = xv[i];
	percentile = xpath_first(x, "percentile");
	warningval = xpath_first(x, "warningval");
	errorval = xpath_first(x, "errorval");
	enableval = xpath_first(x, "enable");
	metric = xml_name(x);
	op = xpath_first(x, "op");
	if (metric0 && (strcmp(metric0, metric)))
	    continue;
	if (metric){
	    if (j++)
	    	FCGX_FPrintF(r->out, ",");
	    FCGX_FPrintF(r->out, "{\"metric\":\"%s\",\"perc\":\"%s\",\"warningval\":\"%s\",\"errorval\":\"%s\",\"op\":\"%s\", \"enable\":\"%s\"}", 
			 metric,
			 percentile?xml_body(percentile):"95",
			 warningval?xml_body(warningval):"0",
			 errorval?xml_body(errorval):"0",
			 xml_body(op),
			 enableval?xml_body(enableval):"false"
			 );
	}
    }
    FCGX_FPrintF(r->out, "]");
    FCGX_FPrintF(r->out, "\r\n");

    retval = 0;
 done:
    if (ax)
	xml_free(ax);
     if (xv)
	free(xv);
     if (resbuf)
	cbuf_free(resbuf);
    return retval;
}


/*! Get list of metrics from yang spec
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data

 * GET api/metrics
 * @retval ["rtt", "tior", ...];
 */
static int
api_metrics(FCGX_Request *r, 
	    char        **pvec, 
	    int           pn, 
	    cvec         *qvec, 
	    cvec         *dvec)
{
    int     retval = -1;
    cbuf   *resbuf = NULL;
    char   *xmlstr;
    cxobj  *mx = NULL;
    cxobj  *dx;
    cxobj  *x = NULL;
    int     i;

    if ((resbuf = cbuf_new()) == NULL)
	goto done;
    if (netconf_rpc(resbuf, 
		    "<rpc><grideye><metrics/></grideye></rpc>]]>]]>") < 0){
	clicon_debug(1, "%s error", __FUNCTION__);
	goto done;
    }
    xmlstr = cbuf_get(resbuf);
    if (clicon_xml_parse_string(&xmlstr, &mx) < 0){
	clicon_debug(1, "err:%d reason:%s", clicon_errno, clicon_err_reason);
	goto done;
    }
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    //    FCGX_FPrintF(r->out, "{ \"metrics\":[");

    FCGX_FPrintF(r->out, "[");
    if ((dx = xpath_first(mx, "//data")) != NULL){
	x = NULL;
	i = 0;
	while ((x = xml_child_each(dx, x, -1)) != NULL) {
	    if (i++)
		FCGX_FPrintF(r->out, ", ");
	    FCGX_FPrintF(r->out, "\"%s\"", xml_name(x));
	}
    }
    FCGX_FPrintF(r->out, "]\r\n");

    retval = 0;
 done:
    if (mx)
	xml_free(mx);
     if (resbuf)
	cbuf_free(resbuf);
    return retval;    
}

/*!
 * @note XXX hardcoded that 'nordunet' is template and not included
 */
static int
api_agents(FCGX_Request *r,
            char        **pvec,
            int           pn,
            cvec         *qvec,
            cvec         *dvec)
{
    int     retval = -1;
    cxobj  *ax = NULL;
    cxobj **xvec = NULL;
    cxobj  *x = NULL;
    int     i;
    int     j;
    size_t xlen;

    if (get_db_entry("sender", NULL, NULL, &ax) < 0)
	goto done;
    if (xpath_vec(ax, "//sender", &xvec, &xlen) < 0)
	goto done;

    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    //    FCGX_FPrintF(r->out, "{ \"agents\":[");                              
    FCGX_FPrintF(r->out, "[");
    x = NULL;
    j = 0;
    for (i=0; i< xlen; i++){
	x = xvec[i];
	/* XXX: 'nordunet' hardcoded */
	if (strcmp("nordunet", xml_find_body(x, "name")) == 0)
	    continue;
	if (j++)
	    FCGX_FPrintF(r->out, ", ");

	FCGX_FPrintF(r->out, "\"%s\"", xml_find_body(x, "name"));
    }
    FCGX_FPrintF(r->out, "]\r\n");

    retval = 0;
 done:
    if (xvec)
        free(xvec);
    if (ax)
        xml_free(ax);
    return retval;
}


/*! Get metric specification from yang 
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data
 *
 * GET api/metric_spec?name=rtt
 * @retval [ {
 *           "rtt": {
 *                   "description": "Round-trip latency",
 *                   "type": "uint32",
 *                   "units": "µs"
 *              }
 *            }]
 */
static int
api_metric_spec(FCGX_Request *r, 
		char        **pvec, 
		int           pn, 
		cvec         *qvec, 
		cvec         *dvec)
{
    int     retval = -1;
    cbuf   *resbuf = NULL;
    char   *xmlstr;
    cxobj  *mx = NULL;
    cxobj  *dx;
    cxobj  *sx;
    char   *metric;
    cxobj  *x = NULL;
    int     i;
    int     j;

    clicon_debug(1, "%s", __FUNCTION__);
    if ((resbuf = cbuf_new()) == NULL)
	goto done;
    if ((metric = cvec_find_str(qvec, "name")) == NULL){
	if (netconf_rpc(resbuf, 
			"<rpc><grideye><metric_spec/></grideye></rpc>]]>]]>") < 0){
	    clicon_debug(1, "%s error", __FUNCTION__);
	    goto done;
	}
    }
    else {
	if (netconf_rpc(resbuf, 
			"<rpc><grideye><metric_spec>%s</metric_spec></grideye></rpc>]]>]]>",
			metric) < 0){
	    clicon_debug(1, "%s error", __FUNCTION__);
	    goto done;
	}
    }
    xmlstr = cbuf_get(resbuf);
    clicon_debug(1, "%s xmlstr: %s", __FUNCTION__, xmlstr);
    if (clicon_xml_parse_string(&xmlstr, &mx) < 0){
	clicon_debug(1, "err:%d reason:%s", clicon_errno, clicon_err_reason);
	goto done;
    }
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    //    FCGX_FPrintF(r->out, "{ \"%s\":[", );
    FCGX_FPrintF(r->out, "[{");
    /*

{
   "rtt":{
      "description":"Round-trip latency", 
      "type":"uint32", 
      "units":"µs"
  }}     */
    if ((dx = xpath_first(mx, "//data")) != NULL){
	j = 0;
	x = NULL;
	while ((x = xml_child_each(dx, x, -1)) != NULL) {
	    if (j++)
		FCGX_FPrintF(r->out, ", ");
	    FCGX_FPrintF(r->out, "\"%s\":{", xml_name(x));
	    sx = NULL;
	    i = 0;
	    while ((sx = xml_child_each(x, sx, -1)) != NULL) {
		if (i++)
		    FCGX_FPrintF(r->out, ", ");
		FCGX_FPrintF(r->out, "\"%s\":\"%s\"", 
			     xml_name(sx), xml_body(sx));
	    }
	    FCGX_FPrintF(r->out, "}");
	}
    }
    FCGX_FPrintF(r->out, "}]\r\n");

    retval = 0;
 done:
    if (mx)
	xml_free(mx);
     if (resbuf)
	cbuf_free(resbuf);
    return retval;    
}

/*! Generic REST GET method 
 * @param[in]  r        Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  dvec   Stream input data
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * Example:
 *  curl -G http://localhost/api/data/profile/name=default/metric/rtt
 */
static int
api_data_get(FCGX_Request *r, 
	     cvec         *pcvec, 
	     int           pi,
	     cvec         *qvec)

{
    int     retval = -1;
    cg_var *cv;
    char   *val;
    int     i;
    cbuf   *res = NULL;
    cbuf   *path = NULL;
    cbuf   *path1 = NULL;
    char   *xmlstr;
    cxobj  *xt = NULL;
    cxobj  *xg = NULL;
    cbuf   *cbx = NULL;
	
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
    clicon_debug(1, "path:%s", cbuf_get(path));
    if ((res = cbuf_new()) == NULL)
	goto done;
    if (netconf_rpc(res, 
		    "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"%s\" /></get-config></rpc>]]>]]>", 
		    cbuf_get(path)) < 0){
	clicon_debug(1, "%s error", __FUNCTION__);
	goto done;
    }
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: application/yang.data+xml\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    xmlstr = cbuf_get(res);
    if (clicon_xml_parse_string(&xmlstr, &xt) < 0){
	clicon_debug(1, "err:%d reason:%s", clicon_errno, clicon_err_reason);
	goto done;
    }
    if ((xg = xpath_first(xt, cbuf_get(path1))) != NULL){
	if ((cbx = cbuf_new()) == NULL)
	    goto done;
	if (clicon_xml2cbuf(cbx, xg, 0, 0) < 0)
	    goto done;
	FCGX_FPrintF(r->out, "%s\r\n", cbuf_get(cbx));
    }
    retval = 0;
 done:
    if (cbx)
	cbuf_free(cbx);
    if (xt)
	xml_free(xt);
     if (res)
	cbuf_free(res);
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
api_data_put(FCGX_Request *r, 
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
api_data_delete(FCGX_Request *r, 
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
api_data(FCGX_Request *r, 
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
	retval = api_data_get(r, pcvec, pi, qvec);
    else if (strcmp(request_method, "PUT")==0)
	retval = api_data_put(r, pcvec, pi, qvec, dvec);
    else if (strcmp(request_method, "DELETE")==0)
	retval = api_data_delete(r, pcvec, pi, qvec);
    else
	retval = notfound(r);
    return retval;
}

/*! Get user (from cookie) 
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pvec   Vector of path (DOCUMENT_URI)
 * @param[in]  pn     Length of path
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  dvec   Stream input data

 * @retval {
              name:"kalle", 
              template: "asender", 
              profile: "default", 
	      dbuser:"john", 
	      dbpasswd: "au", 
	      agents: ["a1", "a2",..]
           }
 */
static int
api_user(FCGX_Request *r, 
	 char        **pvec, 
	 int           pn, 
	 cvec         *qvec, 
	 cvec         *dvec)
{
    int     retval = -1;
    char   *cookie;
    char   *cval = NULL;
    cxobj  *ux = NULL;
    cxobj  *sx = NULL;
    cxobj  *x = NULL;
    char   *user;
    char   *id;
    char   *dbuser;
    char   *dbpasswd;
    char   *plot_ival;
    char   *plot_dur;
    char   *profile = NULL;
    cxobj  *profx = NULL;
    char   *template = DEFAULT_TEMPLATE;
    cxobj **xv = NULL;
    size_t  xlen;
    int    i;

    clicon_debug(1, "%s", __FUNCTION__);
    if ((cookie = FCGX_GetParam("HTTP_COOKIE", r->envp)) == NULL){
	FCGX_SetExitStatus(403, r->out);
	goto done;
    }
    if (get_user_cookie(cookie, USER_COOKIE, &cval) <0)
	goto done;
    if (cval == NULL){ /* Cookie not found, same as no cookie string found */
	FCGX_SetExitStatus(403, r->out);
	goto done;
    }
    if (get_db_entry("user", "id", cval, &ux) < 0)
	goto done;	
    if (check_credentials(NULL, ux) == 0){
	FCGX_SetExitStatus(403, r->out);
	goto done;
    }
    if ((x = xpath_first(ux, "//user/name")) == NULL)
	goto done;
    user = xml_body(x);    
    if ((x = xpath_first(ux, "//user/template")) != NULL)
	template = xml_body(x);    
    if ((x = xpath_first(ux, "//user/profile")) != NULL)
	profile = xml_body(x);    


    if ((x = xpath_first(ux, "//user/id")) == NULL)
	goto done;
    id = xml_body(x);    
    if ((x = xpath_first(ux, "//user/resultdb/username")) == NULL)
	goto done;
    dbuser = xml_body(x);    
    if ((x = xpath_first(ux, "//user/resultdb/password")) == NULL)
	goto done;
    dbpasswd = xml_body(x);    
    /* Get profile including plot settings and metric rules */
    if (get_db_entry("profile", "name", profile, &profx) < 0)
	goto done;

    if ((x = xpath_first(profx, "//profile/interval")) == NULL)
      goto done;
    plot_ival = xml_body(x);    
    if ((x = xpath_first(profx, "//profile/duration")) == NULL)
	goto done;
    plot_dur = xml_body(x);    
    /* Get all senders with matching id */
    if (get_db_entry("sender", "userid", cval, &sx) < 0)
	goto done;	
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "{\"name\": \"%s\","
		 "\"id\":\"%s\","
		 "\"template\":\"%s\","
		 "\"profile\":\"%s\","
		 "\"dbuser\":\"%s\","
		 "\"dbpasswd\":\"%s\","
		 "\"plot_ival\":\"%s\","
		 "\"plot_dur\":\"%s\","
		 "\"agents\":[", 
		 user, id, template, profile, dbuser, dbpasswd,
		 plot_ival, plot_dur);
    if (xpath_vec(sx, "//sender", &xv, &xlen) < 0)
	goto done;
    for (i=0; i<xlen; i++){
	if ((x = xpath_first(xv[i], "name")) == NULL)
	    continue;
	if (i)
	    FCGX_FPrintF(r->out, ",");
	FCGX_FPrintF(r->out, "\"%s\"", xml_body(x));
    }
    FCGX_FPrintF(r->out, "]}");
    retval = 0;
 done:
    clicon_debug(1, "%s end %d", __FUNCTION__, retval);
    if (xv)
	free(xv);
    if (ux)
	xml_free(ux);
    if (sx)
	xml_free(sx);
    return retval;
}

/*! Process a FastCGI request
 * @param[in]  r        Fastcgi request handle
 */
static int
request_process(FCGX_Request *r)
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
    if (strcmp(method, "cli") == 0)
	retval = api_cli(r, pvec+3, pn-3, 
			 qvec, data);
    else if (strcmp(method, "netconf") == 0)
	retval = api_netconf(r, pvec+3, pn-3, 
			     qvec, data);
    else if (strcmp(method, "login") == 0)
	retval = api_login(r, pvec+3, pn-3, 
			   qvec, dvec);
    else if (strcmp(method, "logout") == 0)
	retval = api_logout(r, pvec+3, pn-3, 
			    qvec, dvec);
    else if (strcmp(method, "signup") == 0)
	retval = api_signup(r, pvec+3, pn-3, 
			    qvec, dvec);
    else if (strcmp(method, "settings") == 0)
	retval = api_settings(r, pvec+3, pn-3, 
			      qvec, dvec);
    else if (strcmp(method, "callhome") == 0)
	retval = api_callhome(r, pvec+3, pn-3, 
			      qvec, dvec);
    else if (strcmp(method, "metric_rules") == 0)
	retval = api_metric_rules(r, pvec+3, pn-3, 
				  qvec, dvec);
    else if (strcmp(method, "metrics") == 0)
	retval = api_metrics(r, pvec+3, pn-3, 
			     qvec, dvec);
    else if (strcmp(method, "agents") == 0)
	retval = api_agents(r, pvec+3, pn-3, 
			     qvec, dvec);
    else if (strcmp(method, "metric_spec") == 0)
	retval = api_metric_spec(r, pvec+3, pn-3, 
			     qvec, dvec);
    else if (strcmp(method, "data") == 0) /* restconf, skip /api/data */
	retval = api_data(r, pcvec, 2, qvec, dvec);
    else if (strcmp(method, "user") == 0)
	retval = api_user(r, pvec+3, pn-3, 
			  qvec, dvec);
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
    clicon_debug(1, "%s", argv[0]);

    if ((sockpath = clicon_option_str(h, "CLICON_RESTCONF_PATH")) == NULL){
	clicon_err(OE_CFG, errno, "No CLICON_RESTCONF_PATH in clixon configure file");
	goto done;
    }
    if ((sock = FCGX_OpenSocket(sockpath, 10)) < 0){
	clicon_err(OE_CFG, errno, "FCGX_OpenSocket");
	goto done;
    }
    if (FCGX_Init() != 0){
	clicon_err(OE_CFG, errno, "FCGX_Init");
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
		request_process(r);
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
