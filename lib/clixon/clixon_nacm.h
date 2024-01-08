/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
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

 * XML sort and earch functions when used with YANG
 */
#ifndef _CLIXON_NACM_H
#define _CLIXON_NACM_H

/*
 * Types
 */
/* NACM access rights, 
 * Note that these are not the same as netconf operations
 * @see rfc8341 3.2.2
 * @see enum operation_type  Netconf operations
 */
enum nacm_access{
    NACM_CREATE,
    NACM_READ,
    NACM_UPDATE,
    NACM_DELETE,
    NACM_EXEC
};

/*
 * Prototypes
 */
int nacm_rpc(char *rpc, char *module, char *username, cxobj *xnacm, cbuf *cbret);
int nacm_datanode_read(clixon_handle h, cxobj *xt, cxobj **xvec, size_t xlen, char *username,
                       cxobj *nacm_xtree);
int nacm_datanode_write(clixon_handle h, cxobj *xr, cxobj *xt,
                        enum nacm_access access,
                        char *username, cxobj *xnacm, cbuf *cbret);
int nacm_access_pre(clixon_handle h, char *peername, char *username, cxobj **xnacmp);
int verify_nacm_user(clixon_handle h, enum nacm_credentials_t cred, char *peername, char *nacmname, cbuf *cbret);

#endif /* _CLIXON_NACM_H */
