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
 * Protocol to communicate with CLICON config daemon
 */

#ifndef _CLIXON_PROTO_H_
#define _CLIXON_PROTO_H_

/*
 * Types
 */
enum format_enum{
    MSG_NOTIFY_TXT, /* means filter works on strings */
    MSG_NOTIFY_XML, /* means filter works on xml */
};

/* See also map_type2str in clicon_proto.c */
enum clicon_msg_type{
    CLICON_MSG_NETCONF = 1, /* Generic netconf message (lock/unlock/..) can all
			   msgs go to this?
			  1. string: netconf message
			 */
    CLICON_MSG_CHANGE,   /* Change a (single) database entry:
			  1. uint32: operation: OP_MERGE/OP_REPLACE/OP_REMOVE
			  2. uint32: length of value string
			  3. string: name of database to change (eg "running")
			  4. string: key
			  5. string: value (can be NULL)
			 */
};

/* Protocol message header */
struct clicon_msg {
    uint16_t    op_len;      /* length of message. */
    uint16_t    op_type;     /* message type, see enum clicon_msg_type */
    char        op_body[0];  /* rest of message, actual data */
};

/*
 * Prototypes
 */ 
int clicon_connect_unix(char *sockpath);

int clicon_rpc_connect_unix(struct clicon_msg    *msg, 
			    char                 *sockpath,
			    char                **ret,
			    int                  *sock0);

int clicon_rpc_connect_inet(struct clicon_msg    *msg, 
			    char                 *dst, 
			    uint16_t              port,
			    char                **ret,
			    int                  *sock0);

int clicon_rpc(int s, struct clicon_msg *msg, char **xret);

int clicon_msg_send(int s, struct clicon_msg *msg);

int clicon_msg_rcv(int s, struct clicon_msg **msg, int *eof);

int send_msg_notify(int s, int level, char *event);

int send_msg_reply(int s, uint16_t type, char *data, uint16_t datalen);

int send_msg_ok(int s, char *data);

int send_msg_err(int s, int err, int suberr, char *format, ...);

int send_msg_netconf_reply(int s, char *format, ...);


#endif  /* _CLIXON_PROTO_H_ */
