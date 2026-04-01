/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2026 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * gRPC/nghttp2 connection management for clixon_grpc
 */

#ifndef _GRPC_NGHTTP2_H_
#define _GRPC_NGHTTP2_H_

/* gRPC Length-Prefixed-Message prefix size: 1B compressed flag + 4B length */
#define GRPC_PREFIX_LEN 5

/* gRPC status codes (https://grpc.github.io/grpc/core/md_doc_statuscodes.html) */
#define GRPC_OK                  0
#define GRPC_CANCELLED           1
#define GRPC_UNKNOWN             2
#define GRPC_INVALID_ARGUMENT    3
#define GRPC_NOT_FOUND           5
#define GRPC_ALREADY_EXISTS      6
#define GRPC_PERMISSION_DENIED   7
#define GRPC_FAILED_PRECONDITION 9
#define GRPC_UNIMPLEMENTED       12
#define GRPC_INTERNAL            13
#define GRPC_UNAVAILABLE         14
#define GRPC_UNAUTHENTICATED     16

int grpc_listen_init(clixon_handle h, uint16_t port);
int grpc_send_framed(void *gc_opaque, int32_t stream_id,
                     const uint8_t *framed_buf, size_t framed_len,
                     int grpc_status, const char *grpc_msg);
void grpc_conns_free_all(void);

#endif /* _GRPC_NGHTTP2_H_ */
