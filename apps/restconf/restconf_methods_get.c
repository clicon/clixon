/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
  
 * Restconf method implementation for operations get and data get and head
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
#include <time.h>
#include <signal.h>
#include <limits.h>
#include <sys/time.h>
#include <sys/wait.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include "restconf_lib.h"
#include "restconf_handle.h"
#include "restconf_api.h"
#include "restconf_err.h"
#include "restconf_methods_get.h"

/*! Generic GET (both HEAD and GET)
 * According to restconf 
 * @param[in]  h        Clixon handle
 * @param[in]  req      Generic Www handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec    Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi       Offset, where path starts  
 * @param[in]  qvec     Vector of query string (QUERY_STRING)
 * @param[in]  pretty   Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Output media
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
 * @note: If a retrieval request for a data resource representing a YANG leaf-
 * list or list object identifies more than one instance, and XML
 * encoding is used in the response, then an error response containing a
 * "400 Bad Request" status-line MUST be returned by the server.
 * Netconf: <get-config>, <get>                        
 */
static int
api_data_get2(clicon_handle  h,
	      void          *req,
	      char          *api_path, 
	      cvec          *pcvec, /* XXX remove? */
	      int            pi,
	      cvec          *qvec,
	      int            pretty,
	      restconf_media media_out,
	      int            head)
{
    int        retval = -1;
    char      *xpath = NULL;
    cbuf      *cbx = NULL;
    yang_stmt *yspec;
    cxobj     *xret = NULL;
    cxobj     *xerr = NULL; /* malloced */
    cxobj     *xe = NULL;   /* not malloced */
    cxobj    **xvec = NULL;
    size_t     xlen;
    int        i;
    cxobj     *x;
    int        ret;
    char      *namespace = NULL;
    cvec      *nsc = NULL;
    char      *attr; /* attribute value string */
    netconf_content content = CONTENT_ALL;
    int32_t    depth = -1;  /* Nr of levels to print, -1 is all, 0 is none */
    cxobj     *xtop = NULL;
    cxobj     *xbot = NULL;
    yang_stmt *y = NULL;
    
    clicon_debug(1, "%s", __FUNCTION__);
    if ((yspec = clicon_dbspec_yang(h)) == NULL){
	clicon_err(OE_FATAL, 0, "No DB_SPEC");
	goto done;
    }
    /* strip /... from start */
    for (i=0; i<pi; i++)
	api_path = index(api_path+1, '/');
    if (api_path){
	if ((xtop = xml_new("top", NULL, CX_ELMNT)) == NULL)
	    goto done;
	/* Translate api-path to xml, but to validate the api-path, note: strict=1 
	 * xtop and xbot unnecessary for this function but needed by function
	 */
	if ((ret = api_path2xml(api_path, yspec, xtop, YC_DATANODE, 1, &xbot, &y, &xerr)) < 0)
	    goto done;
	/* Translate api-path to xpath: xpath (cbpath) and namespace context (nsc) */
	if (ret != 0 &&
	    (ret = api_path2xpath(api_path, yspec, &xpath, &nsc, &xerr)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
    }

    /* Check for content attribute */
    if ((attr = cvec_find_str(qvec, "content")) != NULL){
	clicon_debug(1, "%s content=%s", __FUNCTION__, attr);
	if ((int)(content = netconf_content_str2int(attr)) == -1){
	    if (netconf_bad_attribute_xml(&xerr, "application",
					  "content", "Unrecognized value of content attribute") < 0)
		goto done;
	    if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
    }
    /* Check for depth attribute */
    if ((attr = cvec_find_str(qvec, "depth")) != NULL){
	clicon_debug(1, "%s depth=%s", __FUNCTION__, attr);
	if (strcmp(attr, "unbounded") != 0){
	    char *reason = NULL;
	    if ((ret = parse_int32(attr, &depth, &reason)) < 0){
		clicon_err(OE_XML, errno, "parse_int32");
		goto done;
	    }
	    if (ret==0){
		if (netconf_bad_attribute_xml(&xerr, "application",
					      "depth", "Unrecognized value of depth attribute") < 0)
		    goto done;
		if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
		    goto done;
		goto ok;
	    }
	}
    }

    clicon_debug(1, "%s path:%s", __FUNCTION__, xpath);
    switch (content){
    case CONTENT_CONFIG:
    case CONTENT_NONCONFIG:
    case CONTENT_ALL:
	ret = clicon_rpc_get(h, xpath, nsc, content, depth, &xret);
	break;
    default:
	clicon_err(OE_XML, EINVAL, "Invalid content attribute %d", content);
	goto done;
	break;
    }
    if (ret < 0){
	if (netconf_operation_failed_xml(&xerr, "protocol", clicon_err_reason) < 0)
	    goto done;
	if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
	    goto done;
	goto ok;
    }
    /* We get return via netconf which is complete tree from root 
     * We need to cut that tree to only the object.
     */
#if 0 /* DEBUG */
    if (clicon_debug_get())
	clicon_log_xml(LOG_DEBUG, xret, "%s xret:", __FUNCTION__);
#endif
    /* Check if error return  */
    if ((xe = xpath_first(xret, NULL, "//rpc-error")) != NULL){
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
	    goto done;
	goto ok;
    }
    /* Normal return, no error */
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    if (xpath==NULL || strcmp(xpath,"/")==0){ /* Special case: data root */
	switch (media_out){
	case YANG_DATA_XML:
	    if (clicon_xml2cbuf(cbx, xret, 0, pretty, -1) < 0) /* Dont print top object?  */
		goto done;
	    break;
	case YANG_DATA_JSON:
	    if (xml2json_cbuf(cbx, xret, pretty) < 0)
		goto done;
	    break;
	default:
	    break;
	}
    }
    else{
	if (xpath_vec(xret, nsc, "%s", &xvec, &xlen, xpath) < 0){
	    if (netconf_operation_failed_xml(&xerr, "application", clicon_err_reason) < 0)
		goto done;
	    if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
	/* Check if not exists */
	if (xlen == 0){
	    /* 4.3: If a retrieval request for a data resource represents an 
	       instance that does not exist, then an error response containing 
	       a "404 Not Found" status-line MUST be returned by the server.  
	       The error-tag value "invalid-value" is used in this case. */
	    if (netconf_invalid_value_xml(&xerr, "application", "Instance does not exist") < 0)
		goto done;
	    /* override invalid-value default 400 with 404 */
	    if (api_return_err0(h, req, xerr, pretty, media_out, 404) < 0)
		goto done;
	    goto ok;
	}
	switch (media_out){
	case YANG_DATA_XML:
	    for (i=0; i<xlen; i++){
		char *prefix;
		x = xvec[i];
		/* Some complexities in grafting namespace in existing trees to new */
		prefix = xml_prefix(x);
		if (xml_find_type_value(x, prefix, "xmlns", CX_ATTR) == NULL){
		    if (xml2ns(x, prefix, &namespace) < 0)
			goto done;
		    if (namespace && xmlns_set(x, prefix, namespace) < 0)
			goto done;
		}
		if (clicon_xml2cbuf(cbx, x, 0, pretty, -1) < 0) /* Dont print top object?  */
		    goto done;
	    }
	    break;
	case YANG_DATA_JSON:
	    /* In: <x xmlns="urn:example:clixon">0</x>
	     * Out: {"example:x": {"0"}}
	     */
	    if (xml2json_cbuf_vec(cbx, xvec, xlen, pretty) < 0)
		goto done;
	    break;
	default:
	    break;
	}
    }
    clicon_debug(1, "%s cbuf:%s", __FUNCTION__, cbuf_get(cbx));
    if (restconf_reply_header(req, "Content-Type", "%s", restconf_media_int2str(media_out)) < 0)
	goto done;
    if (restconf_reply_header(req, "Cache-Control", "no-cache") < 0)
	goto done;
    if (restconf_reply_send(req, 200, cbx, head) < 0)
	goto done;
    cbx = NULL;
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (xpath)
	free(xpath);
    if (nsc)
	xml_nsctx_free(nsc);
    if (xtop)
        xml_free(xtop);
    if (cbx)
        cbuf_free(cbx);
    if (xret)
	xml_free(xret);
    if (xerr)
	xml_free(xerr);
    if (xvec)
	free(xvec);
    return retval;
}

/*! REST HEAD method
 * @param[in]  h        Clixon handle
 * @param[in]  req      Generic Www handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec    Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi       Offset, where path starts  
 * @param[in]  qvec     Vector of query string (QUERY_STRING)
 * @param[in]  pretty   Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Output media
 *
 * The HEAD method is sent by the client to retrieve just the header fields 
 * that would be returned for the comparable GET method, without the 
 * response message-body. 
 * Relation to netconf: none                        
 */
int
api_data_head(clicon_handle h,
	      void         *req,
	      char         *api_path,
	      cvec         *pcvec,
	      int           pi,
	      cvec         *qvec,
	      int           pretty,
	      restconf_media media_out,
	      ietf_ds_t     ds)
{
    return api_data_get2(h, req, api_path, pcvec, pi, qvec, pretty, media_out, 1);
}

/*! REST GET method
 * According to restconf 
 * @param[in]  h        Clixon handle
 * @param[in]  req      Generic Www handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec    Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi       Offset, where path starts  
 * @param[in]  qvec     Vector of query string (QUERY_STRING)
 * @param[in]  pretty   Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Output media
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
	     void         *req,
	     char         *api_path, 
             cvec         *pcvec,
             int           pi,
             cvec         *qvec,
	     int           pretty,
	     restconf_media media_out,
	     ietf_ds_t     ds)
{
    return api_data_get2(h, req, api_path, pcvec, pi, qvec, pretty, media_out, 0);
}

/*! GET restconf/operations resource
 * @param[in]  h      Clixon handle
 * @param[in]  req    Generic Www handle
 * @param[in]  path   According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element 
 * @param[in]  pi     Offset, where path starts  
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * @param[in]  pretty Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Output media
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
		   void         *req,
		   char         *path, 
		   int           pi,
		   cvec         *qvec, 
		   char         *data,
		   int           pretty,
		   restconf_media media_out)
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
    switch (media_out){
    case YANG_DATA_XML:
	cprintf(cbx, "<operations>");
	break;
    case YANG_DATA_JSON:
	if (pretty)
	    cprintf(cbx, "{\"operations\": {\n");
	else
	    cprintf(cbx, "{\"operations\":{");
	break;
    default:
	break;
    }
    ymod = NULL;
    i = 0;
    while ((ymod = yn_each(yspec, ymod)) != NULL) {
	namespace = yang_find_mynamespace(ymod);
	yc = NULL; 
	while ((yc = yn_each(ymod, yc)) != NULL) {
	    if (yang_keyword_get(yc) != Y_RPC)
		continue;
	    switch (media_out){
	    case YANG_DATA_XML:
		cprintf(cbx, "<%s xmlns=\"%s\"/>", yang_argument_get(yc), namespace);
		break;
	    case YANG_DATA_JSON:
		if (i++){
		    cprintf(cbx, ",");
		    if (pretty)
			cprintf(cbx, "\n\t");
		}
		if (pretty)
		    cprintf(cbx, "\"%s:%s\": [null]", yang_argument_get(ymod), yang_argument_get(yc));
		else
		    cprintf(cbx, "\"%s:%s\":[null]", yang_argument_get(ymod), yang_argument_get(yc));
		break;
	    default:
		break;
	    }
	}
    }
    switch (media_out){
    case YANG_DATA_XML:
	cprintf(cbx, "</operations>");
	break;
    case YANG_DATA_JSON:
	if (pretty)
	    cprintf(cbx, "}\n}");
	else
	    cprintf(cbx, "}}");
	break;
    default:
	break;
    }
    if (restconf_reply_header(req, "Content-Type", "%s", restconf_media_int2str(media_out)) < 0)
	goto done;
    if (restconf_reply_header(req, "Cache-Control", "no-cache") < 0)
	goto done;
    if (restconf_reply_send(req, 200, cbx, 0) < 0)
	goto done;
    cbx = NULL;
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

