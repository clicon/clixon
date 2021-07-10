/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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
 *  netconf capabilities
 *****************************************************************************/

#ifndef NETCONF_NETCONF_CAPABILITIES_H
#define NETCONF_NETCONF_CAPABILITIES_H

enum netconf_capability_store {
    SERVER,
    CLIENT
};

int netconf_capabilities_init(clicon_handle ch);
int netconf_capabilities_lock(clicon_handle ch, enum netconf_capability_store store);
int netconf_capabilities_put(clicon_handle ch, char * rawCapability, enum netconf_capability_store store);
int netconf_capabilities_check(clicon_handle ch, char * capability, enum netconf_capability_store store);
int netconf_capabilities_free(clicon_handle ch);

#endif //NETCONF_NETCONF_CAPABILITIES_H
