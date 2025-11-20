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

 *
 * Client-side functions for clicon_proto protocol
 * Not strict delimiter between these functions and the ones in
 * clixon_proto.[ch], but these are "higher level"
 */

#ifndef _CLIXON_PROTO_CLIENT_H_
#define _CLIXON_PROTO_CLIENT_H_

int clicon_rpc_msg(clixon_handle h, cbuf *cbsend, cxobj **xret0);
int clicon_rpc_msg_persistent(clixon_handle h, cbuf *cbsend, cxobj **xret0, int *sock0);
int clicon_rpc_netconf(clixon_handle h, char *xmlst, cxobj **xret, int *sp);
int clicon_rpc_netconf_xml(clixon_handle h, cxobj *xml, cxobj **xret, int *sp);
int clicon_rpc_get_config(clixon_handle h, char *username, char *db, char *xpath, cvec *nsc, char *defaults, cxobj **xret);
int clicon_rpc_edit_config(clixon_handle h, char *db, enum operation_type op,
                           char *xml);
int clicon_rpc_copy_config(clixon_handle h, char *db1, char *db2);
int clicon_rpc_delete_config(clixon_handle h, char *db);
int clicon_rpc_lock(clixon_handle h, char *db);
int clicon_rpc_unlock(clixon_handle h, char *db);
int clicon_rpc_get2(clixon_handle h, char *xpath, cvec *nsc, netconf_content content, int32_t depth, char *defaults, int bind, cxobj **xret);
int clicon_rpc_get(clixon_handle h, char *xpath, cvec *nsc, netconf_content content, int32_t depth, char *defaults, cxobj **xret);
int clicon_rpc_get_pageable_list(clixon_handle h, char *datastore, char *xpath,
                                 cvec *nsc, netconf_content content, int32_t depth, char *defaults,
                                 uint32_t offset, uint32_t limit,
                                 char *direction, char *sort, char *where,
                                 cxobj **xt);
int clicon_rpc_close_session(clixon_handle h);
int clicon_rpc_kill_session(clixon_handle h, uint32_t session_id);
int clicon_rpc_validate(clixon_handle h, char *db);
int clicon_rpc_commit(clixon_handle h, int confirmed, int cancel, uint32_t timeout, char *persist, char *persist_id);
int clicon_rpc_discard_changes(clixon_handle h);
int clicon_rpc_update(clixon_handle h);
int clicon_rpc_create_subscription(clixon_handle h, char *stream, char *filter, int *s);
int clicon_rpc_debug(clixon_handle h, int level);
int clicon_rpc_restconf_debug(clixon_handle h, int level);
int clicon_hello_req(clixon_handle h, char *transport, char *source_host, uint32_t *id);
int clixon_rpc_clixon_cache(clixon_handle h, const char *op, const char *type, const char *domain, const char *spec, const char *module, const char *revision, const char *keyword, const char *argument, cbuf *data);
int clicon_rpc_restart_plugin(clixon_handle h, char *plugin);

#endif  /* _CLIXON_PROTO_CLIENT_H_ */
