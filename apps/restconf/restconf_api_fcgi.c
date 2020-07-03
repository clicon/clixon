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
  
  * Concrete functions for FCGI of the
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

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include <fcgiapp.h> /* Need to be after clixon_xml-h due to attribute format */

#include "restconf_lib.h"
#include "restconf_api.h"  /* Virtual api */


/*! HTTP headers done, if there is a message body coming next
 * @param[in]  req   Fastcgi request handle
 * @retval     body  Handle for body handling (in fcgi same as req)
 * 
 * HTTP-message = start-line *( header-field CRLF ) CRLF [ message-body ]
 * @see eg RFC 7230
 * XXX may be unecessary (or body start or something)
 */
FCGX_Request *
restconf_reply_body_start(void  *req0)
{
    FCGX_Request *req = (FCGX_Request *)req0;

    FCGX_FPrintF(req->out, "\r\n");
    return req;
}

/*! Add HTTP header field name and value to reply, fcgi specific
 * @param[in]  req   Fastcgi request handle
 * @param[in]  name  HTTP header field name
 * @param[in]  vfmt  HTTP header field value format string w variable parameter
 * @see eg RFC 7230
 */
int
restconf_reply_header(void       *req0,
		      const char *name,
		      const char *vfmt,
		      ...)
{
    FCGX_Request *req = (FCGX_Request *)req0;
    int        retval = -1;
    size_t     vlen;
    char      *value = NULL;
    va_list    ap;
    
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
    FCGX_FPrintF(req->out, "%s: %s\r\n", name, value); 
    retval = 0;
 done:
    if (value)
	free(value);
    return retval;
}

/*! Add HTTP message body to reply, fcgi specific
 * @param[in]     req         Fastcgi request handle
 * @param[in,out] content_len This is for Content-Length header
 * @param[in]     bfmt        HTTP message body format string w variable parameter
 * @see eg RFC 7230
 */
int
restconf_reply_body_add(void     *req0,
			size_t   *content_len,
			char     *bfmt,
			...)
{
    FCGX_Request *req = (FCGX_Request *)req0;
    int     retval = -1;
    size_t  sz;
    size_t  blen;
    char   *body = NULL;
    va_list ap;

    if (req == NULL || bfmt == NULL){
	clicon_err(OE_CFG, EINVAL, "req or body is NULL");
	return -1;
    }
    va_start(ap, bfmt);
    blen = vsnprintf(NULL, 0, bfmt, ap);
    va_end(ap);
    /* allocate body string exactly fitting */
    if ((body = malloc(blen+1)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    /* second round: compute actual body */
    va_start(ap, bfmt);    
    if (vsnprintf(body, blen+1, bfmt, ap) < 0){
	clicon_err(OE_UNIX, errno, "vsnprintf");
	va_end(ap);
	goto done;
    }
    va_end(ap);
    FCGX_FPrintF(req->out, "%s", body); 
    /* Increment in/out Content-Length parameter */
    if (content_len){
	sz = strlen(body);
	*content_len += sz;
    }
    retval = 0;
 done:
    if (body)
	free(body);
    return retval;
}

/*! Send HTTP reply with potential message body
 * @param[in]     req   Fastcgi request handle
 * @param[in]     code  Status code
 * @param[in]     cb    Body as a cbuf if non-NULL
 * 
 * Prerequisites: status code set, headers given, body if wanted set
 */
int
restconf_reply_send(void  *req0,
		    int    code,
		    cbuf  *cb)
{
    FCGX_Request *req = (FCGX_Request *)req0;
    int           retval = -1;
    const char *reason_phrase;

    FCGX_SetExitStatus(code, req->out);
    if ((reason_phrase = restconf_code2reason(code)) == NULL)
	reason_phrase="";
    if (restconf_reply_header(req, "Status", "%d %s", code, reason_phrase) < 0)
	goto done;
    FCGX_FPrintF(req->out, "\r\n");
    /* Write a body if cbuf is nonzero */
    if (cb != NULL && cbuf_len(cb)){
	FCGX_FPrintF(req->out, "%s", cbuf_get(cb));
	FCGX_FPrintF(req->out, "\r\n");
    }
    FCGX_FFlush(req->out); /* Is this only for notification ? */
    retval = 0;
 done:
    return retval;
}

/*!
 * @param[in]  req        Fastcgi request handle
 */
cbuf *
restconf_get_indata(void *req0)
{
    FCGX_Request *req = (FCGX_Request *)req0;
    int   c;
    cbuf *cb = NULL;

    if ((cb = cbuf_new()) == NULL)
	return NULL;
    while ((c = FCGX_GetChar(req->in)) != -1)
	cprintf(cb, "%c", c);
    return cb;
}
