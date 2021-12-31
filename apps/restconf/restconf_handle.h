/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 *
 */

#ifndef _RESTCONF_HANDLE_H_
#define _RESTCONF_HANDLE_H_

/*
 * Prototypes 
 */
clicon_handle restconf_handle_init(void);
int           restconf_handle_exit(clicon_handle h);
char         *restconf_param_get(clicon_handle h, const char *param);
int           restconf_param_set(clicon_handle h, const char *param, char *val);
int           restconf_param_del_all(clicon_handle h);
clixon_auth_type_t restconf_auth_type_get(clicon_handle h);
int           restconf_auth_type_set(clicon_handle h, clixon_auth_type_t type);
int           restconf_pretty_get(clicon_handle h);
int           restconf_pretty_set(clicon_handle h, int pretty);
char         *restconf_fcgi_socket_get(clicon_handle h);
int           restconf_fcgi_socket_set(clicon_handle h, char *socketpath);

#endif  /* _RESTCONF_HANDLE_H_ */
