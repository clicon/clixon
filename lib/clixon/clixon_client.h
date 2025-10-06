/*
 *
  ***** BEGIN LICENSE BLOCK *****

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
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****
  *
  */

#ifndef _CLIXON_CLIENT_H
#define _CLIXON_CLIENT_H

/*
 * Types
 */
typedef void *clixon_handle;
typedef void *clixon_client_handle;

/* Connection type as parameter to connect
 */
typedef enum {
    /* Internal IPC API, connect directly on local UNIX domain socket to backend
     * or using IP according to CLICON_SOCK_FAMILY setting
     * see https://clixon-docs.readthedocs.io/en/latest/netconf.html#ipc
     * Must be local on device
     */
    CLIXON_CLIENT_IPC,
    /* Regular NETCONF via local netconf binary
     * Fork clixon_netconf locally which in turn communicates with backend
     * Must be local on device
     */
    CLIXON_CLIENT_NETCONF,
    /* Regular NETCONF using ssh sub-system via local SSH (openssh) client binary
     * Fork ssh locally which in turn communicates remotely to device
     * Must have openssh installed locally and device must have ssh sub-subsystem
     */
    CLIXON_CLIENT_SSH
} clixon_client_type;

/*
 * Prototypes
 */

#ifdef __cplusplus
extern "C" {
#endif

clixon_handle clixon_client_init(const char *config_file);
int   clixon_client_terminate(clixon_handle h);
int   clixon_client_hello(int sock, const char *descr, int base10, int base11, int privcand);
clixon_client_handle clixon_client_connect(clixon_handle h, clixon_client_type socktype, const char *dest);
int   clixon_client_disconnect(clixon_client_handle ch);
int   clixon_client_get_bool(clixon_client_handle ch, int *rval, const char *xnamespace, const char *xpath);
int   clixon_client_get_str(clixon_client_handle ch, char *rval, int n, const char *xnamespace, const char *xpath);
int   clixon_client_get_uint8(clixon_client_handle ch, uint8_t *rval, const char *xnamespace, const char *xpath);
int   clixon_client_get_uint16(clixon_client_handle ch, uint16_t *rval, const char *xnamespace, const char *xpath);
int   clixon_client_get_uint32(clixon_client_handle ch, uint32_t *rval, const char *xnamespace, const char *xpath);
int   clixon_client_get_uint64(clixon_client_handle ch, uint64_t *rval, const char *xnamespace, const char *xpath);

/* Access functions */
int   clixon_client_socket_get(clixon_client_handle ch);

#ifdef __cplusplus
}
#endif

#endif /* _CLIXON_CLIENT_H */
