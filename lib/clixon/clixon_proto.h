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
 * Protocol to communicate with CLICON config daemon
 */

#ifndef _CLIXON_PROTO_H_
#define _CLIXON_PROTO_H_

/*
 * Prototypes
 */

int clixon_inet2sin(const char *addrtype, const char *addrstr, uint16_t port,
                    struct sockaddr *sa, size_t *sa_len);

/* Connect */
int clixon_rpc_connect_unix(clixon_handle h, const char *sockpath, int *sock0);
int clixon_rpc_connect_inet(clixon_handle h, const char *dst, uint16_t port,
                            int *sock0);
int clixon_rpc_connect(clixon_handle h, int *sock0);

/* NETCONF 1.0 */
int clixon_msg_rcv10(int s, const char *descr, cbuf **msg, int *eof);
int clixon_msg_send10(int s, const char *descr, cbuf *msg);
int clixon_rpc10(int sock, const char *descr, cbuf *msgin, cbuf **msgret, int *eof);

/* NETCONF 1.1 */
int clixon_msg_rcv11(int s, const char *descr, int intr, cbuf **msg, int *eof);
int clixon_rpc11(int sock, const char *descr, cbuf *msg, cbuf **msgret, int *eof);
int clixon_msg_send11(int s, const char *descr, cbuf *msg);

int clixon_msg_send(int s, const char *descr, cbuf *cb);
int send_msg_reply(int s, const char *descr, char *data, uint32_t datalen);
int send_msg_notify_xml(clixon_handle h, int s, const char *descr, cxobj *xev);

#endif  /* _CLIXON_PROTO_H_ */
