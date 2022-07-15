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

#ifndef _SNMP_LIB_H_
#define _SNMP_LIB_H_

/*
 * Constants
 */
/* Need some way to multiplex SNMP_ and MIB errors on OE_SNMP error handler */
#define CLIXON_ERR_SNMP_MIB 0x1000

#define IETF_YANG_SMIV2_NS "urn:ietf:params:xml:ns:yang:ietf-yang-smiv2"

/* Special case/extended Clixon ASN1 types
 * Set in type_yang2asn1() if extended is true
 * Must be back to proper net-snmp ASN_ types in type_snmp2xml and type_xml2snmp
 * before calling netsnmp API
*/
#define CLIXON_ASN_EXTRAS       253 /* Special case clixon address >= this */
#define CLIXON_ASN_PHYS_ADDR    253 /* Special case phy-address */
#define CLIXON_ASN_FIXED_STRING 254 /* RFC2578 Sec 7.7: String-valued, fixed-length */
#define CLIXON_ASN_ROWSTATUS    255 

/*
 * Types 
 */
/* Userdata to pass around in netsmp callbacks
 */
struct clixon_snmp_handle {
    clicon_handle sh_h;
    yang_stmt    *sh_ys;               /* Leaf for scalar, list for table */
    oid           sh_oid[MAX_OID_LEN]; /* OID for debug, may be removed? */
    size_t        sh_oidlen;           
    char         *sh_default;          /* MIB default value leaf only */
    cvec         *sh_cvk_orig;         /* Index/Key variable values (original) */
    netsnmp_table_registration_info *sh_table_info; /* To mimic table-handler in libnetsnmp code 
						     * save only to free properly */
};
typedef struct clixon_snmp_handle clixon_snmp_handle;

/*
 * Prototypes
 */
int    oid_eq(const oid * objid0, size_t objid0len, const oid * objid1, size_t objid1len);
int    oid_append(const oid *objid0, size_t *objid0len, const oid *objid1, size_t objid1len);
int    oid_cbuf(cbuf *cb, const oid *objid, size_t objidlen);
int    oid_print(FILE *f, const oid *objid, size_t objidlen);
int    snmp_yang_type_get(yang_stmt *ys, yang_stmt **yrefp, char **origtypep, yang_stmt **yrestypep, char **restypep);
int    yangext_oid_get(yang_stmt *yn, oid *objid, size_t *objidlen, char **objidstr);
int    snmp_access_str2int(char *modes_str);
const char *snmp_msg_int2str(int msg);
void  *snmp_handle_clone(void *arg);
void   snmp_handle_free(void *arg);
int    type_yang2asn1(yang_stmt *ys, int *asn1_type, int extended);
int    type_snmp2xml(yang_stmt                  *ys,
		     int                        *asn1type,
		     netsnmp_variable_list      *requestvb,
		     netsnmp_agent_request_info *reqinfo,
		     netsnmp_request_info       *requests,
		     char                      **valstr);
int    type_xml2snmp_pre(char *xmlstr, yang_stmt *ys, char **snmpstr);
int    type_xml2snmp(char *snmpstr, int *asn1type, u_char **snmpval, size_t *snmplen, char **reason);
int    snmp_yang2xpath(yang_stmt *ys, cvec *keyvec, char **xpath);
int    snmp_str2oid(char *str, yang_stmt *yi, oid *objid, size_t *objidlen);
int    snmp_oid2str(oid **oidi, size_t *oidilen, yang_stmt *yi, cg_var *cv);
int    clixon_snmp_err_cb(void *handle, int suberr, cbuf *cb);
int    snmp_xmlkey2val_oid(cxobj *xrow, cvec *cvk_name, cvec **cvk_orig, oid *objidk, size_t *objidklen);

/*========== libnetsnmp-specific code =============== */
int    clixon_snmp_api_agent_check(void);
int    clixon_snmp_api_agent_cleanup(void);
int    clixon_snmp_api_oid_find(oid *oid1, size_t oidlen);

#endif /* _SNMP_LIB_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif

