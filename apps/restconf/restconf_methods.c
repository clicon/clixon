/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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
 * See rfc8040

 * sudo apt-get install libfcgi-dev
 * gcc -o fastcgi fastcgi.c -lfcgi

 * sudo su -c "/www-data/clixon_restconf -D 1 f /usr/local/etc/example.xml " -s /bin/sh www-data

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

 * "api-path" is "URI-encoded path expression" definition in RFC8040 3.5.3
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>
#include <assert.h>
#include <time.h>
#include <signal.h>
#include <limits.h>
#include <sys/time.h>
#include <sys/wait.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include <fcgiapp.h> /* Need to be after clixon_xml-h due to attribute format */

#include "restconf_lib.h"
#include "restconf_methods.h"

/*! REST OPTIONS method
 * According to restconf
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
 * According to restconf 
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML
 * @param[in]  head   If 1 is HEAD, otherwise GET
 * @code
 *  curl -G http://localhost/restconf/data/interfaces/interface=eth0
 * @endcode                                     
 * See RFC8040 Sec 4.2 and 4.3
 * XXX: cant find a way to use Accept request field to choose Content-Type  
 *      I would like to support both xml and json.           
 * Request may contain                                        
 *     Accept: application/yang.data+json,application/yang.data+xml   
 * Response contains one of:                           
 *     Content-Type: application/yang-data+xml    
 *     Content-Type: application/yang-data+json  
 * NOTE: If a retrieval request for a data resource representing a YANG leaf-
 * list or list object identifies more than one instance, and XML
 * encoding is used in the response, then an error response containing a
 * "400 Bad Request" status-line MUST be returned by the server.
 * Netconf: <get-config>, <get>                        
 */
static int
api_data_get2(clicon_handle h,
	      FCGX_Request *r,
	      cvec         *pcvec,
	      int           pi,
	      cvec         *qvec,
	      int           pretty,
	      int           use_xml,
	      int           head)
{
    int        retval = -1;
    cbuf      *cbpath = NULL;
    char      *path;
    cbuf      *cbx = NULL;
    yang_stmt *yspec;
    cxobj     *xret = NULL;
    cxobj     *xerr = NULL; /* malloced */
    cxobj     *xe = NULL;
    cxobj    **xvec = NULL;
    size_t     xlen;
    int        i;
    cxobj     *x;
    int        ret;
    
    clicon_debug(1, "%s", __FUNCTION__);
    yspec = clicon_dbspec_yang(h);
    if ((cbpath = cbuf_new()) == NULL)
        goto done;
    cprintf(cbpath, "/");
    /* We know "data" is element pi-1 */
    if ((ret = api_path2xpath(yspec, pcvec, pi, cbpath)) < 0)
	goto done;
    if (ret == 0){
	if (netconf_operation_failed_xml(&xerr, "protocol", clicon_err_reason) < 0)
	    goto done;
	clicon_err_reset();
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    path = cbuf_get(cbpath);
    clicon_debug(1, "%s path:%s", __FUNCTION__, path);
    if (clicon_rpc_get(h, path, &xret) < 0){
	if (netconf_operation_failed_xml(&xerr, "protocol", clicon_err_reason) < 0)
	    goto done;
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    if (xml_apply(xret, CX_ELMNT, xml_spec_populate, yspec) < 0)
	goto done;
    /* We get return via netconf which is complete tree from root 
     * We need to cut that tree to only the object.
     */
#if 0 /* DEBUG */
    if (debug){
	cbuf *cb = cbuf_new();
	clicon_xml2cbuf(cb, xret, 0, 0);
	clicon_debug(1, "%s xret:%s", __FUNCTION__, cbuf_get(cb));
	cbuf_free(cb);
    }
#endif
    /* Check if error return  */
    if ((xe = xpath_first(xret, "//rpc-error")) != NULL){
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* Normal return, no error */
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    if (head){
	FCGX_SetExitStatus(200, r->out); /* OK */
	FCGX_FPrintF(r->out, "Content-Type: application/yang-data+%s\r\n", use_xml?"xml":"json");
	FCGX_FPrintF(r->out, "\r\n");
	goto ok;
    }
    if (path==NULL || strcmp(path,"/")==0){ /* Special case: data root */
	if (use_xml){
	    if (clicon_xml2cbuf(cbx, xret, 0, pretty) < 0) /* Dont print top object?  */
		goto done;
	}
	else{
	    if (xml2json_cbuf(cbx, xret, pretty) < 0)
		goto done;
	}
    }
    else{
	if (xpath_vec(xret, "%s", &xvec, &xlen, path) < 0){
	    if (netconf_operation_failed_xml(&xerr, "application", clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
	if (use_xml){
	    for (i=0; i<xlen; i++){
		char *prefix, *namespace;
		x = xvec[i];
		/* Some complexities in grafting namespace in existing trees to new */
		prefix = xml_prefix(x);
		if (xml_find_type_value(x, prefix, "xmlns", CX_ATTR) == NULL){
		    if (xml2ns(x, prefix, &namespace) < 0)
			goto done;
		    if (namespace && xmlns_set(x, prefix, namespace) < 0)
			goto done;
		}
		if (clicon_xml2cbuf(cbx, x, 0, pretty) < 0) /* Dont print top object?  */
		    goto done;
	    }
	}
	else{
	    /* In: <x xmlns="urn:example:clixon">0</x>
	     * Out: {"example:x": {"0"}}
	     */
	    if (xml2json_cbuf_vec(cbx, xvec, xlen, pretty) < 0)
		goto done;
	}
    }
    clicon_debug(1, "%s cbuf:%s", __FUNCTION__, cbuf_get(cbx));
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: application/yang-data+%s\r\n", use_xml?"xml":"json");
    FCGX_FPrintF(r->out, "\r\n");
    FCGX_FPrintF(r->out, "%s", cbx?cbuf_get(cbx):"");
    FCGX_FPrintF(r->out, "\r\n\r\n");
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (cbx)
        cbuf_free(cbx);
    if (cbpath)
	cbuf_free(cbpath);
    if (xret)
	xml_free(xret);
    if (xerr)
	xml_free(xerr);
    if (xvec)
	free(xvec);
    return retval;
}

/*! REST HEAD method
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML
 *
 * The HEAD method is sent by the client to retrieve just the header fields 
 * that would be returned for the comparable GET method, without the 
 * response message-body. 
 * Relation to netconf: none                        
 */
int
api_data_head(clicon_handle h,
	      FCGX_Request *r,
	      cvec         *pcvec,
	      int           pi,
	      cvec         *qvec,
	      int           pretty,
	      int           use_xml)
{
    return api_data_get2(h, r, pcvec, pi, qvec, pretty, use_xml, 1);
}

/*! REST GET method
 * According to restconf 
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML
 * @code
 *  curl -G http://localhost/restconf/data/interfaces/interface=eth0
 * @endcode                                     
 * XXX: cant find a way to use Accept request field to choose Content-Type  
 *      I would like to support both xml and json.           
 * Request may contain                                        
 *     Accept: application/yang.data+json,application/yang.data+xml   
 * Response contains one of:                           
 *     Content-Type: application/yang-data+xml    
 *     Content-Type: application/yang-data+json  
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
             cvec         *qvec,
	     int           pretty,
	     int           use_xml)
{
    return api_data_get2(h, r, pcvec, pi, qvec, pretty, use_xml, 0);
}

/*! Generic REST POST  method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML for output data
 * @param[in]  parse_xml Set to 0 for JSON and 1 for XML for input data

 * @note restconf POST is mapped to edit-config create. 
 * See RFC8040 Sec 4.4.1

 POST:
   target resource type is datastore --> create a top-level resource
   target resource type is  data resource --> create child resource

   The message-body MUST contain exactly one instance of the
   expected data resource.  The data model for the child tree is the
   subtree, as defined by YANG for the child resource.

   If the POST method succeeds, a "201 Created" status-line is returned
   and there is no response message-body.  A "Location" header
   identifying the child resource that was created MUST be present in
   the response in this case.

   If the data resource already exists, then the POST request MUST fail
   and a "409 Conflict" status-line MUST be returned.
 * Netconf:  <edit-config> (nc:operation="create") | invoke an RPC operation        * @example
 */
int
api_data_post(clicon_handle h,
	      FCGX_Request *r, 
	      char         *api_path, 
	      cvec         *pcvec, 
	      int           pi,
	      cvec         *qvec, 
	      char         *data,
	      int           pretty,
	      int           use_xml,
    	      int           parse_xml)
{
    int        retval = -1;
    enum operation_type op = OP_CREATE;
    int        i;
    cxobj     *xdata = NULL;
    cbuf      *cbx = NULL;
    cxobj     *xtop = NULL; /* xpath root */
    cxobj     *xbot = NULL;
    cxobj     *x;
    yang_stmt *y = NULL;
    yang_stmt *yspec;
    cxobj     *xa;
    cxobj     *xret = NULL;
    cxobj     *xretcom = NULL; /* return from commit */
    cxobj     *xretdis = NULL; /* return from discard-changes */
    cxobj     *xerr = NULL; /* malloced must be freed */
    cxobj     *xe;            /* dont free */
    char      *username;
    int        ret;
    
    clicon_debug(1, "%s api_path:\"%s\" json:\"%s\"",
		 __FUNCTION__, 
		 api_path, data);
    if ((yspec = clicon_dbspec_yang(h)) == NULL){
	clicon_err(OE_FATAL, 0, "No DB_SPEC");
	goto done;
    }
    for (i=0; i<pi; i++)
	api_path = index(api_path+1, '/');
    /* Create config top-of-tree */
    if ((xtop = xml_new("config", NULL, NULL)) == NULL)
	goto done;
    /* Translate api_path to xtop/xbot */
    xbot = xtop;
    if (api_path){
	if ((ret = api_path2xml(api_path, yspec, xtop, YC_DATANODE, 1, &xbot, &y)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    clicon_err_reset();
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    /* Parse input data as json or xml into xml */
    if (parse_xml){
	if (xml_parse_string(data, NULL, &xdata) < 0){
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    else if (json_parse_str(data, &xdata) < 0){
	if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
	    goto done;
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* 4.4.1: The message-body MUST contain exactly one instance of the
     * expected data resource. 
     */
    if (xml_child_nr(xdata) != 1){
	if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
	    goto done;
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    x = xml_child_i(xdata,0);
    /* Add operation (create/replace) as attribute */
    if ((xa = xml_new("operation", x, NULL)) == NULL)
	goto done;
    xml_type_set(xa, CX_ATTR);
    if (xml_value_set(xa, xml_operation2str(op)) < 0)
	goto done;
    /* Replace xbot with x, ie bottom of api-path with data */
    if (xml_addsub(xbot, x) < 0)
	goto done;
    if (!parse_xml){ /* If JSON, translate namespace from module:name to xmlns=uri */
	if (json2xml_ns(yspec, x, &xerr) < 0)
	    goto done;
	if (xerr){
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    /* Create text buffer for transfer to backend */
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    /* For internal XML protocol: add username attribute for access control
     */
    username = clicon_username_get(h);
    cprintf(cbx, "<rpc username=\"%s\">", username?username:"");
    cprintf(cbx, "<edit-config><target><candidate /></target>");
    cprintf(cbx, "<default-operation>none</default-operation>");
    if (clicon_xml2cbuf(cbx, xtop, 0, 0) < 0)
	goto done;
    cprintf(cbx, "</edit-config></rpc>");
    clicon_debug(1, "%s xml: %s api_path:%s",__FUNCTION__, cbuf_get(cbx), api_path);
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xret, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xret, "//rpc-error")) != NULL){
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* Assume this is validation failed since commit includes validate */
    cbuf_reset(cbx);
    /* commit/discard should be done automaticaly by the system, therefore
     * recovery user is used here (edit-config but not commit may be permitted
     by NACM */
    cprintf(cbx, "<rpc username=\"%s\">", NACM_RECOVERY_USER);
    cprintf(cbx, "<commit/></rpc>");
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xretcom, "//rpc-error")) != NULL){
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", username?username:"");
	cprintf(cbx, "<discard-changes/></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretdis, NULL) < 0)
	    goto done;
	/* log errors from discard, but ignore */
	if ((xpath_first(xretdis, "//rpc-error")) != NULL)
	    clicon_log(LOG_WARNING, "%s: discard-changes failed which may lead candidate in an inconsistent state", __FUNCTION__);
	if (api_return_err(h, r, xe, pretty, use_xml) < 0) /* Use original xe */
	    goto done;
	goto ok;
    }
    if (xretcom){ /* Clear: can be reused again below */
	xml_free(xretcom);
	xretcom = NULL;
    }
    if (if_feature(yspec, "ietf-netconf", "startup")){
	/* RFC8040 Sec 1.4:
	 * If the NETCONF server supports :startup, the RESTCONF server MUST
	 * automatically update the non-volatile startup configuration
	 * datastore, after the "running" datastore has been altered as a
	 * consequence of a RESTCONF edit operation.
	 */
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", NACM_RECOVERY_USER);
	cprintf(cbx, "<copy-config><source><running/></source><target><startup/></target></copy-config></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	    goto done;
	/* If copy-config failed, log and ignore (already committed) */
	if ((xe = xpath_first(xretcom, "//rpc-error")) != NULL){

	    clicon_log(LOG_WARNING, "%s: copy-config running->startup failed", __FUNCTION__);
	}
    }

    FCGX_SetExitStatus(201, r->out); /* Created */
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (xret)
	xml_free(xret);
    if (xerr)
	xml_free(xerr);
    if (xretcom)
	xml_free(xretcom);
    if (xretdis)
	xml_free(xretdis);
    if (xtop)
	xml_free(xtop);
    if (xdata)
	xml_free(xdata);
     if (cbx)
	cbuf_free(cbx); 
   return retval;
} /* api_data_post */


/*! Check matching keys
 *
 * @param[in] y        Yang statement, should be list or leaf-list
 * @param[in] xdata    XML data tree
 * @param[in] xapipath XML api-path tree
 * @retval    0        Yes, keys match
 * @retval    -1        No keys do not match
 * If the target resource represents a YANG leaf-list, then the PUT
 * method MUST NOT change the value of the leaf-list instance.
 *
 * If the target resource represents a YANG list instance, then the key
 * leaf values, in message-body representation, MUST be the same as the
 * key leaf values in the request URI.  The PUT method MUST NOT be used
 * to change the key leaf values for a data resource instance.
 */
static int
match_list_keys(yang_stmt *y,
		cxobj     *xdata,
		cxobj     *xapipath)
{
    int        retval = -1;
    cvec      *cvk = NULL; /* vector of index keys */
    cg_var    *cvi;
    char      *keyname;
    cxobj     *xkeya; /* xml key object in api-path */
    cxobj     *xkeyd; /* xml key object in data */
    char      *keya;
    char      *keyd;

    if (yang_keyword_get(y) != Y_LIST && yang_keyword_get(y) != Y_LEAF_LIST)
	goto done;
    cvk = yang_cvec_get(y); /* Use Y_LIST cache, see ys_populate_list() */
    cvi = NULL;
    while ((cvi = cvec_each(cvk, cvi)) != NULL) {
	keyname = cv_string_get(cvi);	    
	if ((xkeya = xml_find(xapipath, keyname)) == NULL)
	    goto done; /* No key in api-path */
	if ((keya = xml_body(xkeya)) == NULL)
	    goto done;
	if ((xkeyd = xml_find(xdata, keyname)) == NULL)
	    goto done; /* No key in data */
	if ((keyd = xml_body(xkeyd)) == NULL)
	    goto done;
	if (strcmp(keya, keyd) != 0)
	    goto done; /* keys dont match */
    }
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Generic REST PUT  method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML for output data
 * @param[in]  parse_xml Set to 0 for JSON and 1 for XML for input data

 * @note restconf PUT is mapped to edit-config replace. 
 * See RFC8040 Sec 4.5
 * @example
      curl -X PUT -d '{"enabled":"false"}' http://127.0.0.1/restconf/data/interfaces/interface=eth1
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
	     char         *api_path0, 
	     cvec         *pcvec, 
	     int           pi,
	     cvec         *qvec, 
	     char         *data,
	     int           pretty,
	     int           use_xml,
	     int           parse_xml)
{
    int        retval = -1;
    enum operation_type op = OP_REPLACE;
    int        i;
    cxobj     *xdata = NULL;
    cbuf      *cbx = NULL;
    cxobj     *xtop = NULL; /* xpath root */
    cxobj     *xbot = NULL;
    cxobj     *xparent;
    cxobj     *x;
    yang_stmt *y = NULL;
    yang_stmt *yp; /* yang parent */
    yang_stmt *yspec;
    cxobj     *xa;
    char      *api_path;
    cxobj     *xret = NULL;
    cxobj     *xretcom = NULL; /* return from commit */
    cxobj     *xretdis = NULL; /* return from discard-changes */
    cxobj     *xerr = NULL; /* malloced must be freed */
    cxobj     *xe;
    char      *username;
    int        ret;
    char      *namespace0;

    clicon_debug(1, "%s api_path:\"%s\" json:\"%s\"",
		 __FUNCTION__, api_path0, data);
    if ((yspec = clicon_dbspec_yang(h)) == NULL){
	clicon_err(OE_FATAL, 0, "No DB_SPEC");
	goto done;
    }
    api_path=api_path0;
    for (i=0; i<pi; i++)
	api_path = index(api_path+1, '/');
    /* Create config top-of-tree */
    if ((xtop = xml_new("config", NULL, NULL)) == NULL)
	goto done;
    /* Translate api_path to xtop/xbot */
    xbot = xtop;
    if (api_path){
	if ((ret = api_path2xml(api_path, yspec, xtop, YC_DATANODE, 1, &xbot, &y)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    clicon_err_reset();
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    /* Parse input data as json or xml into xml */
    if (parse_xml){
	if (xml_parse_string(data, NULL, &xdata) < 0){
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    else{
	if (json_parse_str(data, &xdata) < 0){
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    /* The message-body MUST contain exactly one instance of the
     * expected data resource. 
     */
    if (xml_child_nr(xdata) != 1){
	if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
	    goto done;
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    x = xml_child_i(xdata,0);
    if (!parse_xml){ /* If JSON, translate namespace from module:name to xmlns=uri */
	if (json2xml_ns(yspec, x, &xerr) < 0)
	    goto done;
	if (xerr){
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    
    /* Add operation (create/replace) as attribute */
    if ((xa = xml_new("operation", x, NULL)) == NULL)
	goto done;
    xml_type_set(xa, CX_ATTR);
    if (xml_value_set(xa, xml_operation2str(op)) < 0)
	goto done;
#if 0
    if (debug){
	cbuf *ccc=cbuf_new();
	if (clicon_xml2cbuf(ccc, xdata, 0, 0) < 0)
	    goto done;
	clicon_debug(1, "%s DATA:%s", __FUNCTION__, cbuf_get(ccc));
    }
#endif
    /* Replace xparent with x, ie bottom of api-path with data */	    
    if (api_path==NULL && strcmp(xml_name(x),"data")==0){
	if (xml_addsub(NULL, x) < 0)
	    goto done;
	if (xtop)
	    xml_free(xtop);
	xtop = x;
	xml_name_set(xtop, "config");
    }
    else {
	clicon_debug(1, "%s x:%s xbot:%s",__FUNCTION__, xml_name(x), xml_name(xbot));
	/* Check same symbol in api-path as data */	    
	if (strcmp(xml_name(x), xml_name(xbot))){
	    if (netconf_operation_failed_xml(&xerr, "protocol", "Not same symbol in api-path as data") < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
	/* If list or leaf-list, api-path keys must match data keys 
	 * There are two cases, either the object is the list element itself,
	 *   eg xpath:obj=a  data:<obj><key>b</key></obj>
	 * or the object is the key element:
	 *   eg xpath:obj=a/key  data:<key>b</key>
	 * That is why the conditional is somewhat hairy
	 */	    
	xparent = xml_parent(xbot);
	if (y){
	    yp = yang_parent_get(y);
	    if (((yang_keyword_get(y) == Y_LIST || yang_keyword_get(y) == Y_LEAF_LIST) &&
		 match_list_keys(y, x, xbot) < 0) ||
		(yp && yang_keyword_get(yp) == Y_LIST &&
		 match_list_keys(yp, xml_parent(x), xparent) < 0)){
		if (netconf_operation_failed_xml(&xerr, "protocol", "api-path keys do not match data keys") < 0)
		    goto done;
		if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		    goto done;
		}
		if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		    goto done;
		goto ok;
		
	    }
	}

	xml_purge(xbot);
	if (xml_addsub(xparent, x) < 0)
	    goto done;
	/* If we already have that default namespace, remove it in child */
	if ((xa = xml_find_type(x, NULL, "xmlns", CX_ATTR)) != NULL){
	    if (xml2ns(xparent, NULL, &namespace0) < 0)
		goto done;
	    /* Set xmlns="" default namespace attribute (if diff from default) */
	    if (strcmp(namespace0, xml_value(xa))==0)
		xml_purge(xa);
	}		
    }
    /* Create text buffer for transfer to backend */
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    /* For internal XML protocol: add username attribute for access control
     */
    username = clicon_username_get(h);
    cprintf(cbx, "<rpc username=\"%s\">", username?username:"");
    cprintf(cbx, "<edit-config><target><candidate /></target>");
    cprintf(cbx, "<default-operation>none</default-operation>");
    if (clicon_xml2cbuf(cbx, xtop, 0, 0) < 0)
	goto done;
    cprintf(cbx, "</edit-config></rpc>");
    clicon_debug(1, "%s xml: %s api_path:%s",__FUNCTION__, cbuf_get(cbx), api_path);
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xret, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xret, "//rpc-error")) != NULL){
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    cbuf_reset(cbx);
    /* commit/discard should be done automaticaly by the system, therefore
     * recovery user is used here (edit-config but not commit may be permitted
     by NACM */
    cprintf(cbx, "<rpc username=\"%s\">", NACM_RECOVERY_USER);
    cprintf(cbx, "<commit/></rpc>");
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xretcom, "//rpc-error")) != NULL){
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", username?username:"");
	cprintf(cbx, "<discard-changes/></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretdis, NULL) < 0)
	    goto done;
	/* log errors from discard, but ignore */
	if ((xpath_first(xretdis, "//rpc-error")) != NULL)
	    clicon_log(LOG_WARNING, "%s: discard-changes failed which may lead candidate in an inconsistent state", __FUNCTION__);
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    if (xretcom){ /* Clear: can be reused again below */
	xml_free(xretcom);
	xretcom = NULL;
    }
    if (if_feature(yspec, "ietf-netconf", "startup")){
	/* RFC8040 Sec 1.4:
	 * If the NETCONF server supports :startup, the RESTCONF server MUST
	 * automatically update the non-volatile startup configuration
	 * datastore, after the "running" datastore has been altered as a
	 * consequence of a RESTCONF edit operation.
	 */
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", NACM_RECOVERY_USER);
	cprintf(cbx, "<copy-config><source><running/></source><target><startup/></target></copy-config></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	    goto done;
	/* If copy-config failed, log and ignore (already committed) */
	if ((xe = xpath_first(xretcom, "//rpc-error")) != NULL){

	    clicon_log(LOG_WARNING, "%s: copy-config running->startup failed", __FUNCTION__);
	}
    }
    FCGX_SetExitStatus(201, r->out); /* Created */
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (xret)
	xml_free(xret);
    if (xerr)
	xml_free(xerr);
    if (xretcom)
	xml_free(xretcom);
    if (xretdis)
	xml_free(xretdis);
    if (xtop)
	xml_free(xtop);
    if (xdata)
	xml_free(xdata);
     if (cbx)
	cbuf_free(cbx); 
   return retval;
} /* api_data_put */

/*! Generic REST PATCH  method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * Netconf:  <edit-config> (nc:operation="merge")      
 * See RFC8040 Sec 4.6
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
    notimplemented(r);
    return 0;
}

/*! Generic REST DELETE method translated to edit-config
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pi     Offset, where path starts
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML
 * See RFC 8040 Sec 4.7
 * Example:
 *  curl -X DELETE http://127.0.0.1/restconf/data/interfaces/interface=eth0
 * Netconf:  <edit-config> (nc:operation="delete")      
 */
int
api_data_delete(clicon_handle h,
		FCGX_Request *r, 
		char         *api_path,
		int           pi,
		int           pretty,
		int           use_xml)
{
    int        retval = -1;
    int        i;
    cxobj     *xtop = NULL; /* xpath root */
    cxobj     *xbot = NULL;
    cxobj     *xa;
    cbuf      *cbx = NULL;
    yang_stmt *y = NULL;
    yang_stmt *yspec;
    enum operation_type op = OP_DELETE;
    cxobj     *xret = NULL;
    cxobj     *xretcom = NULL; /* return from commmit */
    cxobj     *xretdis = NULL; /* return from discard */
    cxobj     *xerr = NULL;
    char      *username;
    int        ret;
    cxobj     *xe; /* xml error, no free */

    clicon_debug(1, "%s api_path:%s", __FUNCTION__, api_path);
    if ((yspec = clicon_dbspec_yang(h)) == NULL){
	clicon_err(OE_FATAL, 0, "No DB_SPEC");
	goto done;
    }
    for (i=0; i<pi; i++)
	api_path = index(api_path+1, '/');
    /* Create config top-of-tree */
    if ((xtop = xml_new("config", NULL, NULL)) == NULL)
	goto done;
    xbot = xtop;
    if (api_path){
	if ((ret = api_path2xml(api_path, yspec, xtop, YC_DATANODE, 1, &xbot, &y)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    clicon_err_reset();
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    if ((xa = xml_new("operation", xbot, NULL)) == NULL)
	goto done;
    xml_type_set(xa, CX_ATTR);
    if (xml_value_set(xa, xml_operation2str(op)) < 0)
	goto done;
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    /* For internal XML protocol: add username attribute for access control
     */
    username = clicon_username_get(h);
    cprintf(cbx, "<rpc username=\"%s\">", username?username:"");
    cprintf(cbx, "<edit-config><target><candidate /></target>");
    cprintf(cbx, "<default-operation>none</default-operation>");
    if (clicon_xml2cbuf(cbx, xtop, 0, 0) < 0)
	goto done;
    cprintf(cbx, "</edit-config></rpc>");
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xret, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xret, "//rpc-error")) != NULL){
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* Assume this is validation failed since commit includes validate */
    cbuf_reset(cbx);
    /* commit/discard should be done automaticaly by the system, therefore
     * recovery user is used here (edit-config but not commit may be permitted
     by NACM */
    cprintf(cbx, "<rpc username=\"%s\">", NACM_RECOVERY_USER);
    cprintf(cbx, "<commit/></rpc>");
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xretcom, "//rpc-error")) != NULL){
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", NACM_RECOVERY_USER);
	cprintf(cbx, "<discard-changes/></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretdis, NULL) < 0)
	    goto done;
	/* log errors from discard, but ignore */
	if ((xpath_first(xretdis, "//rpc-error")) != NULL)
	    clicon_log(LOG_WARNING, "%s: discard-changes failed which may lead candidate in an inconsistent state", __FUNCTION__);
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    if (xretcom){ /* Clear: can be reused again below */
	xml_free(xretcom);
	xretcom = NULL;
    }
    if (if_feature(yspec, "ietf-netconf", "startup")){
	/* RFC8040 Sec 1.4:
	 * If the NETCONF server supports :startup, the RESTCONF server MUST
	 * automatically update the non-volatile startup configuration
	 * datastore, after the "running" datastore has been altered as a
	 * consequence of a RESTCONF edit operation.
	 */
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", NACM_RECOVERY_USER);
	cprintf(cbx, "<copy-config><source><running/></source><target><startup/></target></copy-config></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	    goto done;
	/* If copy-config failed, log and ignore (already committed) */
	if ((xe = xpath_first(xretcom, "//rpc-error")) != NULL){

	    clicon_log(LOG_WARNING, "%s: copy-config running->startup failed", __FUNCTION__);
	}
    }
    FCGX_SetExitStatus(201, r->out);
    FCGX_FPrintF(r->out, "Content-Type: text/plain\r\n");
    FCGX_FPrintF(r->out, "\r\n");
 ok:
    retval = 0;
 done:
    if (cbx)
	cbuf_free(cbx); 
    if (xret)
	xml_free(xret);
    if (xretcom)
	xml_free(xretcom);
    if (xretdis)
	xml_free(xretdis);
    if (xtop)
	xml_free(xtop);
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
   return retval;
}

/*! GET restconf/operations resource
 * @param[in]  h      Clixon handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  path   According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML
 *
 * @code
 *  curl -G http://localhost/restconf/operations
 * @endcode                                     
 * RFC8040 Sec 3.3.2:
 * This optional resource is a container that provides access to the
 * data-model-specific RPC operations supported by the server.  The
 * server MAY omit this resource if no data-model-specific RPC
 * operations are advertised.
 * From ietf-restconf.yang:
 * In XML, the YANG module namespace identifies the module:
 *      <system-restart xmlns='urn:ietf:params:xml:ns:yang:ietf-system'/>
 * In JSON, the YANG module name identifies the module:
 *       { 'ietf-system:system-restart' : [null] }
 */
int
api_operations_get(clicon_handle h,
		   FCGX_Request *r, 
		   char         *path, 
		   cvec         *pcvec, 
		   int           pi,
		   cvec         *qvec, 
		   char         *data,
		   int           pretty,
		   int           use_xml)
{
    int        retval = -1;
    yang_stmt *yspec;
    yang_stmt *ymod; /* yang module */
    yang_stmt *yc;
    char      *namespace;
    cbuf      *cbx = NULL;
    cxobj     *xt = NULL;
    int        i;
    
    clicon_debug(1, "%s", __FUNCTION__);
    yspec = clicon_dbspec_yang(h);
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    if (use_xml)
	cprintf(cbx, "<operations>");
    else
	cprintf(cbx, "{\"operations\": {");
    ymod = NULL;
    i = 0;
    while ((ymod = yn_each(yspec, ymod)) != NULL) {
	namespace = yang_find_mynamespace(ymod);
	yc = NULL; 
	while ((yc = yn_each(ymod, yc)) != NULL) {
	    if (yang_keyword_get(yc) != Y_RPC)
		continue;
	    if (use_xml)
		cprintf(cbx, "<%s xmlns=\"%s\"/>", yang_argument_get(yc), namespace);
	    else{
		if (i++)
		    cprintf(cbx, ",");
		cprintf(cbx, "\"%s:%s\": null", yang_argument_get(ymod), yang_argument_get(yc));
	    }
	}
    }
    if (use_xml)
	cprintf(cbx, "</operations>");
    else
	cprintf(cbx, "}}");
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: application/yang-data+%s\r\n", use_xml?"xml":"json");
    FCGX_FPrintF(r->out, "\r\n");
    FCGX_FPrintF(r->out, "%s", cbx?cbuf_get(cbx):"");
    FCGX_FPrintF(r->out, "\r\n\r\n");
    // ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (cbx)
        cbuf_free(cbx);
    if (xt)
	xml_free(xt);
    return retval;
}

/*! Handle input data to api_operations_post 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  data   Stream input data
 * @param[in]  yspec  Yang top-level specification 
 * @param[in]  yrpc   Yang rpc spec
 * @param[in]  xrpc   XML pointer to rpc method
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML for output data
 * @param[in]  parse_xml Set to 0 for JSON and 1 for XML for input data
 * @retval     1      OK
 * @retval     0      Fail, Error message sent
 * @retval    -1      Fatal error, clicon_err called
 *
 * RFC8040 3.6.1
 *  If the "rpc" or "action" statement has an "input" section, then
 *  instances of these input parameters are encoded in the module
 *  namespace where the "rpc" or "action" statement is defined, in an XML
 *  element or JSON object named "input", which is in the module
 *  namespace where the "rpc" or "action" statement is defined.
 * (Any other input is assumed as error.)
 */
static int
api_operations_post_input(clicon_handle h,
			  FCGX_Request *r, 
			  char         *data,
			  yang_stmt    *yspec,
			  yang_stmt    *yrpc,
			  cxobj        *xrpc,
			  int           pretty,
			  int           use_xml,
			  int           parse_xml)
{
    int        retval = -1;
    cxobj     *xdata = NULL;
    cxobj     *xerr = NULL; /* malloced must be freed */
    cxobj     *xe;
    cxobj     *xinput;
    cxobj     *x;
    cbuf      *cbret = NULL;

    clicon_debug(1, "%s %s", __FUNCTION__, data);
    if ((cbret = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, 0, "cbuf_new");
	goto done;
    }
    /* Parse input data as json or xml into xml */
    if (parse_xml){
	if (xml_parse_string(data, yspec, &xdata) < 0){
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto fail;
	}
    }
    else { /* JSON */
	if (json_parse_str(data, &xdata) < 0){
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto fail;
	}
	/* Special case for JSON: It looks like: <top><module:input>
	 * Need to translate to <top><input xmlns="">
	 */
	if (json2xml_ns(yspec, xdata, &xerr) < 0)
	    goto done;
	if (xerr){
	    if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto fail;
	}
    }
    xml_name_set(xdata, "data");
    /* Here xdata is: 
     * <data><input xmlns="urn:example:clixon">...</input></data>
     */
#if 1
    if (debug){
	cbuf *ccc=cbuf_new();
	if (clicon_xml2cbuf(ccc, xdata, 0, 0) < 0)
	    goto done;
	clicon_debug(1, "%s DATA:%s", __FUNCTION__, cbuf_get(ccc));
    }
#endif
    /* Validate that exactly only <input> tag */
    if ((xinput = xml_child_i_type(xdata, 0, CX_ELMNT)) == NULL ||
	strcmp(xml_name(xinput),"input") != 0 ||
	xml_child_nr_type(xdata, CX_ELMNT) != 1){

	if (xml_child_nr_type(xdata, CX_ELMNT) == 0){
	    if (netconf_malformed_message_xml(&xerr, "restconf RPC does not have input statement") < 0)
		goto done;
	}
	else
	    if (netconf_malformed_message_xml(&xerr, "restconf RPC has malformed input statement (multiple or not called input)") < 0)
		goto done;	
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto fail;
    }
    //    clicon_debug(1, "%s input validation passed", __FUNCTION__);
    /* Add all input under <rpc>path */
    x = NULL;
    while ((x = xml_child_i_type(xinput, 0, CX_ELMNT)) != NULL)
	if (xml_addsub(xrpc, x) < 0) 	
	    goto done;
    /* Here xrpc is:  <myfn xmlns="uri"><x>42</x></myfn>
     */
    // ok:
    retval = 1;
 done:
    clicon_debug(1, "%s retval: %d", __FUNCTION__, retval);
    if (cbret)
	cbuf_free(cbret);
    if (xerr)
	xml_free(xerr);
    if (xdata)
	xml_free(xdata);
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! Handle output data to api_operations_post 
 * @param[in]  h        CLIXON handle
 * @param[in]  r        Fastcgi request handle
 * @param[in]  xret     XML reply messages from backend/handler
 * @param[in]  yspec    Yang top-level specification 
 * @param[in]  youtput  Yang rpc output specification
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML for output data
 * @param[out] xoutputp Restconf JSON/XML output
 * @retval     1        OK
 * @retval     0        Fail, Error message sent
 * @retval    -1        Fatal error, clicon_err called
 * xret should like: <top><rpc-reply><x xmlns="uri">0</x></rpc-reply></top>
 */
static int
api_operations_post_output(clicon_handle h,
			   FCGX_Request *r, 
			   cxobj        *xret,
			   yang_stmt    *yspec,
			   yang_stmt    *youtput,
			   char         *namespace,
			   int           pretty,
			   int           use_xml,
			   cxobj       **xoutputp)
    
{
    int        retval = -1;
    cxobj     *xoutput = NULL;
    cxobj     *xerr = NULL; /* assumed malloced, will be freed */
    cxobj     *xe;          /* just pointer */
    cxobj     *xa;          /* xml attribute (xmlns) */
    cxobj     *x;
    cxobj     *xok;
    cbuf      *cbret = NULL;
    int        isempty;
    
    //    clicon_debug(1, "%s", __FUNCTION__);
    if ((cbret = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, 0, "cbuf_new");
	goto done;
    }
    /* Validate that exactly only <rpc-reply> tag */
    if ((xoutput = xml_child_i_type(xret, 0, CX_ELMNT)) == NULL ||
	strcmp(xml_name(xoutput),"rpc-reply") != 0 ||
	xml_child_nr_type(xret, CX_ELMNT) != 1){
	if (netconf_malformed_message_xml(&xerr, "restconf RPC does not have single input") < 0)
	    goto done;	
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto fail;
    }
    /* xoutput should now look: <rpc-reply><x xmlns="uri">0</x></rpc-reply> */
    /* 9. Translate to restconf RPC data */
    xml_name_set(xoutput, "output");
    /* xoutput should now look: <output><x xmlns="uri">0</x></output> */
#if 1
    if (debug){
	cbuf *ccc=cbuf_new();
	if (clicon_xml2cbuf(ccc, xoutput, 0, 0) < 0)
	    goto done;
	clicon_debug(1, "%s XOUTPUT:%s", __FUNCTION__, cbuf_get(ccc));
    }
#endif

    /* Sanity check of outgoing XML 
     * For now, skip outgoing checks.
     * (1) Does not handle <ok/> properly
     * (2) Uncertain how validation errors should be logged/handled
     */
    if (youtput!=NULL){
	xml_spec_set(xoutput, youtput); /* needed for xml_spec_populate */
#if 0
	if (xml_apply(xoutput, CX_ELMNT, xml_spec_populate, yspec) < 0)
	    goto done;
	if ((ret = xml_yang_validate_all(xoutput, cbret)) < 0)
	    goto done;
	if (ret == 1 &&
	    (ret = xml_yang_validate_add(xoutput, cbret)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if (xml_parse_string(cbuf_get(cbret), yspec, &xerr) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, "rpc-reply/rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto fail;
	}
#endif
    }
    /* Special case, no yang output (single <ok/> - or empty body?)
     * RFC 7950 7.14.4
     * If the RPC operation invocation succeeded and no output parameters
     * are returned, the <rpc-reply> contains a single <ok/> element
     * RFC 8040 3.6.2
     * If the "rpc" statement has no "output" section, the response message
     * MUST NOT include a message-body and MUST send a "204 No Content"
     * status-line instead.
     */
    isempty = xml_child_nr_type(xoutput, CX_ELMNT) == 0 ||
	(xml_child_nr_type(xoutput, CX_ELMNT) == 1 &&
	 (xok = xml_child_i_type(xoutput, 0, CX_ELMNT)) != NULL &&
	 strcmp(xml_name(xok),"ok")==0);
    if (isempty) {
	/* Internal error - invalid output from rpc handler */
	FCGX_SetExitStatus(204, r->out); /* OK */
	FCGX_FPrintF(r->out, "Status: 204 No Content\r\n");
	FCGX_FPrintF(r->out, "\r\n");
	goto fail;
    }
    /* Clear namespace of parameters */
    x = NULL;
    while ((x = xml_child_each(xoutput, x, CX_ELMNT)) != NULL) {
	if ((xa = xml_find_type(x, NULL, "xmlns", CX_ATTR)) != NULL)
	    if (xml_purge(xa) < 0)
		goto done;
    }
    /* Set namespace on output */
    if (xmlns_set(xoutput, NULL, namespace) < 0)
	goto done;
    *xoutputp = xoutput;
    retval = 1;
 done:
    clicon_debug(1, "%s retval: %d", __FUNCTION__, retval);
    if (cbret)
	cbuf_free(cbret);
    if (xerr)
	xml_free(xerr);
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! REST operation POST method 
 * @param[in]  h      CLIXON handle
 * @param[in]  r      Fastcgi request handle
 * @param[in]  path   According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  use_xml Set to 0 for JSON and 1 for XML for output data
 * @param[in]  parse_xml Set to 0 for JSON and 1 for XML for input data
 * See RFC 8040 Sec 3.6 / 4.4.2
 * @note We map post to edit-config create. 
 *      POST {+restconf}/operations/<operation>
 * 1. Initialize
 * 2. Get rpc module and name from uri (oppath) and find yang spec
 * 3. Build xml tree with user and rpc: <rpc username="foo"><myfn xmlns="uri"/>
 * 4. Parse input data (arguments):
 *             JSON: {"example:input":{"x":0}}
 *             XML:  <input xmlns="uri"><x>0</x></input>
 * 5. Translate input args to Netconf RPC, add to xml tree:
 *             <rpc username="foo"><myfn xmlns="uri"><x>42</x></myfn></rpc>
 * 6. Validate outgoing RPC and fill in default values
 *  <rpc username="foo"><myfn xmlns="uri"><x>42</x><y>99</y></myfn></rpc>
 * 7. Send to RPC handler, either local or backend
 * 8. Receive reply from local/backend handler as Netconf RPC
 *       <rpc-reply><x xmlns="uri">0</x></rpc-reply>
 * 9. Translate to restconf RPC data:
 *             JSON: {"example:output":{"x":0}}
 *             XML:  <output xmlns="uri"><x>0</x></input>
 * 10. Validate and send reply to originator
 */
int
api_operations_post(clicon_handle h,
		    FCGX_Request *r, 
		    char         *path, 
		    cvec         *pcvec, 
		    int           pi,
		    cvec         *qvec, 
		    char         *data,
		    int           pretty,
		    int           use_xml,
		    int           parse_xml)
{
    int        retval = -1;
    int        i;
    char      *oppath = path;
    yang_stmt *yspec;
    yang_stmt *youtput = NULL;
    yang_stmt *yrpc = NULL;
    cxobj     *xret = NULL;
    cxobj     *xerr = NULL; /* malloced must be freed */
    cxobj     *xtop = NULL; /* xpath root */
    cxobj     *xbot = NULL;
    yang_stmt *y = NULL;
    cxobj     *xoutput = NULL;
    cxobj     *xa;
    cxobj     *xe;
    char      *username;
    cbuf      *cbret = NULL;
    int        ret = 0;
    char      *prefix = NULL;
    char      *id = NULL;
    yang_stmt *ys = NULL;
    char      *namespace = NULL;
    
    clicon_debug(1, "%s json:\"%s\" path:\"%s\"", __FUNCTION__, data, path);
    /* 1. Initialize */
    if ((yspec = clicon_dbspec_yang(h)) == NULL){
	clicon_err(OE_FATAL, 0, "No DB_SPEC");
	goto done;
    }
    if ((cbret = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, 0, "cbuf_new");
	goto done;
    }
    for (i=0; i<pi; i++)
	oppath = index(oppath+1, '/');
    if (oppath == NULL || strcmp(oppath,"/")==0){
	if (netconf_operation_failed_xml(&xerr, "protocol", "Operation name expected") < 0)
	    goto done;
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* 2. Get rpc module and name from uri (oppath) and find yang spec 
     *       POST {+restconf}/operations/<operation>
     *
     * The <operation> field identifies the module name and rpc identifier
     * string for the desired operation.
     */
    if (nodeid_split(oppath+1, &prefix, &id) < 0) /* +1 skip / */
	goto done;
    if ((ys = yang_find(yspec, Y_MODULE, prefix)) == NULL){
	if (netconf_operation_failed_xml(&xerr, "protocol", "yang module not found") < 0)
	    goto done;
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    if ((yrpc = yang_find(ys, Y_RPC, id)) == NULL){
	if (netconf_missing_element_xml(&xerr, "application", id, "RPC not defined") < 0)
	    goto done;
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* 3. Build xml tree with user and rpc: 
     * <rpc username="foo"><myfn xmlns="uri"/>
     */
    if ((xtop = xml_new("rpc", NULL, NULL)) == NULL)
	goto done;
    xbot = xtop;
    /* Here xtop is: <rpc/> */
    if ((username = clicon_username_get(h)) != NULL){
	if ((xa = xml_new("username", xtop, NULL)) == NULL)
	    goto done;
	xml_type_set(xa, CX_ATTR);
	if (xml_value_set(xa, username) < 0)
	    goto done;
	/* Here xtop is: <rpc username="foo"/> */
    }
    if ((ret = api_path2xml(oppath, yspec, xtop, YC_SCHEMANODE, 1, &xbot, &y)) < 0)
	goto done;
    if (ret == 0){ /* validation failed */
	if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
	    goto done;
	clicon_err_reset();
	if ((xe = xpath_first(xerr, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* Here xtop is: <rpc username="foo"><myfn xmlns="uri"/></rpc> 
     * xbot is <myfn xmlns="uri"/>
     * 4. Parse input data (arguments):
     *             JSON: {"example:input":{"x":0}}
     *             XML:  <input xmlns="uri"><x>0</x></input>
     */
    namespace = xml_find_type_value(xbot, NULL, "xmlns", CX_ATTR);
    clicon_debug(1, "%s : 4. Parse input data: %s", __FUNCTION__, data);
    if (data && strlen(data)){
	if ((ret = api_operations_post_input(h, r, data, yspec, yrpc, xbot,
					     pretty, use_xml, parse_xml)) < 0)
	    goto done;
	if (ret == 0)
	    goto ok;
    }
    /* Here xtop is: 
      <rpc username="foo"><myfn xmlns="uri"><x>42</x></myfn></rpc> */
#if 1
    if (debug){
	cbuf *ccc=cbuf_new();
	if (clicon_xml2cbuf(ccc, xtop, 0, 0) < 0)
	    goto done;
	clicon_debug(1, "%s 5. Translate input args: %s",
		     __FUNCTION__, cbuf_get(ccc));
    }
#endif
    /* 6. Validate incoming RPC and fill in defaults */
    if (xml_spec_populate_rpc(h, xtop, yspec) < 0) /*  */
	goto done;
    if ((ret = xml_yang_validate_rpc(xtop, cbret)) < 0)
	goto done;
    if (ret == 0){
	if (xml_parse_string(cbuf_get(cbret), NULL, &xret) < 0)
	    goto done;
	if ((xe = xpath_first(xret, "rpc-reply/rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, r, xe, pretty, use_xml) < 0)
	    goto done;
	goto ok;
    }
    /* Here xtop is (default values):
     * <rpc username="foo"><myfn xmlns="uri"><x>42</x><y>99</y></myfn></rpc>
    */
#if 0
    if (debug){
	cbuf *ccc=cbuf_new();
	if (clicon_xml2cbuf(ccc, xtop, 0, 0) < 0)
	    goto done;
	clicon_debug(1, "%s 6. Validate and defaults:%s", __FUNCTION__, cbuf_get(ccc));
    }
#endif
    /* 7. Send to RPC handler, either local or backend
     * Note (1) xtop is <rpc><method> xbot is <method>
     *      (2) local handler wants <method> and backend wants <rpc><method>
     */
    /* Look for local (client-side) restconf plugins. 
     * -1:Error, 0:OK local, 1:OK backend 
     */
    if ((ret = rpc_callback_call(h, xbot, cbret, r)) < 0)
	goto done;
    if (ret > 0){ /* Handled locally */
	if (xml_parse_string(cbuf_get(cbret), NULL, &xret) < 0)
	    goto done;
	/* Local error: return it and quit */
	if ((xe = xpath_first(xret, "rpc-reply/rpc-error")) != NULL){
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    else {    /* Send to backend */
	if (clicon_rpc_netconf_xml(h, xtop, &xret, NULL) < 0)
	    goto done;
	if ((xe = xpath_first(xret, "rpc-reply/rpc-error")) != NULL){
	    if (api_return_err(h, r, xe, pretty, use_xml) < 0)
		goto done;
	    goto ok;
	}
    }
    /* 8. Receive reply from local/backend handler as Netconf RPC
     *       <rpc-reply><x xmlns="uri">0</x></rpc-reply>
     */
#if 1
    if (debug){
	cbuf *ccc=cbuf_new();
	if (clicon_xml2cbuf(ccc, xret, 0, 0) < 0)
	    goto done;
	clicon_debug(1, "%s 8. Receive reply:%s", __FUNCTION__, cbuf_get(ccc));
    }
#endif
    youtput = yang_find(yrpc, Y_OUTPUT, NULL);
    if ((ret = api_operations_post_output(h, r, xret, yspec, youtput, namespace,
					  pretty, use_xml, &xoutput)) < 0)
	goto done;
    if (ret == 0)
	goto ok;
    /* xoutput should now look: <output xmlns="uri"><x>0</x></output> */
    FCGX_SetExitStatus(200, r->out); /* OK */
    FCGX_FPrintF(r->out, "Content-Type: application/yang-data+%s\r\n", use_xml?"xml":"json");
    FCGX_FPrintF(r->out, "\r\n");
    cbuf_reset(cbret);
    if (use_xml){
	if (clicon_xml2cbuf(cbret, xoutput, 0, pretty) < 0)
	    goto done;
	/* xoutput should now look: <output xmlns="uri"><x>0</x></output> */
    }
    else{
	if (xml2json_cbuf(cbret, xoutput, pretty) < 0)
	    goto done;
	/* xoutput should now look: {"example:output": {"x":0,"y":42}} */
    }
    FCGX_FPrintF(r->out, "%s", cbuf_get(cbret));
    FCGX_FPrintF(r->out, "\r\n\r\n");
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (prefix)
	free(prefix);
    if (id)
	free(id);
    if (xtop)
	xml_free(xtop);
    if (xret)
	xml_free(xret);
    if (xerr)
	xml_free(xerr);
    if (cbret)
	cbuf_free(cbret);
   return retval;
}
