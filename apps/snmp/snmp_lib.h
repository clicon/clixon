/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2022 Olof Hagsand and Kristofer Hallin

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

#ifndef _SNMP_LIB_H_
#define _SNMP_LIB_H_

/*
 * Types 
 */
/* Userdata to pass around in netsmp callbacks
 */
struct clixon_snmp_handle {
    clicon_handle sh_h;
    yang_stmt    *sh_ys;
    oid           sh_oid[MAX_OID_LEN]; /* OID for debug, may be removed? */
    size_t        sh_oidlen;           
    char         *sh_default;          /* MIB default value leaf only */
    cvec         *sh_cvk;              /* Index/Key variables */
};
typedef struct clixon_snmp_handle clixon_snmp_handle;

/*
 * Prototypes
 */
int   snmp_access_str2int(char *modes_str);
const char *snmp_msg_int2str(int msg);
int   snmp_handle_free(clixon_snmp_handle *sh);
int   type_yang2asn1(yang_stmt *ys, int *asn1_type);
int   type_snmp2xml(yang_stmt                  *ys,
		    netsnmp_variable_list      *requestvb,
		    netsnmp_agent_request_info *reqinfo,
		    netsnmp_request_info       *requests,
		    char                      **valstr);
int   type_xml2snmpstr(char *xmlstr, yang_stmt *ys, char **snmpstr);
int   type_snmpstr2val(char *snmpstr, int *asn1type, u_char **snmpval, size_t *snmplen, char **reason);
int   yang2xpath(yang_stmt *ys, cvec *keyvec, char **xpath);

#endif /* _SNMP_LIB_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif

