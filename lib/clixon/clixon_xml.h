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

 * Clixon XML object (cxobj) support functions.
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208/
 * Canonical XML version (just for info)
 *      https://www.w3.org/TR/xml-c14n
 */

#ifndef _CLIXON_XML_H
#define _CLIXON_XML_H

#include "clixon_yang.h"			/* for yang_stmt */

/*
 * Constants
 */

/*! Input symbol for netconf edit-config (+validate)
 *
 * ietf-netconf.yang defines is as input:
 *    choice edit-content {
 *       anyxml config;
 * See also DATASTORE_TOP_SYMBOL which is the clixon datastore top symbol. By default also config
 */
#define NETCONF_INPUT_CONFIG "config"

/* List pagination namespaces
 */

/* ietf-list-pagination.yang
 */
#define IETF_PAGINATON_NAMESPACE "urn:ietf:params:xml:ns:yang:ietf-list-pagination"

/* ietf-list-pagination-nc.yang
 */
#define IETF_PAGINATON_NC_NAMESPACE "urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc"

/*! RFC 6243 With-defaults Capability for NETCONF
 *
 * ietf-netconf-with-defaults
 * First in use in get requests
 */
#define IETF_NETCONF_WITH_DEFAULTS_YANG_NAMESPACE "urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults"

/*! Second in use in by replies for tagged attributes */
#define IETF_NETCONF_WITH_DEFAULTS_ATTR_NAMESPACE "urn:ietf:params:xml:ns:netconf:default:1.0"
#define IETF_NETCONF_WITH_DEFAULTS_ATTR_PREFIX "wd"

/*! Output symbol for netconf get/get-config
 *    ietf-netconf.yang defines it as output:
 *       output {    anyxml data;
 */
#define NETCONF_OUTPUT_DATA "data"

/*! Name of xml top object created by xml parse functions
 *
 * This is a "neutral" symbol without any meaning as opposed to the previous symbols ^
 * @see DATASTORE_TOP_SYMBOL which should be used for clixon top-level config trees
 */
#define XML_TOP_SYMBOL "top"

/*
 * Types
 */
/*! Netconf operation type */
enum operation_type{ /* edit-config operation */
    OP_MERGE,  /* merge config-data */
    OP_REPLACE,/* replace or create config-data */
    OP_CREATE, /* create config data, error if exist */
    OP_DELETE, /* delete config data, error if it does not exist */
    OP_REMOVE, /* delete config data (not a netconf feature) */
    OP_NONE
};

/*! Netconf insert type (see RFC7950 Sec 7.8.6) */
enum insert_type{ /* edit-config insert */
    INS_FIRST,
    INS_LAST,
    INS_BEFORE,
    INS_AFTER,
};

/*! XML object types */
enum cxobj_type {CX_ERROR=-1,
                 CX_ELMNT,
                 CX_ATTR,
                 CX_BODY};

/*! How to bind yang to XML top-level when parsing 
 *
 * Assume an XML tree x with parent xp (or NULL) and a set of children c1,c2:   
 *
 *                (XML)  xp  
 *                       |
 *                       x
 *                      / \
 *                     c1  c2
 * (1) If you make a binding using YB_MODULE, you assume there is a loaded module "ym" with a top-level
 * data resource "y" that the XML node x can match to:
 *
 *                (XML)  xp          ym (YANG)
 *                       |           |
 *                       x - - - - - y
 *                      / \         / \
 *                     x1  x2 - -  y1  y2
 * In that case, "y" is a container, list, leaf or leaf-list with same name as "x". 
 *
 * (2) If you make a binding using YB_PARENT, you assume xp already have a YANG binding (eg to "yp"):
 *
 *                (XML)  xp - - - -  yp (YANG)
 *                       |           
 *                       x           
 * so that the yang binding of "x" is a child of "yp":
 *
 *                (XML)  xp - - - -  yp (YANG)
 *                       |           |
 *                       x  - - - -  y         
 *                      / \         / \
 *                     x1  x2 - -  y1  y2
 */
enum yang_bind{
    YB_NONE=0,   /* Dont do Yang binding */
    YB_MODULE,   /* Search for matching yang binding among top-level symbols of Yang modules of direct
                  * children
                  * Ie, xml looks like: <top><x>... where "x" is a top-level symbol in a module
                  */
    YB_MODULE_NEXT, /* Search for matching yang binding among top-level symbols of Yang modules of
                  * next-level children
                  * Ie, xml looks like: <top><config><x>... where "x" is a top-level symbol in a module
                  */
    YB_PARENT,   /* Assume yang binding of existing parent and match its children by name */
    YB_RPC,      /* Assume top-level xml is an incoming netconf RPC message (or hello) */

};
typedef enum yang_bind yang_bind;

#define CX_ANY CX_ERROR /* catch all and error is same */

typedef struct xml cxobj; /* struct defined in clicon_xml.c */

/*! Callback function type for xml_apply
 *
 * @param[in]  x    XML node  
 * @param[in]  arg  General-purpose argument
 * @retval     2    Locally abort this subtree, continue with others
 * @retval     1    Abort, dont continue with others, return 1 to end user
 * @retval     0    OK, continue
 * @retval    -1    Error, aborted at first error encounter, return -1 to end user
 */
typedef int (xml_applyfn_t)(cxobj *x, void *arg);

typedef struct clixon_xml_vec clixon_xvec; /* struct defined in clicon_xml_vec.c */

/*! Alternative tree formats,
 *
 * @see format_int2str, format_str2int, datastore_format in clixon-lib.yang
 */
enum format_enum{
    FORMAT_XML,
    FORMAT_JSON,
    FORMAT_TEXT,
    FORMAT_CLI,
    FORMAT_NETCONF,  /* Last concrete format, used in code */
    FORMAT_DEFAULT,  /* Indirect: actual value in CLICON_CLI_OUTPUT_FORMAT */
    FORMAT_PIPE_XML_DEFAULT /* Meta: If pipe, xml, if not default */
};

/*! XML flags
 */
#define XML_FLAG_MARK      0x01 /* General-purpose eg expand and xpath_vec selection and
                                 * diffs between candidate and running */
#define XML_FLAG_TRANSIENT 0x02 /* Marker for dynamic algorithms, unmark asap */
#define XML_FLAG_ADD       0x04 /* Node is added (commits) or parent added rec*/
#define XML_FLAG_DEL       0x08 /* Node is deleted (commits) or parent deleted rec */
#define XML_FLAG_CHANGE    0x10 /* Node is changed (commits) or child changed rec */
#define XML_FLAG_NONE      0x20 /* Node is added as NETCONF edit-config operation=NONE */
#define XML_FLAG_DEFAULT   0x40 /* Added when a value is set as default @see xml_default */
#define XML_FLAG_TOP       0x80 /* Top datastore symbol */
#define XML_FLAG_BODYKEY  0x100 /* Text parsing key to be translated from body to key */
#define XML_FLAG_ANYDATA  0x200 /* Treat as anydata, eg mount-points before bound */
#define XML_FLAG_CACHE_DIRTY 0x400 /* This part of XML tree is not synced to disk */
#define XML_FLAG_SKIP      0x800 /* Node is skipped in xml_diff */
#define XML_FLAG_DENY     0x1000 /* Marked as read denied by NACM  */

/*
 * Prototypes
 */
const char *xml_type2str(enum cxobj_type type);
int       xml_stats_global(uint64_t *nr);
int       xml_stats(cxobj *xt, uint64_t *nrp, size_t *szp);
char     *xml_name(cxobj *xn);
int       xml_name_set(cxobj *xn, const char *name);
char     *xml_prefix(cxobj *xn);
int       xml_prefix_set(cxobj *xn, const char *name);
char     *nscache_get(cxobj *x, const char *prefix);
int       nscache_get_prefix(cxobj *x, const char *ns, char **prefix);
cvec     *nscache_get_all(cxobj *x);
int       nscache_set(cxobj *x, const char *prefix, const char *ns);
int       nscache_clear(cxobj *x);
int       nscache_replace(cxobj *x, cvec *ns);
cxobj    *xml_parent(cxobj *xn);
int       xml_parent_set(cxobj *xn, cxobj *parent);
#ifdef XML_PARENT_CANDIDATE
cxobj    *xml_parent_candidate(cxobj *xn);
int       xml_parent_candidate_set(cxobj *xn, cxobj *parent);
#endif /* XML_PARENT_CANDIDATE */

uint16_t  xml_flag(cxobj *xn, uint16_t flag);
int       xml_flag_set(cxobj *xn, uint16_t flag);
int       xml_flag_reset(cxobj *xn, uint16_t flag);

char     *xml_value(cxobj *xn);
int       xml_value_set(cxobj *xn, const char *val);
int       xml_value_append(cxobj *xn, const char *val);
enum cxobj_type xml_type(cxobj *xn);
enum cxobj_type xml_type_set(cxobj *xn, enum cxobj_type type);
int       xml_child_nr(cxobj *xn);
int       xml_child_nr_type(cxobj *xn, enum cxobj_type type);
int       xml_child_nr_notype(cxobj *xn, enum cxobj_type type);
int       xml_child_nr_set(cxobj *xn, size_t nr);
cxobj    *xml_child_i(cxobj *xn, int i);
cxobj    *xml_child_i_type(cxobj *xn, int i, enum cxobj_type type);
cxobj    *xml_child_i_set(cxobj *xt, int i, cxobj *xc);
int       xml_child_order(cxobj *xn, cxobj *xc);
int       xml_vector_decrement(cxobj *x, int nr);
cxobj    *xml_child_each(cxobj *xparent, cxobj *xprev,  enum cxobj_type type);
cxobj    *xml_child_each_attr(cxobj *xparent, cxobj *xprev);
int       xml_child_insert_pos(cxobj *x, cxobj *xc, int pos);
int       xml_childvec_set(cxobj *x, int len);
cxobj   **xml_childvec_get(cxobj *x);
int       clixon_child_xvec_append(cxobj *x, clixon_xvec *xv);
cxobj    *xml_new(const char *name, cxobj *xn_parent, enum cxobj_type type);
cxobj    *xml_new_body(const char *name, cxobj *parent, const char *val);
yang_stmt *xml_spec(cxobj *x);
int       xml_spec_set(cxobj *x, yang_stmt *spec);
cg_var   *xml_cv(cxobj *x);
int       xml_cv_set(cxobj *x, cg_var *cv);
cxobj    *xml_find(cxobj *xn_parent, const char *name);
int       xml_addsub(cxobj *xp, cxobj *xc);
cxobj    *xml_wrap_all(cxobj *xp, const char *tag);
cxobj    *xml_wrap(cxobj *xc, const char *tag);
int       xml_purge(cxobj *xc);
int       xml_child_rm(cxobj *xp, int i);
int       xml_rm(cxobj *xc);
int       xml_rm_children(cxobj *x, enum cxobj_type type);
int       xml_rootchild(cxobj  *xp, int i, cxobj **xcp);
int       xml_rootchild_node(cxobj  *xp, cxobj *xc);
int       xml_enumerate_children(cxobj *xp);
int       xml_enumerate_reset(cxobj *xp);
int       xml_enumerate_get(cxobj *x);

char     *xml_body(cxobj *xn);
cxobj    *xml_body_get(cxobj *xn);
char     *xml_find_type_value(cxobj *xn_parent, const char *prefix,
                              const char *name, enum cxobj_type type);
cxobj    *xml_find_type(cxobj *xn_parent, const char *prefix, const char *name, enum cxobj_type type);
char     *xml_find_value(cxobj *xn_parent, const char *name);
char     *xml_find_body(cxobj *xn, const char *name);
cxobj    *xml_find_body_obj(cxobj *xt, const char *name, const char *val);
int       xml_free0(cxobj *x);
int       xml_free(cxobj *xn);
int       xml_copy_one(cxobj *xn0, cxobj *xn1);
int       xml_copy(cxobj *x0, cxobj *x1);
cxobj    *xml_dup(cxobj *x0);
int       cxvec_dup(cxobj **vec0, int len0, cxobj ***vec1, int *len1);
int       cxvec_append(cxobj *x, cxobj ***vec, size_t *len);
int       cxvec_prepend(cxobj *x, cxobj ***vec, int *len);
int       xml_apply(cxobj *xn, enum cxobj_type type, xml_applyfn_t fn, void *arg);
int       xml_apply0(cxobj *xn, enum cxobj_type type, xml_applyfn_t fn, void *arg);
int       xml_apply_ancestor(cxobj *xn, xml_applyfn_t fn, void *arg);
int       xml_isancestor(cxobj *x, cxobj *xp);
cxobj    *xml_root(cxobj *xn);
int       xml_operation(const char *opstr, enum operation_type *op);
char     *xml_operation2str(enum operation_type op);
int       xml_attr_insert2val(const char *instr, enum insert_type *ins);
cxobj    *xml_add_attr(cxobj *xn, const char *name, const char *value,
                       const char *prefix, const char *ns);
#ifdef XML_EXPLICIT_INDEX
int       xml_search_index_p(cxobj *x);
int       xml_search_vector_get(cxobj *x, const char *name, clixon_xvec **xvec);
int       xml_search_child_insert(cxobj *xp, cxobj *x);
int       xml_search_child_rm(cxobj *xp, cxobj *x);
cxobj    *xml_child_index_each(cxobj *xparent, const char *name, cxobj *xprev, enum cxobj_type type);

#endif

#endif /* _CLIXON_XML_H */
