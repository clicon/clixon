/*
 *
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
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 * XML support functions.
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208/
 */
#ifndef _CLIXON_XML_H
#define _CLIXON_XML_H

/*
 * Constants
 */
/* If rpc call does not have a namespace (eg w xmlns) then use the default NETCONF
 * namespace (rfc6241 3.1)
 */
#define DEFAULT_XML_RPC_NAMESPACE "urn:ietf:params:xml:ns:netconf:base:1.0"
/* default namespace statement, such as in <rpc xmlns="..."> */
#define DEFAULT_XMLNS "xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\""

/*
 * Types
 */
/* Netconf operation type */
enum operation_type{ /* edit-configo */
    OP_MERGE,  /* merge config-data */
    OP_REPLACE,/* replace or create config-data */
    OP_CREATE, /* create config data, error if exist */
    OP_DELETE, /* delete config data, error if it does not exist */
    OP_REMOVE, /* delete config data (not a netconf feature) */
    OP_NONE
};

enum cxobj_type {CX_ERROR=-1, 
		 CX_ELMNT, 
		 CX_ATTR, 
		 CX_BODY};
#define CX_ANY CX_ERROR /* catch all and error is same */

typedef struct xml cxobj; /* struct defined in clicon_xml.c */

/*! Callback function type for xml_apply 
 * @retval    -1    Error, aborted at first error encounter
 * @retval     0    OK, continue
 * @retval     1    Abort, dont continue with others
 * @retval     2    Locally, just abort this subtree, continue with others
 */
typedef int (xml_applyfn_t)(cxobj *x, void *arg);

/*
 * xml_flag() flags:
 */
#define XML_FLAG_MARK   0x01  /* Marker for dynamic algorithms, eg expand */
#define XML_FLAG_ADD    0x02  /* Node is added (commits) or parent added rec*/
#define XML_FLAG_DEL    0x04  /* Node is deleted (commits) or parent deleted rec */
#define XML_FLAG_CHANGE 0x08  /* Node is changed (commits) or child changed rec */
#define XML_FLAG_NONE   0x10  /* Node is added as NONE */

/* Iterate through modules to find the matching datanode
 * or rpc if no xmlns attribute specifies namespace.
 * This is lazy non-strict semantics of finding namespaces.
 * And it is wrong, but is the way Clixon originally was written."
 * @see CLICON_XML_NS_STRICT clixon configure option 
 */
extern int _CLICON_XML_NS_STRICT;

/*
 * Prototypes
 */
char     *xml_type2str(enum cxobj_type type);
char     *xml_name(cxobj *xn);
int       xml_name_set(cxobj *xn, char *name);
char     *xml_prefix(cxobj *xn);
int       xml_prefix_set(cxobj *xn, char *name);
int       xml2ns(cxobj *x, char *localname, char **namespace);
int       xmlns_set(cxobj *x, char *prefix, char *namespace);
cxobj    *xml_parent(cxobj *xn);
int       xml_parent_set(cxobj *xn, cxobj *parent);

uint16_t  xml_flag(cxobj *xn, uint16_t flag);
int       xml_flag_set(cxobj *xn, uint16_t flag);
int       xml_flag_reset(cxobj *xn, uint16_t flag);

char     *xml_value(cxobj *xn);
int       xml_value_set(cxobj *xn, char *val);
char     *xml_value_append(cxobj *xn, char *val);
enum cxobj_type xml_type(cxobj *xn);
int       xml_type_set(cxobj *xn, enum cxobj_type type);

int       xml_child_nr(cxobj *xn);
int       xml_child_nr_type(cxobj *xn, enum cxobj_type type);
int       xml_child_nr_notype(cxobj *xn, enum cxobj_type type);
cxobj    *xml_child_i(cxobj *xn, int i);
cxobj    *xml_child_i_type(cxobj *xn, int i, enum cxobj_type type);
cxobj    *xml_child_i_set(cxobj *xt, int i, cxobj *xc);
cxobj    *xml_child_each(cxobj *xparent, cxobj *xprev,  enum cxobj_type type);

cxobj   **xml_childvec_get(cxobj *x);
int       xml_childvec_set(cxobj *x, int len);
cxobj    *xml_new(char *name, cxobj *xn_parent, yang_stmt *spec);
yang_stmt *xml_spec(cxobj *x);
int       xml_spec_set(cxobj *x, yang_stmt *spec);
cxobj    *xml_find(cxobj *xn_parent, char *name);

int       xml_addsub(cxobj *xp, cxobj *xc);
cxobj    *xml_insert(cxobj *xt, char *tag);
int       xml_purge(cxobj *xc);
int       xml_child_rm(cxobj *xp, int i);
int       xml_rm(cxobj *xc);
int       xml_rootchild(cxobj  *xp, int i, cxobj **xcp);

char     *xml_body(cxobj *xn);
cxobj    *xml_body_get(cxobj *xn);
char     *xml_find_type_value(cxobj *xn_parent, char *prefix,
			      char *name, enum cxobj_type type);
cxobj    *xml_find_type(cxobj *xn_parent, char *prefix, char *name, enum cxobj_type type);
char     *xml_find_value(cxobj *xn_parent, char *name);
char     *xml_find_body(cxobj *xn, char *name);
cxobj    *xml_find_body_obj(cxobj *xt, char *name, char *val);

int       xml_free(cxobj *xn);

int       xml_print(FILE  *f, cxobj *xn);
int       clicon_xml2file(FILE *f, cxobj *xn, int level, int prettyprint);
int       clicon_xml2cbuf(cbuf *xf, cxobj *xn, int level, int prettyprint);
int       xml_parse_file(int fd, char *endtag, yang_spec *yspec, cxobj **xt);
int       xml_parse_string(const char *str, yang_spec *yspec, cxobj **xml_top);
#if defined(__GNUC__) && __GNUC__ >= 3
int       xml_parse_va(cxobj **xt, yang_spec *yspec, const char *format, ...)  __attribute__ ((format (printf, 3, 4)));
#else
int       xml_parse_va(cxobj **xt, yang_spec *yspec, const char *format, ...);
#endif
int       xmltree2cbuf(cbuf *cb, cxobj *x, int level);
int       xml_copy_one(cxobj *xn0, cxobj *xn1);
int       xml_copy(cxobj *x0, cxobj *x1);
cxobj    *xml_dup(cxobj *x0);

int       cxvec_dup(cxobj **vec0, size_t len0, cxobj ***vec1, size_t *len1);
int       cxvec_append(cxobj *x, cxobj ***vec, size_t  *len);
int       xml_apply(cxobj *xn, enum cxobj_type type, xml_applyfn_t fn, void *arg);
int       xml_apply0(cxobj *xn, enum cxobj_type type, xml_applyfn_t fn, void *arg);
int       xml_apply_ancestor(cxobj *xn, xml_applyfn_t fn, void *arg);

int       xml_body_parse(cxobj *xb, enum cv_type type, cg_var **cvp);
int       xml_body_int32(cxobj *xb, int32_t *val);
int       xml_body_uint32(cxobj *xb, uint32_t *val);
int       xml_operation(char *opstr, enum operation_type *op);
char     *xml_operation2str(enum operation_type op);

#endif /* _CLIXON_XML_H */
