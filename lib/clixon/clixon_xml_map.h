/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
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

 *
 * Translation / mapping code between formats
 */

#ifndef _CLIXON_XML_MAP_H_
#define _CLIXON_XML_MAP_H_

/*! Maximum number of supported bit positions in YANG "bits" data type.
 *
 * As defined in RFC7950 (section 9.7.4.2.) the position 
 * value must be in the range 0 to 4294967295. But who needs
 * that much bit positions? (To set bit 4'294'967'295 it would be
 * necessary to tranfer 4294967295/8 = 536'870'911 bytes!)
 */
#define CLIXON_BITS_POS_MAX 1024

/*
 * Types
 */
/*! Declared in clixon_yang_internal */
typedef enum yang_class yang_class;

/*
 * Prototypes
 */
int isxmlns(cxobj *x);
int xmlns_assign(cxobj *x);
int xml2cvec(cxobj *xt, yang_stmt *ys, cvec **cvv0);
int cvec2xml_1(cvec *cvv, const char *toptag, cxobj *xp, cxobj **xt0);
int xml_tree_prune_flagged_sub(cxobj *xt, int flag, int test, int *upmark);
int xml_tree_mark_flagged_sub(cxobj *xt, int flag, int test, int delmark, int *upmark);
int xml_tree_prune_flags(cxobj *xt, int flags, int mask);
int xml_tree_prune_flags1(cxobj *xt, int flags, int mask, int recurse, int *removed);
int xml_namespace_change(cxobj *x, const char *ns, const char *prefix);
int xml_sanity(cxobj *x, void  *arg);
int xml_non_config_data(cxobj *xt, cxobj **xerr);
int assign_namespace_element(cxobj *x0, cxobj *x1, cxobj *x1p);
int assign_namespace_body(cxobj *x0, cxobj *x1);
int yang_valstr2enum(yang_stmt *ytype, const char *valstr, char **enumstr);
int yang_bitsstr2val(clixon_handle h, yang_stmt *ytype, const char *bitsstr, unsigned char **outval, size_t *outlen);
int yang_bitsstr2flags(yang_stmt *ytype, const char *bitsstr, uint32_t *flags);
int yang_val2bitsstr(clixon_handle h, yang_stmt *ytype, unsigned char *outval, size_t snmplen, cbuf *cb);
int yang_bits_map(yang_stmt *yt, const char *str, const char *nodeid, uint32_t *flags);
int yang_enum2valstr(yang_stmt *ytype, const char *enumstr, char **valstr);
int yang_enum2int(yang_stmt *ytype, const char *enumstr, int32_t *val);
int yang_enum_int_value(cxobj *node, int32_t *val);
int xml_copy_marked(cxobj *x0, cxobj *x1);
int yang_check_when_xpath(cxobj *xn, cxobj *xp, yang_stmt *yn, int *hit, int *nrp, char **xpathp);
int yang_xml_mandatory(cxobj *xt, yang_stmt *ys);
int xml_rpc_isaction(cxobj *xn);
int xml_find_action(cxobj *xn, int top, cxobj **xap);
int purge_tagged_nodes(cxobj *xn, const char *ns, const char *name, const char *value, int keepnode);
int clixon_compare_xmls(cxobj *xc1, cxobj *xc2, enum format_enum format);
int xml_template_apply(cxobj *x, void *arg);

#endif  /* _CLIXON_XML_MAP_H_ */
