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
struct clicon_msg *clicon_msg_netconf_encode(char *format, ...);
struct clicon_msg *clicon_msg_netconf_encode_xml(cxobj *xml);

int clicon_msg_netconf_decode(struct clicon_msg *msg, cxobj **xml);

struct clicon_msg *
clicon_msg_change_encode(char *db, uint32_t op, char *key, 
			 char *lvec, uint32_t lvec_len);

int
clicon_msg_change_decode(struct clicon_msg *msg, 
			char **db, uint32_t *op, char **key, 
			char **lvec, uint32_t *lvec_len, 
			const char *label);

struct clicon_msg *
clicon_msg_dbitems_get_reply_encode(cvec          **cvecv,
				    int             cveclen);
int 
clicon_msg_dbitems_get_reply_decode(char              *data,
				uint16_t           datalen,
				cvec            ***cvecv,
				size_t            *cveclen,
				const char        *label);

#endif  /* _CLIXON_PROTO_ENCODE_H_ */
