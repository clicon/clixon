/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

/* In cases where message-id is not given by external client, use this
 * Note hardcoded message-id, which is ok for server, but a client should
 * eg assign message-id:s incrementally
 */
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

/* RFC 6022 YANG Module for NETCONF Monitoring
 */
#define NETCONF_MONITORING_NAMESPACE "urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring"

/* RFC 9144 Comparison of Network Management Datastore Architecture (NMDA) Datastores
 */
#define NETCONF_COMPARE_NAMESPACE "urn:ietf:params:xml:ns:yang:ietf-nmda-compare"

/*! draft-ietf-netconf-privcand  NETCONF and RESTCONF Private Candidate Datastores
 */
#define NETCONF_PRIVCAND_NAMESPACE "urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate"

/* Default STREAM namespace (see rfc5277 3.1)
 * From RFC8040:
 *  The structure of the event data is based on the <notification>
 *  element definition in Section 4 of [RFC5277].  It MUST conform to the
 *  schema for the <notification> element in Section 4 of [RFC5277],
 *  using the XML namespace as defined in the XSD as follows:
 *     urn:ietf:params:xml:ns:netconf:notification:1.0
 * It is used everywhere in yangmodels, but not in openconfig
 */
#define NETCONF_NOTIFICATION_NAMESPACE "urn:ietf:params:xml:ns:netconf:notification:1.0"
#define NETCONF_NOTIFICATION_CAPABILITY "urn:ietf:params:netconf:capability:notification:1.0"

/*
 * Then there is also this namespace that is only used in RFC5277 seems to be for "netconf"
 * events. The usage seems wrong here,...
 */
#define EVENT_RFC5277_NAMESPACE "urn:ietf:params:xml:ns:netmod:notification"

/* NETCONF and RESTCONF Private Candidate Datastores draft-ietf-netconf-privcand-08
 */
#define NETCONF_PRIVATE_CANDIDATE_CAPABILITY "urn:ietf:params:netconf:capability:private-candidate:1.0"
/*
 * Types
 */
/*! Content query parameter RFC 8040 Sec 4.8.1
 *
 * Clixon extention: content so that RFC8040 content attribute can be conveyed
 * internally used in <get>
 * @see netconf_content_map
 */
enum netconf_content{
    CONTENT_CONFIG,    /* config data only */
    CONTENT_NONCONFIG, /* state data only */
    CONTENT_ALL        /* default */
};
typedef enum netconf_content netconf_content;

enum target_type{ /* netconf */
    RUNNING,
    CANDIDATE
};

enum test_option{ /* edit-config */
    SET,
    TEST_THEN_SET,
    TEST_ONLY
};

enum error_option{ /* edit-config */
    STOP_ON_ERROR,
    CONTINUE_ON_ERROR
};

/*! NETCONF framing
 *
 * @see netconf_framing_map
 * @see netconf-framing-type in clixon-lib.yang
 */
enum framing_type{
    NETCONF_SSH_EOM = 0,     /* RFC 4742, RFC 6242 hello msg (end-of-msg: ]]>]]>)*/
    NETCONF_SSH_CHUNKED,     /* RFC 6242 Chunked framing */
};
typedef enum framing_type netconf_framing_type;

/* NETCONF with-defaults
 * @see RFC 6243
 */
enum withdefaults_type{
    WITHDEFAULTS_REPORT_ALL = 0,   /* in cache */
    WITHDEFAULTS_TRIM,
    WITHDEFAULTS_EXPLICIT,         /* on file */
    WITHDEFAULTS_REPORT_ALL_TAGGED
};
typedef enum withdefaults_type withdefaults_type;

/*! Privcand keywords from ietf-netconf-private-candidate.yang update RPC
 *
 * @see pcmap for string/symbol mapping
 */
enum privcand_resolution{
    PR_REVERT,
    PR_PREFCAND,
    PR_PREFRUN
};
typedef enum privcand_resolution privcand_resolution;

/*
 * Macros
 */
/*
 * Prototypes
 */
const char *withdefaults_int2str(int keyword);
int withdefaults_str2int(const char *str);
int privcand_res_str2key(const char *str);
int netconf_in_use(cbuf *cb, const char *type, const char *message);
int netconf_invalid_value(cbuf *cb, const char *type, const char *message);
int netconf_invalid_value_xml(cxobj **xret, const char *type, const char *message);
int netconf_too_big(cbuf *cb, const char *type, const char *message);
int netconf_missing_attribute(cbuf *cb, const char *type, const char *info, const char *message);
int netconf_missing_attribute_xml(cxobj **xret, const char *type, const char *info, const char *message);
int netconf_bad_attribute(cbuf *cb, const char *type, const char *info, const char *message);
int netconf_bad_attribute_xml(cxobj **xret, const char *type, const char *info, const char *message);
int netconf_unknown_attribute(cbuf *cb, const char *type, const char *info, const char *message);
int netconf_common_rpc_err(cbuf *cb, const char *ns, const char *type, const char *tag,
                           const char *info, const char *severity, const char *message);
int netconf_common_rpc_err_xml(cxobj **xret, const char *ns, const char *type,
                               const char *tag, const char *severity,
                               const char *infotag, const char *info,
                               const char *message);
int netconf_missing_element(cbuf *cb, const char *type, const char *element, const char *message);
int netconf_missing_yang_xml(cxobj **xret, const char *path, const char *app_tag, const char *info, const char *message);
int netconf_missing_element_xml(cxobj **xret, const char *type, const char *element, const char *message);
int netconf_bad_element(cbuf *cb, const char *type, const char *info, const char *element);
int netconf_bad_element_xml(cxobj **xret, const char *type, const char *info, const char *element);
int netconf_unknown_element(cbuf *cb, const char *type, const char *element, const char *message);
int netconf_unknown_element_xml(cxobj **xret, const char *type, const char *element, const char *message);
int netconf_unknown_namespace(cbuf *cb, const char *type, const char *ns, const char *message);
int netconf_unknown_namespace_xml(cxobj **xret, const char *type, const char *ns, const char *message);
int netconf_access_denied(cbuf *cb, const char *type, const char *message);
int netconf_access_denied_xml(cxobj **xret, const char *type, const char *message);
int netconf_lock_denied(cbuf *cb, const char *info, const char *message);
int netconf_resource_denied(cbuf *cb, const char *type, const char *message);
int netconf_rollback_failed(cbuf *cb, const char *type, const char *message);
int netconf_data_exists(cbuf *cb, const char *message);
int netconf_data_missing(cbuf *cb, const char *message);
int netconf_data_missing_xml(cxobj **xret, const char *message);
int netconf_missing_choice_xml(cxobj **xret, cxobj *x, const char *missing_choice, const char *message);
int netconf_operation_not_supported_xml(cxobj **xret, const char *type, const char *message);
int netconf_operation_not_supported(cbuf *cb, const char *type, const char *message);
int netconf_operation_failed(cbuf *cb, const char *type, const char *message, ...) __attribute__ ((format (printf, 3, 4)));
int netconf_operation_failed_xml(cxobj **xret, const char *type, const char *message);
int netconf_malformed_message(cbuf *cb, const char *message);
int netconf_malformed_message_xml(cxobj **xret, const char *message);
int netconf_data_not_unique(cbuf *cb, cxobj *x, cvec *cvk);
int netconf_data_not_unique_xml(cxobj **xret, cxobj *x, cvec *cvk);
int netconf_minmax_elements_xml(cxobj **xret, cxobj *xp, const char *name, int max);
int netconf_trymerge(cxobj *x, yang_stmt *yspec, cxobj **xret);
int netconf_module_features(clixon_handle h);
int netconf_module_load(clixon_handle h);
char *netconf_db_find(cxobj *xn, const char *name);
const netconf_content netconf_content_str2int(const char *str);
const char *netconf_content_int2str(netconf_content nr);
const netconf_framing_type netconf_framing_str2int(const char *str);
const char *netconf_framing_int2str(netconf_framing_type fr);
int netconf_capabilites(clixon_handle h, cbuf *cb);
int netconf_hello_server(clixon_handle h, cbuf *cb, uint32_t session_id);
int netconf_hello_req(clixon_handle h, cbuf *cb);
int clixon_netconf_internal_error(cxobj *xerr, const char *msg, const char *arg);
int netconf_parse_uint32(const char *name, char *valstr, const char *defaultstr, uint32_t defaultval,
                         cbuf *cbret, uint32_t *value);
int netconf_parse_uint32_xml(const char *name, char *valstr, const char *defaultstr, uint32_t defaultval,
                             cxobj **xerr, uint32_t *value);
int netconf_message_id_next(clixon_handle h);
int netconf_framing_preamble(netconf_framing_type framing, cbuf *cb);
int netconf_framing_postamble(netconf_framing_type framing, cbuf *cb);
int netconf_output(int s, cbuf *xf, const char *msg);
int netconf_output_encap(netconf_framing_type framing, cbuf *cb);
int netconf_input_chunked_framing(char ch, int *state, size_t *size);
int netconf_cbuf_err2cb(clixon_handle h, cbuf *cb0, cbuf *cberr);

#endif /* _CLIXON_NETCONF_LIB_H */
