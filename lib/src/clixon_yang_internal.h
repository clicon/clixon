/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2010 Olof Hagsand
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
  * This file defines the internal YANG data structures used by the Clixon implementation
  * This file SHOULD ONLY be included by clixon_yang.h.
  * Accesses should be made via the API defined in clixon_yang.h
  */

#ifndef _CLIXON_YANG_INTERNAL_H_
#define _CLIXON_YANG_INTERNAL_H_

/*! Yang type cache. Yang type statements can cache all typedef info here
 *
 * @note unions not cached
*/
struct yang_type_cache{
    uint8_t    yc_options;  /* See YANG_OPTIONS_* that determines pattern/
                               fraction fields. */
    uint8_t    yc_rxmode;   /* Need to store mode for freeing since handle may not be
                             * available. See enum regexp_mode */
    uint8_t    yc_fraction; /* Fraction digits for decimal64 (if YANG_OPTIONS_FRACTION_DIGITS */
    cvec      *yc_cvv;      /* Range and length restriction. (if YANG_OPTION_
                               LENGTH|RANGE. Can be a vector if multiple 
                               ranges */
    cvec      *yc_patterns; /* List of regexp, if cvec_len() > 0 */
    cvec      *yc_regexps;  /* List of _compiled_ regexp, if cvec_len() > 0 */
    yang_stmt *yc_resolved; /* Resolved type object, can be NULL - note direct ptr */
};
typedef struct yang_type_cache yang_type_cache;

/*! yang statement 
 *
 * This is an internal type, not exposed in the API
 * The external type is "yang_stmt" defined in clixon_yang.h
 * @note  There is additional info in maps, yang_when_set and yang_mymodule_set
 */
struct yang_stmt {
    /* On x86_64, the following three fields take 8 bytes */
    enum rfc_6020      ys_keyword:8; /* YANG keyword */
    uint8_t            ys_ref;       /* Reference count for free: 0 means
                                      * no sharing, 1: two references */
    uint16_t           ys_flags;     /* Flags according to YANG_FLAG_MARK and others */
    uint32_t           ys_len;       /* Number of children */
#ifdef YANG_SPEC_LINENR
    /* Increases memory w 8 extra bytes on x86_64
     * XXX: can we enable this when needed for schema nodeid sub-parsing? */
    uint32_t           ys_linenum;   /* For debug/errors: line number (in ys_filename) */
#endif
    struct yang_stmt **ys_stmt;      /* Vector of children statement pointers */
    struct yang_stmt  *ys_parent;    /* Backpointer to parent: yang-stmt or yang-spec */
    char              *ys_argument;  /* String / argument depending on keyword */
    /* XXX: can we move this to union, No SPEC is already there */
    cg_var            *ys_cv;        /* cligen variable. See ys_populate()
                                        Following stmts have cv:s:
                                        Y_FEATURE: boolean true or false
                                        Y_CONFIG: boolean true or false
                                        Y_LEAF: for default value
                                        Y_LEAF_LIST,
                                        Y_MAX_ELEMENTS:
                                        Y_MIN_ELEMENTS: inte
                                        Y_MANDATORY: boolean true or false
                                        Y_REQUIRE_INSTANCE: true or false
                                        Y_FRACTION_DIGITS for fraction-digits
                                        Y_REVISION (uint32)
                                        Y_REVISION_DATE (uint32)
                                        Y_UNKNOWN (optional argument)
                                        Y_ENUM: value
                                     */
    cvec              *ys_cvec;      /* List of stmt-specific variables 
                                        Y_EXTENSION: vector of instantiated UNKNOWNS
                                        Y_IDENTITY: store all derived types as <module>:<id> list
                                        Y_LENGTH: length_min, length_max
                                        Y_LIST: vector of keys
                                        Y_RANGE: range_min, range_max
                                        Y_SPEC: shared mount-point xpaths
                                        Y_TYPE: store all derived types as <module>:<id> list
                                        Y_UNIQUE: vector of descendant schema node ids
                                        Y_UNKNOWN: app-dep: yang-mount-points
                                     */
    yang_stmt         *ys_orig;      /* Pointer to original (for uses/augment copies) */
    union {                          /* Depends on ys_keyword */
        rpc_callback_t  *ysu_action_cb; /* Y_ACTION: Action callback list*/
        char            *ysu_filename;  /* Y_MODULE/Y_SUBMODULE: For debug/errors: filename */
        yang_type_cache *ysu_typecache; /* Y_TYPE: cache all typedef data except unions */
#ifdef OPTIMIZE_YSPEC_NAMESPACE
        map_str2ptr     *ysu_nscache;   /* Y_SPEC: namespace to module cache */
#endif
#ifdef OPTIMIZE_NO_PRESENCE_CONTAINER
        cxobj           *ysu_nopres_cache; /* Y_CONTAINER: no-presence XML cache */
#endif
    } u;
};

/* Access macros */
#define ys_action_cb      u.ysu_action_cb
#define ys_filename       u.ysu_filename
#define ys_typecache      u.ysu_typecache
#ifdef OPTIMIZE_YSPEC_NAMESPACE
#define ys_nscache        u.ysu_nscache
#endif
#ifdef OPTIMIZE_NO_PRESENCE_CONTAINER
#define ys_nopres_cache   u.ysu_nopres_cache
#endif

#endif  /* _CLIXON_YANG_INTERNAL_H_ */
