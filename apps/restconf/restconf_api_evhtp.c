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
  
  * Concrete functions for libevhtp of the
  * Virtual clixon restconf API functions.
  * @see restconf_api.h for virtual API
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

/* evhtp */ 
#include <evhtp/evhtp.h>
#include <evhtp/sslutils.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include "restconf_lib.h"
#include "restconf_api.h"  /* Virtual api */

/*! Add HTTP header field name and value to reply, evhtp specific
 * @param[in]  req   Evhtp http request handle
 * @param[in]  name  HTTP header field name
 * @param[in]  vfmt  HTTP header field value format string w variable parameter
 * @see eg RFC 7230
 */
int
restconf_reply_header(void   *req0,
		      char   *name,
		      char   *vfmt,
		      ...)

{
    evhtp_request_t *req = (evhtp_request_t *)req0;
    int              retval = -1;
    size_t           vlen;
    char            *value = NULL;
    va_list          ap;
    evhtp_header_t  *evhdr;
	
    if (req == NULL || name == NULL || vfmt == NULL){
	clicon_err(OE_CFG, EINVAL, "req, name or value is NULL");
	return -1;
    }
    va_start(ap, vfmt);
    vlen = vsnprintf(NULL, 0, vfmt, ap);
    va_end(ap);
    /* allocate value string exactly fitting */
    if ((value = malloc(vlen+1)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    /* second round: compute actual value */
    va_start(ap, vfmt);    
    if (vsnprintf(value, vlen+1, vfmt, ap) < 0){
	clicon_err(OE_UNIX, errno, "vsnprintf");
	va_end(ap);
	goto done;
    }
    va_end(ap);
    if ((evhdr = evhtp_header_new(name, value, 0, 1)) == NULL){  /* 1: free after use */
	clicon_err(OE_CFG, errno, "evhttp_header_new");
	goto done;
    }
    value = NULL; /* freed by evhtp */
    evhtp_headers_add_header(req->headers_out, evhdr);
    retval = 0;
 done:
    if (value)
    	free(value);
    return retval;
}

/*! Send HTTP reply with potential message body
 * @param[in]     req         Evhtp http request handle
 * @param[in]     cb          Body as a cbuf, send if 
 * 
 * Prerequisites: status code set, headers given, body if wanted set
 */
int
restconf_reply_send(void  *req0,
		    int    code,
		    cbuf  *cb)
{
    evhtp_request_t    *req = (evhtp_request_t *)req0;
    int                 retval = -1;
    evhtp_connection_t *conn;
    struct evbuffer    *eb = NULL;
    const char *reason_phrase;
    
    req->status = code;
    if ((reason_phrase = restconf_code2reason(code)) == NULL)
	reason_phrase="";
    if (restconf_reply_header(req, "Status", "%d %s", code, reason_phrase) < 0)
	goto done;
#if 1    /* Optional? */
    if ((conn = evhtp_request_get_connection(req)) == NULL){
	clicon_err(OE_DAEMON, EFAULT, "evhtp_request_get_connection");
	goto done;
    }
    htp_sslutil_add_xheaders(req->headers_out, conn->ssl, HTP_SSLUTILS_XHDR_ALL);
#endif

    /* If body, add a content-length header */
    if (cb != NULL && cbuf_len(cb))
	if (restconf_reply_header(req, "Content-Length", "%d", cbuf_len(cb)) < 0)
	    goto done;

    /* create evbuffer* : bufferevent_write_buffer/ drain, 
       ie send everything , except body */
    evhtp_send_reply_start(req, req->status); 

    /* Write a body if cbuf is nonzero */
    if (cb != NULL && cbuf_len(cb)){

	/* Suboptimal, copy from cbuf to evbuffer */
	if ((eb = evbuffer_new()) == NULL){
	    clicon_err(OE_CFG, errno, "evbuffer_new");
	    goto done;
	}
	if (evbuffer_add(eb, cbuf_get(cb), cbuf_len(cb)) < 0){
	    clicon_err(OE_CFG, errno, "evbuffer_add");
	    goto done;
	}
	evhtp_send_reply_body(req, eb); /* conn->bev = eb, body is different */
    }
    evhtp_send_reply_end(req);      /* just flag finished */
    retval = 0;
 done:
    if (eb)
	evhtp_safe_free(eb, evbuffer_free);
    return retval;
}

/*! get input data
 * @param[in]  req        Fastcgi request handle
 * @note Pulls up an event buffer and then copies it to a cbuf. This is not efficient.
 */
cbuf *
restconf_get_indata(void *req0)
{
    evhtp_request_t *req = (evhtp_request_t *)req0;    
    cbuf            *cb = NULL;
    
    if ((cb = cbuf_new()) == NULL)
	return NULL;
    if (evbuffer_get_length(req->buffer_in))
	cprintf(cb, "%s", evbuffer_pullup(req->buffer_in, -1));
    return cb;
}
