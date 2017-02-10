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

 *
 * Client-side functions for clicon_proto protocol
 * Historically this code was part of the clicon_cli application. But
 * it should (is?) be general enough to be used by other applications.
 */

#ifndef _CLIXON_PROTO_CLIENT_H_
#define _CLIXON_PROTO_CLIENT_H_

int clicon_rpc_commit(clicon_handle h, char *from, char *to);
int clicon_rpc_validate(clicon_handle h, char *db);
int clicon_rpc_change(clicon_handle h, char *db, 
		      enum operation_type op, char *key, char *val);

int clicon_rpc_xmlput(clicon_handle h, char *db, enum operation_type op, 
		      char *api_path, char *xml);
int clicon_rpc_dbitems(clicon_handle h, char *db, char *rx, 
		       char *attr, char *val, 
		       cvec ***cvv, size_t *cvvlen);
int clicon_rpc_save(clicon_handle h, char *dbname, int snapshot, char *filename);
int clicon_rpc_load(clicon_handle h, int replace, char *db, char *filename);
int clicon_rpc_copy(clicon_handle h, char *db1, char *db2);
int clicon_rpc_kill(clicon_handle h, int session_id);
int clicon_rpc_debug(clicon_handle h, int level);
int clicon_rpc_call(clicon_handle h, uint16_t op, char *plugin, char *func,
		    void *param, uint16_t paramlen, 
		    char **ret, uint16_t *retlen,
		    const void *label);
int clicon_rpc_subscription(clicon_handle h, int status, char *stream, 
			    enum format_enum format, char *filter, int *s);


#endif  /* _CLIXON_PROTO_CLIENT_H_ */
