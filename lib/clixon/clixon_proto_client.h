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

 *
 * Client-side functions for clicon_proto protocol
 * Historically this code was part of the clicon_cli application. But
 * it should (is?) be general enough to be used by other applications.
 */

#ifndef _CLIXON_PROTO_CLIENT_H_
#define _CLIXON_PROTO_CLIENT_H_

int clicon_rpc_connect(clicon_handle h, int *sock0);
int clicon_rpc_msg(clicon_handle h, struct clicon_msg *msg, cxobj **xret0);
int clicon_rpc_msg_persistent(clicon_handle h, struct clicon_msg *msg, cxobj **xret0, int *sock0);
int clicon_rpc_netconf(clicon_handle h, char *xmlst, cxobj **xret, int *sp);
int clicon_rpc_netconf_xml(clicon_handle h, cxobj *xml, cxobj **xret, int *sp);
int clicon_rpc_get_config(clicon_handle h, char *username, char *db, char *xpath, cvec *nsc, cxobj **xret);
int clicon_rpc_edit_config(clicon_handle h, char *db, enum operation_type op, 
			   char *xml);
int clicon_rpc_copy_config(clicon_handle h, char *db1, char *db2);
int clicon_rpc_delete_config(clicon_handle h, char *db);
int clicon_rpc_lock(clicon_handle h, char *db);
int clicon_rpc_unlock(clicon_handle h, char *db);
int clicon_rpc_get(clicon_handle h, char *xpath, cvec *nsc, netconf_content content, int32_t depth, cxobj **xret);
int clicon_rpc_get_pageable_list(clicon_handle h, char *datastore, char *xpath, yang_stmt *yli,
				 cvec *nsc, netconf_content content, int32_t depth,
				 char *limit, char *offset, char *direction, char *sort, char *where,
				 cxobj **xt);
int clicon_rpc_close_session(clicon_handle h);
int clicon_rpc_kill_session(clicon_handle h, uint32_t session_id);
int clicon_rpc_validate(clicon_handle h, char *db);
int clicon_rpc_commit(clicon_handle h);
int clicon_rpc_discard_changes(clicon_handle h);
int clicon_rpc_create_subscription(clicon_handle h, char *stream, char *filter, int *s);
int clicon_rpc_debug(clicon_handle h, int level);
int clicon_rpc_restconf_debug(clicon_handle h, int level);
int clicon_hello_req(clicon_handle h, uint32_t *id);

#endif  /* _CLIXON_PROTO_CLIENT_H_ */
