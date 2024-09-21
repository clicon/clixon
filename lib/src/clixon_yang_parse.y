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

 * Yang parser. Hopefully useful but not complete
 * @see https://tools.ietf.org/html/rfc6020 YANG 1.0
 * @see https://tools.ietf.org/html/rfc7950 YANG 1.1
 *
 * How identifiers map
 * IDENTIFIER     = [A-Za-z_][A-Za-z0-9_\-\.]
 * prefix         = IDENTIFIER
 * identifier_arg = IDENTIFIER
 * identifier_ref = prefix : IDENTIFIER
 * node_identier  = prefix : IDENTIFIER
 *
 * Missing args (just strings);
 * - length-arg-str
 * - path-arg-str
 * - date-arg-str
 */

%start file

%union {
    char *string;
}

%token MY_EOF
%token WS           /* white space (at least one) */
%token <string>   CHARS
%token <string>   ERRCHARS /* Error chars */
%token <string>   IDENTIFIER
%token <string>   BOOL
%token <string>   INT

%type <string>    ustring
%type <string>    qstrings
%type <string>    qstring
%type <string>    string
%type <string>    integer_value_str
%type <string>    identifier_ref_arg_str
%type <string>    if_feature_expr_str
%type <string>    refine_arg_str
%type <string>    augment_arg_str
%type <string>    uses_augment_arg_str
%type <string>    identifier_str
%type <string>    bool_str

/* rfc 6020 keywords 
   See also enum rfc_6020 in clicon_yang.h. There, the constants have Y_ prefix instead of K_
 * Wanted to unify these (K_ and Y_) but gave up for several reasons:
 * - Dont want to expose a generated yacc file to the API
 * - Cant use the symbols in this file because yacc needs token definitions
 */
%token K_ACTION
%token K_ANYDATA
%token K_ANYXML
%token K_ARGUMENT
%token K_AUGMENT
%token K_BASE
%token K_BELONGS_TO
%token K_BIT
%token K_CASE
%token K_CHOICE
%token K_CONFIG
%token K_CONTACT
%token K_CONTAINER
%token K_DEFAULT
%token K_DESCRIPTION
%token K_DEVIATE
%token K_DEVIATION
%token K_ENUM
%token K_ERROR_APP_TAG
%token K_ERROR_MESSAGE
%token K_EXTENSION
%token K_FEATURE
%token K_FRACTION_DIGITS
%token K_GROUPING
%token K_IDENTITY
%token K_IF_FEATURE
%token K_IMPORT
%token K_INCLUDE
%token K_INPUT
%token K_KEY
%token K_LEAF
%token K_LEAF_LIST
%token K_LENGTH
%token K_LIST
%token K_MANDATORY
%token K_MAX_ELEMENTS
%token K_MIN_ELEMENTS
%token K_MODIFIER
%token K_MODULE
%token K_MUST
%token K_NAMESPACE
%token K_NOTIFICATION
%token K_ORDERED_BY
%token K_ORGANIZATION
%token K_OUTPUT
%token K_PATH
%token K_PATTERN
%token K_POSITION
%token K_PREFIX
%token K_PRESENCE
%token K_RANGE
%token K_REFERENCE
%token K_REFINE
%token K_REQUIRE_INSTANCE
%token K_REVISION
%token K_REVISION_DATE
%token K_RPC
%token K_STATUS
%token K_SUBMODULE
%token K_TYPE
%token K_TYPEDEF
%token K_UNIQUE
%token K_UNITS
%token K_USES
%token K_VALUE
%token K_WHEN
%token K_YANG_VERSION
%token K_YIN_ELEMENT

/* Deviate keywords
 */
%token D_NOT_SUPPORTED
%token D_ADD
%token D_DELETE
%token D_REPLACE

%lex-param     {void *_yy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_yy}

%{
/* Here starts user C-code */

/* typecast macro */
#define _YY ((clixon_yang_yacc *)_yy)

#define _YYERROR(msg) {clixon_debug(CLIXON_DBG_YANG, "YYERROR %s '%s' %d", (msg), clixon_yang_parsetext, _YY->yy_linenum); YYERROR;}

/* add _yy to error parameters */
#define YY_(msgid) msgid

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if.h>

#include <cligen/cligen.h>

#include "clixon_queue.h"
#include "clixon_string.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_yang_parse_lib.h"
#include "clixon_yang_parse.h"

/* Best debugging is to enable PARSE_DEBUG below and add -d to the LEX compile statement in the Makefile
 * And then run the testcase with -D 1
 * Disable it to stop any calls to clixon_debug. Having it on by default would mean very large debug outputs.
 */
#if 0
#define _PARSE_DEBUG(s) clixon_debug(CLIXON_DBG_PARSE|CLIXON_DBG_DETAIL, (s))
#define _PARSE_DEBUG1(s, s1) clixon_debug(CLIXON_DBG_PARSE|CLIXON_DBG_DETAIL, (s), (s1))
#else
#define _PARSE_DEBUG(s)
#define _PARSE_DEBUG1(s, s1)
#endif

extern int clixon_yang_parseget_lineno  (void);

/*
   clixon_yang_parseerror
   also called from yacc generated code *
*/
void
clixon_yang_parseerror(void *_yy,
                       char *s)
{
    clixon_err(OE_YANG, 0, "%s on line %d: %s at or before: '%s'",
               _YY->yy_name,
               _YY->yy_linenum,
               s,
               clixon_yang_parsetext);
  return;
}

int
yang_parse_init(clixon_yang_yacc *yy)
{
    return 0;
}

int
yang_parse_exit(clixon_yang_yacc *yy)
{
    return 0;
}

/*! Pop a yang parse context on stack
 *
 * @param[in]  yy     Yang yacc argument
 * @retval     0       OK
 * @retval    -1       Error
 */
int
ystack_pop(clixon_yang_yacc *yy)
{
    struct ys_stack *ystack;

    if ((ystack = yy->yy_stack) == NULL){
        clixon_err(OE_YANG, 0, "ystack is NULL");
        return -1;
    }
    if (yang_sort_subelements(ystack->ys_node) < 0)
        return -1;
    yy->yy_stack = ystack->ys_next;
    free(ystack);
    return 0;
}

/*! Push a yang parse context on stack
 *
 * @param[in]  yy        Yang yacc argument
 * @param[in]  yn        Yang node to push
 */
struct ys_stack *
ystack_push(clixon_yang_yacc *yy,
            yang_stmt        *yn)
{
    struct ys_stack *ystack;

    if ((ystack = malloc(sizeof(*ystack))) == NULL) {
        clixon_err(OE_YANG, errno, "malloc");
        return NULL;
    }
    memset(ystack, 0, sizeof(*ystack));
    ystack->ys_node = yn;
    ystack->ys_next = yy->yy_stack;
    yy->yy_stack = ystack;
    return ystack;
}

/*! Add a yang statement to existing top-of-stack.
 *
 * @param[in]  yy        Yang yacc argument
 * @param[in]  keyword   Yang keyword
 * @param[in]  argument  Yang argument
 * @param[in]  extra     Yang extra for cornercases (unknown/extension)

 * @note consumes 'argument' and 'extra' which assumes it is malloced and not freed by caller
 */
static yang_stmt *
ysp_add(clixon_yang_yacc *yy,
        enum rfc_6020     keyword,
        char             *argument,
        char             *extra)
{
    struct ys_stack *ystack = yy->yy_stack;
    yang_stmt       *ys = NULL;
    yang_stmt       *yn;

    ystack = yy->yy_stack;
    if (ystack == NULL){
        clixon_err(OE_YANG, errno, "No stack");
        goto err;
    }
    if ((yn = ystack->ys_node) == NULL){
        clixon_err(OE_YANG, errno, "No ys_node");
        goto err;
    }
    if ((ys = ys_new(keyword)) == NULL)
        goto err;
    /* NOTE: does not make a copy of string, ie argument is 'consumed' here */
    yang_argument_set(ys, argument);
    if (yn_insert(yn, ys) < 0) /* Insert into hierarchy */
        goto err;
    yang_linenum_set(ys, yy->yy_linenum); /* For error/debugging */
    if (ys_parse_sub(ys, yy->yy_name, extra) < 0)     /* Check statement-specific syntax */
        goto err2; /* dont free since part of tree */
    return ys;
  err:
    if (ys)
        ys_free(ys);
  err2:
    return NULL;
}

/*! Add a yang statement to existing top-of-stack and then push it on stack
 *
 * @param[in]  yy        Yang yacc argument
 * @param[in]  keyword   Yang keyword
 * @param[in]  argument  Yang argument
 * @param[in]  extra     Yang extra for cornercases (unknown/extension)
 */
static yang_stmt *
ysp_add_push(clixon_yang_yacc *yy,
             enum rfc_6020     keyword,
             char             *argument,
             char             *extra)
{
    yang_stmt *ys;

    if ((ys = ysp_add(yy, keyword, argument, extra)) == NULL)
        return NULL;
    if (ystack_push(yy, ys) == NULL)
        return NULL;
    return ys;
}


%}

%%

/*
   statement = keyword [argument] (";" / "{" *statement "}")
   The argument is a string
   recursion: right is wrong
   Let subststmt rules contain an empty rule, but not stmt rules
*/

file          : module_stmt MY_EOF
                       { _PARSE_DEBUG("file->module-stmt"); YYACCEPT; }
              | submodule_stmt MY_EOF
                       { _PARSE_DEBUG("file->submodule-stmt"); YYACCEPT; }
              ;

/* module identifier-arg-str */
module_stmt   : K_MODULE identifier_str
                  { if ((_YY->yy_module = ysp_add_push(_yy, Y_MODULE, $2, NULL)) == NULL) _YYERROR("module_stmt");
                        }
                '{' module_substmts '}'
                  { if (ystack_pop(_yy) < 0) _YYERROR("module_stmt");
                    _PARSE_DEBUG("module_stmt -> id-arg-str { module-substmts }");}
              ;

module_substmts : module_substmts module_substmt
                      {_PARSE_DEBUG("module-substmts -> module-substmts module-substm");}
              | module_substmt
                      { _PARSE_DEBUG("module-substmts ->");}
              ;

module_substmt : module_header_stmts { _PARSE_DEBUG("module-substmt -> module-header-stmts");}
               | linkage_stmts       { _PARSE_DEBUG("module-substmt -> linake-stmts");}
               | meta_stmts          { _PARSE_DEBUG("module-substmt -> meta-stmts");}
               | revision_stmts      { _PARSE_DEBUG("module-substmt -> revision-stmts");}
               | body_stmts          { _PARSE_DEBUG("module-substmt -> body-stmts");}
               | unknown_stmt        { _PARSE_DEBUG("module-substmt -> unknown-stmt");}
               |                     { _PARSE_DEBUG("module-substmt ->");}
               ;

/* submodule */
submodule_stmt : K_SUBMODULE identifier_str
                    { if ((_YY->yy_module = ysp_add_push(_yy, Y_SUBMODULE, $2, NULL)) == NULL) _YYERROR("submodule_stmt"); }
                '{' submodule_substmts '}'
                    { if (ystack_pop(_yy) < 0) _YYERROR("submodule_stmt");
                        _PARSE_DEBUG("submodule_stmt -> id-arg-str { submodule-substmts }");}
              ;

submodule_substmts : submodule_substmts submodule_substmt
                       { _PARSE_DEBUG("submodule-stmts -> submodule-substmts submodule-substmt"); }
              | submodule_substmt
                       { _PARSE_DEBUG("submodule-stmts -> submodule-substmt"); }
              ;

submodule_substmt : submodule_header_stmts
                              { _PARSE_DEBUG("submodule-substmt -> submodule-header-stmts"); }
               | linkage_stmts  { _PARSE_DEBUG("submodule-substmt -> linake-stmts");}
               | meta_stmts     { _PARSE_DEBUG("submodule-substmt -> meta-stmts");}
               | revision_stmts { _PARSE_DEBUG("submodule-substmt -> revision-stmts");}
               | body_stmts     { _PARSE_DEBUG("submodule-stmt -> body-stmts"); }
               | unknown_stmt   { _PARSE_DEBUG("submodule-substmt -> unknown-stmt");}
               |                { _PARSE_DEBUG("submodule-substmt ->");}
              ;

/* linkage */
linkage_stmts : linkage_stmts linkage_stmt
                       { _PARSE_DEBUG("linkage-stmts -> linkage-stmts linkage-stmt"); }
              | linkage_stmt
                       { _PARSE_DEBUG("linkage-stmts -> linkage-stmt"); }
              ;

linkage_stmt  : import_stmt  { _PARSE_DEBUG("linkage-stmt -> import-stmt"); }
              | include_stmt { _PARSE_DEBUG("linkage-stmt -> include-stmt"); }
              ;

/* module-header */
module_header_stmts : module_header_stmts module_header_stmt
                  { _PARSE_DEBUG("module-header-stmts -> module-header-stmts module-header-stmt"); }
              | module_header_stmt   { _PARSE_DEBUG("module-header-stmts -> "); }
              ;

module_header_stmt : yang_version_stmt
                               { _PARSE_DEBUG("module-header-stmt -> yang-version-stmt"); }
              | namespace_stmt { _PARSE_DEBUG("module-header-stmt -> namespace-stmt"); }
              | prefix_stmt    { _PARSE_DEBUG("module-header-stmt -> prefix-stmt"); }
              ;

/* submodule-header */
submodule_header_stmts : submodule_header_stmts submodule_header_stmt
                  { _PARSE_DEBUG("submodule-header-stmts -> submodule-header-stmts submodule-header-stmt"); }
              | submodule_header_stmt
                  { _PARSE_DEBUG("submodule-header-stmts -> submodule-header-stmt"); }
              ;

submodule_header_stmt : yang_version_stmt
                  { _PARSE_DEBUG("submodule-header-stmt -> yang-version-stmt"); }
              | belongs_to_stmt { _PARSE_DEBUG("submodule-header-stmt -> belongs-to-stmt"); }
              ;

/* yang-version-stmt = yang-version-keyword  yang-version-arg-str */
yang_version_stmt : K_YANG_VERSION string stmtend
                { if (ysp_add(_yy, Y_YANG_VERSION, $2, NULL) == NULL) _YYERROR("yang_version_stmt");
                            _PARSE_DEBUG("yang-version-stmt -> YANG-VERSION string"); }
              ;

/* import */
import_stmt   : K_IMPORT identifier_str
                     { if (ysp_add_push(_yy, Y_IMPORT, $2, NULL) == NULL) _YYERROR("import_stmt"); }
                '{' import_substmts '}'
                     { if (ystack_pop(_yy) < 0) _YYERROR("import_stmt");
                       _PARSE_DEBUG("import-stmt -> IMPORT id-arg-str { import-substmts }");}
              ;

import_substmts : import_substmts import_substmt
                      { _PARSE_DEBUG("import-substmts -> import-substmts import-substm");}
              | import_substmt
                      { _PARSE_DEBUG("import-substmts ->");}
              ;

import_substmt : prefix_stmt        { _PARSE_DEBUG("import-stmt -> prefix-stmt"); }
               | revision_date_stmt { _PARSE_DEBUG("import-stmt -> revision-date-stmt"); }
               | description_stmt   { _PARSE_DEBUG("import-stmt -> description-stmt"); }
               | reference_stmt     { _PARSE_DEBUG("import-stmt -> reference-stmt"); }
              ;

include_stmt  : K_INCLUDE identifier_str ';'
                { if (ysp_add(_yy, Y_INCLUDE, $2, NULL)== NULL) _YYERROR("include_stmt");
                           _PARSE_DEBUG("include-stmt -> id-str"); }
              | K_INCLUDE identifier_str
              { if (ysp_add_push(_yy, Y_INCLUDE, $2, NULL) == NULL) _YYERROR("include_stmt"); }
              '{' include_substmts '}'
                { if (ystack_pop(_yy) < 0) _YYERROR("include_stmt");
                  _PARSE_DEBUG("include-stmt -> id-str { include-substmts }"); }
              ;

include_substmts : include_substmts include_substmt
                      { _PARSE_DEBUG("include-substmts -> include-substmts include-substm");}
              | include_substmt
                      { _PARSE_DEBUG("include-substmts ->");}
              ;

include_substmt : revision_date_stmt { _PARSE_DEBUG("include-stmt -> revision-date-stmt"); }
                | description_stmt   { _PARSE_DEBUG("include-stmt -> description-stmt"); }
                | reference_stmt     { _PARSE_DEBUG("include-stmt -> reference-stmt"); }
               ;


/* namespace-stmt = namespace-keyword sep uri-str */
namespace_stmt : K_NAMESPACE string stmtend
                { if (ysp_add(_yy, Y_NAMESPACE, $2, NULL)== NULL) _YYERROR("namespace_stmt");
                            _PARSE_DEBUG("namespace-stmt -> NAMESPACE string"); }
              ;

prefix_stmt   : K_PREFIX identifier_str stmtend /* XXX prefix-arg-str */
                { if (ysp_add(_yy, Y_PREFIX, $2, NULL)== NULL) _YYERROR("prefix_stmt");
                             _PARSE_DEBUG("prefix-stmt -> PREFIX string ;");}
              ;

belongs_to_stmt : K_BELONGS_TO identifier_str
                    { if (ysp_add_push(_yy, Y_BELONGS_TO, $2, NULL) == NULL) _YYERROR("belongs_to_stmt"); }
                  '{' prefix_stmt '}'
                    { if (ystack_pop(_yy) < 0) _YYERROR("belongs_to_stmt");
                      _PARSE_DEBUG("belongs-to-stmt -> BELONGS-TO id-arg-str { prefix-stmt } ");
                        }
                 ;

organization_stmt: K_ORGANIZATION string stmtend
                { if (ysp_add(_yy, Y_ORGANIZATION, $2, NULL)== NULL) _YYERROR("belongs_to_stmt");
                           _PARSE_DEBUG("organization-stmt -> ORGANIZATION string ;");}
              ;

contact_stmt  : K_CONTACT string stmtend
                { if (ysp_add(_yy, Y_CONTACT, $2, NULL)== NULL) _YYERROR("contact_stmt");
                            _PARSE_DEBUG("contact-stmt -> CONTACT string"); }
              ;

description_stmt : K_DESCRIPTION string stmtend
                { if (ysp_add(_yy, Y_DESCRIPTION, $2, NULL)== NULL) _YYERROR("description_stmt");
                           _PARSE_DEBUG("description-stmt -> DESCRIPTION string ;");}
              ;

reference_stmt : K_REFERENCE string stmtend
                { if (ysp_add(_yy, Y_REFERENCE, $2, NULL)== NULL) _YYERROR("reference_stmt");
                           _PARSE_DEBUG("reference-stmt -> REFERENCE string ;");}
              ;

units_stmt    : K_UNITS string ';'
                { if (ysp_add(_yy, Y_UNITS, $2, NULL)== NULL) _YYERROR("units_stmt");
                            _PARSE_DEBUG("units-stmt -> UNITS string"); }
              ;

revision_stmt : K_REVISION string ';'  /* XXX date-arg-str */
                { if (ysp_add(_yy, Y_REVISION, $2, NULL) == NULL) _YYERROR("revision_stmt");
                         _PARSE_DEBUG("revision-stmt -> date-arg-str ;"); }
              | K_REVISION string
              { if (ysp_add_push(_yy, Y_REVISION, $2, NULL) == NULL) _YYERROR("revision_stmt"); }
                '{' revision_substmts '}'  /* XXX date-arg-str */
                     { if (ystack_pop(_yy) < 0) _YYERROR("revision_stmt");
                       _PARSE_DEBUG("revision-stmt -> date-arg-str { revision-substmts  }"); }
              ;

revision_substmts : revision_substmts revision_substmt
                     { _PARSE_DEBUG("revision-substmts -> revision-substmts revision-substmt }"); }
              | revision_substmt
                     { _PARSE_DEBUG("revision-substmts -> }"); }
              ;

revision_substmt : description_stmt { _PARSE_DEBUG("revision-substmt -> description-stmt"); }
              | reference_stmt      { _PARSE_DEBUG("revision-substmt -> reference-stmt"); }
              | unknown_stmt        { _PARSE_DEBUG("revision-substmt -> unknown-stmt");}
              |                     { _PARSE_DEBUG("revision-substmt -> "); }
              ;


/* revision */
revision_stmts : revision_stmts revision_stmt
                       { _PARSE_DEBUG("revision-stmts -> revision-stmts revision-stmt"); }
              | revision_stmt
                       { _PARSE_DEBUG("revision-stmts -> "); }
              ;

revision_date_stmt : K_REVISION_DATE string stmtend  /* XXX date-arg-str */
                { if (ysp_add(_yy, Y_REVISION_DATE, $2, NULL) == NULL) _YYERROR("revision_date_stmt");
                         _PARSE_DEBUG("revision-date-stmt -> date;"); }
              ;

extension_stmt : K_EXTENSION identifier_str ';'
               { if (ysp_add(_yy, Y_EXTENSION, $2, NULL) == NULL) _YYERROR("extension_stmt");
                    _PARSE_DEBUG("extenstion-stmt -> EXTENSION id-str ;"); }
              | K_EXTENSION identifier_str
                { if (ysp_add_push(_yy, Y_EXTENSION, $2, NULL) == NULL) _YYERROR("extension_stmt"); }
               '{' extension_substmts '}'
                 { if (ystack_pop(_yy) < 0) _YYERROR("extension_stmt");
                    _PARSE_DEBUG("extension-stmt -> EXTENSION id-str { extension-substmts }"); }
              ;

/* extension substmts */
extension_substmts : extension_substmts extension_substmt
                  { _PARSE_DEBUG("extension-substmts -> extension-substmts extension-substmt"); }
              | extension_substmt
                  { _PARSE_DEBUG("extension-substmts -> extension-substmt"); }
              ;

extension_substmt : argument_stmt    { _PARSE_DEBUG("extension-substmt -> argument-stmt"); }
              | status_stmt          { _PARSE_DEBUG("extension-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("extension-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("extension-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("extension-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("extension-substmt -> "); }
              ;

argument_stmt  : K_ARGUMENT identifier_str ';'
               { if (ysp_add(_yy, Y_ARGUMENT, $2, NULL) == NULL) _YYERROR("argument_stmt");
                         _PARSE_DEBUG("argument-stmt -> ARGUMENT identifier ;"); }
               | K_ARGUMENT identifier_str
               { if (ysp_add_push(_yy, Y_ARGUMENT, $2, NULL) == NULL) _YYERROR("argument_stmt"); }
                '{' argument_substmts '}'
                       { if (ystack_pop(_yy) < 0) _YYERROR("argument_stmt");
                         _PARSE_DEBUG("argument-stmt -> ARGUMENT { argument-substmts }"); }
               ;

/* argument substmts */
argument_substmts : argument_substmts argument_substmt
                      { _PARSE_DEBUG("argument-substmts -> argument-substmts argument-substmt"); }
                  | argument_substmt
                      { _PARSE_DEBUG("argument-substmts -> argument-substmt"); }
                  ;

argument_substmt : yin_element_stmt1 { _PARSE_DEBUG("argument-substmt -> yin-element-stmt1");}
                 | unknown_stmt   { _PARSE_DEBUG("argument-substmt -> unknown-stmt");}
                 |
                 ;


/* Example of optional rule, eg [yin-element-stmt] */
yin_element_stmt1 : K_YIN_ELEMENT bool_str stmtend {free($2);}
               ;

/* Identity */
identity_stmt  : K_IDENTITY identifier_str ';'
              { if (ysp_add(_yy, Y_IDENTITY, $2, NULL) == NULL) _YYERROR("identity_stmt");
                           _PARSE_DEBUG("identity-stmt -> IDENTITY string ;"); }

              | K_IDENTITY identifier_str
              { if (ysp_add_push(_yy, Y_IDENTITY, $2, NULL) == NULL) _YYERROR("identity_stmt"); }
               '{' identity_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("identity_stmt");
                             _PARSE_DEBUG("identity-stmt -> IDENTITY string { identity-substmts }"); }
              ;

identity_substmts : identity_substmts identity_substmt
                      { _PARSE_DEBUG("identity-substmts -> identity-substmts identity-substmt"); }
              | identity_substmt
                      { _PARSE_DEBUG("identity-substmts -> identity-substmt"); }
              ;

identity_substmt : if_feature_stmt   { _PARSE_DEBUG("identity-substmt -> if-feature-stmt"); }
              | base_stmt            { _PARSE_DEBUG("identity-substmt -> base-stmt"); }
              | status_stmt          { _PARSE_DEBUG("identity-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("identity-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("identity-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("identity-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("identity-substmt -> "); }
              ;

base_stmt     : K_BASE identifier_ref_arg_str stmtend
                { if (ysp_add(_yy, Y_BASE, $2, NULL)== NULL) _YYERROR("base_stmt");
                            _PARSE_DEBUG("base-stmt -> BASE identifier-ref-arg-str"); }
              ;

/* Feature */
feature_stmt  : K_FEATURE identifier_str ';'
               { if (ysp_add(_yy, Y_FEATURE, $2, NULL) == NULL) _YYERROR("feature_stmt");
                      _PARSE_DEBUG("feature-stmt -> FEATURE id-arg-str ;"); }
              | K_FEATURE identifier_str
              { if (ysp_add_push(_yy, Y_FEATURE, $2, NULL) == NULL) _YYERROR("feature_stmt"); }
              '{' feature_substmts '}'
                  { if (ystack_pop(_yy) < 0) _YYERROR("feature_stmt");
                    _PARSE_DEBUG("feature-stmt -> FEATURE id-arg-str { feature-substmts }"); }
              ;

/* feature substmts */
feature_substmts : feature_substmts feature_substmt
                      { _PARSE_DEBUG("feature-substmts -> feature-substmts feature-substmt"); }
              | feature_substmt
                      { _PARSE_DEBUG("feature-substmts -> feature-substmt"); }
              ;

feature_substmt : if_feature_stmt    { _PARSE_DEBUG("feature-substmt -> if-feature-stmt"); }
              | status_stmt          { _PARSE_DEBUG("feature-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("feature-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("feature-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("feature-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("feature-substmt -> "); }
              ;

/* if-feature-stmt = if-feature-keyword sep if-feature-expr-str */
if_feature_stmt : K_IF_FEATURE if_feature_expr_str stmtend
                { if (ysp_add(_yy, Y_IF_FEATURE, $2, NULL) == NULL) _YYERROR("if_feature_stmt");
                            _PARSE_DEBUG("if-feature-stmt -> IF-FEATURE if-feature-expr-str"); }
              ;

/* a string that matches the rule if-feature-expr
 * @see yang_if_feature_parse
 */
if_feature_expr_str : string
                  { $$=$1;
                  _PARSE_DEBUG("if-feature-expr-str -> string that matches the rule if-feature-expr");
                  }
              ;

/* Typedef */
typedef_stmt  : K_TYPEDEF identifier_str
                 { if (ysp_add_push(_yy, Y_TYPEDEF, $2, NULL) == NULL) _YYERROR("typedef_stmt"); }
               '{' typedef_substmts '}'
                 { if (ystack_pop(_yy) < 0) _YYERROR("typedef_stmt");
                   _PARSE_DEBUG("typedef-stmt -> TYPEDEF id-arg-str { typedef-substmts }"); }
              ;

typedef_substmts : typedef_substmts typedef_substmt
                      { _PARSE_DEBUG("typedef-substmts -> typedef-substmts typedef-substmt"); }
              | typedef_substmt
                      { _PARSE_DEBUG("typedef-substmts -> typedef-substmt"); }
              ;

typedef_substmt : type_stmt          { _PARSE_DEBUG("typedef-substmt -> type-stmt"); }
              | units_stmt           { _PARSE_DEBUG("typedef-substmt -> units-stmt"); }
              | default_stmt         { _PARSE_DEBUG("typedef-substmt -> default-stmt"); }
              | status_stmt          { _PARSE_DEBUG("typedef-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("typedef-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("typedef-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("typedef-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("typedef-substmt -> "); }
              ;

/* Type */
type_stmt     : K_TYPE identifier_ref_arg_str ';'
               { if (ysp_add(_yy, Y_TYPE, $2, NULL) == NULL) _YYERROR("type_stmt");
                           _PARSE_DEBUG("type-stmt -> TYPE identifier-ref-arg-str ;");}
              | K_TYPE identifier_ref_arg_str
              { if (ysp_add_push(_yy, Y_TYPE, $2, NULL) == NULL) _YYERROR("type_stmt");
                         }
                '{' type_body_stmts '}'
                         { if (ystack_pop(_yy) < 0) _YYERROR("type_stmt");
                           _PARSE_DEBUG("type-stmt -> TYPE identifier-ref-arg-str { type-body-stmts }");}
              ;

/* type-body-stmts is a little special since it is a choice of
   sub-specifications that are all lists. One could model it as a list of 
   type-body-stmts and each individual specification as a simple.
 */
type_body_stmts : type_body_stmts type_body_stmt
                         { _PARSE_DEBUG("type-body-stmts -> type-body-stmts type-body-stmt"); }
              |
                         { _PARSE_DEBUG("type-body-stmts -> "); }
              ;

type_body_stmt/* numerical-restrictions */
              : range_stmt             { _PARSE_DEBUG("type-body-stmt -> range-stmt"); }
              /* decimal64-specification */
              | fraction_digits_stmt   { _PARSE_DEBUG("type-body-stmt -> fraction-digits-stmt"); }
              /* string-restrictions */
              | length_stmt           { _PARSE_DEBUG("type-body-stmt -> length-stmt"); }
              | pattern_stmt          { _PARSE_DEBUG("type-body-stmt -> pattern-stmt"); }
              /* enum-specification */
              | enum_stmt             { _PARSE_DEBUG("type-body-stmt -> enum-stmt"); }
              /* leafref-specifications */
              | path_stmt             { _PARSE_DEBUG("type-body-stmt -> path-stmt"); }
              | require_instance_stmt { _PARSE_DEBUG("type-body-stmt -> require-instance-stmt"); }
              /* identityref-specification */
              | base_stmt             { _PARSE_DEBUG("type-body-stmt -> base-stmt"); }
              /* instance-identifier-specification (see require-instance-stmt above */
              /* bits-specification */
              | bit_stmt               { _PARSE_DEBUG("type-body-stmt -> bit-stmt"); }
              /* union-specification */
              | type_stmt              { _PARSE_DEBUG("type-body-stmt -> type-stmt"); }
/* Cisco uses this (eg Cisco-IOS-XR-sysadmin-nto-misc-set-hostname.yang) but I dont see this is in the RFC */
              | unknown_stmt           { _PARSE_DEBUG("type-body-stmt -> unknown-stmt");}
              ;

/* range-stmt */
range_stmt   : K_RANGE string ';' /* XXX range-arg-str */
               { if (ysp_add(_yy, Y_RANGE, $2, NULL) == NULL) _YYERROR("range_stmt");
                           _PARSE_DEBUG("range-stmt -> RANGE string ;"); }

              | K_RANGE string
              { if (ysp_add_push(_yy, Y_RANGE, $2, NULL) == NULL) _YYERROR("range_stmt"); }
               '{' range_substmts '}'
                          { if (ystack_pop(_yy) < 0) _YYERROR("range_stmt");
                             _PARSE_DEBUG("range-stmt -> RANGE string { range-substmts }"); }
              ;

range_substmts : range_substmts range_substmt
                      { _PARSE_DEBUG("range-substmts -> range-substmts range-substmt"); }
              | range_substmt
                      { _PARSE_DEBUG("range-substmts -> range-substmt"); }
              ;

range_substmt : error_message_stmt   { _PARSE_DEBUG("range-substmt -> error-message-stmt");}
              | description_stmt     { _PARSE_DEBUG("range-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("range-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("range-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("range-substmt -> "); }
              ;

/* fraction-digits-stmt = fraction-digits-keyword fraction-digits-arg-str */
fraction_digits_stmt : K_FRACTION_DIGITS string stmtend
                { if (ysp_add(_yy, Y_FRACTION_DIGITS, $2, NULL) == NULL) _YYERROR("fraction_digits_stmt");
                            _PARSE_DEBUG("fraction-digits-stmt -> FRACTION-DIGITS string"); }
              ;

/* meta */
meta_stmts    : meta_stmts meta_stmt { _PARSE_DEBUG("meta-stmts -> meta-stmts meta-stmt"); }
              | meta_stmt            { _PARSE_DEBUG("meta-stmts -> meta-stmt"); }
              ;

meta_stmt     : organization_stmt    { _PARSE_DEBUG("meta-stmt -> organization-stmt"); }
              | contact_stmt         { _PARSE_DEBUG("meta-stmt -> contact-stmt"); }
              | description_stmt     { _PARSE_DEBUG("meta-stmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("meta-stmt -> reference-stmt"); }
              ;


/* length-stmt */
length_stmt   : K_LENGTH string ';' /* XXX length-arg-str */
               { if (ysp_add(_yy, Y_LENGTH, $2, NULL) == NULL) _YYERROR("length_stmt");
                           _PARSE_DEBUG("length-stmt -> LENGTH string ;"); }

              | K_LENGTH string
              { if (ysp_add_push(_yy, Y_LENGTH, $2, NULL) == NULL) _YYERROR("length_stmt"); }
               '{' length_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("length_stmt");
                             _PARSE_DEBUG("length-stmt -> LENGTH string { length-substmts }"); }
              ;

length_substmts : length_substmts length_substmt
                      { _PARSE_DEBUG("length-substmts -> length-substmts length-substmt"); }
              | length_substmt
                      { _PARSE_DEBUG("length-substmts -> length-substmt"); }
              ;

length_substmt : error_message_stmt  { _PARSE_DEBUG("length-substmt -> error-message-stmt");}
              | description_stmt     { _PARSE_DEBUG("length-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("length-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("length-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("length-substmt -> "); }
              ;

/* Pattern */
pattern_stmt  : K_PATTERN string ';'
               { if (ysp_add(_yy, Y_PATTERN, $2, NULL) == NULL) _YYERROR("pattern_stmt");
                           _PARSE_DEBUG("pattern-stmt -> PATTERN string ;"); }

              | K_PATTERN string
              { if (ysp_add_push(_yy, Y_PATTERN, $2, NULL) == NULL) _YYERROR("pattern_stmt"); }
               '{' pattern_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("pattern_stmt");
                             _PARSE_DEBUG("pattern-stmt -> PATTERN string { pattern-substmts }"); }
              ;

pattern_substmts : pattern_substmts pattern_substmt
                      { _PARSE_DEBUG("pattern-substmts -> pattern-substmts pattern-substmt"); }
              | pattern_substmt
                      { _PARSE_DEBUG("pattern-substmts -> pattern-substmt"); }
              ;

pattern_substmt : modifier_stmt    { _PARSE_DEBUG("pattern-substmt -> modifier-stmt");}
              | error_message_stmt { _PARSE_DEBUG("pattern-substmt -> error-message-stmt");}
              | error_app_tag_stmt { _PARSE_DEBUG("pattern-substmt -> error-app-tag-stmt");}
              | description_stmt   { _PARSE_DEBUG("pattern-substmt -> description-stmt");}
              | reference_stmt     { _PARSE_DEBUG("pattern-substmt -> reference-stmt"); }
              | unknown_stmt       { _PARSE_DEBUG("pattern-substmt -> unknown-stmt");}
              |                    { _PARSE_DEBUG("pattern-substmt -> "); }
              ;

modifier_stmt  : K_MODIFIER string stmtend
                { if (ysp_add(_yy, Y_MODIFIER, $2, NULL)== NULL) _YYERROR("modifier_stmt");
                            _PARSE_DEBUG("modifier-stmt -> MODIFIER string"); }
              ;

default_stmt  : K_DEFAULT string stmtend
                { if (ysp_add(_yy, Y_DEFAULT, $2, NULL)== NULL) _YYERROR("default_stmt");
                            _PARSE_DEBUG("default-stmt -> DEFAULT string"); }
              ;

/* enum-stmt */
enum_stmt     : K_ENUM string ';'
               { if (ysp_add(_yy, Y_ENUM, $2, NULL) == NULL) _YYERROR("enum_stmt");
                           _PARSE_DEBUG("enum-stmt -> ENUM string ;"); }
              | K_ENUM string
              { if (ysp_add_push(_yy, Y_ENUM, $2, NULL) == NULL) _YYERROR("enum_stmt"); }
               '{' enum_substmts '}'
                         { if (ystack_pop(_yy) < 0) _YYERROR("enum_stmt");
                           _PARSE_DEBUG("enum-stmt -> ENUM string { enum-substmts }"); }
              ;

enum_substmts : enum_substmts enum_substmt
                      { _PARSE_DEBUG("enum-substmts -> enum-substmts enum-substmt"); }
              | enum_substmt
                      { _PARSE_DEBUG("enum-substmts -> enum-substmt"); }
              ;

enum_substmt  : if_feature_stmt      { _PARSE_DEBUG("enum-substmt -> if-feature-stmt"); }
              | value_stmt           { _PARSE_DEBUG("enum-substmt -> value-stmt"); }
              | status_stmt          { _PARSE_DEBUG("enum-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("enum-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("enum-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("enum-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("enum-substmt -> "); }
              ;

path_stmt     : K_PATH string stmtend /* XXX: path-arg-str */
                { if (ysp_add(_yy, Y_PATH, $2, NULL)== NULL) _YYERROR("path_stmt");
                            _PARSE_DEBUG("path-stmt -> PATH string"); }
              ;

require_instance_stmt : K_REQUIRE_INSTANCE bool_str stmtend
                { if (ysp_add(_yy, Y_REQUIRE_INSTANCE, $2, NULL)== NULL) _YYERROR("require_instance_stmt");
                            _PARSE_DEBUG("require-instance-stmt -> REQUIRE-INSTANCE string"); }
              ;

/* bit-stmt */
bit_stmt     : K_BIT identifier_str ';'
               { if (ysp_add(_yy, Y_BIT, $2, NULL) == NULL) _YYERROR("bit_stmt");
                           _PARSE_DEBUG("bit-stmt -> BIT string ;"); }
              | K_BIT identifier_str
              { if (ysp_add_push(_yy, Y_BIT, $2, NULL) == NULL) _YYERROR("bit_stmt"); }
               '{' bit_substmts '}'
                         { if (ystack_pop(_yy) < 0) _YYERROR("bit_stmt");
                           _PARSE_DEBUG("bit-stmt -> BIT string { bit-substmts }"); }
              ;

bit_substmts : bit_substmts bit_substmt
                      { _PARSE_DEBUG("bit-substmts -> bit-substmts bit-substmt"); }
              | bit_substmt
                      { _PARSE_DEBUG("bit-substmts -> bit-substmt"); }
              ;

bit_substmt   : if_feature_stmt      { _PARSE_DEBUG("bit-substmt -> if-feature-stmt"); }
              | position_stmt        { _PARSE_DEBUG("bit-substmt -> positition-stmt"); }
              | status_stmt          { _PARSE_DEBUG("bit-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("bit-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("bit-substmt -> reference-stmt"); }
              |                      { _PARSE_DEBUG("bit-substmt -> "); }
              ;

/* position-stmt = position-keyword position-value-arg-str */
position_stmt : K_POSITION integer_value_str stmtend
                { if (ysp_add(_yy, Y_POSITION, $2, NULL) == NULL) _YYERROR("position_stmt");
                            _PARSE_DEBUG("position-stmt -> POSITION integer-value"); }
              ;

/* status-stmt = status-keyword sep status-arg-str XXX: current-keyword*/
status_stmt   : K_STATUS string stmtend
                { if (ysp_add(_yy, Y_STATUS, $2, NULL) == NULL) _YYERROR("status_stmt");
                            _PARSE_DEBUG("status-stmt -> STATUS string"); }
              ;

config_stmt   : K_CONFIG bool_str stmtend
                { if (ysp_add(_yy, Y_CONFIG, $2, NULL) == NULL) _YYERROR("config_stmt");
                            _PARSE_DEBUG("config-stmt -> CONFIG config-arg-str"); }
              ;

/* mandatory-stmt = mandatory-keyword mandatory-arg-str */
mandatory_stmt : K_MANDATORY bool_str stmtend
                         { yang_stmt *ys;
                             if ((ys = ysp_add(_yy, Y_MANDATORY, $2, NULL))== NULL) _YYERROR("mandatory_stmt");
                           _PARSE_DEBUG("mandatory-stmt -> MANDATORY mandatory-arg-str ;");}
              ;

presence_stmt : K_PRESENCE string stmtend
                         { yang_stmt *ys;
                             if ((ys = ysp_add(_yy, Y_PRESENCE, $2, NULL))== NULL) _YYERROR("presence_stmt");
                           _PARSE_DEBUG("presence-stmt -> PRESENCE string ;");}
              ;

/* ordered-by-stmt = ordered-by-keyword sep ordered-by-arg-str */
ordered_by_stmt : K_ORDERED_BY string stmtend
                         { yang_stmt *ys;
                             if ((ys = ysp_add(_yy, Y_ORDERED_BY, $2, NULL))== NULL) _YYERROR("ordered_by_stmt");
                           _PARSE_DEBUG("ordered-by-stmt -> ORDERED-BY ordered-by-arg ;");}
              ;

/* must-stmt */
must_stmt     : K_MUST string ';'
               { if (ysp_add(_yy, Y_MUST, $2, NULL) == NULL) _YYERROR("must_stmt");
                           _PARSE_DEBUG("must-stmt -> MUST string ;"); }

              | K_MUST string
              { if (ysp_add_push(_yy, Y_MUST, $2, NULL) == NULL) _YYERROR("must_stmt"); }
               '{' must_substmts '}'
                         { if (ystack_pop(_yy) < 0) _YYERROR("must_stmt");
                           _PARSE_DEBUG("must-stmt -> MUST string { must-substmts }"); }
              ;

must_substmts : must_substmts must_substmt
                      { _PARSE_DEBUG("must-substmts -> must-substmts must-substmt"); }
              | must_substmt
                      { _PARSE_DEBUG("must-substmts -> must-substmt"); }
              ;

must_substmt  : error_message_stmt   { _PARSE_DEBUG("must-substmt -> error-message-stmt"); }
              | error_app_tag_stmt   { _PARSE_DEBUG("must-substmt -> error-app-tag-stmt"); }
              | description_stmt     { _PARSE_DEBUG("must-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("must-substmt -> reference-stmt"); }
              |                      { _PARSE_DEBUG("must-substmt -> "); }
              ;

/* error-message-stmt */
error_message_stmt   : K_ERROR_MESSAGE string stmtend
               { if (ysp_add(_yy, Y_ERROR_MESSAGE, $2, NULL) == NULL) _YYERROR("error_message_stmt");
                  _PARSE_DEBUG("error-message-stmt -> ERROR-MESSAGE string"); }
               ;

error_app_tag_stmt : K_ERROR_APP_TAG string stmtend
               { if (ysp_add(_yy, Y_ERROR_MESSAGE, $2, NULL) == NULL) _YYERROR("error_message_stmt");
                  _PARSE_DEBUG("error-app-tag-stmt -> ERROR-APP-TAG string"); }
               ;

/* min-elements-stmt = min-elements-keyword min-value-arg-str */
min_elements_stmt : K_MIN_ELEMENTS integer_value_str stmtend
                { if (ysp_add(_yy, Y_MIN_ELEMENTS, $2, NULL)== NULL) _YYERROR("min_elements_stmt");
                           _PARSE_DEBUG("min-elements-stmt -> MIN-ELEMENTS integer ;");}
              ;

/* max-elements-stmt   = max-elements-keyword ("unbounded"|integer-value) 
 * XXX cannot use integer-value
 */
max_elements_stmt : K_MAX_ELEMENTS string stmtend
                { if (ysp_add(_yy, Y_MAX_ELEMENTS, $2, NULL)== NULL) _YYERROR("max_elements_stmt");
                           _PARSE_DEBUG("max-elements-stmt -> MIN-ELEMENTS integer ;");}
              ;

value_stmt   : K_VALUE integer_value_str stmtend
                { if (ysp_add(_yy, Y_VALUE, $2, NULL) == NULL) _YYERROR("value_stmt");
                            _PARSE_DEBUG("value-stmt -> VALUE integer-value"); }
              ;

/* Grouping */
grouping_stmt  : K_GROUPING identifier_str ';'
                    { if (ysp_add(_yy, Y_GROUPING, $2, NULL) == NULL) _YYERROR("grouping_stmt");
                      _PARSE_DEBUG("grouping-stmt -> GROUPING id-arg-str ;"); }
               | K_GROUPING identifier_str
                    { if (ysp_add_push(_yy, Y_GROUPING, $2, NULL) == NULL) _YYERROR("grouping_stmt"); }
               '{' grouping_substmts '}'
                    { if (ystack_pop(_yy) < 0) _YYERROR("grouping_stmt");
                      _PARSE_DEBUG("grouping-stmt -> GROUPING id-arg-str { grouping-substmts }"); }
              ;

grouping_substmts : grouping_substmts grouping_substmt
                      { _PARSE_DEBUG("grouping-substmts -> grouping-substmts grouping-substmt"); }
              | grouping_substmt
                      { _PARSE_DEBUG("grouping-substmts -> grouping-substmt"); }
              ;

grouping_substmt : status_stmt       { _PARSE_DEBUG("grouping-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("grouping-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("grouping-substmt -> reference-stmt"); }
              | typedef_stmt         { _PARSE_DEBUG("grouping-substmt -> typedef-stmt"); }
              | grouping_stmt        { _PARSE_DEBUG("grouping-substmt -> grouping-stmt"); }
              | data_def_stmt        { _PARSE_DEBUG("grouping-substmt -> data-def-stmt"); }
              | action_stmt          { _PARSE_DEBUG("grouping-substmt -> action-stmt"); }
              | notification_stmt    { _PARSE_DEBUG("grouping-substmt -> notification-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("container-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("grouping-substmt -> "); }
              ;


/* container */
container_stmt : K_CONTAINER identifier_str ';'
                { if (ysp_add(_yy, Y_CONTAINER, $2, NULL) == NULL) _YYERROR("container_stmt");
                             _PARSE_DEBUG("container-stmt -> CONTAINER id-arg-str ;");}
              | K_CONTAINER identifier_str
              { if (ysp_add_push(_yy, Y_CONTAINER, $2, NULL) == NULL) _YYERROR("container_stmt"); }
                '{' container_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("container_stmt");
                             _PARSE_DEBUG("container-stmt -> CONTAINER id-arg-str { container-substmts }");}
              ;

container_substmts : container_substmts container_substmt
              | container_substmt
              ;

container_substmt : when_stmt       { _PARSE_DEBUG("container-substmt -> when-stmt"); }
              | if_feature_stmt     { _PARSE_DEBUG("container-substmt -> if-feature-stmt"); }
              | must_stmt           { _PARSE_DEBUG("container-substmt -> must-stmt"); }
              | presence_stmt       { _PARSE_DEBUG("container-substmt -> presence-stmt"); }
              | config_stmt         { _PARSE_DEBUG("container-substmt -> config-stmt"); }
              | status_stmt         { _PARSE_DEBUG("container-substmt -> status-stmt"); }
              | description_stmt    { _PARSE_DEBUG("container-substmt -> description-stmt");}
              | reference_stmt      { _PARSE_DEBUG("container-substmt -> reference-stmt"); }
              | typedef_stmt        { _PARSE_DEBUG("container-substmt -> typedef-stmt"); }
              | grouping_stmt       { _PARSE_DEBUG("container-substmt -> grouping-stmt"); }
              | data_def_stmt       { _PARSE_DEBUG("container-substmt -> data-def-stmt");}
              | action_stmt         { _PARSE_DEBUG("container-substmt -> action-stmt");}
              | notification_stmt   { _PARSE_DEBUG("container-substmt -> notification-stmt");}
              | unknown_stmt        { _PARSE_DEBUG("container-substmt -> unknown-stmt");}
              |                     { _PARSE_DEBUG("container-substmt ->");}
              ;

leaf_stmt     : K_LEAF identifier_str ';'
                { if (ysp_add(_yy, Y_LEAF, $2, NULL) == NULL) _YYERROR("leaf_stmt");
                           _PARSE_DEBUG("leaf-stmt -> LEAF id-arg-str ;");}
              | K_LEAF identifier_str
              { if (ysp_add_push(_yy, Y_LEAF, $2, NULL) == NULL) _YYERROR("leaf_stmt"); }
                '{' leaf_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("leaf_stmt");
                             _PARSE_DEBUG("leaf-stmt -> LEAF id-arg-str { lead-substmts }");}
              ;

leaf_substmts : leaf_substmts leaf_substmt
              | leaf_substmt
              ;

leaf_substmt  : when_stmt            { _PARSE_DEBUG("leaf-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("leaf-substmt -> if-feature-stmt"); }
              | type_stmt            { _PARSE_DEBUG("leaf-substmt -> type-stmt"); }
              | units_stmt           { _PARSE_DEBUG("leaf-substmt -> units-stmt"); }
              | must_stmt            { _PARSE_DEBUG("leaf-substmt -> must-stmt"); }
              | default_stmt         { _PARSE_DEBUG("leaf-substmt -> default-stmt"); }
              | config_stmt          { _PARSE_DEBUG("leaf-substmt -> config-stmt"); }
              | mandatory_stmt       { _PARSE_DEBUG("leaf-substmt -> mandatory-stmt"); }
              | status_stmt          { _PARSE_DEBUG("leaf-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("leaf-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("leaf-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("leaf-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("leaf-substmt ->"); }
              ;

/* leaf-list */
leaf_list_stmt : K_LEAF_LIST identifier_str ';'
                { if (ysp_add(_yy, Y_LEAF_LIST, $2, NULL) == NULL) _YYERROR("leaf_list_stmt");
                           _PARSE_DEBUG("leaf-list-stmt -> LEAF id-arg-str ;");}
              | K_LEAF_LIST identifier_str
              { if (ysp_add_push(_yy, Y_LEAF_LIST, $2, NULL) == NULL) _YYERROR("leaf_list_stmt"); }
                '{' leaf_list_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("leaf_list_stmt");
                             _PARSE_DEBUG("leaf-list-stmt -> LEAF-LIST id-arg-str { lead-substmts }");}
              ;

leaf_list_substmts : leaf_list_substmts leaf_list_substmt
              | leaf_list_substmt
              ;

leaf_list_substmt : when_stmt        { _PARSE_DEBUG("leaf-list-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("leaf-list-substmt -> if-feature-stmt"); }
              | type_stmt            { _PARSE_DEBUG("leaf-list-substmt -> type-stmt"); }
              | units_stmt           { _PARSE_DEBUG("leaf-list-substmt -> units-stmt"); }
              | must_stmt            { _PARSE_DEBUG("leaf-list-substmt -> must-stmt"); }
              | default_stmt         { _PARSE_DEBUG("leaf-list-substmt -> default-stmt"); }
              | config_stmt          { _PARSE_DEBUG("leaf-list-substmt -> config-stmt"); }
              | min_elements_stmt    { _PARSE_DEBUG("leaf-list-substmt -> min-elements-stmt"); }
              | max_elements_stmt    { _PARSE_DEBUG("leaf-list-substmt -> max-elements-stmt"); }
              | ordered_by_stmt      { _PARSE_DEBUG("leaf-list-substmt -> ordered-by-stmt"); }
              | status_stmt          { _PARSE_DEBUG("leaf-list-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("leaf-list-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("leaf-list-substmt -> reference-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("leaf-list-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("leaf-list-stmt ->"); }
              ;

list_stmt     : K_LIST identifier_str ';'
                { if (ysp_add(_yy, Y_LIST, $2, NULL) == NULL) _YYERROR("list_stmt");
                           _PARSE_DEBUG("list-stmt -> LIST id-arg-str ;"); }
              | K_LIST identifier_str
              { if (ysp_add_push(_yy, Y_LIST, $2, NULL) == NULL) _YYERROR("list_stmt"); }
               '{' list_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("list_stmt");
                             _PARSE_DEBUG("list-stmt -> LIST id-arg-str { list-substmts }"); }
              ;

list_substmts : list_substmts list_substmt
                      { _PARSE_DEBUG("list-substmts -> list-substmts list-substmt"); }
              | list_substmt
                      { _PARSE_DEBUG("list-substmts -> list-substmt"); }
              ;

list_substmt  : when_stmt            { _PARSE_DEBUG("list-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("list-substmt -> if-feature-stmt"); }
              | must_stmt            { _PARSE_DEBUG("list-substmt -> must-stmt"); }
              | key_stmt             { _PARSE_DEBUG("list-substmt -> key-stmt"); }
              | unique_stmt          { _PARSE_DEBUG("list-substmt -> unique-stmt"); }
              | config_stmt          { _PARSE_DEBUG("list-substmt -> config-stmt"); }
              | min_elements_stmt    { _PARSE_DEBUG("list-substmt -> min-elements-stmt"); }
              | max_elements_stmt    { _PARSE_DEBUG("list-substmt -> max-elements-stmt"); }
              | ordered_by_stmt      { _PARSE_DEBUG("list-substmt -> ordered-by-stmt"); }
              | status_stmt          { _PARSE_DEBUG("list-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("list-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("list-substmt -> reference-stmt"); }
              | typedef_stmt         { _PARSE_DEBUG("list-substmt -> typedef-stmt"); }
              | grouping_stmt        { _PARSE_DEBUG("list-substmt -> grouping-stmt"); }
              | data_def_stmt        { _PARSE_DEBUG("list-substmt -> data-def-stmt"); }
              | action_stmt          { _PARSE_DEBUG("list-substmt -> action-stmt"); }
              | notification_stmt    { _PARSE_DEBUG("list-substmt -> notification-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("list-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("list-substmt -> "); }
              ;

/* key-stmt = key-keyword sep key-arg-str */
key_stmt      : K_KEY string stmtend
                { if (ysp_add(_yy, Y_KEY, $2, NULL)== NULL) _YYERROR("key_stmt");
                           _PARSE_DEBUG("key-stmt -> KEY id-arg-str ;");}
              ;

/* unique-stmt = unique-keyword unique-arg-str */
unique_stmt   : K_UNIQUE string stmtend
                { if (ysp_add(_yy, Y_UNIQUE, $2, NULL)== NULL) _YYERROR("unique_stmt");
                           _PARSE_DEBUG("key-stmt -> KEY id-arg-str ;");}
              ;

/* choice */
choice_stmt   : K_CHOICE identifier_str ';'
               { if (ysp_add(_yy, Y_CHOICE, $2, NULL) == NULL) _YYERROR("choice_stmt");
                           _PARSE_DEBUG("choice-stmt -> CHOICE id-arg-str ;"); }
              | K_CHOICE identifier_str
              { if (ysp_add_push(_yy, Y_CHOICE, $2, NULL) == NULL) _YYERROR("choice_stmt"); }
               '{' choice_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("choice_stmt");
                             _PARSE_DEBUG("choice-stmt -> CHOICE id-arg-str { choice-substmts }"); }
              ;

choice_substmts : choice_substmts choice_substmt
                      { _PARSE_DEBUG("choice-substmts -> choice-substmts choice-substmt"); }
              | choice_substmt
                      { _PARSE_DEBUG("choice-substmts -> choice-substmt"); }
              ;

choice_substmt : when_stmt           { _PARSE_DEBUG("choice-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("choice-substmt -> if-feature-stmt"); }
              | default_stmt         { _PARSE_DEBUG("choice-substmt -> default-stmt"); }
              | config_stmt          { _PARSE_DEBUG("choice-substmt -> config-stmt"); }
              | mandatory_stmt       { _PARSE_DEBUG("choice-substmt -> mandatory-stmt"); }
              | status_stmt          { _PARSE_DEBUG("choice-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("choice-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("choice-substmt -> reference-stmt"); }
              | short_case_stmt      { _PARSE_DEBUG("choice-substmt -> short-case-stmt");}
              | case_stmt            { _PARSE_DEBUG("choice-substmt -> case-stmt");}
              | unknown_stmt         { _PARSE_DEBUG("choice-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("choice-substmt -> "); }
              ;

/* case */
case_stmt   : K_CASE identifier_str ';'
               { if (ysp_add(_yy, Y_CASE, $2, NULL) == NULL) _YYERROR("case_stmt");
                           _PARSE_DEBUG("case-stmt -> CASE id-arg-str ;"); }
              | K_CASE identifier_str
              { if (ysp_add_push(_yy, Y_CASE, $2, NULL) == NULL) _YYERROR("case_stmt"); }
               '{' case_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("case_stmt");
                             _PARSE_DEBUG("case-stmt -> CASE id-arg-str { case-substmts }"); }
              ;

case_substmts : case_substmts case_substmt
                      { _PARSE_DEBUG("case-substmts -> case-substmts case-substmt"); }
              | case_substmt
                      { _PARSE_DEBUG("case-substmts -> case-substmt"); }
              ;

case_substmt  : when_stmt            { _PARSE_DEBUG("case-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("case-substmt -> if-feature-stmt"); }
              | status_stmt          { _PARSE_DEBUG("case-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("case-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("case-substmt -> reference-stmt"); }
              | data_def_stmt        { _PARSE_DEBUG("case-substmt -> data-def-stmt");}
              | unknown_stmt         { _PARSE_DEBUG("case-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("case-substmt -> "); }
              ;

anydata_stmt   : K_ANYDATA identifier_str ';'
               { if (ysp_add(_yy, Y_ANYDATA, $2, NULL) == NULL) _YYERROR("anydata_stmt");
                           _PARSE_DEBUG("anydata-stmt -> ANYDATA id-arg-str ;"); }
              | K_ANYDATA identifier_str
              { if (ysp_add_push(_yy, Y_ANYDATA, $2, NULL) == NULL) _YYERROR("anydata_stmt"); }
               '{' anyxml_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("anydata_stmt");
                             _PARSE_DEBUG("anydata-stmt -> ANYDATA id-arg-str { anyxml-substmts }"); }
              ;

/* anyxml */
anyxml_stmt   : K_ANYXML identifier_str ';'
               { if (ysp_add(_yy, Y_ANYXML, $2, NULL) == NULL) _YYERROR("anyxml_stmt");
                           _PARSE_DEBUG("anyxml-stmt -> ANYXML id-arg-str ;"); }
              | K_ANYXML identifier_str
              { if (ysp_add_push(_yy, Y_ANYXML, $2, NULL) == NULL) _YYERROR("anyxml_stmt"); }
               '{' anyxml_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("anyxml_stmt");
                             _PARSE_DEBUG("anyxml-stmt -> ANYXML id-arg-str { anyxml-substmts }"); }
              ;

anyxml_substmts : anyxml_substmts anyxml_substmt
                      { _PARSE_DEBUG("anyxml-substmts -> anyxml-substmts anyxml-substmt"); }
              | anyxml_substmt
                      { _PARSE_DEBUG("anyxml-substmts -> anyxml-substmt"); }
              ;

anyxml_substmt  : when_stmt          { _PARSE_DEBUG("anyxml-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("anyxml-substmt -> if-feature-stmt"); }
              | must_stmt            { _PARSE_DEBUG("anyxml-substmt -> must-stmt"); }
              | config_stmt          { _PARSE_DEBUG("anyxml-substmt -> config-stmt"); }
              | mandatory_stmt       { _PARSE_DEBUG("anyxml-substmt -> mandatory-stmt"); }
              | status_stmt          { _PARSE_DEBUG("anyxml-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("anyxml-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("anyxml-substmt -> reference-stmt"); }
              | ustring ':' ustring ';' { free($1); free($3);
                                       _PARSE_DEBUG("anyxml-substmt -> anyxml extension"); }
              | unknown_stmt         { _PARSE_DEBUG("anyxml-substmt -> unknown-stmt");}
              ;

/* uses-stmt = uses-keyword identifier-ref-arg-str */
uses_stmt     : K_USES identifier_ref_arg_str ';'
               { if (ysp_add(_yy, Y_USES, $2, NULL) == NULL) _YYERROR("uses_stmt");
                           _PARSE_DEBUG("uses-stmt -> USES identifier-ref-arg-str ;"); }
              | K_USES identifier_ref_arg_str
              { if (ysp_add_push(_yy, Y_USES, $2, NULL) == NULL) _YYERROR("uses_stmt"); }
               '{' uses_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("uses_stmt");
                             _PARSE_DEBUG("uses-stmt -> USES identifier-ref-arg-str { uses-substmts }"); }
              ;

uses_substmts : uses_substmts uses_substmt
                      { _PARSE_DEBUG("uses-substmts -> uses-substmts uses-substmt"); }
              | uses_substmt
                      { _PARSE_DEBUG("uses-substmts -> uses-substmt"); }
              ;

uses_substmt  : when_stmt            { _PARSE_DEBUG("uses-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("uses-substmt -> if-feature-stmt"); }
              | status_stmt          { _PARSE_DEBUG("uses-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("uses-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("uses-substmt -> reference-stmt"); }
              | refine_stmt          { _PARSE_DEBUG("uses-substmt -> refine-stmt"); }
              | uses_augment_stmt    { _PARSE_DEBUG("uses-substmt -> uses-augment-stmt"); }
              | unknown_stmt         { _PARSE_DEBUG("uses-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("uses-substmt -> "); }
              ;

/* refine-stmt = refine-keyword sep refine-arg-str */
refine_stmt   : K_REFINE refine_arg_str ';'
               { if (ysp_add(_yy, Y_REFINE, $2, NULL) == NULL) _YYERROR("refine_stmt");
                   _PARSE_DEBUG("refine-stmt -> REFINE id-arg-str ;"); }
              | K_REFINE refine_arg_str '{'
              { if (ysp_add_push(_yy, Y_REFINE, $2, NULL) == NULL) _YYERROR("refine_stmt"); }
                  refine_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("refine_stmt");
                               _PARSE_DEBUG("refine-stmt -> REFINE id-arg-str { refine-substmts }"); }
              ;

refine_substmts : refine_substmts refine_substmt
                      { _PARSE_DEBUG("refine-substmts -> refine-substmts refine-substmt"); }
              | refine_substmt
                      { _PARSE_DEBUG("refine-substmts -> refine-substmt"); }
              ;

refine_substmt  : if_feature_stmt  { _PARSE_DEBUG("refine-substmt -> if-feature-stmt"); }
              | must_stmt          { _PARSE_DEBUG("refine-substmt -> must-stmt"); }
              | presence_stmt      { _PARSE_DEBUG("refine-substmt -> presence-stmt"); }
              | default_stmt       { _PARSE_DEBUG("refine-substmt -> default-stmt"); }
              | config_stmt        { _PARSE_DEBUG("refine-substmt -> config-stmt"); }
              | mandatory_stmt     { _PARSE_DEBUG("refine-substmt -> mandatory-stmt"); }
              | min_elements_stmt  { _PARSE_DEBUG("refine-substmt -> min-elements-stmt"); }
              | max_elements_stmt  { _PARSE_DEBUG("refine-substmt -> max-elements-stmt"); }
              | description_stmt   { _PARSE_DEBUG("refine-substmt -> description-stmt"); }
              | reference_stmt     { _PARSE_DEBUG("refine-substmt -> reference-stmt"); }
              | unknown_stmt       { _PARSE_DEBUG("refine-substmt -> unknown-stmt");}
              |                    { _PARSE_DEBUG("refine-substmt -> "); }
              ;

/* refine-arg-str      = < a string that matches the rule refine-arg >
 * @see yang_schema_nodeid_subparse sub-parser
 */
refine_arg_str :  string
                 { $$ = $1;
                   _PARSE_DEBUG("refine-arg-str -> < a string that matches the rule refine-arg >"); }
               ;

/* uses-augment-stmt = augment-keyword uses-augment-arg-str 
 * Same keyword as in augment-stmt, but here is sub of uses
 */
uses_augment_stmt : K_AUGMENT uses_augment_arg_str
                    { if (ysp_add_push(_yy, Y_AUGMENT, $2, NULL) == NULL) _YYERROR("uses_augment_stmt"); }
                    '{' augment_substmts '}'
                      { if (ystack_pop(_yy) < 0) _YYERROR("uses_augment_stmt");
                             _PARSE_DEBUG("uses-augment-stmt -> AUGMENT uses-augment-arg-str { augment-substmts }"); }

/* augment-stmt = augment-keyword sep augment-arg-str 
 * augment_stmt   : K_AUGMENT abs_schema_nodeid_strs
 * Same keyword as in uses-augment-stmt, but here is sub of (sub)module
 */
augment_stmt   : K_AUGMENT augment_arg_str
                   { if (ysp_add_push(_yy, Y_AUGMENT, $2, NULL) == NULL) _YYERROR("augment_stmt"); }
               '{' augment_substmts '}'
                   { if (ystack_pop(_yy) < 0) _YYERROR("augment_stmt");
                             _PARSE_DEBUG("augment-stmt -> AUGMENT abs-schema-node-str { augment-substmts }"); }
              ;

augment_substmts : augment_substmts augment_substmt
                      { _PARSE_DEBUG("augment-substmts -> augment-substmts augment-substmt"); }
              | augment_substmt
                      { _PARSE_DEBUG("augment-substmts -> augment-substmt"); }
              ;

augment_substmt : when_stmt          { _PARSE_DEBUG("augment-substmt -> when-stmt"); }
              | if_feature_stmt      { _PARSE_DEBUG("augment-substmt -> if-feature-stmt"); }
              | status_stmt          { _PARSE_DEBUG("augment-substmt -> status-stmt"); }
              | description_stmt     { _PARSE_DEBUG("augment-substmt -> description-stmt"); }
              | reference_stmt       { _PARSE_DEBUG("augment-substmt -> reference-stmt"); }
              | data_def_stmt        { _PARSE_DEBUG("augment-substmt -> data-def-stmt"); }
              | case_stmt            { _PARSE_DEBUG("augment-substmt -> case-stmt");}
              | action_stmt          { _PARSE_DEBUG("augment-substmt -> action-stmt");}
              | notification_stmt    { _PARSE_DEBUG("augment-substmt -> notification-stmt");}
              | unknown_stmt         { _PARSE_DEBUG("augment-substmt -> unknown-stmt");}
              |                      { _PARSE_DEBUG("augment-substmt -> "); }
              ;

/* augment-arg-str = < a string that matches the rule augment-arg >
 * @see yang_schema_nodeid_subparse sub-parser
 */
augment_arg_str :  string
                 { $$ = $1;
                   _PARSE_DEBUG("augment-arg-str -> < a string that matches the rule augment-arg >"); }
               ;

/* uses-augment-arg-str = < a string that matches the rule uses-augment-arg >
 * @see yang_schema_nodeid_subparse sub-parser
 */
uses_augment_arg_str :  string
                 { $$ = $1;
                   _PARSE_DEBUG("uses-augment-arg-str -> < a string that matches the rule uses-augment-arg >"); }
               ;

/* when */
when_stmt   : K_WHEN string ';'
               { if (ysp_add(_yy, Y_WHEN, $2, NULL) == NULL) _YYERROR("when_stmt");
                           _PARSE_DEBUG("when-stmt -> WHEN string ;"); }
            | K_WHEN string
            { if (ysp_add_push(_yy, Y_WHEN, $2, NULL) == NULL) _YYERROR("when_stmt"); }
               '{' when_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("when_stmt");
                             _PARSE_DEBUG("when-stmt -> WHEN string { when-substmts }"); }
              ;

when_substmts : when_substmts when_substmt
                      { _PARSE_DEBUG("when-substmts -> when-substmts when-substmt"); }
              | when_substmt
                      { _PARSE_DEBUG("when-substmts -> when-substmt"); }
              ;

when_substmt  : description_stmt { _PARSE_DEBUG("when-substmt -> description-stmt"); }
              | reference_stmt   { _PARSE_DEBUG("when-substmt -> reference-stmt"); }
              |                  { _PARSE_DEBUG("when-substmt -> "); }
              ;

/* rpc */
rpc_stmt   : K_RPC identifier_str ';'
               { if (ysp_add(_yy, Y_RPC, $2, NULL) == NULL) _YYERROR("rpc_stmt");
                           _PARSE_DEBUG("rpc-stmt -> RPC id-arg-str ;"); }
           | K_RPC identifier_str
           { if (ysp_add_push(_yy, Y_RPC, $2, NULL) == NULL) _YYERROR("rpc_stmt"); }
             '{' rpc_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("rpc_stmt");
                             _PARSE_DEBUG("rpc-stmt -> RPC id-arg-str { rpc-substmts }"); }
              ;

rpc_substmts : rpc_substmts rpc_substmt
                      { _PARSE_DEBUG("rpc-substmts -> rpc-substmts rpc-substmt"); }
              | rpc_substmt
                      { _PARSE_DEBUG("rpc-substmts -> rpc-substmt"); }
              ;

rpc_substmt   : if_feature_stmt  { _PARSE_DEBUG("rpc-substmt -> if-feature-stmt"); }
              | status_stmt      { _PARSE_DEBUG("rpc-substmt -> status-stmt"); }
              | description_stmt { _PARSE_DEBUG("rpc-substmt -> description-stmt"); }
              | reference_stmt   { _PARSE_DEBUG("rpc-substmt -> reference-stmt"); }
              | typedef_stmt     { _PARSE_DEBUG("rpc-substmt -> typedef-stmt"); }
              | grouping_stmt    { _PARSE_DEBUG("rpc-substmt -> grouping-stmt"); }
              | input_stmt       { _PARSE_DEBUG("rpc-substmt -> input-stmt"); }
              | output_stmt      { _PARSE_DEBUG("rpc-substmt -> output-stmt"); }
              | unknown_stmt     { _PARSE_DEBUG("rpc-substmt -> unknown-stmt");}
              |                  { _PARSE_DEBUG("rpc-substmt -> "); }
              ;

/* action */
action_stmt   : K_ACTION identifier_str ';'
               { if (ysp_add(_yy, Y_ACTION, $2, NULL) == NULL) _YYERROR("action_stmt");
                           _PARSE_DEBUG("action-stmt -> ACTION id-arg-str ;"); }
              | K_ACTION identifier_str
              { if (ysp_add_push(_yy, Y_ACTION, $2, NULL) == NULL) _YYERROR("action_stmt"); }
               '{' rpc_substmts '}'
                           { if (ystack_pop(_yy) < 0) _YYERROR("action_stmt");
                             _PARSE_DEBUG("action-stmt -> ACTION id-arg-str { rpc-substmts }"); }
              ;

/* notification */
notification_stmt : K_NOTIFICATION identifier_str ';'
                        { if (ysp_add(_yy, Y_NOTIFICATION, $2, NULL) == NULL) _YYERROR("notification_stmt");
                           _PARSE_DEBUG("notification-stmt -> NOTIFICATION id-arg-str ;"); }
                  | K_NOTIFICATION identifier_str
                  { if (ysp_add_push(_yy, Y_NOTIFICATION, $2, NULL) == NULL) _YYERROR("notification_stmt"); }
                    '{' notification_substmts '}'
                        { if (ystack_pop(_yy) < 0) _YYERROR("notification_stmt");
                             _PARSE_DEBUG("notification-stmt -> NOTIFICATION id-arg-str { notification-substmts }"); }
                  ;

notification_substmts : notification_substmts notification_substmt
                         { _PARSE_DEBUG("notification-substmts -> notification-substmts notification-substmt"); }
                      | notification_substmt
                         { _PARSE_DEBUG("notification-substmts -> notification-substmt"); }
                      ;

notification_substmt : if_feature_stmt  { _PARSE_DEBUG("notification-substmt -> if-feature-stmt"); }
                     | must_stmt        { _PARSE_DEBUG("notification-substmt -> must-stmt"); }
                     | status_stmt      { _PARSE_DEBUG("notification-substmt -> status-stmt"); }
                     | description_stmt { _PARSE_DEBUG("notification-substmt -> description-stmt"); }
                     | reference_stmt   { _PARSE_DEBUG("notification-substmt -> reference-stmt"); }
                     | typedef_stmt     { _PARSE_DEBUG("notification-substmt -> typedef-stmt"); }
                     | grouping_stmt    { _PARSE_DEBUG("notification-substmt -> grouping-stmt"); }
                     | data_def_stmt    { _PARSE_DEBUG("notification-substmt -> data-def-stmt"); }
                     | unknown_stmt     { _PARSE_DEBUG("notification-substmt -> unknown-stmt");}
                     |                  { _PARSE_DEBUG("notification-substmt -> "); }
                     ;

deviation_stmt : K_DEVIATION string
                        { if (ysp_add_push(_yy, Y_DEVIATION, $2, NULL) == NULL) _YYERROR("deviation_stmt"); }
                    '{' deviation_substmts '}'
                        { if (ystack_pop(_yy) < 0) _YYERROR("deviation_stmt");
                             _PARSE_DEBUG("deviation-stmt -> DEVIATION id-arg-str { notification-substmts }"); }
               ;

deviation_substmts : deviation_substmts deviation_substmt
                         { _PARSE_DEBUG("deviation-substmts -> deviation-substmts deviation-substmt"); }
                      | deviation_substmt
                         { _PARSE_DEBUG("deviation-substmts -> deviation-substmt"); }
                      ;

deviation_substmt : description_stmt  { _PARSE_DEBUG("deviation-substmt -> description-stmt"); }
                  | reference_stmt    { _PARSE_DEBUG("deviation-substmt -> reference-stmt"); }
                  | deviate_not_supported_stmt { _PARSE_DEBUG("yang-stmt -> deviate-not-supported-stmt");}
                  | deviate_add_stmt     { _PARSE_DEBUG("deviation-stmt -> deviate-add-stmt");}
                  | deviate_delete_stmt  { _PARSE_DEBUG("deviation-stmt -> deviate-delete-stmt");}
                  | deviate_replace_stmt { _PARSE_DEBUG("deviation-stmt -> deviate-replace-stmt");}
                  ;

not_supported_keyword_str : D_NOT_SUPPORTED
                          | '"' D_NOT_SUPPORTED '"'
                          | '\'' D_NOT_SUPPORTED '\''
                          ;

deviate_not_supported_stmt
                  : K_DEVIATE not_supported_keyword_str ';'
                  { if (ysp_add(_yy, Y_DEVIATE, strdup("not-supported"), NULL) == NULL) _YYERROR("notification_stmt");
                           _PARSE_DEBUG("deviate-not-supported-stmt -> DEVIATE not-supported ;"); }
                  ;

add_keyword_str    : D_ADD
                   | '"' D_ADD '"'
                   | '\'' D_ADD '\''
                   ;

deviate_add_stmt   : K_DEVIATE add_keyword_str ';'
                  { if (ysp_add(_yy, Y_DEVIATE, strdup("add"), NULL) == NULL) _YYERROR("notification_stmt");
                           _PARSE_DEBUG("deviate-add-stmt -> DEVIATE add ;"); }
                  | K_DEVIATE add_keyword_str
                  { if (ysp_add_push(_yy, Y_DEVIATE, strdup("add"), NULL) == NULL) _YYERROR("deviate_stmt"); }
                    '{' deviate_add_substmts '}'
                        { if (ystack_pop(_yy) < 0) _YYERROR("deviate_stmt");
                             _PARSE_DEBUG("deviate-add-stmt -> DEVIATE add { deviate-substmts }"); }
                   ;

deviate_add_substmts : deviate_add_substmts deviate_add_substmt
                         { _PARSE_DEBUG("deviate-add-substmts -> deviate-add-substmts deviate-add-substmt"); }
                     | deviate_add_substmt
                         { _PARSE_DEBUG("deviate-add-substmts -> deviate-add-substmt"); }
                     ;

deviate_add_substmt : units_stmt    { _PARSE_DEBUG("deviate-add-substmt -> units-stmt"); }
                | must_stmt         { _PARSE_DEBUG("deviate-add-substmt -> must-stmt"); }
                | unique_stmt       { _PARSE_DEBUG("deviate-add-substmt -> unique-stmt"); }
                | default_stmt      { _PARSE_DEBUG("deviate-add-substmt -> default-stmt"); }
                | config_stmt       { _PARSE_DEBUG("deviate-add-substmt -> config-stmt"); }
                | mandatory_stmt    { _PARSE_DEBUG("deviate-add-substmt -> mandatory-stmt"); }
                | min_elements_stmt { _PARSE_DEBUG("deviate-add-substmt -> min-elements-stmt"); }
                | max_elements_stmt { _PARSE_DEBUG("deviate-add-substmt -> max-elements-stmt"); }
                |                   { _PARSE_DEBUG("deviate-add-substmt -> "); }
                ;

delete_keyword_str : D_DELETE
                   | '"' D_DELETE '"'
                   | '\'' D_DELETE '\''
                   ;

deviate_delete_stmt   : K_DEVIATE delete_keyword_str ';'
                  { if (ysp_add(_yy, Y_DEVIATE, strdup("delete"), NULL) == NULL) _YYERROR("notification_stmt");
                           _PARSE_DEBUG("deviate-delete-stmt -> DEVIATE delete ;"); }
                  | K_DEVIATE delete_keyword_str
                  { if (ysp_add_push(_yy, Y_DEVIATE, strdup("delete"), NULL) == NULL) _YYERROR("deviate_stmt"); }
                    '{' deviate_delete_substmts '}'
                        { if (ystack_pop(_yy) < 0) _YYERROR("deviate_stmt");
                             _PARSE_DEBUG("deviate-delete-stmt -> DEVIATE delete { deviate-delete-substmts }"); }
                   ;

deviate_delete_substmts : deviate_delete_substmts deviate_delete_substmt
                         { _PARSE_DEBUG("deviate-delete-substmts -> deviate-delete-substmts deviate-delete-substmt"); }
                     | deviate_delete_substmt
                         { _PARSE_DEBUG("deviate-delete-substmts -> deviate-delete-substmt"); }
                     ;
deviate_delete_substmt : units_stmt { _PARSE_DEBUG("deviate-delete-substmt -> units-stmt"); }
                | must_stmt         { _PARSE_DEBUG("deviate-delete-substmt -> must-stmt"); }
                | unique_stmt       { _PARSE_DEBUG("deviate-delete-substmt -> unique-stmt"); }
                | default_stmt      { _PARSE_DEBUG("deviate-delete-substmt -> default-stmt"); }
                |                   { _PARSE_DEBUG("deviate-delete-substmt -> "); }
                ;

replace_keyword_str : D_REPLACE
                   | '"' D_REPLACE '"'
                   | '\'' D_REPLACE '\''
                   ;

deviate_replace_stmt   : K_DEVIATE replace_keyword_str ';'
                  { if (ysp_add(_yy, Y_DEVIATE, strdup("replace"), NULL) == NULL) _YYERROR("notification_stmt");
                           _PARSE_DEBUG("deviate-replace-stmt -> DEVIATE replace ;"); }
                  | K_DEVIATE replace_keyword_str
                  { if (ysp_add_push(_yy, Y_DEVIATE, strdup("replace"), NULL) == NULL) _YYERROR("deviate_stmt"); }
                    '{' deviate_replace_substmts '}'
                        { if (ystack_pop(_yy) < 0) _YYERROR("deviate_stmt");
                             _PARSE_DEBUG("deviate-replace-stmt -> DEVIATE replace { deviate-replace-substmts }"); }
                   ;

deviate_replace_substmts : deviate_replace_substmts deviate_replace_substmt
                         { _PARSE_DEBUG("deviate-replace-substmts -> deviate-replace-substmts deviate-replace-substmt"); }
                     | deviate_replace_substmt
                         { _PARSE_DEBUG("deviate-replace-substmts -> deviate-replace-substmt"); }
                     ;

deviate_replace_substmt : type_stmt         { _PARSE_DEBUG("deviate-replace-substmt -> type-stmt"); }
                | units_stmt        { _PARSE_DEBUG("deviate-replace-substmt -> units-stmt"); }
                | default_stmt      { _PARSE_DEBUG("deviate-replace-substmt -> default-stmt"); }
                | config_stmt       { _PARSE_DEBUG("deviate-replace-substmt -> config-stmt"); }
                | mandatory_stmt    { _PARSE_DEBUG("deviate-replace-substmt -> mandatory-stmt"); }
                | min_elements_stmt { _PARSE_DEBUG("deviate-replace-substmt -> min-elements-stmt"); }
                | max_elements_stmt { _PARSE_DEBUG("deviate-replace-substmt -> max-elements-stmt"); }
                |                   { _PARSE_DEBUG("deviate-replace-substmt -> "); }
                ;

/* Represents the usage of an extension
   unknown-statement   = prefix ":" identifier [sep string] optsep
                         (";" /
                          "{" optsep
                              *((yang-stmt / unknown-statement) optsep)
                           "}") stmt
 *
 */
unknown_stmt  : ustring ':' ustring optsep ';'
              {
                  char *id;
                  if ((id=clixon_string_del_join($1, ":", $3)) == NULL) _YYERROR("unknown_stmt");
                  free($3);
                  if (ysp_add(_yy, Y_UNKNOWN, id, NULL) == NULL) _YYERROR("unknown_stmt");
                  _PARSE_DEBUG("unknown-stmt -> ustring : ustring ;");
               }
              | ustring ':' ustring sep string optsep ';'
                {
                    char *id;
                    if ((id=clixon_string_del_join($1, ":", $3)) == NULL) _YYERROR("unknown_stmt");
                    free($3);
                    if (ysp_add(_yy, Y_UNKNOWN, id, $5) == NULL){ _YYERROR("unknown_stmt"); }
                    _PARSE_DEBUG("unknown-stmt -> ustring : ustring sep string ;");
               }
              | ustring ':' ustring optsep
                 {
                     char *id;
                     if ((id=clixon_string_del_join($1, ":", $3)) == NULL) _YYERROR("unknown_stmt");
                     free($3);
                     if (ysp_add_push(_yy, Y_UNKNOWN, id, NULL) == NULL) _YYERROR("unknown_stmt"); }
                 '{' unknown_substmts '}'
                       { if (ystack_pop(_yy) < 0) _YYERROR("unknown_stmt");
                         _PARSE_DEBUG("unknown-stmt -> ustring : ustring { yang-stmts }"); }
              | ustring ':' ustring sep string optsep
                 {
                     char *id;
                     if ((id=clixon_string_del_join($1, ":", $3)) == NULL) _YYERROR("unknown_stmt");
                     free($3);
                     if (ysp_add_push(_yy, Y_UNKNOWN, id, $5) == NULL) _YYERROR("unknown_stmt"); }
                 '{' unknown_substmts '}'
                       { if (ystack_pop(_yy) < 0) _YYERROR("unknown_stmt");
                         _PARSE_DEBUG("unknown-stmt -> ustring : ustring string { yang-stmts }"); }
              ;

unknown_substmts : unknown_substmts unknown_substmt
                         { _PARSE_DEBUG("unknown-substmts -> unknown-substmts unknown-substmt"); }
                 | unknown_substmt
                         { _PARSE_DEBUG("unknown-substmts -> unknown-substmt"); }
                 ;

unknown_substmt : yang_stmt          { _PARSE_DEBUG("unknown-substmt -> yang-stmt");}
                | unknown_stmt       { _PARSE_DEBUG("unknown-substmt -> unknown-stmt");}
;

yang_stmt     : action_stmt          { _PARSE_DEBUG("yang-stmt -> action-stmt");}
              | anydata_stmt         { _PARSE_DEBUG("yang-stmt -> anydata-stmt");}
              | anyxml_stmt          { _PARSE_DEBUG("yang-stmt -> anyxml-stmt");}
              | argument_stmt        { _PARSE_DEBUG("yang-stmt -> argument-stmt");}
              | augment_stmt         { _PARSE_DEBUG("yang-stmt -> augment-stmt");}
              | base_stmt            { _PARSE_DEBUG("yang-stmt -> base-stmt");}
              | bit_stmt             { _PARSE_DEBUG("yang-stmt -> bit-stmt");}
              | case_stmt            { _PARSE_DEBUG("yang-stmt -> case-stmt");}
              | choice_stmt          { _PARSE_DEBUG("yang-stmt -> choice-stmt");}
              | config_stmt          { _PARSE_DEBUG("yang-stmt -> config-stmt");}
              | contact_stmt         { _PARSE_DEBUG("yang-stmt -> contact-stmt");}
              | container_stmt       { _PARSE_DEBUG("yang-stmt -> container-stmt");}
              | default_stmt         { _PARSE_DEBUG("yang-stmt -> default-stmt");}
              | description_stmt     { _PARSE_DEBUG("yang-stmt -> description-stmt");}
              | deviate_not_supported_stmt { _PARSE_DEBUG("yang-stmt -> deviate-not-supported-stmt");}
              | deviate_add_stmt     { _PARSE_DEBUG("yang-stmt -> deviate-add-stmt");}
              | deviate_delete_stmt  { _PARSE_DEBUG("yang-stmt -> deviate-delete-stmt");}
              | deviate_replace_stmt { _PARSE_DEBUG("yang-stmt -> deviate-replace-stmt");}
              | deviation_stmt       { _PARSE_DEBUG("yang-stmt -> deviation-stmt");}
              | enum_stmt            { _PARSE_DEBUG("yang-stmt -> enum-stmt");}
              | error_app_tag_stmt   { _PARSE_DEBUG("yang-stmt -> error-app-tag-stmt");}
              | error_message_stmt   { _PARSE_DEBUG("yang-stmt -> error-message-stmt");}
              | extension_stmt       { _PARSE_DEBUG("yang-stmt -> extension-stmt");}
              | feature_stmt         { _PARSE_DEBUG("yang-stmt -> feature-stmt");}
              | fraction_digits_stmt { _PARSE_DEBUG("yang-stmt -> fraction-digits-stmt");}
              | grouping_stmt        { _PARSE_DEBUG("yang-stmt -> grouping-stmt");}
              | identity_stmt        { _PARSE_DEBUG("yang-stmt -> identity-stmt");}
              | if_feature_stmt      { _PARSE_DEBUG("yang-stmt -> if-feature-stmt");}
              | import_stmt          { _PARSE_DEBUG("yang-stmt -> import-stmt");}
              | include_stmt         { _PARSE_DEBUG("yang-stmt -> include-stmt");}
              | input_stmt           { _PARSE_DEBUG("yang-stmt -> input-stmt");}
              | key_stmt             { _PARSE_DEBUG("yang-stmt -> key-stmt");}
              | leaf_list_stmt       { _PARSE_DEBUG("yang-stmt -> leaf-list-stmt");}
              | leaf_stmt            { _PARSE_DEBUG("yang-stmt -> leaf-stmt");}
              | length_stmt          { _PARSE_DEBUG("yang-stmt -> length-stmt");}
              | list_stmt            { _PARSE_DEBUG("yang-stmt -> list-stmt");}
              | mandatory_stmt       { _PARSE_DEBUG("yang-stmt -> mandatory-stmt");}
              | max_elements_stmt    { _PARSE_DEBUG("yang-stmt -> max-elements-stmt");}
              | min_elements_stmt    { _PARSE_DEBUG("yang-stmt -> min-elements-stmt");}
              | modifier_stmt        { _PARSE_DEBUG("yang-stmt -> modifier-stmt");}
              | module_stmt          { _PARSE_DEBUG("yang-stmt -> module-stmt");}
              | must_stmt            { _PARSE_DEBUG("yang-stmt -> must-stmt");}
              | namespace_stmt       { _PARSE_DEBUG("yang-stmt -> namespace-stmt");}
              | notification_stmt    { _PARSE_DEBUG("yang-stmt -> notification-stmt");}
              | ordered_by_stmt      { _PARSE_DEBUG("yang-stmt -> ordered-by-stmt");}
              | organization_stmt    { _PARSE_DEBUG("yang-stmt -> organization-stmt");}
              | output_stmt          { _PARSE_DEBUG("yang-stmt -> output-stmt");}
              | path_stmt            { _PARSE_DEBUG("yang-stmt -> path-stmt");}
              | pattern_stmt         { _PARSE_DEBUG("yang-stmt -> pattern-stmt");}
              | position_stmt        { _PARSE_DEBUG("yang-stmt -> position-stmt");}
              | prefix_stmt          { _PARSE_DEBUG("yang-stmt -> prefix-stmt");}
              | presence_stmt        { _PARSE_DEBUG("yang-stmt -> presence-stmt");}
              | range_stmt           { _PARSE_DEBUG("yang-stmt -> range-stmt");}
              | reference_stmt       { _PARSE_DEBUG("yang-stmt -> reference-stmt");}
              | refine_stmt          { _PARSE_DEBUG("yang-stmt -> refine-stmt");}
              | require_instance_stmt { _PARSE_DEBUG("yang-stmt -> require-instance-stmt");}
              | revision_date_stmt   { _PARSE_DEBUG("yang-stmt -> revision-date-stmt");}
              | revision_stmt        { _PARSE_DEBUG("yang-stmt -> revision-stmt");}
              | rpc_stmt             { _PARSE_DEBUG("yang-stmt -> rpc-stmt");}
              | status_stmt          { _PARSE_DEBUG("yang-stmt -> status-stmt");}
              | submodule_stmt       { _PARSE_DEBUG("yang-stmt -> submodule-stmt");}
              | typedef_stmt         { _PARSE_DEBUG("yang-stmt -> typedef-stmt");}
              | type_stmt            { _PARSE_DEBUG("yang-stmt -> type-stmt");}
              | unique_stmt          { _PARSE_DEBUG("yang-stmt -> unique-stmt");}
              | units_stmt           { _PARSE_DEBUG("yang-stmt -> units-stmt");}
              | uses_augment_stmt    { _PARSE_DEBUG("yang-stmt -> uses-augment-stmt");}
              | uses_stmt            { _PARSE_DEBUG("yang-stmt -> uses-stmt");}
              | value_stmt           { _PARSE_DEBUG("yang-stmt -> value-stmt");}
              | when_stmt            { _PARSE_DEBUG("yang-stmt -> when-stmt");}
              | yang_version_stmt    { _PARSE_DEBUG("yang-stmt -> yang-version-stmt");}
              /*              | yin_element_stmt     { _PARSE_DEBUG("yang-stmt -> list-stmt");} */
              ;

/* body */
body_stmts    : body_stmts body_stmt { _PARSE_DEBUG("body-stmts -> body-stmts body-stmt"); }
              | body_stmt            { _PARSE_DEBUG("body-stmts -> body-stmt");}
              ;

body_stmt     : extension_stmt       { _PARSE_DEBUG("body-stmt -> extension-stmt");}
              | feature_stmt         { _PARSE_DEBUG("body-stmt -> feature-stmt");}
              | identity_stmt        { _PARSE_DEBUG("body-stmt -> identity-stmt");}
              | typedef_stmt         { _PARSE_DEBUG("body-stmt -> typedef-stmt");}
              | grouping_stmt        { _PARSE_DEBUG("body-stmt -> grouping-stmt");}
              | data_def_stmt        { _PARSE_DEBUG("body-stmt -> data-def-stmt");}
              | augment_stmt         { _PARSE_DEBUG("body-stmt -> augment-stmt");}
              | rpc_stmt             { _PARSE_DEBUG("body-stmt -> rpc-stmt");}
              | notification_stmt    { _PARSE_DEBUG("body-stmt -> notification-stmt");}
              | deviation_stmt       { _PARSE_DEBUG("body-stmt -> deviation-stmt");}
              ;

data_def_stmt : container_stmt       { _PARSE_DEBUG("data-def-stmt -> container-stmt");}
              | leaf_stmt            { _PARSE_DEBUG("data-def-stmt -> leaf-stmt");}
              | leaf_list_stmt       { _PARSE_DEBUG("data-def-stmt -> leaf-list-stmt");}
              | list_stmt            { _PARSE_DEBUG("data-def-stmt -> list-stmt");}
              | choice_stmt          { _PARSE_DEBUG("data-def-stmt -> choice-stmt");}
              | anydata_stmt         { _PARSE_DEBUG("data-def-stmt -> anydata-stmt");}
              | anyxml_stmt          { _PARSE_DEBUG("data-def-stmt -> anyxml-stmt");}
              | uses_stmt            { _PARSE_DEBUG("data-def-stmt -> uses-stmt");}
              ;

/* short-case */
short_case_stmt : container_stmt   { _PARSE_DEBUG("short-case-substmt -> container-stmt"); }
                | leaf_stmt          { _PARSE_DEBUG("short-case-substmt -> leaf-stmt"); }
                | leaf_list_stmt     { _PARSE_DEBUG("short-case-substmt -> leaf-list-stmt"); }
                | list_stmt          { _PARSE_DEBUG("short-case-substmt -> list-stmt"); }
                | anydata_stmt       { _PARSE_DEBUG("short-case-substmt -> anydata-stmt");}
                | anyxml_stmt        { _PARSE_DEBUG("short-case-substmt -> anyxml-stmt");}
                ;

/* input */
input_stmt  : K_INPUT
                  { if (ysp_add_push(_yy, Y_INPUT, NULL, NULL) == NULL) _YYERROR("input_stmt"); }
               '{' input_substmts '}'
                  { if (ystack_pop(_yy) < 0) _YYERROR("input_stmt");
                      _PARSE_DEBUG("input-stmt -> INPUT { input-substmts }"); }
              ;

input_substmts : input_substmts input_substmt
                   { _PARSE_DEBUG("input-substmts -> input-substmts input-substmt"); }
              | input_substmt
                   { _PARSE_DEBUG("input-substmts -> input-substmt"); }
              ;

input_substmt : typedef_stmt         { _PARSE_DEBUG("input-substmt -> typedef-stmt"); }
              | grouping_stmt        { _PARSE_DEBUG("input-substmt -> grouping-stmt"); }
              | data_def_stmt        { _PARSE_DEBUG("input-substmt -> data-def-stmt"); }
              |                      { _PARSE_DEBUG("input-substmt -> "); }
              ;

/* output */
output_stmt  : K_OUTPUT  /* XXX reuse input-substatements since they are same */
                   { if (ysp_add_push(_yy, Y_OUTPUT, NULL, NULL) == NULL) _YYERROR("output_stmt"); }
               '{' input_substmts '}'
                   { if (ystack_pop(_yy) < 0) _YYERROR("output_stmt");
                       _PARSE_DEBUG("output-stmt -> OUTPUT { input-substmts }"); }
              ;

/* XXX this is not the "string" rule in Section 14, rather it is the string as described in 6.1
 */
string        : qstrings { $$=$1;
                   _PARSE_DEBUG("string -> qstrings"); }
              | ustring  { $$=$1;
                   _PARSE_DEBUG( "string -> ustring"); }
              ;

/* quoted string */
qstrings      : qstrings '+' qstring
                     {
                         int len = strlen($1);
                         $$ = realloc($1, len + strlen($3) + 1);
                         sprintf($$+len, "%s", $3);
                         free($3);
                         _PARSE_DEBUG("qstrings-> qstrings '+' qstring");
                     }
              | qstring
                     { $$=$1;
                         _PARSE_DEBUG("qstrings-> qstring"); }
              ;

qstring        : '"' ustring '"'  { $$=$2;
                   _PARSE_DEBUG("qstring-> \" ustring \"");}
               | '"' '"'  { $$=strdup("");
                   _PARSE_DEBUG("qstring-> \"  \"");}
               | '\'' ustring '\''  { $$=$2;
                   _PARSE_DEBUG("qstring-> ' ustring '"); }
               | '\'' '\''  { $$=strdup("");
                   _PARSE_DEBUG("qstring-> '  '");}
               ;

/* unquoted string */
ustring       : ustring CHARS
                     {
                         int len = strlen($1);
                         $$ = realloc($1, len+strlen($2) + 1);
                         sprintf($$+len, "%s", $2);
                         _PARSE_DEBUG1("ustring-> string + CHARS(%s)", $2);
                         free($2);
                     }
              | CHARS
                      {  _PARSE_DEBUG1("ustring-> CHARS(%s)", $1); $$=$1; }
              | ERRCHARS
                      {  _PARSE_DEBUG1("ustring-> ERRCHARS(%s)", $1); _YYERROR("Invalid string chars"); }
              ;

identifier_str : '"' IDENTIFIER '"' { $$ = $2;
                         _PARSE_DEBUG("identifier_str -> \" IDENTIFIER \" ");}
               | '\'' IDENTIFIER '\'' { $$ = $2;
                         _PARSE_DEBUG("identifier_str -> ' IDENTIFIER ' ");}
               | IDENTIFIER           { $$ = $1;
                         _PARSE_DEBUG("identifier_str -> IDENTIFIER ");}
               ;

integer_value_str : '"' INT '"' { $$=$2; }
                  | '\'' INT '\'' { $$=$2; }
                  |     INT     { $$=$1; }
                  ;

bool_str       : '"' BOOL '"' { $$ = $2;
                   _PARSE_DEBUG("bool_str -> \" BOOL \" ");}
               | '\'' BOOL '\'' { $$ = $2;
                   _PARSE_DEBUG("bool_str -> ' BOOL ' ");}
               |     BOOL     { $$ = $1;
                   _PARSE_DEBUG("bool_str -> BOOL ");}
               ;


/* ;;; Basic Rules */

/* identifier-ref-arg-str      = < a string that matches the rule idenetifier-ref-arg >
 * @see yang_schema_nodeid_subparse sub-parser
 */
identifier_ref_arg_str :  string
                 { $$ = $1;
                   _PARSE_DEBUG("identifier-ref-arg-str -> < a string that matches the rule identifier-ref-arg >"); }
               ;

/*   optsep = *(WSP / line-break) */
optsep :       sep
               |
               ;

/*      sep = 1*(WSP / line-break) 
 * Note WS can in turn contain multiple white-space. 
 * Reason for doing list here is that the lex stage filters comments, 
 * For example, "   // foo\n \t  " will return WS WS
 */
sep            : sep WS
               | WS
               ;

stmtend        : ';'
               | '{' '}'
               | '{' unknown_stmt '}'
               ;

%%
