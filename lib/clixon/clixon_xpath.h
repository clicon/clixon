/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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

 * Clixon XML XPath 1.0 according to https://www.w3.org/TR/xpath-10
 */
#ifndef _CLIXON_XPATH_H
#define _CLIXON_XPATH_H

/*
 * Types
 */
enum xp_op{
    XO_AND,
    XO_OR,
    XO_DIV,
    XO_MOD,
    XO_ADD,
    XO_MULT,
    XO_SUB,
    XO_EQ,
    XO_NE,
    XO_GE,
    XO_LE,
    XO_LT,
    XO_GT,
    XO_UNION,
};

/* Axis specifiers according to https://www.w3.org/TR/xpath-10/#NT-AxisName
 * @see axis_type_int2str
 */
enum axis_type{
    A_NAN = 0, /* Not set */
    A_ANCESTOR,
    A_ANCESTOR_OR_SELF,
    A_ATTRIBUTE,
    A_CHILD,
    A_DESCENDANT,
    A_DESCENDANT_OR_SELF,
    A_FOLLOWING,
    A_FOLLOWING_SIBLING,
    A_NAMESPACE,
    A_PARENT,
    A_PRECEDING,
    A_PRECEDING_SIBLING,
    A_SELF,
    A_ROOT /* XXX Not in https://www.w3.org/TR/xpath-10 */
};

/* used as non-terminal type in yacc rules
 * @see xpath_tree_int2str
 */
enum xp_type{
    XP_EXP,
    XP_AND,
    XP_RELEX,
    XP_ADD,
    XP_UNION,
    XP_PATHEXPR,
    XP_FILTEREXPR,
    XP_LOCPATH,
    XP_ABSPATH,
    XP_RELLOCPATH,
    XP_STEP,
    XP_NODE, /* s0 is namespace prefix, s1 is name */
    XP_NODE_FN,
    XP_PRED,
    XP_PRI0,
    XP_PRIME_NR,
    XP_PRIME_STR,
    XP_PRIME_FN,
};

/*! XPATH Parsing generates a tree of nodes that is later traversed
 *
 * That is, a tree-structured XPath.
 * Note that the structure follows XPath 1.0 closely. The drawback wit this is that the tree gets
 * very deep very quickly, even for simple XPaths.
 */
struct xpath_tree{
    enum xp_type       xs_type;
    int                xs_int;    /* step-> axis_type */
    double             xs_double; /* set if XP_PRIME_NR */
    char              *xs_strnr;  /* original string xs_double: numeric value */
    char              *xs_s0;     /* set if XP_PRIME_STR, XP_PRIME_FN, XP_NODE[_FN] prefix*/
    char              *xs_s1;     /* set if XP_NODE NAME */
    struct xpath_tree *xs_c0;     /* child 0 */
    struct xpath_tree *xs_c1;     /* child 1 */
    int                xs_match;  /* meta: match this node */
};
typedef struct xpath_tree xpath_tree;

/*
 * Prototypes
 */
const char* axis_type_int2str(int axis_type);
int   axis_type_str2int(const char *name);
const char* xpath_tree_int2str(int nodetype);
int   xpath_tree_print_cb(cbuf *cb, xpath_tree *xs);
int   xpath_tree_print(FILE *f, xpath_tree *xs);
int   xpath_tree2cbuf(xpath_tree *xs, cbuf *xpathcb);
int   xpath_tree_eq(xpath_tree *xt1, xpath_tree *xt2, xpath_tree ***vec, size_t *len);
xpath_tree *xpath_tree_traverse(xpath_tree *xt, ...);
int   xpath_tree_free(xpath_tree *xs);
int   xpath_parse(const char *xpath, xpath_tree **xptree);
int   xpath_vec_ctx(cxobj *xcur, cvec *nsc, const char *xpath, int localonly, xp_ctx **xrp);

int    xpath_vec_bool(cxobj *xcur, cvec *nsc, const char *xpformat, ...) __attribute__ ((format (printf, 3, 4)));
int    xpath_vec_flag(cxobj *xcur, cvec *nsc, const char *xpformat, uint16_t flags,
                   cxobj ***vec, size_t *veclen, ...) __attribute__ ((format (printf, 3, 7)));

/* Functions with explicit namespace context (nsc) set. If you do not need
 * explicit namespace contexts (most do not) consider using the API functions
 * below without nsc set.
 * If you do not know what a namespace context is, see README.md#xml-and-xpath
 */
cxobj *xpath_first(cxobj *xcur, cvec *nsc, const char *xpformat,  ...) __attribute__ ((format (printf, 3, 4)));
cxobj *xpath_first_localonly(cxobj *xcur, const char *xpformat,  ...) __attribute__ ((format (printf, 2, 3)));
int    xpath_vec(cxobj *xcur, cvec *nsc, const char *xpformat, cxobj ***vec, size_t *veclen, ...) __attribute__ ((format (printf, 3, 6)));

int xpath2canonical(const char *xpath0, cvec *nsc0, yang_stmt *yspec,
                    char **xpath1, cvec **nsc1, cbuf **cbreason);
int xpath2canonical1(const char *xpath0, cvec *nsc0, yang_stmt *yspec, int exprstr,
                     char **xpath1, cvec **nsc1, cbuf **cbreason);
int xpath_count(cxobj *xcur, cvec *nsc, const char *xpath, uint32_t *count);
int xml2xpath(cxobj *x, cvec *nsc, int spec, int apostrophe, char **xpath);
int xpath2xml(const char *xpath, cvec *nsc, cxobj *xtop, yang_stmt *ytop,
              cxobj **xbotp, yang_stmt **ybotp, cxobj **xerr);

#endif /* _CLIXON_XPATH_H */
