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
 * Protocol to communicate between clients (eg clixon_cli, clixon_netconf) 
 * and server (clicon_backend)
 */

#ifndef _CLIXON_PROTO_ENCODE_H_
#define _CLIXON_PROTO_ENCODE_H_

/*
 * Prototypes
 */ 
struct clicon_msg *
clicon_msg_commit_encode(char *dbsrc, char *dbdst, 
			const char *label); 

int
clicon_msg_commit_decode(struct clicon_msg *msg, 
			char **dbsrc, char **dbdst, 
			const char *label);

struct clicon_msg *
clicon_msg_validate_encode(char *db,
			  const char *label);

int
clicon_msg_validate_decode(struct clicon_msg *msg, char **db,
			const char *label);

struct clicon_msg *
clicon_msg_change_encode(char *db, uint32_t op, char *key, 
			char *lvec, uint32_t lvec_len, 
			const char *label);

int
clicon_msg_change_decode(struct clicon_msg *msg, 
			char **db, uint32_t *op, char **key, 
			char **lvec, uint32_t *lvec_len, 
			const char *label);

struct clicon_msg *
clicon_msg_xmlput_encode(char       *db, 
			 uint32_t    op, 
			 char       *api_path, 
			 char       *xml, 
			 const char *label);

int
clicon_msg_xmlput_decode(struct clicon_msg *msg, 
			 char             **db, 
			 uint32_t          *op, 
			 char             **api_path, 
			 char             **xml, 
			 const char        *label);

struct clicon_msg *
clicon_msg_dbitems_get_reply_encode(cvec          **cvecv,
				int             cveclen,
				const char     *label);
int 
clicon_msg_dbitems_get_reply_decode(char              *data,
				uint16_t           datalen,
				cvec            ***cvecv,
				size_t            *cveclen,
				const char        *label);

struct clicon_msg *
clicon_msg_save_encode(char *db, uint32_t snapshot, char *filename, 
		      const char *label);

int
clicon_msg_save_decode(struct clicon_msg *msg, 
		      char **db, uint32_t *snapshot, char **filename, 
		      const char *label);

struct clicon_msg *
clicon_msg_load_encode(int replace, char *db, char *filename, 
		       const char *label);

int
clicon_msg_load_decode(struct clicon_msg *msg, 
		       int *replace, char **db, char **filename, 
		       const char *label);

struct clicon_msg *
clicon_msg_copy_encode(char *db_src, char *db_dst, 
		       const char *label);

int
clicon_msg_copy_decode(struct clicon_msg *msg, 
		      char **db_src, char **db_dst, 
		       const char *label);

struct clicon_msg *
clicon_msg_kill_encode(uint32_t session_id, const char *label);

int
clicon_msg_kill_decode(struct clicon_msg *msg, uint32_t *session_id, 
		      const char *label);

struct clicon_msg *
clicon_msg_debug_encode(uint32_t level, const char *label);

int
clicon_msg_debug_decode(struct clicon_msg *msg, uint32_t *level, 
		      const char *label);

struct clicon_msg *
clicon_msg_call_encode(uint16_t op, char *plugin, char *func,
		      uint16_t arglen, void *arg,
		      const char *label);

int
clicon_msg_call_decode(struct clicon_msg *msg, 
		      struct clicon_msg_call_req **req,
		      const char *label);

struct clicon_msg *
clicon_msg_subscription_encode(int status, 
			       char *stream, 
			       enum format_enum format,
			       char *filter, 
			       const char *label);

int clicon_msg_subscription_decode(struct clicon_msg *msg, 
				   int               *status, 
				   char             **stream, 
				   enum format_enum  *format,
				   char             **filter, 
				   const char        *label);

struct clicon_msg *
clicon_msg_notify_encode(int level, char *event, const char *label);

int 
clicon_msg_notify_decode(struct clicon_msg *msg, int *level,
			 char **event, const char *label);

struct clicon_msg *clicon_msg_err_encode(uint32_t err, uint32_t suberr, 
					 char *reason, const char *label);

int clicon_msg_err_decode(struct clicon_msg *msg, uint32_t *err, uint32_t *suberr,
			  char **reason, const char *label);

#endif  /* _CLIXON_PROTO_ENCODE_H_ */
