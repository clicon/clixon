/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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
 * Part of the external API to plugins. Applications should not include
 * this file directly (only via clicon_backend.h).
 * Internal code should include this
 */

#ifndef _CLIXON_BACKEND_CLIENT_H_
#define _CLIXON_BACKEND_CLIENT_H_

/*
 * Types
 */
/* Backend client entry.
 * Keep state about every connected client.
 * References from RFC 6022, ietf-netconf-monitoring.yang sessions container
 * @note that there is a discrepancy here between a client and a session
 * A session may have multiple client endpoints, most notably a regular 
 * client socket and a separate notification client socket.
 * But they are the same session. 
 * But the clixon client-entry do not differentiate
 * @see backend_client_add
 */
struct client_entry{
    struct client_entry  *ce_next;    /* The clients linked list */
    struct sockaddr       ce_addr;    /* The clients (UNIX domain) address */
    int                   ce_s;       /* Stream socket to client */
    int                   ce_nr;      /* Client number (for dbg/tracing) */
    uint32_t              ce_id;      /* Session id, accessor functions: clicon_session_id_get/set */
    char                 *ce_username;/* Translated from peer user cred */
    clixon_handle         ce_handle;  /* clicon config handle (all clients have same?) */
    char                 *ce_transport; /* Identifies the transport for each session.
                                           Clixon-lib.yang extends these values by prefixing with
                                           "cl:", where cl is ensured to be declared ie by
                                           netconf-monitoring state */
    char                 *ce_source_host; /* Host identifier of the NETCONF client */
    struct timeval        ce_time;    /* Time at the server at which the session was established. */
    uint32_t              ce_in_rpcs ;       /* Number of correct <rpc> messages received. */
    uint32_t              ce_in_bad_rpcs;    /* Not correct <rpc> messages */
    uint32_t              ce_out_rpc_errors; /*  <rpc-error> messages*/
    uint32_t              ce_out_notifications; /* Outgoing notifications */
};
typedef struct client_entry client_entry;

/*
 * Prototypes
 */
client_entry *backend_client_find(clixon_handle h, uint32_t id);

#endif /* _CLIXON_BACKEND_CLIENT_H_ */
