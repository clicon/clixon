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

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>
#include <ctype.h>
#include <time.h>
#include <signal.h>
#include <dlfcn.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/wait.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include <fcgi_stdio.h> /* Need to be after clixon_xml-h due to attribute format */

#include "restconf_lib.h"

/* See RFC 8040 Section 7:  Mapping from NETCONF<error-tag> to Status Code
 * and RFC 6241 Appendix A. NETCONF Error list
 */
static const map_str2int netconf_restconf_map[] = {
    {"in-use",                 409},
    {"invalid-value",          400},
    {"invalid-value",          404},
    {"invalid-value",          406},
    {"too-big",                413}, /* request */
    {"too-big",                400}, /* response */
    {"missing-attribute",      400},
    {"bad-attribute",          400},
    {"unknown-attribute",      400},
    {"bad-element",            400},
    {"unknown-element",        400},
    {"unknown-namespace",      400},
    {"access-denied",          401},
    {"access-denied",          403},
    {"lock-denied",            409},
    {"resource-denied",        409},
    {"rollback-failed",        500},
    {"data-exists",            409},
    {"data-missing",           409},
    {"operation-not-supported",405},
    {"operation-not-supported",501},
    {"operation-failed",       412},
    {"operation-failed",       500},
    {"partial-operation",      500},
    {"malformed-message",      400},
    {NULL,                     -1}
};

/* See 7231 Section 6.1
 */
static const map_str2int http_reason_phrase_map[] = {
    {"Continue",                      100},
    {"Switching Protocols",           101},
    {"OK",                            200}, 
    {"Created",                       201},
    {"Accepted",                      202},
    {"Non-Authoritative Information", 203},
    {"No Content",                    204},
    {"Reset Content",                 205},
    {"Partial Content",               206},
    {"Multiple Choices",              300},
    {"Moved Permanently",             301},
    {"Found",                         302},
    {"See Other",                     303},
    {"Not Modified",                  304},
    {"Use Proxy",                     305},
    {"Temporary Redirect",            307},
    {"Bad Request",                   400},
    {"Unauthorized",                  401},
    {"Payment Required",              402},
    {"Forbidden",                     403},
    {"Not Found",                     404},
    {"Method Not Allowed",            405},
    {"Not Acceptable",                406},
    {"Proxy Authentication Required", 407},
    {"Request Timeout",               408},
    {"Conflict",                      409},
    {"Gone",                          410},
    {"Length Required",               411},
    {"Precondition Failed",           412},
    {"Payload Too Large",             413},
    {"URI Too Long",                  414},
    {"Unsupported Media Type",        415},
    {"Range Not Satisfiable",         416},
    {"Expectation Failed",            417},
    {"Upgrade Required",              426},
    {"Internal Server Error",         500},
    {"Not Implemented",               501},
    {"Bad Gateway",                   502},
    {"Service Unavailable",           503},
    {"Gateway Timeout",               504},
    {"HTTP Version Not Supported",    505},
    {NULL,                            -1}
};

int
restconf_err2code(char *tag)
{
    return clicon_str2int(netconf_restconf_map, tag);
}

const char *
restconf_code2reason(int code)
{
    return clicon_int2str(http_reason_phrase_map, code);
}

/*! HTTP error 400
 * @param[in]  r        Fastcgi request handle
 */
int
badrequest(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 400\r\n"); /* 400 bad request */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Clixon Bad request/h1>\n");
    FCGX_FPrintF(r->out, "The requested URL %s or data is in some way badly formed.\n",
		 path);
    return 0;
}

/*! HTTP error 401
 * @param[in]  r        Fastcgi request handle
 */
int
unauthorized(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 401\r\n"); /* 401 unauthorized */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<error-tag>access-denied</error-tag>\n");
    FCGX_FPrintF(r->out, "The requested URL %s was unauthorized.\n", path);
   return 0;
}

/*! HTTP error 403
 * @param[in]  r        Fastcgi request handle
 */
int
forbidden(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 403\r\n"); /* 403 forbidden */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Grideye Forbidden</h1>\n");
    FCGX_FPrintF(r->out, "The requested URL %s was forbidden.\n", path);
   return 0;
}

/*! HTTP error 404
 * @param[in]  r        Fastcgi request handle
 */
int
notfound(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 404\r\n"); /* 404 not found */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Not Found</h1>\n");
    FCGX_FPrintF(r->out, "The requested URL %s was not found on this server.\n",
		 path);
    return 0;
}

/*! HTTP error 409
 * @param[in]  r        Fastcgi request handle
 */
int
conflict(FCGX_Request *r)
{
    clicon_debug(1, "%s", __FUNCTION__);
    FCGX_FPrintF(r->out, "Status: 409\r\n"); /* 409 Conflict */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Data resource already exists</h1>\n");
    return 0;
}

/*! HTTP error 500
 * @param[in]  r        Fastcgi request handle
 */
int
internal_server_error(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 500\r\n"); /* 500 internal server error */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Grideye Internal server error when accessing %s</h1>\n", path);
    return 0;
}

/*! HTTP error 501
 * @param[in]  r        Fastcgi request handle
 */
int
notimplemented(FCGX_Request *r)
{
    clicon_debug(1, "%s", __FUNCTION__);
    FCGX_FPrintF(r->out, "Status: 501\r\n"); 
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Not Implemented/h1>\n");
    return 0;
}

/*! Specialization of clicon_debug with xml tree */
int 
clicon_debug_xml(int    dbglevel, 
		 char  *str,
		 cxobj *x)
{
    int   retval = -1;
    cbuf *cb;

    if ((cb = cbuf_new()) == NULL)
	goto done;
    if (clicon_xml2cbuf(cb, x, 0, 0) < 0)
	goto done;
    clicon_debug(1, "%s %s", str, cbuf_get(cb));
    retval = 0;
 done:
    if (cb!=NULL)
	cbuf_free(cb);
    return retval;
}

/*!
 * @param[in]  r        Fastcgi request handle
 */
static int
printparam(FCGX_Request *r, 
	   char         *e, 
	   int           dbgp)
{
    char *p = FCGX_GetParam(e, r->envp);

    if (dbgp)
	clicon_debug(1, "%s = '%s'", e, p?p:"");
    else
	FCGX_FPrintF(r->out, "%s = '%s'\n", e, p?p:"");
    return 0;
}

/*!
 * @param[in]  r        Fastcgi request handle
 */
int
test(FCGX_Request *r, 
     int           dbg)
{
    printparam(r, "QUERY_STRING", dbg);
    printparam(r, "REQUEST_METHOD", dbg);	
    printparam(r, "CONTENT_TYPE", dbg);	
    printparam(r, "CONTENT_LENGTH", dbg);	
    printparam(r, "SCRIPT_FILENAME", dbg);	
    printparam(r, "SCRIPT_NAME", dbg);	
    printparam(r, "REQUEST_URI", dbg);	
    printparam(r, "DOCUMENT_URI", dbg);	
    printparam(r, "DOCUMENT_ROOT", dbg);	
    printparam(r, "SERVER_PROTOCOL", dbg);	
    printparam(r, "GATEWAY_INTERFACE", dbg);
    printparam(r, "SERVER_SOFTWARE", dbg);
    printparam(r, "REMOTE_ADDR", dbg);
    printparam(r, "REMOTE_PORT", dbg);
    printparam(r, "SERVER_ADDR", dbg);
    printparam(r, "SERVER_PORT", dbg);
    printparam(r, "SERVER_NAME", dbg);
    printparam(r, "HTTP_COOKIE", dbg);
    printparam(r, "HTTPS", dbg);
    printparam(r, "HTTP_ACCEPT", dbg);
    printparam(r, "HTTP_CONTENT_TYPE", dbg);
    printparam(r, "HTTP_AUTHORIZATION", dbg);
#if 0 /* For debug */
    clicon_debug(1, "All environment vars:");
    {
	extern char **environ;
	int i;
	for (i = 0; environ[i] != NULL; i++){
	    clicon_debug(1, "%s", environ[i]);
	}
    }
    clicon_debug(1, "End environment vars:");
#endif
    return 0;
}

/*!
 * @param[in]  r        Fastcgi request handle
 */
cbuf *
readdata(FCGX_Request *r)
{
    int   c;
    cbuf *cb;

    if ((cb = cbuf_new()) == NULL)
	return NULL;
    while ((c = FCGX_GetChar(r->in)) != -1)
	cprintf(cb, "%c", c);
    return cb;
}


static int nplugins = 0;
static plghndl_t *plugins = NULL;
static plgcredentials_t *_credentials_fn = NULL; /* Credentials callback */

/*! Load all plugins you can find in CLICON_RESTCONF_DIR
 */
int 
restconf_plugin_load(clicon_handle h)
{
    int            retval = -1;
    char          *dir;
    int            ndp;
    struct dirent *dp = NULL;
    int            i;
    plghndl_t     *handle;
    char           filename[MAXPATHLEN];

    clicon_debug(1, "%s", __FUNCTION__); 
    if ((dir = clicon_restconf_dir(h)) == NULL){
	retval = 0;
	goto quit;
    }
    /* Get plugin objects names from plugin directory */
    if((ndp = clicon_file_dirent(dir, &dp, "(.so)$", S_IFREG))<0)
	goto quit;
    /* Load all plugins */
    for (i = 0; i < ndp; i++) {
	snprintf(filename, MAXPATHLEN-1, "%s/%s", dir, dp[i].d_name);
	clicon_debug(1, "DEBUG: Loading plugin '%.*s' ...", 
		     (int)strlen(filename), filename);
	if ((handle = plugin_load(h, filename, RTLD_NOW)) == NULL)
	    goto quit;
	if ((_credentials_fn    = dlsym(handle, PLUGIN_CREDENTIALS)) == NULL)
	    clicon_debug(1, "Failed to load %s", PLUGIN_CREDENTIALS); 
	else
	    clicon_debug(1, "%s callback loaded", PLUGIN_CREDENTIALS); 
	if ((plugins = realloc(plugins, (nplugins+1) * sizeof (*plugins))) == NULL) {
	    clicon_err(OE_UNIX, errno, "realloc");
	    goto quit;
	}
	plugins[nplugins++] = handle;
    }
    retval = 0;
quit:
    if (dp)
	free(dp);
    return retval;
}


/*! Unload all restconf plugins */
int
restconf_plugin_unload(clicon_handle h)
{
    int i;

    for (i = 0; i < nplugins; i++) 
	plugin_unload(h, plugins[i]);
    if (plugins){
	free(plugins);
	plugins = NULL;
    }
    nplugins = 0;
    return 0;
}

/*! Call plugin_start in all plugins
 */
int
restconf_plugin_start(clicon_handle h, 
		      int           argc, 
		      char        **argv)
{
    int i;
    plgstart_t *startfn;

    for (i = 0; i < nplugins; i++) {
	/* Call exit function is it exists */
	if ((startfn = dlsym(plugins[i], PLUGIN_START)) == NULL)
	    break;
	optind = 0;
	if (startfn(h, argc, argv) < 0) {
	    clicon_debug(1, "plugin_start() failed\n");
	    return -1;
	}
    }
    return 0;
}

/*! Run the restconf user-defined credentials callback if present
 * The callback is expected to return the authenticated user, or NULL if not
 * authenticasted.
 * If no callback exists, return user "none"
 * @param[in]  h    Clicon handle
 * @param[in]  r    Fastcgi request handle
 * @param[out] user The authenticated user (or NULL). Malloced, must be freed.
 */
int 
restconf_credentials(clicon_handle h,     
		     FCGX_Request *r,
		     char        **user)
{
    int retval = -1;

    clicon_debug(1, "%s", __FUNCTION__);
    /* If no authentication callback then allow anything. Is this OK? */
    if (_credentials_fn == NULL){
	if ((*user = strdup("none")) == NULL){
	    clicon_err(OE_XML, errno, "strdup");
	    goto done;
	}
	goto ok;
    }
    if (_credentials_fn(h, r, user) < 0) 
	*user = NULL;
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d user:%s", __FUNCTION__, retval, *user);
    return retval;
}

/*! Parse a cookie string and return value of cookie attribute
 * @param[in]  cookiestr  cookie string according to rfc6265 (modified)
 * @param[in]  attribute  cookie attribute
 * @param[out] val        malloced cookie value, free with free()
 */
int
get_user_cookie(char  *cookiestr, 
		char  *attribute, 
		char **val)
{
    int    retval = -1;
    cvec  *cvv = NULL;
    char  *c;

    if (str2cvec(cookiestr, ';', '=', &cvv) < 0)
	goto done;
    if ((c = cvec_find_str(cvv, attribute)) != NULL){
	if ((*val = strdup(c)) == NULL)
	    goto done;
    }
    retval = 0;
 done:
    if (cvv)
	cvec_free(cvv);
    return retval;
}
