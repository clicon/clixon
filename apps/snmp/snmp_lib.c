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
  * See RFC 6643
  * Extensions are grouped in some categories, the one I have seen are, example:
  * 1. leaf
  *      smiv2:max-access "read-write";
  *      smiv2:oid "1.3.6.1.4.1.8072.2.1.1";
  *      smiv2:defval "42"; (not always)
  * 2. container, list
  *      smiv2:oid "1.3.6.1.4.1.8072.2.1";	
  * 3. module level
  *      smiv2:alias "netSnmpExamples" {
  *        smiv2:oid "1.3.6.1.4.1.8072.2";
  *

 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <unistd.h>
#include <pwd.h>
#include <syslog.h>
#include <errno.h>
#include <signal.h>
#include <assert.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>    /* inet_addr */
#include <arpa/inet.h>
#include <netinet/ether.h> /* ether_aton */

/* net-snmp */
#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#include <net-snmp/agent/net-snmp-agent-includes.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include "snmp_lib.h"

/*
 * Local variables
 */
/* Mapping between yang keyword string <--> clixon constants 
 * Here is also the place where doc on some types store variables (cv)
 */
/* Mapping between smiv2 yang extension access string string <--> netsnmp handler codes (agent_handler.h) 
 * Here is also the place where doc on some types store variables (cv)
 * see netsnmp_handler_registration_create()
 */
static const map_str2int snmp_access_map[] = {
    {"read-only",             HANDLER_CAN_RONLY}, /* HANDLER_CAN_GETANDGETNEXT */
    {"read-write",            HANDLER_CAN_RWRITE}, /* HANDLER_CAN_GETANDGETNEXT | HANDLER_CAN_SET */
    {"not-accessible",        0}, // XXX
    {"accessible-for-notify", 0}, // XXX
    {NULL,                   -1}
};

/* Map between clixon and ASN.1 types. 
 * @see net-snmp/library/asn1.h
 * @see union netsnmp_vardata in net-snmp/types.h
 */
static const map_str2int snmp_type_map[] = {
    {"int32",        ASN_INTEGER},   // 2
    {"string",       ASN_OCTET_STR}, // 4
    {"enumeration",  ASN_INTEGER},   // 2 special case
    {"uint32",       ASN_GAUGE},     // 0x42 / 66
    {"uint32",       ASN_COUNTER},   // 0x41 / 65
    {"uint32",       ASN_TIMETICKS}, // 0x43 / 67
    {"uint64",       ASN_COUNTER64}, // 0x46 / 70
    {"boolean",      ASN_INTEGER},   // 2 special case -> enumeration
    {"string",       ASN_IPADDRESS}, // 64
    {NULL,           -1}
};

#define CLIXON_ASN_PHYS_ADDR    253 /* Special case phy-address */
#define CLIXON_ASN_FIXED_STRING 254 /* RFC2578 Sec 7.7: String-valued, fixed-length */

/* Map between clixon "orig" resolved type and ASN.1 types. 
 */
static const map_str2int snmp_orig_map[] = {
    {"counter32",             ASN_COUNTER},   // 0x41 / 65
    {"object-identifier-128", ASN_OBJECT_ID}, // 6
    {"AutonomousType",        ASN_OBJECT_ID}, // 6
    {"DateAndTime",           ASN_OCTET_STR}, // 4
    {"UUIDorZero",            ASN_OCTET_STR}, // 4
    {"binary",                ASN_OCTET_STR}, // 4
    {"timeticks",             ASN_TIMETICKS}, // 0x43 / 67
    {"timestamp",             ASN_TIMETICKS}, // 0x43 / 67
    {"InetAddress",           ASN_IPADDRESS}, // 0x40 / 64 (Dont see this being used)
    {"ipv4-address",          ASN_IPADDRESS}, // 0x40 / 64 (This is used instead)
    {"phys-address",          CLIXON_ASN_PHYS_ADDR}, /* Clixon extended string type */
    {NULL,                    -1}
};

/* Map between SNMP message / mode str and int form
 */
static const map_str2int snmp_msg_map[] = {
    {"MODE_SET_RESERVE1",    MODE_SET_RESERVE1}, // 0
    {"MODE_SET_RESERVE2",    MODE_SET_RESERVE2}, // 1
    {"MODE_SET_ACTION",      MODE_SET_ACTION},   // 2
    {"MODE_SET_COMMIT",      MODE_SET_COMMIT},   // 3
    {"MODE_SET_FREE",        MODE_SET_FREE},     // 4
    {"MODE_GET",             MODE_GET},          // 160
    {"MODE_GETNEXT",         MODE_GETNEXT},      // 161
    {NULL,                   -1}
};

/*! Translate from snmp string to int representation
 * @note Internal snmpd, maybe find something in netsnmpd?
 */
int
snmp_access_str2int(char *modes_str)
{
    return clicon_str2int(snmp_access_map, modes_str);
}

const char *
snmp_msg_int2str(int msg)
{
    return clicon_int2str(snmp_msg_map, msg);
}

/*! Check equality of two OIDs
 *
 * @param[in] objid0     First OID vector 
 * @param[in] objid0len  Length of first OID vector 
 * @param[in] objid1     Second OID vector 
 * @param[in] objid1len  Length of second OID vector 
 * @retval   0  Equal
 * @retval !=0  Not equal, see man memcmp
 * Should really be netsnmp lib function, but cant find any?
 */
int
oid_eq(const oid *objid0,
       size_t     objid0len,
       const oid *objid1,
       size_t     objid1len)
{
    size_t min;
    int    ret;

    if (objid0len < objid1len)
	min = objid0len;
    else
	min = objid1len;
    /* First compare common prefix */
    ret = memcmp(objid0, objid1, min*sizeof(*objid0));
    if (ret != 0)
	return ret;
    /* If equal, check lengths */
    if (objid0len < objid1len)
	return -1;
    else if (objid0len > objid1len)
	return 1;
    else
	return 0;
}

/*! Append a second OID to a first
 * @param[in,out] objid0     First OID vector 
 * @param[in,out] objid0len  Length of first OID vector 
 * @param[in]     objid1     Second OID vector 
 * @param[in]     objid1len  Length of second OID vector 
 * @retval        0          OK
 * @retval       -1          Error
 * Assume objid0 is allocated with MAX_OID_LEN > oid0len+oid1len
 */
int
oid_append(const oid *objid0,
	   size_t    *objid0len,
	   const oid *objid1,
	   size_t     objid1len)
{
    void *dst;

    dst =  (void*)objid0;
    dst += (*objid0len)*sizeof(*objid0);
    if (memcpy(dst, objid1, objid1len*sizeof(*objid0)) < 0){
	clicon_err(OE_UNIX, errno, "memcpy");
	return -1;
    }
    *objid0len += objid1len;
    return 0;
}

/*! Print objid to file
 * @see fprint_objid but prints symbolic
 */
int
oid_cbuf(cbuf       *cb,
	 const oid *objid,
	 size_t     objidlen)
{
    size_t i;

    for (i=0; i<objidlen; i++)
	cprintf(cb, ".%lu", objid[i]);
    return 0;
}

int
oid_print(FILE      *f,
	  const oid *objid,
	  size_t     objidlen)
{
    int retval = -1;
    cbuf *cb;

    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    oid_cbuf(cb, objid, objidlen);
    fprintf(stderr, "%s", cbuf_get(cb));
    fprintf(stderr, "\n");
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Variant of yang_type_get that follows leafrefs
 */
static int
snmp_yang_type_get(yang_stmt  *ys,
		   yang_stmt **yrefp,
		   char      **origtypep,
		   yang_stmt **yrestypep,
		   char      **restypep)
{
    int        retval = -1;
    yang_stmt *yrestype;        /* resolved type */
    char      *restype;         /* resolved type */
    char      *origtype = NULL; /* original type */
    yang_stmt *ypath;
    yang_stmt *yref = NULL;

    /* Get yang type of leaf and trasnslate to ASN.1 */
    if (yang_type_get(ys, &origtype, &yrestype, NULL, NULL, NULL, NULL, NULL) < 0)
	goto done;
    restype = yrestype?yang_argument_get(yrestype):NULL;
    if (strcmp(restype, "leafref")==0){
	if ((ypath = yang_find(yrestype, Y_PATH, NULL)) == NULL){
	    clicon_err(OE_YANG, 0, "No path in leafref");
	    goto done;
	}
	if (yang_path_arg(ys, yang_argument_get(ypath), &yref) < 0)
	    goto done;
	if (yref == NULL){ 
	    clicon_err(OE_YANG, 0, "No referred YANG node found for leafref path %s", yang_argument_get(ypath));
	    goto done;
	}
	if (origtype){
	    free(origtype);
	    origtype = NULL;
	}
	if (yang_type_get(yref, &origtype, &yrestype, NULL, NULL, NULL, NULL, NULL) < 0)
	    goto done;
	restype = yrestype?yang_argument_get(yrestype):NULL;
    }
    if (yrefp){
	if (yref)
	    *yrefp = yref;
	else
	    *yrefp = ys;
    }
    if (origtypep){
	*origtypep = origtype;
	origtype = NULL;
    }
    if (yrestypep)
	*yrestypep = yrestype;
    if (restypep)
	*restypep = restype;
    retval = 0;
 done:
    if (origtype)
	free(origtype);
    return retval;
}

/*! Given a YANG node, return SMIv2 oid extension as OID 
 * @param[in]  yn        Yang node
 * @param[out] objid     OID vector, assume allocated with MAX_OID_LEN > oidlen
 * @param[out] objidlen  Length of OID vector on return
 * @param[out] objidstrp Pointer to string (direct not malloced) optional
 * @retval     1         OK
 * @retval     0         Invalid, not found
 * @retval    -1         Error
 */
int
yangext_oid_get(yang_stmt *yn,
		oid       *objid,
		size_t    *objidlen,
    		char     **objidstrp)
{
    int        retval = -1;
    int        exist = 0;
    char      *oidstr = NULL;
    yang_stmt *yref = NULL;
    
    if (yang_keyword_get(yn) == Y_LEAF){
	if (snmp_yang_type_get(yn, &yref, NULL, NULL, NULL) < 0)
	    goto done;
    }
    else
	yref = yn;
    /* Get OID from table /list  */
    if (yang_extension_value(yref, "oid", IETF_YANG_SMIV2_NS, &exist, &oidstr) < 0)
	goto done;
    if (exist == 0 || oidstr == NULL){
	clicon_debug(1, "OID not found as SMIv2 yang extension of %s", yang_argument_get(yref));
	goto fail;
    }
    if (snmp_parse_oid(oidstr, objid, objidlen) == NULL){
	clicon_err(OE_XML, errno, "snmp_parse_oid");
	goto done;
    }
    if (objidstrp)
	*objidstrp = oidstr;
    retval = 1;
 done:
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! Duplicate clixon snmp handler struct
 * Use signature of libnetsnmp data_clone field of netsnmp_mib_handler in agent_handler.h
 * @param[in]  arg
 */
void*
snmp_handle_clone(void *arg)
{
    clixon_snmp_handle *sh0 = (clixon_snmp_handle *)arg;
    clixon_snmp_handle *sh1 = NULL;

    if (sh0 == NULL)
	return NULL;
    if ((sh1 = malloc(sizeof(*sh1))) == NULL){
       clicon_err(OE_UNIX, errno, "malloc");
       return NULL;
    }
    memset(sh1, 0, sizeof(*sh1));
    if (sh0->sh_cvk_orig &&
	(sh1->sh_cvk_orig = cvec_dup(sh0->sh_cvk_orig)) == NULL){
	clicon_err(OE_UNIX, errno, "cvec_dup");
	return NULL;
    }
    return (void*)sh1;
}

/*! Free clixon snmp handler struct
 * Use signature of libnetsnmp data_free field of netsnmp_mib_handler in agent_handler.h
 * @param[in]  arg
 */
void
snmp_handle_free(void *arg)
{
    clixon_snmp_handle *sh = (clixon_snmp_handle *)arg;

    if (sh != NULL){
	if (sh->sh_cvk_orig)
	    cvec_free(sh->sh_cvk_orig);
	if (sh->sh_table_info){
	    if (sh->sh_table_info->indexes){
		snmp_free_varbind(sh->sh_table_info->indexes);
	    }
	    free(sh->sh_table_info);
	}
	free(sh);
    }
}

/*! Translate from YANG to SNMP asn1.1 type ids (not value)
 *
 * @param[in]    ys         YANG leaf node
 * @param[out]   asn1_type  ASN.1 type id
 * @param[in]    extended   Special case clixon extended types used in xml<->asn1 data conversions
 * @retval   0   OK
 * @retval   -1  Error
 * @see type_yang2snmp, yang only
 * @note there are some special cases where extended clixon asn1-types are used to convey info
 * to type_snmpstr2val, these types are prefixed with CLIXON_ASN_
 */
int
type_yang2asn1(yang_stmt    *ys,
	       int          *asn1_type,
	       int           extended)
{
    int        retval = -1;
    char      *restype;         /* resolved type */
    char      *origtype = NULL; /* original type */
    int        at;
    yang_stmt *yrestype = NULL;

    /* Get yang type of leaf and translate to ASN.1 */
    if (snmp_yang_type_get(ys, NULL, &origtype, &yrestype, &restype) < 0)
	goto done;
    /* Translate to asn.1 
     * First try original type, first type 
     */
    if ((at = clicon_str2int(snmp_orig_map, origtype)) >= 0 &&
	(extended || (at != CLIXON_ASN_PHYS_ADDR && at != CLIXON_ASN_FIXED_STRING))){
	;
    }
    /* Then try fully resolved type */
    else if ((at = clicon_str2int(snmp_type_map, restype)) < 0){
	clicon_err(OE_YANG, 0, "No snmp translation for YANG %s type:%s",
		   yang_argument_get(ys), restype);
	goto done;
    }
    if (extended && at == ASN_OCTET_STR && yrestype){
	yang_stmt *yrp;
	char *display_hint = NULL;
	yrp = yang_parent_get(yrestype);
	if (yang_extension_value(yrp, "display-hint", IETF_YANG_SMIV2_NS, NULL, &display_hint) < 0)
	    goto done;	
	/* RFC2578/2579 but maybe all strings with display-hint should use this, eg exist>0? */
	if (display_hint && strcmp(display_hint, "255t")==0)
	    at = CLIXON_ASN_FIXED_STRING;
    }
    if (asn1_type)
	*asn1_type = at;
    retval = 0;
 done:
    if (origtype)
	free(origtype);
    return retval;
}

/*! Translate from yang/xml/clixon to SNMP/ASN.1
 *
 * @param[in]   snmpval  Malloc:ed snmp type
 * @param[in]   snmplen  Length of snmp type
 * @param[in]   reqinfo  snmpd API struct for error
 * @param[in]   requests snmpd API struct for error
 * @param[out]  valstr   Clixon/yang/xml string value, free after use)
 * @retval      1        OK, and valstr set
 * @retval      0        Invalid value or type
 * @retval      -1       Error
 * @see type_xml2snmp  for snmpget
 */
int
type_snmp2xml(yang_stmt                  *ys,
	      int                        *asn1type,
	      netsnmp_variable_list      *requestvb,
	      netsnmp_agent_request_info *reqinfo,
	      netsnmp_request_info       *requests,
	      char                      **valstr)
{
    int          retval = -1;
    char        *cvstr;
    enum cv_type cvtype;
    cg_var      *cv = NULL;
    char        *restype = NULL;         /* resolved type */
    char      *origtype = NULL; /* original type */
    yang_stmt   *yrestype = NULL;
    int          ret;

    clicon_debug(1, "%s", __FUNCTION__);
    if (valstr == NULL){
	clicon_err(OE_UNIX, EINVAL, "valstr is NULL");
	goto done;
    }
    if ((cvstr = (char*)clicon_int2str(snmp_type_map, requestvb->type)) == NULL){
	clicon_err(OE_XML, 0, "No mapping for snmp type %d", requestvb->type);
	goto done;
    }
    /* Get yang type of leaf and trasnslate to ASN.1 */
    if (snmp_yang_type_get(ys, NULL, &origtype, &yrestype, &restype) < 0)
	goto done;
    /* special case for enum */
    if (strcmp(cvstr, "int32")==0 && strcmp(restype, "enumeration") == 0)
	cvstr = "string";
    else if (strcmp(cvstr, "int32")==0 && strcmp(restype, "boolean") == 0)
	cvstr = "string";
    cvtype = cv_str2type(cvstr);
    if ((cv = cv_new(cvtype)) == NULL){
	clicon_err(OE_UNIX, errno, "cv_new");
	goto done; 
    }
    switch (*asn1type){
    case ASN_TIMETICKS:   // 67
    case ASN_INTEGER:   // 2
	if (cvtype == CGV_STRING){ 	/* special case for enum */
	    char *xmlstr;
	    cbuf *cb = NULL;

	    if (strcmp(restype, "enumeration") == 0){
		if ((cb = cbuf_new()) == NULL){
		    clicon_err(OE_UNIX, errno, "cbuf_new");
		    goto done;
		}
		cprintf(cb, "%ld", *requestvb->val.integer);
		if (yang_valstr2enum(yrestype, cbuf_get(cb), &xmlstr) < 0)
		    goto done;
		cbuf_free(cb);
	    }
	    else if (strcmp(restype, "boolean") == 0){
		if (*requestvb->val.integer == 1)
		    xmlstr = "true";
		else
		    xmlstr = "false";
	    }
	    cv_string_set(cv, xmlstr);
	}
	else
	    cv_int32_set(cv, *requestvb->val.integer);
	break;
    case ASN_GAUGE:     // 0x42
	cv_uint32_set(cv, *requestvb->val.integer);
	break;
    case ASN_IPADDRESS:{
	struct in_addr addr;
	memcpy(&addr.s_addr, requestvb->val.string, 4);	
	cv_string_set(cv, inet_ntoa(addr));
	break;
    }
    case CLIXON_ASN_FIXED_STRING:
	cv_string_set(cv, (char*)requestvb->val.string);
	*asn1type = ASN_OCTET_STR;
	break;
    case CLIXON_ASN_PHYS_ADDR:
	cv_string_set(cv, ether_ntoa((const struct ether_addr *)requestvb->val.string));
	*asn1type = ASN_OCTET_STR;	
	break;
    case ASN_OCTET_STR: // 4
	cv_string_set(cv, (char*)requestvb->val.string);
	break;
    case ASN_COUNTER64:{ // 0x46 / 70
	uint64_t u64;
	struct counter64 *c64;
	c64 = requestvb->val.counter64;
	u64 = c64->low;
	u64 += c64->high*0x100000000;
	cv_uint64_set(cv, u64);
	break;
    }
    default:
	assert(0); // XXX
	clicon_debug(1, "%s %s not supported", __FUNCTION__, cv_type2str(cvtype));
	if ((ret = netsnmp_request_set_error(requests, SNMP_ERR_WRONGTYPE)) != SNMPERR_SUCCESS){
	    clicon_err(OE_SNMP, ret, "netsnmp_request_set_error");
	    goto done;
	}
	goto fail;
	break;
    }
    if ((*valstr = cv2str_dup(cv)) == NULL){
	clicon_err(OE_UNIX, errno, "cv2str_dup");
	goto done;
    }
    retval = 1;
 done:
    clicon_debug(2, "%s %d", __FUNCTION__, retval);
    if (origtype)
	free(origtype);
    if (cv)
	cv_free(cv);
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! Given xml value and YANG,m return corresponding malloced snmp string
 *
 * For special cases to prepare for proper xml2snmp translation. This includes translating
 * from string values to numeric values for enumeration and boolean.
 * @param[in]   xmlstr0  XML string pre
 * @param[in]   ys       Yang node
 * @param[out]  xmlstr1  XML string ready for translation
 * @retval      1        OK
 * @retval      0        Invalid type
 * @retval      -1       Error
 * @see type_snmp2xml  for snmpset
 */
int
type_xml2snmp_pre(char      *xmlstr0,
		  yang_stmt *ys,
		  char     **xmlstr1)

{
    int        retval = -1;
    yang_stmt *yrestype;        /* resolved type */
    char      *restype = NULL;         /* resolved type */
    char      *str = NULL;
    int        ret;

    if (xmlstr1 == NULL){
	clicon_err(OE_UNIX, EINVAL, "xmlstr1");
	goto done;
    }
    /* Get yang type of leaf and trasnslate to ASN.1 */
    if (snmp_yang_type_get(ys, NULL, NULL, &yrestype, &restype) < 0) // XXX yrestype
	goto done;
    if (strcmp(restype, "enumeration") == 0){ 	/* special case for enum */
	if ((ret = yang_enum2valstr(yrestype, xmlstr0, &str)) < 0)
	    goto done;
	if (ret == 0){
	    clicon_debug(1, "Invalid enum valstr %s", xmlstr0);
	    goto fail;
	}
    }
    /* special case for bool: although smidump translates TruthValue to boolean
     * and there is an ASN_BOOLEAN constant:
     * 1) there is no code for ASN_BOOLEAN and
     * 2) Truthvalue actually translates to enum true(1)/false(0)
     */
    else if (strcmp(restype, "boolean") == 0){ 	
	if (strcmp(xmlstr0, "false")==0)
	    str = "0";
	else
	    str = "1";
    }
    else{
	str = xmlstr0;
    }
    if ((*xmlstr1 = strdup(str)) == NULL){
	clicon_err(OE_UNIX, errno, "strdup");
	goto done;
    }
    retval = 1;
 done:
    clicon_debug(2, "%s %d", __FUNCTION__, retval);
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! Given snmp string value (as translated frm XML) parse into snmp value
 *
 * @param[in]     snmpstr  SNMP type string
 * @param[in,out] asn1type ASN.1 type id
 * @param[out]    snmpval  Malloc:ed snmp type
 * @param[out]    snmplen  Length of snmp type
 * @param[out]    reason   Error reason if retval is 0
 * @retval        1        OK
 * @retval        0        Invalid
 * @retval       -1        Error
 * @note asn1type can be rewritten from CLIXON_ASN_ to ASN_
 * @see type_xml2snmp_pre for some pre-condition XML special cases (eg enums and bool)
 */
int
type_xml2snmp(char       *snmpstr,
	      int        *asn1type,
	      u_char    **snmpval,
	      size_t     *snmplen,
	      char      **reason)
{
    int   retval = -1;
    int   ret;

    if (snmpval == NULL || snmplen == NULL){
	clicon_err(OE_UNIX, EINVAL, "snmpval or snmplen is NULL");
	goto done;
    }
    switch (*asn1type){
    case ASN_INTEGER:   // 2
	*snmplen = 4;
	if ((*snmpval = malloc(*snmplen)) == NULL){
	    clicon_err(OE_UNIX, errno, "malloc");
	    goto done;
	}
	if ((ret = parse_int32(snmpstr, (int32_t*)*snmpval, reason)) < 0)
	    goto done;
	if (ret == 0)
	    goto fail;
	break;
    case ASN_TIMETICKS:
    case ASN_COUNTER: // 0x41
    case ASN_GAUGE:   // 0x42
	*snmplen = 4;
	if ((*snmpval = malloc(*snmplen)) == NULL){
	    clicon_err(OE_UNIX, errno, "malloc");
	    goto done;
	}
	if ((ret = parse_uint32(snmpstr, (uint32_t*)*snmpval, reason)) < 0)
	    goto done;
	if (ret == 0)
	    goto fail;

	break;
    case ASN_OBJECT_ID:{ // 6
	oid    oid1[MAX_OID_LEN] = {0,};
	size_t sz1 = MAX_OID_LEN;
	if (snmp_parse_oid(snmpstr, oid1, &sz1) == NULL){
	    clicon_debug(1, "Failed to parse OID %s", snmpstr);
	    goto fail;
	}
	*snmplen = sizeof(oid)*sz1;
	if ((*snmpval = malloc(*snmplen)) == NULL){
	    clicon_err(OE_UNIX, errno, "malloc");
	    goto done;
	}
	memcpy(*snmpval, oid1, *snmplen);
	break;
    }
    case ASN_OCTET_STR: // 4
	*snmplen = strlen(snmpstr)+1;
	if ((*snmpval = (u_char*)strdup((snmpstr))) == NULL){
	    clicon_err(OE_UNIX, errno, "strdup");
	    goto done;
	}
	break;
    case ASN_COUNTER64:{ // 0x46 / 70
	uint64_t u64;
	struct counter64 *c64;
	*snmplen = sizeof(struct counter64); // 16!
	if ((*snmpval = malloc(*snmplen)) == NULL){
	    clicon_err(OE_UNIX, errno, "malloc");
	    goto done;
	}
	memset(*snmpval, 0, *snmplen);
	if ((ret = parse_uint64(snmpstr, &u64, reason)) < 0)
	    goto done;
	c64 = (struct counter64 *)*snmpval;
	c64->low = u64&0xffffffff;
	c64->high = u64/0x100000000;
	if (ret == 0)
	    goto fail;
    }
	break;
    case ASN_IPADDRESS:{
	in_addr_t saddr;
	*snmplen = 4;
	if ((*snmpval = malloc(*snmplen)) == NULL){
	    clicon_err(OE_UNIX, errno, "malloc");
	    goto done;
	}
	saddr = (int32_t)inet_addr(snmpstr);
	memcpy(*snmpval, &saddr, 4);
	break;
    }
    case CLIXON_ASN_PHYS_ADDR:{
	struct ether_addr *eaddr;
	*snmplen = sizeof(*eaddr);
	if ((*snmpval = malloc(*snmplen + 1)) == NULL){
	    clicon_err(OE_UNIX, errno, "malloc");
	    goto done;
	}
	memset(*snmpval, 0, *snmplen + 1);
	if ((eaddr = ether_aton(snmpstr)) == NULL){
	    clicon_debug(1, "ether_aton(%s)", snmpstr);
	    goto fail;
	}
	memcpy(*snmpval, eaddr, sizeof(*eaddr));
	*asn1type = ASN_OCTET_STR;
	break;
    }
    case CLIXON_ASN_FIXED_STRING: /* OCTET-STRING with decrement length */
	*snmplen = strlen(snmpstr);
	if ((*snmpval = (u_char*)strdup((snmpstr))) == NULL){
	    clicon_err(OE_UNIX, errno, "strdup");
	    goto done;
	}
	*asn1type = ASN_OCTET_STR;
	break;
    default:
	assert(0);
    }
    retval = 1;
 done:
    clicon_debug(2, "%s %d", __FUNCTION__, retval);
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*! Construct an xpath from yang statement, internal fn using cb
 * Recursively construct it to the top.
 * @param[in]  ys     Yang statement
 * @param[in]  keyvec Cvec of key values
 * @param[out] cb     xpath as cbuf
 * @retval     0      OK
 * @retval    -1      Error
 * @see yang2xpath
 */ 
static int
snmp_yang2xpath_cb(yang_stmt *ys, 
		   cvec      *keyvec,
		   cbuf      *cb)
{
    yang_stmt *yp; /* parent */
    int        i;
    cvec      *cvk = NULL; /* vector of index keys */
    int        retval = -1;
    char      *prefix = NULL;
    
    if ((yp = yang_parent_get(ys)) == NULL){
	clicon_err(OE_YANG, EINVAL, "yang expected parent %s", yang_argument_get(ys));
	goto done;
    }
    if (yp != NULL && /* XXX rm */
	yang_keyword_get(yp) != Y_MODULE && 
	yang_keyword_get(yp) != Y_SUBMODULE){
	if (snmp_yang2xpath_cb(yp, keyvec, cb) < 0) /* recursive call */
	    goto done;
	if (yang_keyword_get(yp) != Y_CHOICE && yang_keyword_get(yp) != Y_CASE){
	    cprintf(cb, "/");
	}
    }
    prefix = yang_find_myprefix(ys);
    if (yang_keyword_get(ys) != Y_CHOICE && yang_keyword_get(ys) != Y_CASE){
	if (prefix)
	    cprintf(cb, "%s:", prefix);
	cprintf(cb, "%s", yang_argument_get(ys));
    }
    switch (yang_keyword_get(ys)){
    case Y_LIST:
	cvk = yang_cvec_get(ys); /* Use Y_LIST cache, see ys_populate_list() */
	/* Iterate over individual keys  */
	assert(keyvec && cvec_len(cvk) == cvec_len(keyvec));
	for (i=0; i<cvec_len(cvk); i++){
	    cprintf(cb, "[");
	    if (prefix)
		cprintf(cb, "%s:", prefix);
	    cprintf(cb, "%s='%s']",
		    cv_string_get(cvec_i(cvk, i)),
		    cv_string_get(cvec_i(keyvec, i)));
	}
	break;
    case Y_LEAF_LIST:
	assert(0); // NYI
	break;
    default:
	break;
    } /* switch */
    retval = 0;
 done:
    return retval;
}

/*! Construct an xpath from yang statement, limited to SNMP table translations
 * Recursively construct it to the top.
 * @param[in]  ys     Yang statement
 * @param[in]  keyvec Cvec of key values
 * @param[out] xpath  Malloced xpath string, use free() after use
 * @retval     0      OK
 * @retval     -1     Error
 * @note
 * 1. This should really be in a core .c file, like clixon_yang, BUT
 * 2. It is far from complete so maybe keep it here as a special case
 */ 
int
snmp_yang2xpath(yang_stmt *ys,
		cvec      *keyvec,
		char     **xpath)
{
    int   retval = -1;
    cbuf *cb = NULL;

    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    if (snmp_yang2xpath_cb(ys, keyvec, cb) < 0)
	goto done;
    if (xpath && (*xpath = strdup(cbuf_get(cb))) == NULL){
	clicon_err(OE_UNIX, errno, "strdup");
	goto done;
    }
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Translate from xml body string to SMI OID representation
 * For ints this is one to one, eg 42 -> 42
 * But for eg strings this is more complex, eg foo -> 3.6.22.22 (or something,...)
 * @param[in]  str      XML body string
 * @param[in]  yi       Yang statement
 * @param[out] objid    OID vector 
 * @param[out] objidlen Length of OID vector 
 */
int
snmp_str2oid(char      *str,
	     yang_stmt *yi,
	     oid       *objid,
	     size_t    *objidlen)	     
{
    int        retval = -1;
    int        asn1_type;
    int        i;
    int        j = 0;

    if (type_yang2asn1(yi, &asn1_type, 0) < 0)
	goto done;
    switch (asn1_type){
    case ASN_INTEGER:
    case ASN_GAUGE:
    case ASN_TIMETICKS:
    case ASN_COUNTER64:
    case ASN_COUNTER:
    case ASN_IPADDRESS:
	objid[j++] = atoi(str);
	break;
    case ASN_OCTET_STR:{ /* encode to N.c.c.c.c */
	objid[j++] = strlen(str);
	for (i=0; i<strlen(str); i++)
	    objid[j++] = str[i]&0xff;
	break;
    }
    default:
	break;
    }
    *objidlen = j;
    // ok:
    retval = 0;
 done:
    return retval;
}

/*! Translate from SMI OID representation to name
 * For ints this is one to one, eg 42 -> 42
 * But for eg strings this is more complex, eg foo -> 3.6.22.22 (or something,...)
 * @param[in,out] oidi     ObjID vector
 * @param[in,out] oidilen  Length of ObjID vector
 * @param[in]     yk       Yang statement of key
 * @param[out]    cv       CLIgen variable string notation as "x.y.z"
 * @see rfc2578 Section 7.7
 */
int
snmp_oid2str(oid      **oidi,
	     size_t    *oidilen,
	     yang_stmt *yk,
	     cg_var    *cv)
{
    int    retval = -1;
    int    asn1_type;
    int    i = 0;
    cbuf  *enc = NULL;
    size_t len;

    if (type_yang2asn1(yk, &asn1_type, 1) < 0)
	goto done;
    if ((enc = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    switch (asn1_type){
    case ASN_INTEGER:
    case ASN_GAUGE:
    case ASN_TIMETICKS:
    case ASN_COUNTER64:
    case ASN_COUNTER:
    case ASN_IPADDRESS:
	cprintf(enc, "%lu", (*oidi)[i++]);
	break;
    case CLIXON_ASN_PHYS_ADDR: /* XXX may need special mapping: ether_aton() ?  */
    case ASN_OCTET_STR: /* decode from N.c.c.c.c */
	len = (*oidi)[i++];
	for (; i<len+1; i++){
	    cprintf(enc, "%c", (char)((*oidi)[i]&0xff));
	}
	break;
    case CLIXON_ASN_FIXED_STRING: // XXX
	for (; i<7; i++){
	    cprintf(enc, "%c", (char)((*oidi)[i]&0xff));
	}
	break;
    default:
	break;
    }
    if (cbuf_len(enc)){
	if (cv_string_set(cv, cbuf_get(enc)) < 0){
	    clicon_err(OE_UNIX, errno, "cv_string_set");
	    goto done;
	}
    }
    if (i){
	(*oidi) += i;
	(*oidilen) -= i;
    }
    retval = 0;
 done:
    if (enc)
	cbuf_free(enc);
    return retval;
}

/*! Specialized SNMP error category log/err callback
 *
 * This function displays all negative SNMP errors on the form SNMPERR_* that are not 
 * SNMPERR_SUCCESS(=0)
 * There are also positive SNMP errors on the form SNMP_ERR_* which are not properly handled 
 * below
 * @param[in]    handle  Application-specific handle
 * @param[in]    suberr  Application-specific handle, points to SNMP_ERR_* unless 
                         < CLIXON_ERR_SNMP_MIB in which case they are MIB_* errors defined 
                         in agent_registry.h
  * @param[out]   cb     Read log/error string into this buffer
 * @note Some SNMP API functions sometimes returns NULL/ptr or other return values that do not fall into
 * this category, then OE_SNMP should NOT be used.
 */
int
clixon_snmp_err_cb(void *handle,
		   int   suberr,
		   cbuf *cb)
{
    const char *errstr;

    clicon_debug(1, "%s", __FUNCTION__);
    if (suberr < 0){
	if (suberr < -CLIXON_ERR_SNMP_MIB){
	    switch (suberr+CLIXON_ERR_SNMP_MIB){
	    case MIB_DUPLICATE_REGISTRATION:
		cprintf(cb, "Duplicate MIB registration");
		break;
	    case  MIB_REGISTRATION_FAILED:
		cprintf(cb, "MIB registration failed");
		break;
	    default:
		cprintf(cb, "unknown MIB error %d", suberr+CLIXON_ERR_SNMP_MIB);
		break;
	    }
	}
	else if ((errstr = snmp_api_errstring(suberr)) == NULL)
	    cprintf(cb, "unknown SNMP error %d", suberr);
	else
	    cprintf(cb, "%s", errstr);
    }
    else{ /* See eg SNMP_ERR_* in snmp.h for positive error numbers, are they applicable here? */
	cprintf(cb, "unknown error %d", suberr);
    }
    return 0;
}

/*! Given a XML list entry, return value and OID vector
 *
 * Given an XML list/table entry x with keys [i,j], such as:
 *   <x><i>1</i><j>a</j>...</x>
 * where i and j are list keys (table indexes)
 * Return two vectors:
 * - cvk_val: A vector of key values: [1,a]
 * - cvk_oid: A vector of OIDs: [1, 1.97]
 *
 * @param[in]  xentry   XML list entry
 * @param[in]  cvk_name Vector of list keys
 * @param[out] cvk_val  Vector of XML key values
 * @param[out] objidk   OID key part, to be appended to node OID
 * @retval     -1       Error
 * @retval     0        Invalid (not all indexes present)
 * @retval     1        OK
 * Both cvk_val and cvk_oid can be re-used in successive calls but need to be freed w cvec_free after use
 */
int
snmp_xmlkey2val_oid(cxobj     *xentry,
		    cvec      *cvk_name,
		    cvec     **cvk_val,
		    oid       *objidk,
		    size_t    *objidklen)
{
    int     retval = -1;
    cxobj  *xi;
    int     i;
    cg_var *cv;
    cg_var *cv0;
    oid     objid[MAX_OID_LEN] = {0,};
    size_t  objidlen = MAX_OID_LEN;
    
    *objidklen = 0;
    if (cvk_val){
	if (*cvk_val){
	    cvec_free(*cvk_val);
	    if ((*cvk_val = cvec_dup(cvk_name)) == NULL){
		clicon_err(OE_UNIX, errno, "cvec_dup");
		goto done;
	    }
	}
	else if ((*cvk_val = cvec_dup(cvk_name)) == NULL){
	    clicon_err(OE_UNIX, errno, "cvec_dup");
	    goto done;
	}
    }
    for (i=0; i<cvec_len(cvk_name); i++){
	cv0 = cvec_i(cvk_name, i); 
	if ((xi = xml_find_type(xentry, NULL, cv_string_get(cv0), CX_ELMNT)) == NULL)
	    break;
	if (cvk_val){
	    cv = cvec_i(*cvk_val, i); 
	    if (cv_string_set(cv, xml_body(xi)) < 0){
		clicon_err(OE_UNIX, errno, "cv_string_set");
		goto done;
	    }
	}
	if (snmp_str2oid(xml_body(xi), xml_spec(xi), objid, &objidlen) < 0)
	    goto done;
	if (oid_append(objidk, objidklen, objid, objidlen) < 0)
	    goto done;
    }
    if (i < cvec_len(cvk_name))
	goto fail; /* skip row, not all indexes */
    retval = 1;
 done:
    return retval;
 fail:
    retval = 0;
    goto done;
}

/*========== libnetsnmp-specific code ===============
 * Peeks into internal lib global variables, may be sensitive to library change
 */
/*! Check if netsnmp is connected 
 * @retval 1 yes, running
 * @retval 0 No, not running
 * XXX: this peeks into the "main_session" global variable in agent/snmp_agent.c
 *      Tried to find API function but failed
 */
int
clixon_snmp_api_agent_check(void)
{
    extern netsnmp_session *main_session;
    
    return (main_session != NULL) ? 1 : 0;
}

/*! Cleanup remaining libnetsnmb memory
 * XXX: this peeks into the "tclist" global variable in snmplib/parse.c
 *      Tried to find API function but failed
 */
int
clixon_snmp_api_agent_cleanup(void)
{
    extern void *tclist;
    
    if (tclist)
	free(tclist);
    return 0;
}

/*! See if oid is registered
 * This is good enough for add,
 * But for delete a more advanced function is needed
 * @see netsnmp_subtree_load
 * @retval -1 Error
 * @retval  0 Not found
 * @retval  1 Found
 */
int
clixon_snmp_api_oid_find(oid   *oid0,
			 size_t oid0len)
{
    int              retval = -1;
    netsnmp_subtree *tree1 = NULL;
    
    if ((tree1 = netsnmp_subtree_find(oid0, oid0len, NULL, "")) != NULL &&
	oid_eq(oid0, oid0len, tree1->name_a, tree1->namelen)==0){
	retval = 1;
    }
    else
	retval = 0;
    // done:
    return retval;
}

