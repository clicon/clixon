/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2020 Olof Hagsand

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
  
  * @see https://nginx.org/en/docs/http/ngx_http_core_module.html#var_https
  * @note The response payload for errors uses text_html. RFC7231 is vague
  * on the response payload (and its media). Maybe it should be omitted 
  * altogether?
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

#include <fcgiapp.h> /* Need to be after clixon_xml-h due to attribute format */

#include "restconf_lib.h"

/* See RFC 8040 Section 7:  Mapping from NETCONF<error-tag> to Status Code
 * and RFC 6241 Appendix A. NETCONF Error list
 */
static const map_str2int netconf_restconf_map[] = {
    {"in-use",                 409},
    {"invalid-value",          404},
    {"invalid-value",          400},
    {"invalid-value",          406},
    {"too-big",                413}, /* request */
    {"too-big",                400}, /* response */
    {"missing-attribute",      400},
    {"bad-attribute",          400},
    {"unknown-attribute",      400},
    {"missing-element",        400},
    {"bad-element",            400},
    {"unknown-element",        400},
    {"unknown-namespace",      400},
    {"access-denied",          403}, 
    {"access-denied",          401}, /* or 403 */
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

/* See RFC 8040
 * @see restconf_media_str2int
 */
static const map_str2int http_media_map[] = {
    {"application/yang-data+xml",     YANG_DATA_XML},
    {"application/yang-data+json",    YANG_DATA_JSON},
    {"application/yang-patch+xml",    YANG_PATCH_XML},
    {"application/yang-patch+json",   YANG_PATCH_JSON},
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

const restconf_media
restconf_media_str2int(char *media)
{
    return clicon_str2int(http_media_map, media);
}

const char *
restconf_media_int2str(restconf_media media)
{
    return clicon_int2str(http_media_map, media);
}

/*! Return media_in from Content-Type, -1 if not found or unrecognized
 * @note media-type syntax does not support parameters
 * @see RFC7231 Sec 3.1.1.1 for media-type syntax type:
 *    media-type = type "/" subtype *( OWS ";" OWS parameter )
 *     type       = token
 *    subtype    = token
 * 
 */
restconf_media
restconf_content_type(FCGX_Request *r)
{
    char          *str;
    restconf_media m;

    if ((str = FCGX_GetParam("HTTP_CONTENT_TYPE", r->envp)) == NULL)
	return -1;
    if ((int)(m = restconf_media_str2int(str)) == -1)
	return -1;
    return m;
}

/*! HTTP error 400
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_badrequest(FCGX_Request *r)
{
    char *path;

    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_SetExitStatus(400, r->out);
    FCGX_FPrintF(r->out, "Status: 400 Bad Request\r\n"); /* 400 bad request */
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
restconf_unauthorized(FCGX_Request *r)
{
    char *path;

    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_SetExitStatus(401, r->out);
    FCGX_FPrintF(r->out, "Status: 401 Unauthorized\r\n"); /* 401 unauthorized */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<error-tag>access-denied</error-tag>\n");
    FCGX_FPrintF(r->out, "The requested URL %s was unauthorized.\n", path);
   return 0;
}

/*! HTTP error 403
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_forbidden(FCGX_Request *r)
{
    char *path;

    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_SetExitStatus(403, r->out);
    FCGX_FPrintF(r->out, "Status: 403 Forbidden\r\n"); /* 403 forbidden */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Forbidden</h1>\n");
    FCGX_FPrintF(r->out, "The requested URL %s was forbidden.\n", path);
   return 0;
}

/*! HTTP error 404
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_notfound(FCGX_Request *r)
{
    char *path;

    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_SetExitStatus(404, r->out);
    FCGX_FPrintF(r->out, "Status: 404 Not Found\r\n"); /* 404 not found */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Not Found</h1>\n");
    FCGX_FPrintF(r->out, "Not Found\n");
    FCGX_FPrintF(r->out, "The requested URL %s was not found on this server.\n",
		 path);
    return 0;
}

/*! HTTP error 406 Not acceptable
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_notacceptable(FCGX_Request *r)
{
    char *path;

    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_SetExitStatus(406, r->out);
    FCGX_FPrintF(r->out, "Status: 406 Not Acceptable\r\n"); /* 406 not acceptible */

    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Not Acceptable</h1>\n");
    FCGX_FPrintF(r->out, "Not Acceptable\n");
    FCGX_FPrintF(r->out, "The target resource does not have a current representation that would be acceptable to the user agent.\n",
		 path);
    return 0;
}

/*! HTTP error 409
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_conflict(FCGX_Request *r)
{
    FCGX_SetExitStatus(409, r->out);
    FCGX_FPrintF(r->out, "Status: 409 Conflict\r\n"); /* 409 Conflict */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Data resource already exists</h1>\n");
    return 0;
}

/*! HTTP error 409
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_unsupported_media(FCGX_Request *r)
{
    FCGX_SetExitStatus(415, r->out);
    FCGX_FPrintF(r->out, "Status: 415 Unsupported Media Type\r\n"); 
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Unsupported Media Type</h1>\n");
    return 0;
}

/*! HTTP error 500
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_internal_server_error(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 500 Internal Server Error\r\n"); /* 500 internal server error */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Internal server error when accessing %s</h1>\n", path);
    return 0;
}

/*! HTTP error 501
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_notimplemented(FCGX_Request *r)
{
    clicon_debug(1, "%s", __FUNCTION__);
    FCGX_FPrintF(r->out, "Status: 501 Not Implemented\r\n"); 
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Not Implemented/h1>\n");
    return 0;
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

/*! Print all FCGI headers
 * @param[in]  r        Fastcgi request handle
 * @see https://nginx.org/en/docs/http/ngx_http_core_module.html#var_https
 */
int
restconf_test(FCGX_Request *r, 
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
    printparam(r, "HTTP_HOST", dbg);
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

/*! Return restconf error on get/head request
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  xerr   XML error message from backend
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  media  Output media
 * @param[in]  code   If 0 use rfc8040 sec 7 netconf2restconf error-tag mapping
 *                    otherwise use this code
 */
int
api_return_err(clicon_handle h,
	       FCGX_Request *r,
	       cxobj        *xerr,
	       int           pretty,
	       restconf_media media,
	       int           code0)
{
    int        retval = -1;
    cbuf      *cb = NULL;
    cbuf      *cberr = NULL;
    cxobj     *xtag;
    char      *tagstr;
    int        code;	
    cxobj     *xerr2 = NULL;
    const char *reason_phrase;

    clicon_debug(1, "%s", __FUNCTION__);
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    /* A well-formed error message when entering here should look like:
     * <rpc-error>...<error-tag>invalid-value</error-tag>
     * Check this is so, otherwise generate an internal error.
     */
    if (strcmp(xml_name(xerr), "rpc-error") != 0 ||
	(xtag = xpath_first(xerr, NULL, "error-tag")) == NULL){
	if ((cberr = cbuf_new()) == NULL){
	    clicon_err(OE_UNIX, errno, "cbuf_new");
	    goto done;
	}
	cprintf(cberr, "Internal error, system returned invalid error message: ");
	if (netconf_err2cb(xerr, cberr) < 0)
	    goto done;
	if (netconf_operation_failed_xml(&xerr2, "application",
					 cbuf_get(cberr)) < 0)
	    goto done;
	if ((xerr = xpath_first(xerr2, NULL, "//rpc-error")) == NULL){
	    clicon_err(OE_XML, 0, "Internal error, shouldnt happen");
	    goto done;
	}
    }
    if (xml_name_set(xerr, "error") < 0)
	goto done;
    tagstr = xml_body(xtag);
    if (code0 != 0)
	code = code0;
    else{
	if ((code = restconf_err2code(tagstr)) < 0)
	    code = 500; /* internal server error */
    }
    if ((reason_phrase = restconf_code2reason(code)) == NULL)
	reason_phrase="";
    FCGX_SetExitStatus(code, r->out); /* Created */
    FCGX_FPrintF(r->out, "Status: %d %s\r\n", code, reason_phrase);
    FCGX_FPrintF(r->out, "Content-Type: %s\r\n\r\n", restconf_media_int2str(media));
    switch (media){
    case YANG_DATA_XML:
	if (clicon_xml2cbuf(cb, xerr, 2, pretty, -1) < 0)
	    goto done;
	clicon_debug(1, "%s code:%d err:%s", __FUNCTION__, code, cbuf_get(cb));
	if (pretty){
	    FCGX_FPrintF(r->out, "    <errors xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf\">\n", cbuf_get(cb));
	    FCGX_FPrintF(r->out, "%s", cbuf_get(cb));
	    FCGX_FPrintF(r->out, "    </errors>\r\n");
	}
	else {
	    FCGX_FPrintF(r->out, "<errors xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf\">", cbuf_get(cb));
	    FCGX_FPrintF(r->out, "%s", cbuf_get(cb));
	    FCGX_FPrintF(r->out, "</errors>\r\n");
	}
	break;
    case YANG_DATA_JSON:
	if (xml2json_cbuf(cb, xerr, pretty) < 0)
	    goto done;
	clicon_debug(1, "%s code:%d err:%s", __FUNCTION__, code, cbuf_get(cb));
	if (pretty){
	    FCGX_FPrintF(r->out, "{\n");
	    FCGX_FPrintF(r->out, "  \"ietf-restconf:errors\" : %s\n",
			 cbuf_get(cb));
	    FCGX_FPrintF(r->out, "}\r\n");
	}
	else{
	    FCGX_FPrintF(r->out, "{");
	    FCGX_FPrintF(r->out, "\"ietf-restconf:errors\":");
	    FCGX_FPrintF(r->out, "%s", cbuf_get(cb));
	    FCGX_FPrintF(r->out, "}\r\n");
	}
	break;
    default:
	clicon_err(OE_YANG, EINVAL, "Invalid media type %d", media);
	goto done;
	break;
    } /* switch media */
    // ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (cb)
        cbuf_free(cb);
    if (cberr)
        cbuf_free(cberr);
    return retval;
}

/*! Print location header from FCGI environment
 * @param[in]  r      Fastcgi request handle
 * @param[in]  xobj   If set (eg POST) add to api-path
 * $https  “on” if connection operates in SSL mode, or an empty string otherwise 
 * @note ports are ignored
 */
int
http_location(FCGX_Request *r,
	      cxobj        *xobj)
{
    int   retval = -1;
    char *https;
    char *host;
    char *request_uri;
    cbuf *cb = NULL;

    https = FCGX_GetParam("HTTPS", r->envp);
    host = FCGX_GetParam("HTTP_HOST", r->envp);
    request_uri = FCGX_GetParam("REQUEST_URI", r->envp);
    if (xobj != NULL){
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_UNIX, 0, "cbuf_new");
	    goto done;
	}
	if (xml2api_path_1(xobj, cb) < 0)
	    goto done;
	FCGX_FPrintF(r->out, "Location: http%s://%s%s%s\r\n",
		     https?"s":"",
		     host,
		     request_uri,
		     cbuf_get(cb));
    }
    else
	FCGX_FPrintF(r->out, "Location: http%s://%s%s\r\n",
		     https?"s":"",
		     host,
		     request_uri);
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Clean and close all state of restconf process (but dont exit). 
 * Cannot use h after this 
 * @param[in]  h  Clixon handle
 */
int
restconf_terminate(clicon_handle h)
{
    yang_stmt *yspec;
    cvec      *nsctx;
    cxobj     *x;
    int        fs; /* fgcx socket */

    clicon_debug(1, "%s", __FUNCTION__);
    if ((fs = clicon_socket_get(h)) != -1)
	close(fs);
    clixon_plugin_exit(h);
    rpc_callback_delete_all(h);
    clicon_rpc_close_session(h);
    if ((yspec = clicon_dbspec_yang(h)) != NULL)
	yspec_free(yspec);
    if ((yspec = clicon_config_yang(h)) != NULL)
	yspec_free(yspec);
    if ((nsctx = clicon_nsctx_global_get(h)) != NULL)
	cvec_free(nsctx);
    if ((x = clicon_conf_xml(h)) != NULL)
	xml_free(x);
    xpath_optimize_exit();
    clicon_handle_exit(h);
    clicon_log_exit();
    return 0;
}

/*! If restconf insert/point attributes are present, translate to netconf 
 * @param[in] xdata  URI->XML to translate
 * @param[in] qvec   Query parameters (eg where insert/point should be)
 * @retval    0      OK 
 * @retval   -1      Error
 * A difficulty is that RESTCONF 'point' is a complete identity-identifier encoded
 * as an uri-path
 * wheras NETCONF key and value are:
 * The value of the "key" attribute is the key predicates of the full instance identifier
 * the "value" attribute MUST also be used to specify an existing entry in the
 * leaf-list.
 * This means that api-path is first translated to xpath, and then strip everything
 * except the key values (or leaf-list values).
 * Example:
 * RESTCONF URI: point=%2Fexample-jukebox%3Ajukebox%2Fplaylist%3DFoo-One%2Fsong%3D1
 * Leaf example:
 *   instance-id: /ex:system/ex:service[ex:name='foo'][ex:enabled='']
 *   NETCONF: yang:key="[ex:name='foo'][ex:enabled='']
 * Leaf-list example:
 *   instance-id: /ex:system/ex:service[.='foo']
 *   NETCONF: yang:value="foo"
 */
int
restconf_insert_attributes(cxobj *xdata,
			   cvec  *qvec)
{
    int        retval = -1;
    cxobj     *xa;
    char      *instr;
    char      *pstr;
    yang_stmt *y;
    char      *attrname;
    int        ret;
    char      *xpath = NULL;
    cvec      *nsc = NULL;
    cbuf      *cb = NULL;
    char      *p;
    cg_var    *cv = NULL;

    y = xml_spec(xdata);
    if ((instr = cvec_find_str(qvec, "insert")) != NULL){
	/* First add xmlns:yang attribute */
	if (xmlns_set(xdata, "yang", YANG_XML_NAMESPACE) < 0)
	    goto done;
	/* Then add insert attribute */
	if ((xa = xml_new("insert", xdata, CX_ATTR)) == NULL)
	    goto done;
	if (xml_prefix_set(xa, "yang") < 0)
	    goto done;
	if (xml_value_set(xa, instr) < 0)
	    goto done;
    }
    if ((pstr = cvec_find_str(qvec, "point")) != NULL){
	if (y == NULL){
	    clicon_err(OE_YANG, 0, "Cannot yang resolve %s", xml_name(xdata));
	    goto done;
	}
	if (yang_keyword_get(y) == Y_LIST)
	    attrname="key";
	else
	    attrname="value";
	/* Then add value/key attribute */
	if ((xa = xml_new(attrname, xdata, CX_ATTR)) == NULL)
	    goto done;
	if (xml_prefix_set(xa, "yang") < 0)
	    goto done;
	if ((ret = api_path2xpath(pstr, ys_spec(y), &xpath, &nsc, NULL)) < 0)
	    goto done;
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_UNIX, errno, "cbuf_new");
	    goto done;
	}
	if (yang_keyword_get(y) == Y_LIST){
	    /* translate /../x[] --> []*/
	    if ((p = rindex(xpath,'/')) == NULL)
		p = xpath;
	    p = index(p, '[');
	    cprintf(cb, "%s", p);
	}
	else{ /* LEAF_LIST */
	    /* translate /../x[.='x'] --> x */
	    if ((p = rindex(xpath,'\'')) == NULL){
		clicon_err(OE_YANG, 0, "Translated api->xpath %s->%s not on leaf-list canonical form: ../[.='x']", pstr, xpath);
		goto done;
	    }
	    *p = '\0';
	    if ((p = rindex(xpath,'\'')) == NULL){
		clicon_err(OE_YANG, 0, "Translated api->xpath %s->%s not on leaf-list canonical form: ../[.='x']", pstr, xpath);
		goto done;
	    }
	    p++;
	    cprintf(cb, "%s", p);
	}
	if (xml_value_set(xa, cbuf_get(cb)) < 0)
	    goto done;
    }
    /* Add prefix/namespaces used in attributes */
    cv = NULL;
    while ((cv = cvec_each(nsc, cv)) != NULL){
	char *ns = cv_string_get(cv);
	if (xmlns_set(xdata, cv_name_get(cv), ns) < 0)
	    goto done;
    }
    if (nsc)
	xml_sort(xdata, NULL); /* Ensure attr is first */
    cprintf(cb, "/>");
    retval = 0;
 done:
    if (xpath)
	free(xpath);
    if (nsc)
	xml_nsctx_free(nsc);
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Extract uri-encoded uri-path from fastcgi parameters
 * Use REQUEST_URI parameter and strip ?args
 * REQUEST_URI have args and is encoded
 *   eg /interface=eth%2f0%2f0?insert=first
 * DOCUMENT_URI dont have args and is not encoded
 *   eg /interface=eth/0/0
 *  causes problems with eg /interface=eth%2f0%2f0
 */
char *
restconf_uripath(FCGX_Request *r)
{
    char *path;
    char *q;

    path = FCGX_GetParam("REQUEST_URI", r->envp); 
    if ((q = index(path, '?')) != NULL)
	*q = '\0';
    return path;
}

