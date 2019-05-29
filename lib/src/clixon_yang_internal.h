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

 * Yang functions
 * @see https://tools.ietf.org/html/rfc6020 YANG 1.0
 * @see https://tools.ietf.org/html/rfc7950 YANG 1.1
 */

#ifndef _CLIXON_YANG_INTERNAL_H_
#define _CLIXON_YANG_INTERNAL_H_


/*
 * Actually cligen variable stuff XXX
 */
#define V_UNIQUE	0x01	/* Variable flag */
#define V_UNSET		0x08	/* Variable is unset, ie no default */


#define YANG_FLAG_MARK 0x01  /* Marker for dynamic algorithms, eg expand */

/*! Yang type cache. Yang type statements can cache all typedef info here
 * @note unions not cached
*/
struct yang_type_cache{
    int        yc_options;  /* See YANG_OPTIONS_* that determines pattern/
			       fraction fields. */
    cvec      *yc_cvv;      /* Range and length restriction. (if YANG_OPTION_
                               LENGTH|RANGE. Can be a vector if multiple 
                               ranges*/
    cvec      *yc_patterns; /* list of regexp, if cvec_len() > 0 */
    cvec      *yc_regexps;  /* list of _compiled_ regexp, if cvec_len() > 0 */
    uint8_t    yc_fraction; /* Fraction digits for decimal64 (if 
                               YANG_OPTIONS_FRACTION_DIGITS */
    yang_stmt *yc_resolved; /* Resolved type object, can be NULL - note direct ptr */
};
typedef struct yang_type_cache yang_type_cache;

/*! yang statement 
 */
struct yang_stmt{
    int                ys_len;       /* Number of children */
    struct yang_stmt **ys_stmt;      /* Vector of children statement pointers */
    struct yang_stmt  *ys_parent;    /* Backpointer to parent: yang-stmt or yang-spec */
    enum rfc_6020      ys_keyword;   /* See clicon_yang_parse.tab.h */

    char              *ys_argument;  /* String / argument depending on keyword */   
    int                ys_flags;     /* Flags according to YANG_FLAG_* above */
    yang_stmt         *ys_mymodule;  /* Shortcut to "my" module. Augmented
				       nodes can belong to other 
					modules than the ancestor module */

    char              *ys_extra;     /* For unknown */
    cg_var            *ys_cv;        /* cligen variable. See ys_populate()
					Following stmts have cv:s:
				        leaf: for default value
					leaf-list, 
					config: boolean true or false
					mandatory: boolean true or false
					fraction-digits for fraction-digits
					unknown-stmt (argument)
				     */
    cvec              *ys_cvec;      /* List of stmt-specific variables 
					Y_RANGE: range_min, range_max 
					Y_LIST: vector of keys
					Y_TYPE & identity: store all derived types
				     */
    yang_type_cache   *ys_typecache; /* If ys_keyword==Y_TYPE, cache all typedef data except unions */
    int               _ys_vector_i;   /* internal use: yn_each */
};

/* Yang data definition statement
 * See RFC 7950 Sec 3:
 *   o  data definition statement: A statement that defines new data
 *      nodes.  One of "container", "leaf", "leaf-list", "list", "choice",
 *      "case", "augment", "uses", "anydata", and "anyxml".
 */
#define yang_datadefinition(y) (yang_datanode(y) || (y)->ys_keyword == Y_CHOICE || (y)->ys_keyword == Y_CASE || (y)->ys_keyword == Y_AUGMENT || (y)->ys_keyword == Y_USES)

/* Yang schema node .
 * See RFC 7950 Sec 3:
 *    o  schema node: A node in the schema tree.  One of action, container,
 *       leaf, leaf-list, list, choice, case, rpc, input, output,
 *       notification, anydata, and anyxml.
 */
#define yang_schemanode(y) (yang_datanode(y) || (y)->ys_keyword == Y_RPC || (y)->ys_keyword == Y_CHOICE || (y)->ys_keyword == Y_CASE || (y)->ys_keyword == Y_INPUT || (y)->ys_keyword == Y_OUTPUT || (y)->ys_keyword == Y_NOTIFICATION)

#endif  /* _CLIXON_YANG_INTERNAL_H_ */
