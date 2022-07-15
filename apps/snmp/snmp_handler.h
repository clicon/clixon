/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2022 Olof Hagsand and Kristofer Hallin
  Sponsored by Siklu Communications LTD

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
  
 */

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _SNMP_HANDLER_H_
#define _SNMP_HANDLER_H_

/*
 * Prototypes
 */
int clixon_snmp_table_handler(netsnmp_mib_handler          *handler,
			      netsnmp_handler_registration *nhreg,
			      netsnmp_agent_request_info   *reqinfo,
			      netsnmp_request_info         *requests);
int clixon_snmp_scalar_handler(netsnmp_mib_handler          *handler,
			       netsnmp_handler_registration *nhreg,
			       netsnmp_agent_request_info   *reqinfo,
			       netsnmp_request_info         *requests);

#endif /* _SNMP_HANDLER_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif

