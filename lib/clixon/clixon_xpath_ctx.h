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

 * Clixon XML XPath 1.0 according to https://www.w3.org/TR/xpath-10
 * This file defines XPath contexts using in traversing the XPath parse tree.
 */
#ifndef _CLIXON_XPATH_CTX_H
#define _CLIXON_XPATH_CTX_H

/*
 * Types
 */

/*! XPath expression type
 *
 * An expression is evaluated to yield an object, which has one of the following four basic types:
 *  node-set (an unordered collection of nodes without duplicates)
 *  boolean (true or false)
 *  number (a floating-point number)
 *  string (a sequence of UCS characters)
 */
enum xp_objtype{
    XT_NODESET,
    XT_BOOL,
    XT_NUMBER,
    XT_STRING
};

/*! XPath context and result
 *
 * Expression evaluation occurs with respect to a context. XSLT and XPointer specify how the
 * context is determined for XPath expressions used in XSLT and XPointer respectively. The
 * context consists of:
 *  a node (the context node)
 *  a pair of non-zero positive integers (the context position and the context size)
 *  a set of variable bindings
 *  a function library
 *  the set of namespace declarations in scope for the expression

 * For each node in the node-set to be filtered, the PredicateExpr is
 * evaluated with that node as the context node, with the number of nodes
 * in the node-set as the context size, and with the proximity position
 * of the node in the node-set with respect to the axis as the context
 * position; if PredicateExpr evaluates to true for that node, the node
 * is included in the new node-set; otherwise, it is not included.
 */
struct xp_ctx{
    enum xp_objtype xc_type;
    cxobj         **xc_nodeset; /* if type XT_NODESET */
    size_t          xc_size;    /* Length of nodeset */
    int             xc_position;
    int             xc_bool;    /* if xc_type XT_BOOL */
    double          xc_number;  /* if xc_type XT_NUMBER */
    char           *xc_string;  /* if xc_type XT_STRING */
    cxobj          *xc_node;    /* Node in nodeset XXX maybe not needed*/
    cxobj          *xc_initial; /* RFC 7960 10.1.1 extension: for current() */
    int             xc_descendant;  /* // */
    /* NYI: a set of variable bindings, set of namespace declarations */
};
typedef struct xp_ctx xp_ctx;

/*
 * Variables
 */
extern const map_str2int ctxmap[];

/*
 * Prototypes
 */
int ctx_free(xp_ctx *xc);
xp_ctx *ctx_dup(xp_ctx *xc);
int ctx_nodeset_replace(xp_ctx *xc, cxobj **vec, size_t veclen);
int ctx_print_cb(cbuf *cb, xp_ctx *xc, int indent, const char *str);
int ctx_print(FILE *f, xp_ctx *xc, const char *str);
int ctx2boolean(xp_ctx *xc);
int ctx2string(xp_ctx *xc, char **str0);
int ctx2number(xp_ctx *xc, double *n0);

#endif /* _CLIXON_XPATH_CTX_H */
