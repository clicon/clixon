/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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
 * See draft-ietf-netconf-restconf-17.txt [draft]

 * sudo apt-get install libfcgi-dev
 * gcc -o fastcgi fastcgi.c -lfcgi

 * sudo su -c "/www-data/clixon_restconf -Df /usr/local/etc/routing.conf " -s /bin/sh www-data

 * This is the interface:
 * api/data/profile=<name>/metric=<name> PUT data:enable=<flag>
 * api/test
   +----------------------------+--------------------------------------+
   | 100 Continue               | POST accepted, 201 should follow     |
   | 200 OK                     | Success with response message-body   |
   | 201 Created                | POST to create a resource success    |
   | 204 No Content             | Success without response message-    |
   |                            | body                                 |
   | 304 Not Modified           | Conditional operation not done       |
   | 400 Bad Request            | Invalid request message              |
   | 401 Unauthorized           | Client cannot be authenticated       |
   | 403 Forbidden              | Access to resource denied            |
   | 404 Not Found              | Resource target or resource node not |
   |                            | found                                |
   | 405 Method Not Allowed     | Method not allowed for target        |
   |                            | resource                             |
   | 409 Conflict               | Resource or lock in use              |
   | 412 Precondition Failed    | Conditional method is false          |
   | 413 Request Entity Too     | too-big error                        |
   | Large                      |                                      |
   | 414 Request-URI Too Large  | too-big error                        |
   | 415 Unsupported Media Type | non RESTCONF media type              |
   | 500 Internal Server Error  | operation-failed                     |
   | 501 Not Implemented        | unknown-operation                    |
   | 503 Service Unavailable    | Recoverable server error             |
   +----------------------------+--------------------------------------+
Mapping netconf error-tag -> status code
                 +-------------------------+-------------+
                 | <error&#8209;tag>       | status code |
                 +-------------------------+-------------+
                 | in-use                  | 409         |
                 | invalid-value           | 400         |
                 | too-big                 | 413         |
                 | missing-attribute       | 400         |
                 | bad-attribute           | 400         |
                 | unknown-attribute       | 400         |
                 | bad-element             | 400         |
                 | unknown-element         | 400         |
                 | unknown-namespace       | 400         |
                 | access-denied           | 403         |
                 | lock-denied             | 409         |
                 | resource-denied         | 409         |
                 | rollback-failed         | 500         |
                 | data-exists             | 409         |
                 | data-missing            | 409         |
                 | operation-not-supported | 501         |
                 | operation-failed        | 500         |
                 | partial-operation       | 500         |
                 | malformed-message       | 400         |
                 +-------------------------+-------------+

 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>
#include <assert.h>
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
#include "restconf_methods.h"

/*! REST OPTIONS method
 * According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @code
 *  curl -G http://localhost/restconf/data/interfaces/interface=eth0
 * @endcode                     
 * Minimal support: 
 * 200 OK
 * Allow: HEAD,GET,PUT,DELETE,OPTIONS              
 */
int
api_data_options(clicon_handle h,
		 FCGX_Request *r)
{
    clicon_debug(1, "%s", __FUNCTION__);
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Allow: OPTIONS,HEAD,GET,POST,PUT,DELETE\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    return 0;
}

/*! Generic GET (both HEAD and GET)
 */
static int
api_data_get_gen(clicon_handle h,
		 FCGX_Request *r,
		 cvec         *pcvec,
		 int           pi,
		 cvec         *qvec,
		 int           head)
{
    int        retval = -1;
    cg_var    *cv;
    char      *val;
    char      *v;
    int        i;
    cbuf      *path = NULL;
    cbuf      *path1 = NULL;
    cbuf      *cbx = NULL;
    cxobj    **vec = NULL;
    yang_spec *yspec;
    yang_stmt *y = NULL;
    yang_stmt *ykey;
    char      *name;
    cvec      *cvk = NULL; /* vector of index keys */
    cg_var    *cvi;
    cxobj     *xret = NULL;

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
	    assert(y!=NULL);
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
    if (clicon_rpc_get_config(h, "running", cbuf_get(path), &xret) < 0){
	notfound(r);
	goto done;
    }
    {
	cbuf *cb = cbuf_new();
	clicon_xml2cbuf(cb, xret, 0, 0);
	clicon_debug(1, "%s xret:%s", __FUNCTION__, cbuf_get(cb));
	cbuf_free(cb);
    }
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: application/yang.data+json\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    if (head)
	goto ok;
    clicon_debug(1, "%s name:%s child:%d", __FUNCTION__, xml_name(xret), xml_child_nr(xret));
    vec = xml_childvec_get(xret);
    clicon_debug(1, "%s xretnr:%d", __FUNCTION__, xml_child_nr(xret));
    if (xml2json_cbuf_vec(cbx, vec, xml_child_nr(xret), 0) < 0)
	goto done;
    clicon_debug(1, "%s cbuf:%s", __FUNCTION__, cbuf_get(cbx));
    FCGX_FPrintF(r->out, "%s", cbx?cbuf_get(cbx):"");
    FCGX_FPrintF(r->out, "\r\n\r\n");
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (cbx)
        cbuf_free(cbx);
    if (path)
	cbuf_free(path);
    if (path1)
	cbuf_free(path1);
    if (xret)
	xml_free(xret);
    return retval;
}

/*! REST HEAD method
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
   The HEAD method is sent by the client to retrieve just the header fields 
   that would be returned for the comparable GET method, without the 
   response message-body. 
 * Relation to netconf: none                        
 */
int
api_data_head(clicon_handle h,
	     FCGX_Request *r,
             cvec         *pcvec,
             int           pi,
             cvec         *qvec)
{
    return api_data_get_gen(h, r, pcvec, pi, qvec, 1);
}

/*! REST GET method
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
 * Netconf: <get-config>, <get>                        
 */
int
api_data_get(clicon_handle h,
	     FCGX_Request *r,
             cvec         *pcvec,
             int           pi,
             cvec         *qvec)
{
    return api_data_get_gen(h, r, pcvec, pi, qvec, 0);
}

/*! Generic edit-config method: PUT/POST/PATCH
 */
static int
api_data_edit(clicon_handle h,
	      FCGX_Request *r, 
	      char         *api_path, 
	      cvec         *pcvec, 
	      int           pi,
	      cvec         *qvec, 
	      char         *data,
	      enum operation_type operation)
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
    cprintf(cbx, "<config>");
    x = NULL;
    while ((x = xml_child_each(xdata, x, -1)) != NULL) {
	if (clicon_xml2cbuf(cbx, x, 0, 0) < 0)
	    goto done;	
    }
    cprintf(cbx, "</config>");
    clicon_debug(1, "%s cbx: %s api_path:%s",__FUNCTION__, cbuf_get(cbx), api_path);
    if (clicon_rpc_edit_config(h, "candidate", 
			       operation,
			       api_path,
			       cbuf_get(cbx)) < 0){
	notfound(r);
	goto done;
    }
    
    if (clicon_rpc_commit(h) < 0)
	goto done;
    FCGX_SetExitStatus(201, r->out); /* Created */
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (xdata)
	xml_free(xdata);
     if (cbx)
	cbuf_free(cbx); 
   return retval;
}


/*! REST POST  method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 POST:
   If the POST method succeeds, a "201 Created" status-line is returned
   and there is no response message-body.  A "Location" header
   identifying the child resource that was created MUST be present in
   the response in this case.

   If the data resource already exists, then the POST request MUST fail
   and a "409 Conflict" status-line MUST be returned.
 * Netconf:  <edit-config> (nc:operation="create") | invoke an RPC operation        
 */
int
api_data_post(clicon_handle h,
	      FCGX_Request *r, 
	      char         *api_path, 
	      cvec         *pcvec, 
	      int           pi,
	      cvec         *qvec, 
	      char         *data)
{
    return api_data_edit(h, r, api_path, pcvec, pi, qvec, data, OP_CREATE);
}

/*! Generic REST PUT  method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * Example:
      curl -X PUT -d {\"enabled\":\"false\"} http://127.0.0.1/restconf/data/interfaces/interface=eth1
 *
 PUT:
  if the PUT request creates a new resource,
   a "201 Created" status-line is returned.  If an existing resource is
   modified, a "204 No Content" status-line is returned.

 * Netconf:  <edit-config> (nc:operation="create/replace")
 */
int
api_data_put(clicon_handle h,
	     FCGX_Request *r, 
	     char         *api_path, 
	     cvec         *pcvec, 
	     int           pi,
	     cvec         *qvec, 
	     char         *data)
{
    /* XXX: OP_CREATE? */
    return api_data_edit(h, r, api_path, pcvec, pi, qvec, data, OP_REPLACE);
}

/*! Generic REST PATCH  method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * Netconf:  <edit-config> (nc:operation="merge")      
 */
int
api_data_patch(clicon_handle h,
	      FCGX_Request *r, 
	      char         *api_path, 
	      cvec         *pcvec, 
	      int           pi,
	      cvec         *qvec, 
	      char         *data)
{
    return api_data_edit(h, r, api_path, pcvec, pi, qvec, data, OP_MERGE);
}

/*! Generic REST DELETE method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pi     Offset, where path starts
 * Example:
 *  curl -X DELETE http://127.0.0.1/restconf/data/interfaces/interface=eth0
 * Netconf:  <edit-config> (nc:operation="delete")      
 */
int
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
    if (clicon_rpc_edit_config(h, "candidate", 
			       OP_DELETE, 
			       api_path,
			       "<config/>") < 0){
	notfound(r);
	goto done;
    }
    if (clicon_rpc_commit(h) < 0)
	goto done;
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
   return retval;
}

