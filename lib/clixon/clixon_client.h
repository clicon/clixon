/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****
  */

#ifndef _CLIXON_CLIENT_H
#define _CLIXON_CLIENT_H

/*
 * Prototypes
 */

#ifdef __cplusplus
extern "C" {
#endif
    
int clixon_client_connect(void *h, const struct sockaddr* srv, int srv_sz);
int clixon_client_close(int sock);
int clixon_client_session_start(void *h, const char *db);
int clixon_client_session_end(void *h);
int clixon_client_subscribe(int sock, int priority, int nspace,
                         int *spoint, const char *fmt, ...);
int clixon_client_subscribe_done(int sock);
int clixon_client_read_subscription_socket(int sock, int sub_points[], int *resultlen);
int clixon_client_num_instances(int sock, const char *xnamespace, const char *xpath);
int clixon_client_get_bool(int sock, int *rval, const char *xnamespace, const char *xpath);
int clixon_client_get_str(int sock, char *rval, int n, const char *xnamespace, const char *xpath);
int clixon_client_get_u_int8(int sock, uint8_t *rval, const char *xnamespace, const char *xpath);
int clixon_client_get_u_int16(int sock, uint16_t *rval, const char *xnamespace, const char *xpath);
int clixon_client_get_u_int32(int sock, uint32_t *rval, const char *xnamespace, const char *xpath);
int clixon_client_get_u_int64(int sock, uint64_t *rval, const char *xnamespace, const char *xpath);

void *clixon_client_init(const char *name, FILE *estream, const int debug, const char *config_file);
int clixon_client_terminate(void *h);
    
#ifdef __cplusplus
}
#endif

#endif /* _CLIXON_CLIENT_H */
