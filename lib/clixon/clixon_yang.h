/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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

 * Yang functions
 * @see https://tools.ietf.org/html/rfc6020 YANG 1.0
 * @see https://tools.ietf.org/html/rfc7950 YANG 1.1
 */

#ifndef _CLIXON_YANG_H_
#define _CLIXON_YANG_H_

/*
 * Clixon-specific cligen variable (cv) flags
 * CLIgen flags defined are in the range 0x01 -0x0f
 * An application can use any flags above that
 * @see cv_flag
 */
#define V_UNSET   0x10  /* Used by XML code to denote a value is not default */

/*
 * Yang flags used in
 */
#define YANG_FLAG_MARK  0x01  /* (Dynamic) marker for dynamic algorithms, eg expand and DAG */
#define YANG_FLAG_TMP   0x02  /* (Dynamic) marker for dynamic algorithms, eg DAG detection */
#define YANG_FLAG_NOKEY 0x04  /* Key not mandatory in this list, see eg yang-data extension in
                               * RFC 8040 / ietf-restconf.yang
                               * see restconf_main_extension_cb
                               */
#ifdef XML_EXPLICIT_INDEX
#define YANG_FLAG_INDEX 0x08  /* This yang node under list is (extra) index. --> you can access
                               * list elements using this index with binary search */
#endif
#define YANG_FLAG_STATE_LOCAL  0x10  /* Local inverted value of Y_CONFIG child */
#define YANG_FLAG_DISABLED     0x40  /* Disabled due to if-feature evaluate to false
                                      * Transformed to ANYDATA but some code may need to check
                                      * why it is an ANYDATA
                                      */
#define YANG_FLAG_GROUPING     0x80  /* Mark node as uses/grouping expansion:
                                      * 1) for uses: this uses is expanded
                                      * 2) for grouping: all uses below are expanded
                                      * 3) other nodes: expanded from previous uses
                                      *  container x {
                                      *     ...
                                      *     uses y;  YANG_FLAG_GROUPING (1)
                                      *     leaf z;  YANG_FLAG_GROUPING (3)
                                      *     ...
                                      *  group y {   YANG_FLAG_GROUPING (2)
                                      *     leaf z;
                                      *  }
                                      */
#define YANG_FLAG_MTPOINT_POTENTIAL 0x100 /* Mark node as POTENTIAL mount-point, ie it fulfils:
                                      * - is CONTAINER or LIST, AND
                                      * - has YANG schema mount "mount-point" as child element, AND
                                      * - the extension label matches y (see note below)
                                      * Set by ys_populate2
                                      * Read by yang_schema_mount_point
                                      */
#define YANG_FLAG_MOUNTPOINT   0x200 /* Mark node as ACTUAL populated mount-point
                                      * Set by yang_mount_set 
                                      * Read by ys_free1
                                      */
#define YANG_FLAG_SPEC_MOUNT   0x400 /* Top-level spec is mounted by other top-level tree
                                      */
#define YANG_FLAG_WHEN         0x800 /* Use external map to access when-info for
                                      * augment/grouping. Only orig object */
#define YANG_FLAG_MYMODULE    0x1000 /* Use external map to access my-module for
                                      * UNKNOWNS and augment/grouping */
#define YANG_FLAG_REFINE      0x2000 /* In derived trees from grouping and augments, this node
                                      * may be different from orig, therefore do not use link to
                                      * original. May also be due to deviations of derived trees
                                      */
/*! Names of top-level data YANGs
 */
#define YANG_DOMAIN_TOP "top"
#define YANG_DATA_TOP   "data"    /* "dbspec" */
#define YANG_CONFIG_TOP "config"
#define YANG_NACM_TOP   "nacm_ext_yang"

/*
 * Types
 */
/*! YANG keywords from RFC6020.
 *
 * See also keywords generated by yacc/bison in clicon_yang_parse.tab.h, but they start with K_
 * instead of Y_
 * Wanted to unify these (K_ and Y_) but gave up for several reasons:
 * - Dont want to expose a generated yacc file to the API
 * - Cant use the symbols in this file because yacc needs token definitions
 * - Use 0 as no keyword --> therefore start enumeration with 1.
 * @see ykmap for string/symbol mapping
 */
enum rfc_6020{
    Y_ACTION = 1,
    Y_ANYDATA,
    Y_ANYXML,
    Y_ARGUMENT,
    Y_AUGMENT,
    Y_BASE,
    Y_BELONGS_TO,
    Y_BIT,
    Y_CASE,
    Y_CHOICE,          /* 10 */
    Y_CONFIG,
    Y_CONTACT,
    Y_CONTAINER,
    Y_DEFAULT,
    Y_DESCRIPTION,
    Y_DEVIATE,
    Y_DEVIATION,
    Y_ENUM,
    Y_ERROR_APP_TAG,
    Y_ERROR_MESSAGE,   /* 20 */
    Y_EXTENSION,
    Y_FEATURE,
    Y_FRACTION_DIGITS,
    Y_GROUPING,
    Y_IDENTITY,
    Y_IF_FEATURE,
    Y_IMPORT,
    Y_INCLUDE,
    Y_INPUT,
    Y_KEY,             /* 30 */
    Y_LEAF,
    Y_LEAF_LIST,
    Y_LENGTH,
    Y_LIST,
    Y_MANDATORY,
    Y_MAX_ELEMENTS,
    Y_MIN_ELEMENTS,
    Y_MODIFIER,
    Y_MODULE,
    Y_MUST,             /* 40 */
    Y_NAMESPACE,
    Y_NOTIFICATION,
    Y_ORDERED_BY,
    Y_ORGANIZATION,
    Y_OUTPUT,
    Y_PATH,
    Y_PATTERN,
    Y_POSITION,
    Y_PREFIX,
    Y_PRESENCE,         /* 50 */
    Y_RANGE,
    Y_REFERENCE,
    Y_REFINE,
    Y_REQUIRE_INSTANCE,
    Y_REVISION,
    Y_REVISION_DATE,
    Y_RPC,
    Y_STATUS,
    Y_SUBMODULE,
    Y_TYPE,            /* 60 */
    Y_TYPEDEF,
    Y_UNIQUE,
    Y_UNITS,
    Y_UNKNOWN,
    Y_USES,
    Y_VALUE,
    Y_WHEN, /* See also ys_when_xpath / ys_when_nsc */
    Y_YANG_VERSION,
    Y_YIN_ELEMENT,
    /* Note, from here not actual yang statement from the RFC */
    Y_MOUNTS, /* Top-level root single object, see clixon_yang_mounts_get() */
    Y_DOMAIN, /* YANG domain: many module revisions allowed but name+revision unique */
    Y_SPEC    /* Module set for single data, config and mount-point: unique module name */
};

/* Type used to group yang nodes used in some functions
 * See RFC7950 Sec 3
 */
enum yang_class{
    YC_NONE,            /* Someting else,... */
    YC_DATANODE,        /* See yang_datanode() */
    YC_DATADEFINITION,  /* See yang_datadefinition() */
    YC_SCHEMANODE       /* See yang_schemanode() */
};
typedef enum yang_class yang_class;

struct xml;

/* This is the external handle type exposed in the API.
 * The internal struct is defined in clixon_yang_internal.h */
typedef struct yang_stmt yang_stmt;

/*! Yang apply function worker
 *
 * @param[in]  yn   yang node
 * @param[in]  arg  Argument
 * @retval     2    Locally abort this subtree, continue with others
 * @retval     1    OK, abort traversal and return to caller with "n"
 * @retval     0    OK, continue with next
 * @retval    -1    Error, abort
 */
typedef int (yang_applyfn_t)(yang_stmt *ys, void *arg);

/* Validation level at commit */
enum validate_level_t {
    VL_FULL = 0, /* Do full RFC 7950 validation , 0 : backward-compatible */
    VL_NONE,     /* Do not do any validation */
};
typedef enum validate_level_t validate_level;

/* Yang data definition statement
 * See RFC 7950 Sec 3:
 *   o  data definition statement: A statement that defines new data
 *      nodes.  One of "container", "leaf", "leaf-list", "list", "choice",
 *      "case", "augment", "uses", "anydata", and "anyxml".
 */
#define yang_datadefinition(y) (yang_datanode(y) || yang_keyword_get(y) == Y_CHOICE || yang_keyword_get(y) == Y_CASE || yang_keyword_get(y) == Y_AUGMENT || yang_keyword_get(y) == Y_USES)

/* Yang schema node .
 * See RFC 7950 Sec 3:
 *    o  schema node: A node in the schema tree.  One of action, container,
 *       leaf, leaf-list, list, choice, case, rpc, input, output,
 *       notification, anydata, and anyxml.
 */
#define yang_schemanode(y) (yang_datanode(y) || yang_keyword_get(y) == Y_RPC || yang_keyword_get(y) == Y_CHOICE || yang_keyword_get(y) == Y_CASE || yang_keyword_get(y) == Y_INPUT || yang_keyword_get(y) == Y_OUTPUT || yang_keyword_get(y) == Y_NOTIFICATION || yang_keyword_get(y) == Y_ACTION)

/*
 * Prototypes
 */
/* Access functions */
int        yang_len_get(yang_stmt *ys);
yang_stmt *yang_child_i(yang_stmt *ys, int i);
yang_stmt *yang_parent_get(yang_stmt *ys);
enum rfc_6020 yang_keyword_get(yang_stmt *ys);
char      *yang_argument_get(yang_stmt *ys);
int        yang_argument_set(yang_stmt *ys, char *arg);
int        yang_argument_dup(yang_stmt *ys, char *arg);
yang_stmt *yang_orig_get(yang_stmt *ys);
int        yang_orig_set(yang_stmt *ys, yang_stmt *y0);
cg_var    *yang_cv_get(yang_stmt *ys);
int        yang_cv_set(yang_stmt *ys, cg_var *cv);
cvec      *yang_cvec_get(yang_stmt *ys);
int        yang_cvec_set(yang_stmt *ys, cvec *cvv);
cg_var    *yang_cvec_add(yang_stmt *ys, enum cv_type type, char *name);
int        yang_cvec_rm(yang_stmt *ys, char *name);
int        yang_ref_get(yang_stmt *ys);
int        yang_ref_inc(yang_stmt *ys);
int        yang_ref_dec(yang_stmt *ys);
uint16_t   yang_flag_get(yang_stmt *ys, uint16_t flag);
int        yang_flag_set(yang_stmt *ys, uint16_t flag);
int        yang_flag_reset(yang_stmt *ys, uint16_t flag);
yang_stmt *yang_when_get(clixon_handle h, yang_stmt *ys);
int        yang_when_set(clixon_handle h, yang_stmt *ys, yang_stmt *ywhen);
int        yang_when_xpath_get(yang_stmt *ys, char **xpath, cvec **nsc);
int        yang_when_canonical_xpath_get(yang_stmt *ys, char **xpath, cvec **nsc);
const char *yang_filename_get(yang_stmt *ys);
int        yang_filename_set(yang_stmt *ys, const char *filename);
uint32_t   yang_linenum_get(yang_stmt *ys);
int        yang_linenum_set(yang_stmt *ys, uint32_t linenum);
void      *yang_typecache_get(yang_stmt *ys);
int        yang_typecache_set(yang_stmt *ys, void *ycache);
yang_stmt* yang_mymodule_get(yang_stmt *ys);
int        yang_mymodule_set(yang_stmt *ys, yang_stmt *ym);

/* Stats */
int        yang_stats_global(uint64_t *nr);
int        yang_stats(yang_stmt *y, enum rfc_6020 keyw, uint64_t *nrp, size_t *szp);

/* Other functions */
yang_stmt *yspec_new(clixon_handle h, char *name);
yang_stmt *yspec_new1(clixon_handle h, char *domain, char *name);
yang_stmt *yspec_new_shared(clixon_handle h, char *xpath, char *domain, char *name, yang_stmt *yspec0);
yang_stmt *ydomain_new(clixon_handle h, char *domain);
yang_stmt *ys_new(enum rfc_6020 keyw);
yang_stmt *ys_prune(yang_stmt *yp, int i);
int        ys_prune_self(yang_stmt *ys);
int        ys_free1(yang_stmt *ys, int self);
int        ys_free(yang_stmt *ys);
int        ys_cp_one(yang_stmt *nw, yang_stmt *old);
int        ys_cp(yang_stmt *nw, yang_stmt *old);
yang_stmt *ys_dup(yang_stmt *old);
int        yn_insert(yang_stmt *ys_parent, yang_stmt *ys_child);
int        yn_insert1(yang_stmt *ys_parent, yang_stmt *ys_child);
yang_stmt *yn_iter(yang_stmt *yparent, int *inext);
char      *yang_key2str(int keyword);
int        yang_str2key(char *str);
int        ys_module_by_xml(yang_stmt *ysp, struct xml *xt, yang_stmt **ymodp);
yang_stmt *ys_module(yang_stmt *ys);
int        ys_real_module(yang_stmt *ys, yang_stmt **ymod);
yang_stmt *ys_spec(yang_stmt *ys);
yang_stmt *ys_domain(yang_stmt *ys);
yang_stmt *ys_mounts(yang_stmt *ys);
yang_stmt *yang_find(yang_stmt *yn, int keyword, const char *argument);
yang_stmt *yang_find_datanode(yang_stmt *yn, char *argument);
yang_stmt *yang_find_schemanode(yang_stmt *yn, char *argument);
char      *yang_find_myprefix(yang_stmt *ys);
char      *yang_find_mynamespace(yang_stmt *ys);
int        yang_find_prefix_by_namespace(yang_stmt *ys, char *ns, char **prefix);
int        yang_find_namespace_by_prefix(yang_stmt *ys, char *prefix, char **ns);
yang_stmt *yang_myroot(yang_stmt *ys);
int        yang_choice_case_get(yang_stmt *yc, yang_stmt **ycase, yang_stmt **ychoice);
yang_stmt *yang_choice(yang_stmt *y);
int        yang_order(yang_stmt *y);
int        yang_print_cb(FILE *f, yang_stmt *yn, clicon_output_cb *fn);
int        yang_print(FILE *f, yang_stmt *yn);
int        yang_print_cbuf(cbuf *cb, yang_stmt *yn, int marginal, int pretty);
int        yang_dump1(FILE *f, yang_stmt *yn);
int        yang_deviation(yang_stmt *ys, void *arg);
int        yang_spec_print(FILE *f, yang_stmt *yspec);
int        yang_spec_dump(yang_stmt *yspec, int debuglevel);
int        yang_mounts_print(FILE *f, yang_stmt *ymounts);
int        if_feature(yang_stmt *yspec, char *module, char *feature);
int        ys_populate(yang_stmt *ys, void *arg);
int        ys_populate2(yang_stmt *ys, void *arg);
int        yang_apply(yang_stmt *yn, enum rfc_6020 key, yang_applyfn_t fn, int from, void *arg);
int        yang_datanode(yang_stmt *ys);
int        yang_abs_schema_nodeid(yang_stmt *ys, char *schema_nodeid, yang_stmt **yres);
int        yang_desc_schema_nodeid(yang_stmt *yn, char *schema_nodeid, yang_stmt **yres);
int        yang_config(yang_stmt *ys);
int        yang_config_ancestor(yang_stmt *ys);
int        yang_features(clixon_handle h, yang_stmt *yt);
cvec      *yang_arg2cvec(yang_stmt *ys, char *delimi);
int        yang_key_match(yang_stmt *yn, char *name, int *lastkey);
int        yang_type_cache_get2(yang_stmt *ytype, yang_stmt **resolved, int *options,
                                cvec **cvv, cvec *patterns, cvec *regexps, uint8_t *fraction);
int        yang_type_cache_set2(yang_stmt *ys, yang_stmt *resolved, int options, cvec *cvv,
                                cvec *patterns, uint8_t fraction, int rxmode, cvec *regexps);
yang_stmt *yang_anydata_add(yang_stmt *yp, char *name);
int        yang_extension_value(yang_stmt *ys, char *name, char *ns, int *exist, char **value);
int        yang_sort_subelements(yang_stmt *ys);
int        yang_single_child_type(yang_stmt *ys, enum rfc_6020 subkeyw);
void      *yang_action_cb_get(yang_stmt *ys);
int        yang_action_cb_add(yang_stmt *ys, void *rc);
#ifdef OPTIMIZE_NO_PRESENCE_CONTAINER
void      *yang_nopresence_cache_get(yang_stmt *ys);
int        yang_nopresence_cache_set(yang_stmt *ys, void *x);
#endif
int        ys_populate_feature(clixon_handle h, yang_stmt *ys);
int        yang_init(clixon_handle h);
int        yang_start(clixon_handle h);
int        yang_exit(clixon_handle h);

#endif  /* _CLIXON_YANG_H_ */
