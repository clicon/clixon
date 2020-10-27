/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * Clixon XML XPATH 1.0 according to https://www.w3.org/TR/xpath-10 (Base XML)
 * and rfc 7950 (YANG-specific)
 */
#ifndef _CLIXON_XPATH_FUNCTION_H
#define _CLIXON_XPATH_FUNCTION_H

/*
 * Types 
 */
/*
 * XPath functions from Xpath 1.0 spec or YANG
 * @see xp_checkfn where they are parsed and checked
 * @see clixon_xpath_function.c for implementations
 */
enum clixon_xpath_function{
    XPATHFN_CURRENT,                /* RFC 7950 10.1.1 */
    XPATHFN_RE_MATCH,               /* RFC 7950 10.2.1 NYI */
    XPATHFN_DEREF,                  /* RFC 7950 10.3.1 */
    XPATHFN_DERIVED_FROM,           /* RFC 7950 10.4.1 */
    XPATHFN_DERIVED_FROM_OR_SELF,   /* RFC 7950 10.4.2 */
    XPATHFN_ENUM_VALUE,             /* RFC 7950 10.5.1 NYI */
    XPATHFN_BIT_IS_SET,             /* RFC 7950 10.6.1 NYI */
    XPATHFN_LAST,                   /* XPATH 1.0 4.1   NYI */
    XPATHFN_POSITION,               /* XPATH 1.0 4.1 */
    XPATHFN_COUNT,                  /* XPATH 1.0 4.1 */
    XPATHFN_ID,                     /* XPATH 1.0 4.1   NYI */
    XPATHFN_LOCAL_NAME,             /* XPATH 1.0 4.1   NYI */
    XPATHFN_NAMESPACE_URI,          /* XPATH 1.0 4.1   NYI */
    XPATHFN_NAME,                   /* XPATH 1.0 4.1 */
    XPATHFN_STRING,                 /* XPATH 1.0 4.2   NYI */
    XPATHFN_CONCAT,                 /* XPATH 1.0 4.2   NYI */
    XPATHFN_STARTS_WITH,            /* XPATH 1.0 4.2   NYI */
    XPATHFN_CONTAINS,               /* XPATH 1.0 4.2 */
    XPATHFN_SUBSTRING_BEFORE,       /* XPATH 1.0 4.2   NYI */
    XPATHFN_SUBSTRING_AFTER,        /* XPATH 1.0 4.2   NYI */
    XPATHFN_SUBSTRING,              /* XPATH 1.0 4.2   NYI */
    XPATHFN_STRING_LENGTH,          /* XPATH 1.0 4.2   NYI */
    XPATHFN_NORMALIZE_SPACE,        /* XPATH 1.0 4.2   NYI */
    XPATHFN_TRANSLATE,              /* XPATH 1.0 4.2   NYI */
    XPATHFN_BOOLEAN,                /* XPATH 1.0 4.3   NYI */
    XPATHFN_NOT,                    /* XPATH 1.0 4.3 */
    XPATHFN_TRUE,                   /* XPATH 1.0 4.3   NYI */
    XPATHFN_FALSE,                  /* XPATH 1.0 4.3   NYI */
    XPATHFN_LANG,                   /* XPATH 1.0 4.3   NYI */
    XPATHFN_NUMBER,                 /* XPATH 1.0 4.4   NYI */
    XPATHFN_SUM,                    /* XPATH 1.0 4.4   NYI */
    XPATHFN_FLOOR,                  /* XPATH 1.0 4.4   NYI */
    XPATHFN_CEILING,                /* XPATH 1.0 4.4   NYI */
    XPATHFN_ROUND,                  /* XPATH 1.0 4.4   NYI */
    XPATHFN_COMMENT,                /* XPATH 1.0 nodetype NYI */
    XPATHFN_TEXT,                   /* XPATH 1.0 nodetype */
    XPATHFN_PROCESSING_INSTRUCTIONS,/* XPATH 1.0 nodetype NYI */
    XPATHFN_NODE,                   /* XPATH 1.0 nodetype */
};

/*
 * Prototypes
 */
int xp_fnname_str2int(char *fnname);
const char *xp_fnname_int2str(enum clixon_xpath_function code);

int xp_function_current(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, xp_ctx **xrp);
int xp_function_deref(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, xp_ctx **xrp);
int xp_function_derived_from(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, int self, xp_ctx **xrp);
int xp_function_position(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, xp_ctx **xrp);
int xp_function_count(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, xp_ctx **xrp);
int xp_function_name(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, xp_ctx **xrp);
int xp_function_contains(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, xp_ctx **xrp);
int xp_function_not(xp_ctx *xc, struct xpath_tree *xs, cvec *nsc, int localonly, xp_ctx **xrp);

#endif /* _CLIXON_XPATH_FUNCTION_H */
