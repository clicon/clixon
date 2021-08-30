/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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

 * Netconf library functions. See RFC6241
 * Functions to generate a netconf error message come in two forms: xml-tree and 
 * cbuf. XML tree is preferred.
 */
#ifndef _CLIXON_NETCONF_LIB_H
#define _CLIXON_NETCONF_LIB_H

/*
 * Constants
 */
/* Default NETCONF namespace (see rfc6241 3.1)
 * See USE_NETCONF_NS_AS_DEFAULT for use of this namespace as default
 * Also, bind it to prefix:nc as used by, for example, the operation attribute
 * (also in RFC4741 Sec 3.1)
 * BTW this may not be the best way to keep them.
 */
#define NETCONF_BASE_NAMESPACE "urn:ietf:params:xml:ns:netconf:base:1.0"
#define NETCONF_BASE_PREFIX "nc"

/* In cases where message-id is not given by external client, use this */
#define NETCONF_MESSAGE_ID_DEFAULT "42"
#define NETCONF_MESSAGE_ID_ATTR "message-id=\"42\""

/* Netconf base capability as defined in RFC4741, Sec 8.1
 */
#define NETCONF_BASE_CAPABILITY_1_0 "urn:ietf:params:netconf:base:1.0"

/* Netconf base capability as defined in RFC6241, Sec 8.1
 */
#define NETCONF_BASE_CAPABILITY_1_1 "urn:ietf:params:netconf:base:1.1"

/* See RFC 7950 Sec 5.3.1: YANG defines an XML namespace for NETCONF <edit-config> 
 * operations, <error-info> content, and the <action> element.
 */
#define YANG_XML_NAMESPACE "urn:ietf:params:xml:ns:yang:1"
 
/*
 * Types
 */
/*! Content query parameter RFC 8040 Sec 4.8.1 
 * Clixon extention: content so that RFC8040 content attribute can be conveyed
 * internally used in <get>
 */
enum netconf_content{
    CONTENT_CONFIG,    /* config data only */
    CONTENT_NONCONFIG, /* state data only */
    CONTENT_ALL        /* default */
};
typedef enum netconf_content netconf_content;

/*
 * Macros
 */
/*! Generate textual error log from Netconf error message
 * @param[in]  xerr     Netconf error xml tree on the form: <rpc-error> 
 * @param[in]  format   Format string 
 * @param[in]  arg      String argument to format (optional)
 */
#define clixon_netconf_error(x, f, a) clixon_netconf_error_fn(__FUNCTION__, __LINE__, (x), (f), (a))

/*
 * Prototypes
 */
int netconf_in_use(cbuf *cb, char *type, char *message);
int netconf_invalid_value(cbuf *cb, char *type, char *message);
int netconf_invalid_value_xml(cxobj **xret, char *type, char *message);
int netconf_too_big(cbuf *cb, char *type, char *message);
int netconf_missing_attribute(cbuf *cb,	char *type, char *info, char *message);
int netconf_missing_attribute_xml(cxobj **xret, char *type, char *info, char *message);
int netconf_bad_attribute(cbuf *cb, char *type, char *info, char *message);
int netconf_bad_attribute_xml(cxobj **xret, char *type, char *info, char *message);
int netconf_unknown_attribute(cbuf *cb,	char *type, char *info, char *message);
int netconf_missing_element(cbuf *cb, char *type, char *element, char *message);
int netconf_missing_element_xml(cxobj **xret, char *type, char *element, char *message);
int netconf_bad_element(cbuf *cb, char *type, char *info, char *element);
int netconf_bad_element_xml(cxobj **xret, char *type, char *info, char *element);
int netconf_unknown_element(cbuf *cb, char *type, char *element, char *message);
int netconf_unknown_element_xml(cxobj **xret, char *type, char *element, char *message);
int netconf_unknown_namespace(cbuf *cb, char *type, char *ns, char *message);
int netconf_unknown_namespace_xml(cxobj **xret, char *type, char *ns, char *message);
int netconf_access_denied(cbuf *cb, char *type, char *message);
int netconf_access_denied_xml(cxobj **xret, char *type, char *message);
int netconf_lock_denied(cbuf *cb, char *info, char *message);
int netconf_resource_denied(cbuf *cb, char *type, char *message);
int netconf_rollback_failed(cbuf *cb, char *type, char *message);
int netconf_data_exists(cbuf *cb, char *message);
int netconf_data_missing(cbuf *cb, char *missing_choice, char *message);
int netconf_data_missing_xml(cxobj **xret, char *missing_choice, char *message);
int netconf_operation_not_supported_xml(cxobj **xret, char *type, char *message);
int netconf_operation_not_supported(cbuf *cb, char *type, char *message);
int netconf_operation_failed(cbuf *cb, char *type, char *message);
int netconf_operation_failed_xml(cxobj **xret, char *type, char *message);
int netconf_malformed_message(cbuf *cb, char *message);
int netconf_malformed_message_xml(cxobj **xret, char *message);
int netconf_data_not_unique_xml(cxobj **xret, cxobj *x, cvec *cvk);
int netconf_minmax_elements_xml(cxobj **xret, cxobj *xp, char *name, int max);
int netconf_trymerge(cxobj *x, yang_stmt *yspec, cxobj **xret);
int netconf_module_features(clicon_handle h);
int netconf_module_load(clicon_handle h);
char *netconf_db_find(cxobj *xn, char *name);
int netconf_err2cb(cxobj *xerr, cbuf *cberr);
const netconf_content netconf_content_str2int(char *str);
const char *netconf_content_int2str(netconf_content nr);
int netconf_hello_server(clicon_handle h, cbuf *cb, uint32_t session_id);
int netconf_hello_req(clicon_handle h, cbuf *cb);
int clixon_netconf_error_fn(const char *fn, const int line, cxobj *xerr, const char *fmt, const char *arg);
int clixon_netconf_internal_error(cxobj *xerr, char *msg, char *arg);
int netconf_parse_uint32(char *name, char *valstr, char *defaultstr, uint32_t defaultval, cbuf *cbret, uint32_t *value);
int netconf_parse_uint32_xml(char *name, char *valstr, char *defaultstr, uint32_t defaultval, cxobj **xerr, uint32_t *value);


#endif /* _CLIXON_NETCONF_LIB_H */
