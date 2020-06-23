/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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
#include "restconf_methods.h"

/*! REST OPTIONS method
 * According to restconf
 * @param[in]  h      Clixon handle
 * @param[in]  req    Generic Www handle
 *
 * @code
 *  curl -G http://localhost/restconf/data/interfaces/interface=eth0
 * @endcode                     
 * Minimal support: 
 * 200 OK
 * Allow: HEAD,GET,PUT,DELETE,OPTIONS              
 * @see RFC5789 PATCH Method for HTTP Section 3.2
 */
int
api_data_options(clicon_handle h,
		 void         *req)
{
    int retval = -1;

    clicon_debug(1, "%s", __FUNCTION__);
    if (restconf_reply_header(req, "Allow", "OPTIONS,HEAD,GET,POST,PUT,PATCH,DELETE") < 0)
	goto done;
    if (restconf_reply_header(req, "Accept-Patch", "application/yang-data+xml,application/yang-data+json") < 0)
	goto done;
    if (restconf_reply_send(req, 200, NULL) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! Check matching keys
 *
 * Check that x1 and x2 are of type list/leaf-list and share the same key statements
 * I.e that if x1=<list><key>b</key></list> then x2 = <list><key>b</key></list> as 
 * well. Otherwise return -1.
 * @param[in] y        Yang statement, should be list or leaf-list
 * @param[in] x1       First XML tree (eg data)
 * @param[in] x2       Second XML tree (eg api-path)
 * @retval    0        Yes, keys match
 * @retval    -1       No, keys do not match
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
		cxobj     *x1,
		cxobj     *x2)
{
    int        retval = -1;
    cvec      *cvk = NULL; /* vector of index keys */
    cg_var    *cvi;
    char      *keyname;
    cxobj     *xkey1; /* xml key object of x1 */
    cxobj     *xkey2; /* xml key object of x2 */
    char      *key1;
    char      *key2;

    clicon_debug(1, "%s", __FUNCTION__);
    switch (yang_keyword_get(y)){
    case Y_LIST:
	cvk = yang_cvec_get(y); /* Use Y_LIST cache, see ys_populate_list() */
	cvi = NULL;
	while ((cvi = cvec_each(cvk, cvi)) != NULL) {
	    keyname = cv_string_get(cvi);	    
	    if ((xkey2 = xml_find(x2, keyname)) == NULL)
		goto done; /* No key in api-path */
	    if ((key2 = xml_body(xkey2)) == NULL)
		goto done;
	    if ((xkey1 = xml_find(x1, keyname)) == NULL)
		goto done; /* No key in data */
	    if ((key1 = xml_body(xkey1)) == NULL)
		goto done;
	    if (strcmp(key2, key1) != 0)
		goto done; /* keys dont match */
	}
	break;
    case Y_LEAF_LIST:
	if ((key2 = xml_body(x2)) == NULL)
	    goto done; /* No key in api-path */
	if ((key1 = xml_body(x1)) == NULL)
	    goto done; /* No key in data */
	if (strcmp(key2, key1) != 0)
	    goto done; /* keys dont match */
	break;
    default:
	goto ok;
    }
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Common PUT plain PATCH method 
 * Code checks if object exists.
 * PUT:   If it does not, set op to create, otherwise replace
 * PATCH: If it does not, fail, otherwise replace/merge
 * @param[in] plain_patch  fail if object does not exists AND merge (not replace)
 */ 
static int
api_data_write(clicon_handle h,
	       void         *req, 
	       char         *api_path0, 
	       cvec         *pcvec, 
	       int           pi,
	       cvec         *qvec, 
	       char         *data,
	       int           pretty,
	       restconf_media media_in,
	       restconf_media media_out,
	       int            plain_patch)
{
    int            retval = -1;
    enum operation_type op;
    int            i;
    cxobj         *xdata0 = NULL; /* Original -d data struct (including top symbol) */
    cxobj         *xdata;         /* -d data (without top symbol)*/
    cbuf          *cbx = NULL;
    cxobj         *xtop = NULL; /* top of api-path */
    cxobj         *xbot = NULL; /* bottom of api-path */
    yang_stmt     *ybot = NULL; /* yang of xbot */
    yang_stmt     *ymodapi = NULL; /* yang module of api-path (if any) */
    yang_stmt     *ymoddata = NULL; /* yang module of data (-d) */
    cxobj         *xparent;
    yang_stmt     *yp; /* yang parent */
    yang_stmt     *yspec;
    cxobj         *xa;
    char          *api_path;
    cxobj         *xret = NULL;
    cxobj         *xretcom = NULL; /* return from commit */
    cxobj         *xretdis = NULL; /* return from discard-changes */
    cxobj         *xerr = NULL;    /* malloced must be freed */
    cxobj         *xe;             /* direct pointer into tree, dont free */
    char          *username;
    int            ret;
    char          *namespace = NULL;
    char          *dname;
    cvec          *nsc = NULL;
    yang_bind      yb;
    char          *xpath = NULL;

    clicon_debug(1, "%s api_path:\"%s\"",  __FUNCTION__, api_path0);
    clicon_debug(1, "%s data:\"%s\"", __FUNCTION__, data);
    if ((yspec = clicon_dbspec_yang(h)) == NULL){
	clicon_err(OE_FATAL, 0, "No DB_SPEC");
	goto done;
    }
    api_path=api_path0;
    /* strip /... from start */
    for (i=0; i<pi; i++)
	api_path = index(api_path+1, '/');
    if (api_path){
	/* Translate api-path to xpath: xpath (cbpath) and namespace context (nsc) */
	if ((ret = api_path2xpath(api_path, yspec, &xpath, &nsc, &xerr)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
    }

    xret = NULL;
    if (clicon_rpc_get_config(h, clicon_nacm_recovery_user(h),
			      "candidate", xpath, nsc, &xret) < 0){
	if (netconf_operation_failed_xml(&xerr, "protocol", clicon_err_reason) < 0)
	    goto done;
	if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
	    goto done;
	goto ok;

    }
#if 0
    if (clicon_debug_get())
	clicon_log_xml(LOG_DEBUG, xret, "%s xret:", __FUNCTION__);
#endif
    if (xml_child_nr(xret) == 0){ /* Object does not exist */
	if (plain_patch){    /* If the target resource instance does not exist, the server MUST NOT create it. */
	    restconf_badrequest(h, req);
	    goto ok;
	}
	else
	    op = OP_CREATE;
    }
    else{
	if (plain_patch)
	    op = OP_MERGE;
	else
	    op = OP_REPLACE;
    }
    if (xret){
	xml_free(xret);
	xret = NULL;
    }
    /* Create config top-of-tree */
    if ((xtop = xml_new("config", NULL, CX_ELMNT)) == NULL)
	goto done;
    /* Translate api_path to xml in the form of xtop/xbot */
    xbot = xtop;
    if (api_path){ /* If URI, otherwise top data/config object */
	if ((ret = api_path2xml(api_path, yspec, xtop, YC_DATANODE, 1, &xbot, &ybot, &xerr)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
	if (ybot)
	    ymodapi = ys_module(ybot);
    }
    /* 4.4.1: The message-body MUST contain exactly one instance of the
     * expected data resource.  (tested again below)
     */
    if (data == NULL || strlen(data) == 0){
	if (netconf_malformed_message_xml(&xerr, "The message-body MUST contain exactly one instance of the expected data resource") < 0)
	    goto done;
	if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
	    goto done;
	goto ok;
    }
    /* Create a dummy data tree parent to hook in the parsed data.
     */
    if ((xdata0 = xml_new("data0", NULL, CX_ELMNT)) == NULL)
	goto done;
    if (api_path){ /* XXX mv to copy? */
	cxobj *xfrom;
	cxobj *xac;
	
	xfrom = api_path?xml_parent(xbot):xbot;
	if (xml_copy_one(xfrom, xdata0) < 0)
	    goto done;
	xa = NULL;
	while ((xa = xml_child_each(xfrom, xa, CX_ATTR)) != NULL) {
	    if ((xac = xml_new(xml_name(xa), xdata0, CX_ATTR)) == NULL)
		goto done;
	    if (xml_copy(xa, xac) < 0) /* recursion */
		goto done;
	}
    }
    if (xml_spec(xdata0)==NULL)
	yb = YB_MODULE;
    else
	yb = YB_PARENT;

    /* Parse input data as json or xml into xml 
     * Note that in POST (api_data_post) the new object is grafted on xbot, since it is a new
     * object. In that case all yang bindings can be made since xbot is available.
     * Here the new object replaces xbot and is therefore more complicated to make when parsing.
     * Instead, xbots parent is copied into xdata0 (but not its children).
     */
    switch (media_in){
    case YANG_DATA_XML:
	if ((ret = clixon_xml_parse_string(data, yb, yspec, &xdata0, &xerr)) < 0){
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
	if (ret == 0){
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
	break;
    case YANG_DATA_JSON:
	if ((ret = clixon_json_parse_string(data, yb, yspec, &xdata0, &xerr)) < 0){
	    if (netconf_malformed_message_xml(&xerr, clicon_err_reason) < 0)
		goto done;
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
	if (ret == 0){
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
	break;
    default:
	restconf_unsupported_media(req);
	goto ok;
	break;
    } /* switch media_in */

    /* The message-body MUST contain exactly one instance of the
     * expected data resource. 
     */
    if (xml_child_nr_type(xdata0, CX_ELMNT) != 1){
	if (netconf_malformed_message_xml(&xerr, "The message-body MUST contain exactly one instance of the expected data resource") < 0)
	    goto done;
	if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
	    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
	    goto done;
	}
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
	    goto done;
	goto ok;
    }
    xdata = xml_child_i_type(xdata0, 0, CX_ELMNT);
    /* If the api-path (above) defines a module, then xdata must have a prefix
     * and it match the module defined in api-path
     * This does not apply if api-path is / (no module)
     */
    if (ys_module_by_xml(yspec, xdata, &ymoddata) < 0)
	goto done;
    if (ymoddata && ymodapi){
	if (ymoddata != ymodapi){
	    if (netconf_malformed_message_xml(&xerr, "Data is not prefixed with matching namespace") < 0)
		goto done;
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
    }

    /* Add operation create as attribute. If that fails with Conflict, then 
     * try "replace" (see comment in function header)
     */
    if ((xa = xml_new("operation", xdata, CX_ATTR)) == NULL)
	goto done;
    if (xml_prefix_set(xa, NETCONF_BASE_PREFIX) < 0)
	goto done;
    if (xml_value_set(xa, xml_operation2str(op)) < 0)
	goto done;

    /* Top-of tree, no api-path
     * Replace xparent with x, ie bottom of api-path with data 
     */	    
    dname = xml_name(xdata);
    if (api_path==NULL && strcmp(dname,"data")==0){
	if (xml_addsub(NULL, xdata) < 0)
	    goto done;
	if (xtop)
	    xml_free(xtop);
	xtop = xdata;
	xml_name_set(xtop, "config");
	/* remove default namespace */
	if ((xa = xml_find_type(xtop, NULL, "xmlns", CX_ATTR)) != NULL){
	    if (xml_rm(xa) < 0)
		goto done;
	    if (xml_free(xa) < 0)
		goto done;
	}
    }
    else {
	/* There is an api-path that defines an element in the datastore tree.
	 * Not top-of-tree.
	 */
	clicon_debug(1, "%s Comparing bottom-of api-path (%s) with top-of-data (%s)",__FUNCTION__, xml_name(xbot), dname);

	/* Check same symbol in api-path as data */	    
	if (strcmp(dname, xml_name(xbot))){
	    if (netconf_operation_failed_xml(&xerr, "protocol", "Not same symbol in api-path as data") < 0)
		goto done;
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
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
	if (ybot){
	    /* Ensure list keys match between uri and data. That is:
	     * If data is on the form: -d {"a":{"k":1}} where a is list or leaf-list
	     * then uri-path must be ../a=1
	     * match_list_key() checks if this is true
	     */
	    if (match_list_keys(ybot, xdata, xbot) < 0){
		if (netconf_operation_failed_xml(&xerr, "protocol", "api-path keys do not match data keys") < 0)
		    goto done;
		if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		    goto done;
		}
		if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		    goto done;
		goto ok;
	    }
	    /* Ensure keys in lists are not changed. That is:
	     * If data is on the form: -d {"k":1} and its parent is a list "a"
	     * then the uri-path must be "../a=1 (you cannot change a's key)"
	     */
	    if ((yp = yang_parent_get(ybot)) != NULL &&
		yang_keyword_get(yp) == Y_LIST){
		if ((ret = yang_key_match(yp, dname)) < 0)
		    goto done;
		if (ret == 1){ /* Match: xdata is a key */
		    char *parbod = xml_find_body(xparent, dname);
		    /* Check if the key is different from the one in uri-path,
		     * or does not exist
		     */
		    if (parbod == NULL || strcmp(parbod, xml_body(xdata))){
			if (netconf_operation_failed_xml(&xerr, "protocol", "api-path keys do not match data keys") < 0)
			    goto done;
			if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
			    clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
			    goto done;
			}
			if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
			    goto done;
			goto ok;
		    }
		}
	    }
	}
	xml_purge(xbot);
	if (xml_addsub(xparent, xdata) < 0)
	    goto done;
	/* If restconf insert/point attributes are present, translate to netconf */
	if (restconf_insert_attributes(xdata, qvec) < 0)
	    goto done;
	/* If we already have that default namespace, remove it in child */
	if ((xa = xml_find_type(xdata, NULL, "xmlns", CX_ATTR)) != NULL){
	    if (xml2ns(xparent, NULL, &namespace) < 0)
		goto done;
	    /* Set xmlns="" default namespace attribute (if diff from default) */
	    if (strcmp(namespace, xml_value(xa))==0)
		xml_purge(xa);
	}		
    }
    /* For internal XML protocol: add username attribute for access control
     */
    username = clicon_username_get(h);
    /* Create text buffer for transfer to backend */
    if ((cbx = cbuf_new()) == NULL)
	goto done;
    cprintf(cbx, "<rpc username=\"%s\" xmlns:%s=\"%s\">",
	    username?username:"",
	    NETCONF_BASE_PREFIX,
	    NETCONF_BASE_NAMESPACE); /* bind nc to netconf namespace */
    cprintf(cbx, "<edit-config><target><candidate /></target>");
    cprintf(cbx, "<default-operation>none</default-operation>");
    if (clicon_xml2cbuf(cbx, xtop, 0, 0, -1) < 0)
	goto done;
    cprintf(cbx, "</edit-config></rpc>");
    clicon_debug(1, "%s xml: %s api_path:%s",__FUNCTION__, cbuf_get(cbx), api_path);
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xret, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xret, NULL, "//rpc-error")) != NULL){
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
	    goto done;	    
	goto ok;
    }
    cbuf_reset(cbx);
    /* commit/discard should be done automaticaly by the system, therefore
     * recovery user is used here (edit-config but not commit may be permitted
     by NACM */
    cprintf(cbx, "<rpc username=\"%s\">", clicon_nacm_recovery_user(h));
    cprintf(cbx, "<commit/></rpc>");
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xretcom, NULL, "//rpc-error")) != NULL){
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", username?username:"");
	cprintf(cbx, "<discard-changes/></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretdis, NULL) < 0)
	    goto done;
	/* log errors from discard, but ignore */
	if ((xpath_first(xretdis, NULL, "//rpc-error")) != NULL)
	    clicon_log(LOG_WARNING, "%s: discard-changes failed which may lead candidate in an inconsistent state", __FUNCTION__);
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
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
	cprintf(cbx, "<rpc username=\"%s\">", clicon_nacm_recovery_user(h));
	cprintf(cbx, "<copy-config><source><running/></source><target><startup/></target></copy-config></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	    goto done;
	/* If copy-config failed, log and ignore (already committed) */
	if ((xe = xpath_first(xretcom, NULL, "//rpc-error")) != NULL){

	    clicon_log(LOG_WARNING, "%s: copy-config running->startup failed", __FUNCTION__);
	}
    }
    /* Check if it was created, or if we tried again and replaced it */
    if (op == OP_CREATE){
	if (restconf_reply_send(req, 201, NULL) < 0)
	    goto done;	
    }
    else{
	if (restconf_reply_send(req, 204, NULL) < 0)
	    goto done;	
    }
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (xpath)
	free(xpath);
    if (nsc)
	xml_nsctx_free(nsc);
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
    if (xdata0)
	xml_free(xdata0);
     if (cbx)
	cbuf_free(cbx); 
   return retval;
} /* api_data_write */

/*! Generic REST PUT  method 
 * @param[in]  h        Clixon handle
 * @param[in]  req      Generic Www handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec    Vector of path ie DOCUMENT_URI element
 * @param[in]  pi       Offset, where to start pcvec
 * @param[in]  qvec     Vector of query string (QUERY_STRING)
 * @param[in]  data     Stream input data
 * @param[in]  pretty   Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Output media

 * @note restconf PUT is mapped to edit-config replace. 
 * @see RFC8040 Sec 4.5  PUT
 * @see api_data_post
 * @example
      curl -X PUT -d '{"enabled":"false"}' http://127.0.0.1/restconf/data/interfaces/interface=eth1
 *
 PUT:
   A request message-body MUST be present, representing the new data resource, or the server
   MUST return a "400 Bad Request" status-line.

   ...if the PUT request creates a new resource, a "201 Created" status-line is returned.  
   If an existing resource is modified, a "204 No Content" status-line is returned.

 * Netconf:  <edit-config> (nc:operation="create/replace")
 * Note RFC8040 says that if an object is created, 201 is returned, if replaced 204
 * is returned. But the restconf client does not know if it is replaced or created,
 * only the server knows that. Solutions:
 * 1) extend the netconf <ok/> so it returns if created/replaced. But that would lead
 *    to extension of netconf that may hit other places.
 * 2) Send a get first and see if the resource exists, and then send replace/create.
 *    Will always produce an extra message and the GET may potetnially waste bw.
 * 3) Try to create first, if that fails (with conflict) then try replace.
 *    --> Best solution and applied here
 */
int
api_data_put(clicon_handle h,
	     void         *req, 
	     char         *api_path0, 
	     cvec         *pcvec, 
	     int           pi,
	     cvec         *qvec, 
	     char         *data,
	     int           pretty,
	     restconf_media media_out)
{
    restconf_media media_in;

    media_in = restconf_content_type(h);
    return api_data_write(h, req, api_path0, pcvec, pi, qvec, data, pretty,
			  media_in, media_out, 0);
} 

/*! Generic REST PATCH method for plain patch 
 * @param[in]  h        Clixon handle
 * @param[in]  req      Generic Www handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pcvec    Vector of path ie DOCUMENT_URI element
 * @param[in]  pi       Offset, where to start pcvec
 * @param[in]  qvec     Vector of query string (QUERY_STRING)
 * @param[in]  data     Stream input data
 * @param[in]  pretty   Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Output media
 * Netconf:  <edit-config> (nc:operation="merge")      
 * See RFC8040 Sec 4.6.1
 * Plain patch can be used to create or update, but not delete, a child
 * resource within the target resource.
 * NOTE:    If the target resource instance does not exist, the server MUST NOT
 *   create it. (CANT BE DONE WITH NETCONF)
 */
int
api_data_patch(clicon_handle h,
	       void         *req, 
	       char         *api_path0, 
	       cvec         *pcvec, 
	       int           pi,
	       cvec         *qvec, 
	       char         *data,
	       int           pretty,
	       restconf_media media_out)
{
    restconf_media media_in;
    int ret;

    media_in = restconf_content_type(h);
    switch (media_in){
    case YANG_DATA_XML:
    case YANG_DATA_JSON: 	/* plain patch */
	ret = api_data_write(h, req, api_path0, pcvec, pi, qvec, data, pretty,
			     media_in, media_out, 1);
	break;
    case YANG_PATCH_XML:
    case YANG_PATCH_JSON: 	/* RFC 8072 patch */
	ret = restconf_notimplemented(req);
	break;
    default:
	ret = restconf_unsupported_media(req);
	break;
    }
    return ret;
} 

/*! Generic REST DELETE method translated to edit-config
 * @param[in]  h        Clixon handle
 * @param[in]  req      Generic Www handle
 * @param[in]  api_path According to restconf (Sec 3.5.3.1 in rfc8040)
 * @param[in]  pi       Offset, where path starts
 * @param[in]  pretty   Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Output media
 * See RFC 8040 Sec 4.7
 * Example:
 *  curl -X DELETE http://127.0.0.1/restconf/data/interfaces/interface=eth0
 * Netconf:  <edit-config> (nc:operation="delete")      
 */
int
api_data_delete(clicon_handle h,
		void         *req, 
		char         *api_path,
		int           pi,
		int           pretty,
		restconf_media media_out)
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
    if ((xtop = xml_new("config", NULL, CX_ELMNT)) == NULL)
	goto done;
    xbot = xtop;
    if (api_path){
	if ((ret = api_path2xml(api_path, yspec, xtop, YC_DATANODE, 1, &xbot, &y, &xerr)) < 0)
	    goto done;
	if (ret == 0){ /* validation failed */
	    if ((xe = xpath_first(xerr, NULL, "rpc-error")) == NULL){
		clicon_err(OE_XML, EINVAL, "rpc-error not found (internal error)");
		goto done;
	    }
	    if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
		goto done;
	    goto ok;
	}
    }
    if ((xa = xml_new("operation", xbot, CX_ATTR)) == NULL)
	goto done;
    if (xml_value_set(xa, xml_operation2str(op)) < 0)
	goto done;
    if (xml_namespace_change(xa, NETCONF_BASE_NAMESPACE, NETCONF_BASE_PREFIX) < 0)
	goto done;

    if ((cbx = cbuf_new()) == NULL)
	goto done;
    /* For internal XML protocol: add username attribute for access control
     */
    username = clicon_username_get(h);
    cprintf(cbx, "<rpc username=\"%s\" xmlns:%s=\"%s\">",
	    username?username:"",
	    NETCONF_BASE_PREFIX,
	    NETCONF_BASE_NAMESPACE); /* bind nc to netconf namespace */
    cprintf(cbx, "<edit-config><target><candidate /></target>");
    cprintf(cbx, "<default-operation>none</default-operation>");
    if (clicon_xml2cbuf(cbx, xtop, 0, 0, -1) < 0)
	goto done;
    cprintf(cbx, "</edit-config></rpc>");
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xret, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xret, NULL, "//rpc-error")) != NULL){
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
	    goto done;
	goto ok;
    }
    /* Assume this is validation failed since commit includes validate */
    cbuf_reset(cbx);
    /* commit/discard should be done automatically by the system, therefore
     * recovery user is used here (edit-config but not commit may be permitted
     by NACM */
    cprintf(cbx, "<rpc username=\"%s\">", clicon_nacm_recovery_user(h));
    cprintf(cbx, "<commit/></rpc>");
    if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	goto done;
    if ((xe = xpath_first(xretcom, NULL, "//rpc-error")) != NULL){
	cbuf_reset(cbx);
	cprintf(cbx, "<rpc username=\"%s\">", clicon_nacm_recovery_user(h));
	cprintf(cbx, "<discard-changes/></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretdis, NULL) < 0)
	    goto done;
	/* log errors from discard, but ignore */
	if ((xpath_first(xretdis, NULL, "//rpc-error")) != NULL)
	    clicon_log(LOG_WARNING, "%s: discard-changes failed which may lead candidate in an inconsistent state", __FUNCTION__);
	if (api_return_err(h, req, xe, pretty, media_out, 0) < 0)
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
	cprintf(cbx, "<rpc username=\"%s\">", clicon_nacm_recovery_user(h));
	cprintf(cbx, "<copy-config><source><running/></source><target><startup/></target></copy-config></rpc>");
	if (clicon_rpc_netconf(h, cbuf_get(cbx), &xretcom, NULL) < 0)
	    goto done;
	/* If copy-config failed, log and ignore (already committed) */
	if ((xe = xpath_first(xretcom, NULL, "//rpc-error")) != NULL){

	    clicon_log(LOG_WARNING, "%s: copy-config running->startup failed", __FUNCTION__);
	}
    }
    if (restconf_reply_send(req, 204, NULL) < 0)
	goto done;	
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

