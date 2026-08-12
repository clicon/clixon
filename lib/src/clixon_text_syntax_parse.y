/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * TEXT / curly-brace syntax parsing and translations
 */
%union {
  char *string;
  void *stack;
}

%token MY_EOF
%token <string> TOKEN

%type <stack>  stmts
%type <stack>  stmt
%type <stack>  id
%type <string> value
%type <stack>  values
%type <string> substr

%start top

%lex-param     {yyscan_t yyscanner}    /* passed to yylex() */
%parse-param   {void *_ts}             /* passed to yyparse() and yyerror() */
%parse-param   {yyscan_t yyscanner}    /* passed to yyparse(), yylex(), and yyerror() */
%define api.pure full                  /* make yylval a local, not a global */

%code requires {
#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void *yyscan_t;
#endif
}

%{

/* typecast macro */
#define _TS ((clixon_text_syntax_yacc *)_ts)

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/time.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_string.h"
#include "clixon_xml_nsctx.h"
#include "clixon_xml_vec.h"
#include "clixon_data.h"
#include "clixon_text_syntax_parse.h"
#include "banned.h"

/* Enable for debugging, steals some cycles otherwise */
#if 0
#define _PARSE_DEBUG(s) clixon_debug(CLIXON_DBG_PARSE|CLIXON_DBG_DETAIL,(s))
#else
#define _PARSE_DEBUG(s)
#endif

void
clixon_text_syntax_parseerror(void *arg,
                              yyscan_t yyscanner,
                              char       *s)
{
    clixon_text_syntax_yacc *ts = (clixon_text_syntax_yacc *)arg;

    clixon_err(OE_XML, XMLPARSE_ERRNO, "text_syntax_parse: line %d: %s: at or before: %s",
               ts->ts_linenum,
               s,
               clixon_text_syntax_parseget_text(yyscanner));
    return;
}

static int
text_add_value(cvec *cvv,
               char *value)
{
    cg_var *cvi;

    if ((cvi = cvec_add(cvv, CGV_STRING)) == NULL){
        clixon_err(OE_XML, errno, "cvec_add");
        return -1;
    }
    if (cv_string_set(cvi, value) < 0){
        clixon_err(OE_XML, errno, "cv_string_set");
        return -1;
    }
    return 0;
}

/*! Create XML node prefix:id
 */
static cxobj*
text_create_node(clixon_text_syntax_yacc *ts,
                 char                    *name)
{
    cxobj     *xn = NULL;
    yang_stmt *ymod;
    char      *ns;
    char      *prefix = NULL;
    char      *id = NULL;

    if (nodeid_split(name, &prefix, &id) < 0)
        goto done;
    if ((xn = xml_new(id, NULL, CX_ELMNT)) == NULL)
        goto done;
    if (prefix && ts->ts_yspec){
        /* Silently ignore if module name not found */
        if ((ymod = yang_find(ts->ts_yspec, Y_MODULE, prefix)) != NULL){
            if ((ns = yang_find_mynamespace(ymod)) == NULL){
                clixon_err(OE_YANG, 0, "No namespace");
                goto done;
            }
            /* Set default namespace */
            if (xmlns_set(xn, NULL, ns) < 0)
                goto done;
        }
    }
 done:
    if (prefix)
        free(prefix);
    if (id)
        free(id);
    return xn;
}

static char*
strjoin(char *str0,
        char *str1)
{
    size_t len0;
    size_t len;

    len0 = str0?strlen(str0):0;
    len = len0 + strlen(str1) + 1;
    if ((str0 = realloc(str0, len)) == NULL){
        clixon_err(OE_YANG, errno, "realloc");
        return NULL;
    }
    memcpy(str0+len0, str1, strlen(str1)+1);
    return str0;
}

%}

%%

top        : stmt MY_EOF       { _PARSE_DEBUG("top->stmt");
                                 if (clixon_child_xvec_append(_TS->ts_xtop, $1) < 0) YYERROR;
                                 clixon_xvec_free($1);
                                 YYACCEPT; }
           ;

stmts      : stmts stmt        { _PARSE_DEBUG("stmts->stmts stmt");
                                 if (clixon_xvec_merge($1, $2) < 0) YYERROR;
                                 clixon_xvec_free($2);
                                 $$ = $1;
                               }
           |                   { _PARSE_DEBUG("stmts->stmt");
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
                               }
           ;

stmt       : id values ';'     { _PARSE_DEBUG("stmt-> id value ;");
                                 cvec   *cv = (cvec*)$2;
                                 cg_var *cvi = NULL;
                                 cxobj  *x2;
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
                                 while ((cvi = cvec_each(cv, cvi)) != NULL){
                                     if ((x2 = xml_dup($1)) == NULL) YYERROR;
                                     if (xml_body_set(x2, cv_string_get(cvi)) < 0) YYERROR;
                                     if (clixon_xvec_append($$, x2) < 0) YYERROR;
                                 }
                                 xml_free($1);
                                 cvec_free(cv);
                               }
           | id values '{' stmts '}'  { _PARSE_DEBUG("stmt-> id values { stmts }");
                                 cvec   *cv = (cvec*)$2;
                                 cg_var *cvi = NULL;
                                 cxobj  *xb;
                                 while ((cvi = cvec_each(cv, cvi)) != NULL){
                                     if ((xb = xml_new("body", $1, CX_BODY)) == NULL) YYERROR;
                                     if (xml_value_set(xb, cv_string_get(cvi)) < 0) YYERROR;
                                     xml_flag_set(xb, XML_FLAG_BODYKEY);
                                 }
                                 cvec_free(cv);
                                 if (clixon_child_xvec_append($1, $4) < 0) YYERROR;
                                 clixon_xvec_free($4);
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
                                 if (clixon_xvec_append($$, $1) < 0) YYERROR;
                               }
           | id '[' values ']'
                               { _PARSE_DEBUG("stmt-> id [ values ]");
                                 cvec   *cv = (cvec*)$3;
                                 cg_var *cvi = NULL;
                                 cxobj  *x2;
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
                                 while ((cvi = cvec_each(cv, cvi)) != NULL){
                                     if ((x2 = xml_dup($1)) == NULL) YYERROR;
                                     if (xml_body_set(x2, cv_string_get(cvi)) < 0) YYERROR;
                                     if (clixon_xvec_append($$, x2) < 0) YYERROR;
                                 }
                                 xml_free($1);
                                 cvec_free(cv);
                               }
           ;

id         : TOKEN             { _PARSE_DEBUG("id->TOKEN");
                                 if (($$ = text_create_node(_TS, $1)) == NULL) YYERROR;
                                 free($1);
                               }
           ;

/* Array of string values, possibly empty */
values     : values value      { _PARSE_DEBUG("values->values value");
                                 cvec *cv = (cvec*)$1;
                                 if (text_add_value(cv, $2) < 0) YYERROR;
                                 free($2);
                                 $$ = (void*)cv;
                               }
           |                   { _PARSE_DEBUG("values->");
                                 if (($$ = (void*)cvec_new(0)) == NULL) YYERROR;
                               }
           ;

/* Returns single string either as a single token or contained by double quotes  */
value      : TOKEN             { _PARSE_DEBUG("value->TOKEN");
                                 $$=$1;
                               }
           | '"' substr '"'  { _PARSE_DEBUG("value-> \" substr \"");
                                 $$=$2;
                               }
           ;

/* Value within quotes merged to single string, has separate lexical scope  */
substr     : substr TOKEN      { _PARSE_DEBUG("substr->substr TOKEN");
                                 $$ = strjoin($1, $2); free($2);}
           |                   { _PARSE_DEBUG("substr->");
                                 $$ = NULL; }
           ;

%%
