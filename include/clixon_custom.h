/*
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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

  Custom file as boilerplate appended by clixon_config.h 
  */

#ifndef HAVE_STRNDUP 
#define strndup(s, n) clicon_strndup(s, n)
#endif

/* Set if you want to assert that all rpc messages have set username
 */
#undef RPC_USERNAME_ASSERT

/* If rpc call does not have a namespace (eg using xmlns) then use the default 
 * NETCONF namespace (see rfc6241 3.1)
 * Undefine it if you want to ensure strict namespace assignment on all netconf and
 * XML statements.
 */
#define USE_NETCONF_NS_AS_DEFAULT

/* Make namespace check on RESTCONF PUT and POST -d data
 * Should be defined according to standard
 * Undefine it if you want allow no namespace (pick first name it finds in list
 * of loaded modules).
 */
#define RESTCONF_NS_DATA_CHECK
