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
  *
  * Return errors
  * @see RFC 7231 Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content
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

#include "restconf_lib.h"
#include "restconf_api.h"
#include "restconf_err.h"

/*
 * Constants
 */
/* In the fcgi implementations some errors had body, it would be cleaner to skip them
 * None seem mandatory according to RFC 7231
 */
#define SKIP_BODY

/*
 * NOTE, fcgi seems not enough with a status code (libevhtp is) but must also have a status 
 * header.
 */

/*! HTTP error 400
 * @param[in]  h    Clicon handle
 * @param[in]  req  Generic Www handle
 */
int
restconf_badrequest(clicon_handle h,
		    void         *req)
{
    int   retval = -1;

#ifdef SKIP_BODY /* Remove the body - should it really be there? */
    if (restconf_reply_send(req, 400, NULL) < 0)
	goto done;
    retval = 0;
 done:
#else
    char *path;
    cbuf *cb = NULL;
    
    /* Create body */
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    path = restconf_param_get("REQUEST_URI", r->envp);
    if (restconf_reply_header(req, "Content-Type", "text/html") < 0)
	goto done;
    cprintf(cb, "The requested URL %s or data is in some way badly formed.\n", path);
    if (restconf_reply_send(req, 400, cb) < 0)
	goto done;
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
#endif
    return retval;
}

/*! HTTP error 401
 * @param[in]  h    Clicon handle
 * @param[in]  req  Generic Www handle
 */
int
restconf_unauthorized(clicon_handle h,
		      void         *req)

{
    int   retval = -1;

#ifdef SKIP_BODY /* Remove the body - should it really be there? */
    if (restconf_reply_send(req, 400, NULL) < 0)
	goto done;
    retval = 0;
 done:
#else
    char *path;
    cbuf *cb = NULL;
    
    /* Create body */
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    path = restconf_param_get("REQUEST_URI", r->envp);
    if (restconf_reply_header(req, "Content-Type", "text/html") < 0)
	goto done;
    cprintf(cb, "<error-tag>access-denied</error-tag>\n");
    cprintf(cb, "The requested URL %s was unauthorized.\n", path);
    if (restconf_reply_send(req, 400, cb) < 0)
	goto done;
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
#endif
    return retval;
}

/*! HTTP error 403
 * @param[in]  h    Clicon handle
 * @param[in]  req  Generic Www handle
 */
int
restconf_forbidden(clicon_handle h,
		   void         *req)
{
    int retval = -1;
#ifdef SKIP_BODY /* Remove the body - should it really be there? */
    if (restconf_reply_send(req, 403, NULL) < 0)
	goto done;
    retval = 0;
 done:
#else
    char *path;
    cbuf *cb = NULL;
    
    /* Create body */
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    path = restconf_param_get("REQUEST_URI", r->envp);
    if (restconf_reply_header(req, "Content-Type", "text/html") < 0)
	goto done;
    cprintf(cb, "The requested URL %s was forbidden.\n", path);
    if (restconf_reply_send(req, 403, cb) < 0)
	goto done;
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
#endif
    return retval;
}

/*! HTTP error 404
 * @param[in]  h    Clicon handle
 * @param[in]  req  Generic Www handle
 * XXX skip body?
 */
int
restconf_notfound(clicon_handle h,
		  void         *req)
{
    int   retval = -1;
#ifdef SKIP_BODY /* Remove the body - should it really be there? */
    if (restconf_reply_send(req, 404, NULL) < 0)
	goto done;
    retval = 0;
 done:
#else
    char *path;
    cbuf *cb = NULL;
    
    /* Create body */
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    path = restconf_param_get("REQUEST_URI", r->envp);
    if (restconf_reply_header(req, "Content-Type", "text/html") < 0)
	goto done;
    cprintf(cb, "The requested URL %s was not found on this server.\n", path);
    if (restconf_reply_send(req, 404, cb) < 0)
	goto done;
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
#endif
    return retval;
}

/*! HTTP error 405
 * @param[in]  req      Generic Www handle
 * @param[in]  allow    Which methods are allowed
 */
int
restconf_method_notallowed(void  *req,
			   char  *allow)
{
    int retval = -1;
    
    if (restconf_reply_header(req, "Allow", "%s", allow) < 0)
	goto done;
    if (restconf_reply_send(req, 405, NULL) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! HTTP error 406 Not acceptable
 * @param[in]  h      Clicon handle
 * @param[in]  req    Generic Www handle
 */
int
restconf_notacceptable(clicon_handle h,
		       void         *req)
{
    int retval = -1;

#ifdef SKIP_BODY /* Remove the body - should it really be there? */
    if (restconf_reply_send(req, 406, NULL) < 0)
	goto done;
    retval = 0;
 done:
#else
    char *path;
    cbuf *cb = NULL;
    
    /* Create body */
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    path = restconf_param_get("REQUEST_URI", r->envp);
    if (restconf_reply_header(req, "Content-Type", "text/html") < 0)
	goto done;
    cprintf(cb, "The target resource does not have a current representation that would be acceptable to the user agent.\n", path);
    if (restconf_reply_send(req, 406, cb) < 0)
	goto done;
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
#endif
    return retval;
}

/*! HTTP error 409
 * @param[in]  req      Generic Www handle
 */
int
restconf_conflict(void    *req)

{
    int   retval = -1;

    if (restconf_reply_send(req, 409, NULL) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! HTTP error 409 Unsupporte dmedia
 * @param[in]  req      Generic Www handle
 */
int
restconf_unsupported_media(void  *req)
{
    int   retval = -1;

    if (restconf_reply_send(req, 415, NULL) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! HTTP error 500 Internal server error
 * @param[in]  h      Clicon handle
 * @param[in]  req    Generic Www handle
 */
int
restconf_internal_server_error(clicon_handle h,
			       void         *req)
{
    int retval = -1;
#ifdef SKIP_BODY /* Remove the body - should it really be there? */
    if (restconf_reply_send(req, 500, NULL) < 0)
	goto done;
    retval = 0;
 done:
#else
    char *path;
    cbuf *cb = NULL;
    
    /* Create body */
    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    path = restconf_param_get("REQUEST_URI", r->envp);
    if (restconf_reply_header(req, "Content-Type", "text/html") < 0)
	goto done;
    cprintf(cb, "Internal server error when accessing %s</h1>\n", path);
    if (restconf_reply_send(req, 500, cb) < 0)
	goto done;
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
#endif
    return retval;
}

/*! HTTP error 501 Not implemented
 * @param[in]  req    Generic Www handle
 */
int
restconf_notimplemented(void *req)
{
    int   retval = -1;

    if (restconf_reply_send(req, 501, NULL) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! Generic restconf error function on get/head request
 * @param[in]  h      Clixon handle
 * @param[in]  req    Generic Www handle
 * @param[in]  xerr   XML error message from backend
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  media  Output media
 * @param[in]  code   If 0 use rfc8040 sec 7 netconf2restconf error-tag mapping
 *                    otherwise use this code
 */
int
api_return_err(clicon_handle h,
	       void         *req,
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
    if (restconf_reply_header(req, "Content_Type", "%s", restconf_media_int2str(media)) < 0)
	goto done;
    switch (media){
    case YANG_DATA_XML:
	clicon_debug(1, "%s code:%d err:%s", __FUNCTION__, code, cbuf_get(cb));
	if (pretty){
	    cprintf(cb, "    <errors xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf\">\n");
	    if (clicon_xml2cbuf(cb, xerr, 2, pretty, -1) < 0)
		goto done;
	    cprintf(cb, "    </errors>\r\n");
	}
	else {
	    cprintf(cb, "<errors xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf\">");
	    if (clicon_xml2cbuf(cb, xerr, 2, pretty, -1) < 0)
		goto done;
	    cprintf(cb, "</errors>\r\n");
	}
	break;
    case YANG_DATA_JSON:
	clicon_debug(1, "%s code:%d err:%s", __FUNCTION__, code, cbuf_get(cb));
	if (pretty){
	    cprintf(cb, "{\n\"ietf-restconf:errors\" : ");
	    if (xml2json_cbuf(cb, xerr, pretty) < 0)
		goto done;
	    cprintf(cb, "\n}\r\n");
	}
	else{
	    cprintf(cb, "{");
	    cprintf(cb, "\"ietf-restconf:errors\":");
	    if (xml2json_cbuf(cb, xerr, pretty) < 0)
		goto done;
	    cprintf(cb, "}\r\n");
	}
	break;
    default:
	clicon_err(OE_YANG, EINVAL, "Invalid media type %d", media);
	goto done;
	break;
    } /* switch media */
    if (restconf_reply_send(req, code, cb) < 0)
	goto done;
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
