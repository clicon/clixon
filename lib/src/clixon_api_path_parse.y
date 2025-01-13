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

 * "api-path" is "URI-encoded path expression" definition in RFC8040 3.5.3
 * BNF:
 *  <api-path>       := <root> ("/" (<api-identifier> | <list-instance>))*
 *  <root>           := <string> # See note 1 below
 *  <root>           := <string>
 *  <api-identifier> := [<module-name> ":"] <identifier>
 *  <module-name>    := <identifier>
 *  <list-instance>  := <api-identifier> "=" key-value *("," key-value)
 *  <key-value>      := <string>
 *  <string>         := <an unquoted string>
 *  <identifier>     := (<ALPHA> | "_") (<ALPHA> | <DIGIT> | "_" | "-" | ".")
 * @note 1. <root> is the RESTCONF root resource (Sec 3.3) omitted in all calls below, it is
 *          assumed to be stripped from api-path before calling these functions.
 * @note 2. characters in a key value string are constrained, and some characters need to be 
 *          percent-encoded, 
 */

%start start

 /* Must be here to define YYSTYPE */
%union {
    char     *string;
    void     *stack; /* cv / cvec */
}

%token <string> IDENTIFIER
%token <string> STRING
%token <string> SLASH
%token <string> COLON
%token <string> COMMA
%token <string> EQUAL
%token <string> X_EOF

%type  <stack>  list
%type  <stack>  element
%type  <stack>  api_identifier
%type  <string> module_name
%type  <stack>  list_instance
%type  <stack>  key_values
%type  <stack>  key_value

%lex-param     {void *_ay} /* Add this argument to parse() and lex() function */
%parse-param   {void *_ay}

%{
/* Here starts user C-code */

/* typecast macro */
#define _AY ((clixon_api_path_yacc *)_ay)

#define _YYERROR(msg) {clixon_err(OE_XML, 0, "YYERROR %s '%s' %d", (msg), clixon_api_path_parsetext, _AY->ay_linenum); YYERROR;}

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

/* clixon */
#include "clixon_queue.h"
#include "clixon_string.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_path.h"
#include "clixon_api_path_parse.h"

/* Best debugging is to enable PARSE_DEBUG below and add -d to the LEX compile statement in the Makefile
 * And then run the testcase with -D 1
 * Disable it to stop any calls to clixon_debug. Having it on by default would mean very large debug outputs.
 */
#if 0
#define _PARSE_DEBUG(s) clixon_debug(CLIXON_DBG_PARSE|CLIXON_DBG_DETAIL,(s))
#define _PARSE_DEBUG1(s, s1) clixon_debug(CLIXON_DBG_PARSE|CLIXON_DBG_DETAIL,(s), (s1))
#else
#define _PARSE_DEBUG(s)
#define _PARSE_DEBUG1(s, s1)
#endif

/*
 * Also called from yacc generated code *
 */
void
clixon_api_path_parseerror(void *_ay,
                           char *s)
{
    clixon_err(OE_XML, 0, "%s on line %d: %s at or before: '%s'",
               _AY->ay_name,
               _AY->ay_linenum,
               s,
               clixon_api_path_parsetext);
    return;
}

int
api_path_parse_init(clixon_api_path_yacc *ay)
{
    return 0;
}

int
api_path_parse_exit(clixon_api_path_yacc *ay)
{
    return 0;
}

/*! Append new path structure to clixon path list
 */
static clixon_path *
path_append(clixon_path *list,
            clixon_path *new)
{
    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "%s()", __FUNCTION__);
    if (new == NULL)
        return NULL;
    ADDQ(new, list);
    return list;
}

/*! Add keyvalue to existing clixon path
 */
static clixon_path *
path_add_keyvalue(clixon_path *cp,
                  cvec        *cvk)
{
    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "%s()", __FUNCTION__);
    if (cp)
        cp->cp_cvk = cvk;
    return cp;
}

static clixon_path *
path_new(char *module_name,
         char *id)
{
    clixon_path *cp = NULL;

    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "%s(%s,%s)", __FUNCTION__, module_name, id);
    if ((cp = malloc(sizeof(*cp))) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memset(cp, 0, sizeof(*cp));
    if (module_name)
        if ((cp->cp_prefix = strdup(module_name)) == NULL){
            clixon_err(OE_UNIX, errno, "strdup");
            goto done;
        }
    if ((cp->cp_id = strdup(id)) == NULL){
        clixon_err(OE_UNIX, errno, "strdup");
        goto done;
    }
    return cp;
 done:
    return NULL;
}

/*! Append a key-value cv to a cvec, create the cvec if not exist
 *
 * @param[in] cvv  Either created cvv or NULL, in whihc case it is created
 * @param[in] cv   Is consumed by thius function (if appended)
 * @retval    NULL Error
 * @retval    cvv  Cvec
 */
static cvec *
keyval_add(cvec   *cvv,
           cg_var *cv)
{
    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "%s()", __FUNCTION__);
    if (cv == NULL)
        goto done;
    if (cvv == NULL &&
        (cvv = cvec_new(0)) == NULL) {
        clixon_err(OE_UNIX, errno, "cvec_new");
        goto done;
    }
    if (cvec_append_var(cvv, cv) == NULL){
        clixon_err(OE_UNIX, errno, "cvec_append_var");
        cvv = NULL;
        goto done;
    }
    cv_free(cv);
 done:
    return cvv;
}

/*! Create a single key-value as cv and return it
 */
static cg_var *
keyval_set(char *name,
           char *val)
{
    cg_var *cv = NULL;

    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "%s(%s=%s)", __FUNCTION__, name?name:"NULL", val);
    if ((cv = cv_new(CGV_STRING)) == NULL){
        clixon_err(OE_UNIX, errno, "cv_new");
        goto done;
    }
    if (name && cv_name_set(cv, name) == NULL){
        clixon_err(OE_UNIX, errno, "cv_string_set");
        cv = NULL;
        goto done;
    }
    if (cv_string_set(cv, val) == NULL){
        clixon_err(OE_UNIX, errno, "cv_string_set");
        cv = NULL;
        goto done;
    }
 done:
    return cv;
}

%}

%%

/*
*/

start          : list X_EOF        {_PARSE_DEBUG("top");_AY->ay_top=$1; YYACCEPT; }
               ;

list           : list SLASH element { if (($$ = path_append($1, $3)) == NULL) YYABORT;
                                    _PARSE_DEBUG("list = list / element");}
               |                  { $$ = NULL;
                                    _PARSE_DEBUG("list = ");}
               ;

element        : api_identifier { $$=$1;
                                 _PARSE_DEBUG("element = api_identifier");}
               | list_instance  { $$=$1;
                                 _PARSE_DEBUG("element = list_instance");}
               ;

api_identifier : module_name COLON IDENTIFIER { $$ = path_new($1, $3); free($1); free($3);
                                _PARSE_DEBUG("api_identifier = module_name : IDENTIFIER");}
               | IDENTIFIER                 { $$ = path_new(NULL, $1); free($1);
                                _PARSE_DEBUG("api_identifier = IDENTIFIER");}
               ;

module_name    : IDENTIFIER                 { $$ = $1;
                                _PARSE_DEBUG("module_name = IDENTIFIER");}
               ;

list_instance  : api_identifier EQUAL key_values { $$ = path_add_keyvalue($1, $3);
                                   _PARSE_DEBUG("list_instance->api_identifier = key_values");}
               ;

key_values     : key_values COMMA key_value  { if (($$ = keyval_add($1, $3)) == NULL) YYABORT;
                                       _PARSE_DEBUG("key_values->key_values , key_value");}
               | key_value                 { if (($$ = keyval_add(NULL, $1)) == NULL) YYABORT;
                                             _PARSE_DEBUG("key_values->key_value");}
               ;

key_value      : STRING { $$ = keyval_set(NULL, $1); free($1); _PARSE_DEBUG("keyvalue->STRING"); }
               |        { $$ = keyval_set(NULL, ""); _PARSE_DEBUG("keyvalue->"); }
               ;

%%
