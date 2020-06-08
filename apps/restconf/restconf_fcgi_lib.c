/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2020 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
#include "restconf_fcgi_lib.h"

/*! HTTP error 400
 * @param[in]  r        Fastcgi request handle
 */
int
restconf_badrequest(clicon_handle h,
		    FCGX_Request *r)
{
    char *path;

    path = clixon_restconf_param_get(h, "REQUEST_URI");
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
restconf_unauthorized(clicon_handle h,
		      FCGX_Request *r)
{
    char *path;

    path = clixon_restconf_param_get(h, "REQUEST_URI");
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
restconf_forbidden(clicon_handle h,
		   FCGX_Request *r)
{
    char *path;

    path = clixon_restconf_param_get(h, "REQUEST_URI");
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
restconf_notfound(clicon_handle h,
		  FCGX_Request *r)
{
    char *path;

    path = clixon_restconf_param_get(h, "REQUEST_URI");
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
restconf_notacceptable(clicon_handle h,
		       FCGX_Request *r)
{
    char *path;

    path = clixon_restconf_param_get(h, "REQUEST_URI");
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
restconf_internal_server_error(clicon_handle h,
			       FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = clixon_restconf_param_get(h, "REQUEST_URI");
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

/*! Print all FCGI headers
 * @param[in]  r        Fastcgi request handle
 * @see https://nginx.org/en/docs/http/ngx_http_core_module.html#var_https
 */
int
restconf_test(FCGX_Request *r, 
	      int           dbg)
{
    char **environ = r->envp;
    int    i;

    clicon_debug(1, "All environment vars:");
    for (i = 0; environ[i] != NULL; i++){
	clicon_debug(1, "%s", environ[i]);
    }
    clicon_debug(1, "End environment vars");
    return 0;
}

/*! Convert FCGI parameters to clixon runtime data
 * @param[in]  h     Clixon handle
 * @param[in]  envp  Fastcgi request handle parameter array on the format "<param>=<value>"
 * @see https://nginx.org/en/docs/http/ngx_http_core_module.html#var_https
 */
int
clixon_restconf_params_set(clicon_handle h,
			   char        **envp)
{
    int   retval = -1;
    int   i;
    char *param = NULL;
    char *val = NULL;

    clicon_debug(1, "%s", __FUNCTION__);
    for (i = 0; envp[i] != NULL; i++){ /* on the form <param>=<value> */
	if (clixon_strsplit(envp[i], '=', &param, &val) < 0)
	    goto done;
	clicon_debug(1, "%s param:%s val:%s", __FUNCTION__, param, val);
	if (clixon_restconf_param_set(h, param, val) < 0)
	    goto done;
	if (param){
	    free(param);
	    param = NULL;
	}
	if (val){
	    free(val);
	    val = NULL;
	}
    }
    retval = 0;
 done:
    clicon_debug(1, "%s %d", __FUNCTION__, retval);
    return retval;
}

/*! Clear all FCGI parameters in an environment
 * @param[in]  h     Clixon handle
 * @param[in]  envp  Fastcgi request handle parameter array on the format "<param>=<value>"
 * @see https://nginx.org/en/docs/http/ngx_http_core_module.html#var_https
 */
int
clixon_restconf_params_clear(clicon_handle h,
			     char        **envp)
{
    int   retval = -1;
    int   i;
    char *param = NULL;

    clicon_debug(1, "%s", __FUNCTION__);
    for (i = 0; envp[i] != NULL; i++){ /* on the form <param>=<value> */
	if (clixon_strsplit(envp[i], '=', &param, NULL) < 0)
	    goto done;
	clicon_debug(1, "%s param:%s", __FUNCTION__, param);
	if (clixon_restconf_param_del(h, param) < 0)
	    goto done;
	if (param){
	    free(param);
	    param = NULL;
	}
    }
    retval = 0;
 done:
    clicon_debug(1, "%s %d", __FUNCTION__, retval);
    return retval;
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
http_location(clicon_handle h,
	      FCGX_Request *r,
	      cxobj        *xobj)
{
    int   retval = -1;
    char *https;
    char *host;
    char *request_uri;
    cbuf *cb = NULL;

    https = clixon_restconf_param_get(h, "HTTPS");
    host = clixon_restconf_param_get(h, "HTTP_HOST");
    request_uri = clixon_restconf_param_get(h, "REQUEST_URI");
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


