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

 * Netconf library functions. See RFC6241
 * Functions to generate a netconf error message come in two forms: xml-tree and 
 * cbuf. XML tree is preferred.
 */
#ifndef _CLIXON_NETCONF_LIB_H
#define _CLIXON_NETCONF_LIB_H

/*
 * Prototypes
 */
int netconf_in_use(cbuf *cb, char *type, char *message);
int netconf_invalid_value(cbuf *cb, char *type, char *message);
int netconf_too_big(cbuf *cb, char *type, char *message);
int netconf_missing_attribute(cbuf *cb,	char *type, char *info, char *message);
int netconf_bad_attribute(cbuf *cb, char *type, char *info, char *message);
int netconf_unknown_attribute(cbuf *cb,	char *type, char *info, char *message);
int netconf_missing_element(cbuf *cb, char *type, char *element, char *message);
int netconf_missing_element_xml(cxobj **xret, char *type, char *element, char *message);
int netconf_bad_element(cbuf *cb, char *type, char *info, char *element);
int netconf_bad_element_xml(cxobj **xret, char *type, char *info, char *element);
int netconf_unknown_element(cbuf *cb, char *type, char *element, char *message);
int netconf_unknown_element_xml(cxobj **xret, char *type, char *element, char *message);
int netconf_unknown_namespace(cbuf *cb, char *type, char *namespace, char *message);
int netconf_unknown_namespace_xml(cxobj **xret, char *type, char *namespace, char *message);
int netconf_access_denied(cbuf *cb, char *type, char *message);
int netconf_access_denied_xml(cxobj **xret, char *type, char *message);
int netconf_lock_denied(cbuf *cb, char *info, char *message);
int netconf_resource_denied(cbuf *cb, char *type, char *message);
int netconf_rollback_failed(cbuf *cb, char *type, char *message);
int netconf_data_exists(cbuf *cb, char *message);
int netconf_data_missing(cbuf *cb, char *missing_choice, char *message);
int netconf_data_missing_xml(cxobj **xret, char *missing_choice, char *message);
int netconf_operation_not_supported(cbuf *cb, char *type, char *message);
int netconf_operation_failed(cbuf *cb, char *type, char *message);
int netconf_operation_failed_xml(cxobj **xret, char *type, char *message);
int netconf_malformed_message(cbuf *cb, char *message);
int netconf_malformed_message_xml(cxobj **xret, char *message);
int netconf_data_not_unique_xml(cxobj **xret, cxobj *x,	cvec *cvk);
int netconf_minmax_elements_xml(cxobj **xret, cxobj *x, int max);
int netconf_trymerge(cxobj *x, yang_stmt *yspec, cxobj **xret);
int netconf_module_load(clicon_handle h);
char *netconf_db_find(cxobj *xn, char *name);
int netconf_err2cb(cxobj *xerr, cbuf **cberr);

#endif /* _CLIXON_NETCONF_LIB_H */
