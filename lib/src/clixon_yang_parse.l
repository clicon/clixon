/*
 * Yang 1.0 parser according to RFC6020.
 * It is hopefully useful but not complete
 * RFC7950 defines Yang version 1.1
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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

 * Database specification parser cli syntax
 * (Cloned from cligen parser)
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <netinet/in.h>

#include "clixon_yang_parse.tab.h" /* generated */

#include <cligen/cligen.h>

#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_yang_parse.h"

/* Redefine main lex function so that you can send arguments to it: _yy is added to arg list */
#define YY_DECL int clixon_yang_parselex(void *_yy)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _YY ((struct clicon_yang_yacc_arg *)_yy)

#define     MAXBUF  4*4*64*1024

#define MAX(x,y) ((x)>(y)?(x):(y))
#define MIN(x,y) ((x)<(y)?(x):(y))

#undef clixon_yang_parsewrap
int 
clixon_yang_parsewrap(void)
{
  return 1;
}

/*
   statement = keyword [argument] (";" / "{" *statement "}") 
   The argument is a string

   Example: keyword argument ; keyword ; keyword { keyword argument; } keyword

   STRING0 corresponds to string rule
   ARGUMENT corresponds to identifier-arg-str,unique-arg-str,key-arg-str, etc.
                           more to do here.
*/


%}

%x KEYWORD
%s ARGUMENT
%s STRING0
%s STRING1
%s STRING2
%s ESCAPE
%s COMMENT1
%s COMMENT2

%%
 /* Common tokens */
<KEYWORD,ARGUMENT,STRING0>[ \t]            
<KEYWORD,ARGUMENT,STRING0><<EOF>> { return MY_EOF; }
<KEYWORD,ARGUMENT,STRING0,COMMENT1>\n   { _YY->yy_linenum++; }
<KEYWORD,ARGUMENT,STRING0>"/*"    { _YY->yy_lex_state = YYSTATE; BEGIN(COMMENT1); }
<KEYWORD,ARGUMENT,STRING0>"//"    { _YY->yy_lex_state = YYSTATE; BEGIN(COMMENT2); }

<KEYWORD>\}               { return *yytext; }

 /* RFC 6020 keywords */
<KEYWORD>anyxml           { BEGIN(ARGUMENT); return K_ANYXML; }
<KEYWORD>argument         { BEGIN(ARGUMENT); return K_ARGUMENT; }
<KEYWORD>augment          { BEGIN(ARGUMENT); return K_AUGMENT; }
<KEYWORD>base             { BEGIN(ARGUMENT); return K_BASE; }
<KEYWORD>belongs-to       { BEGIN(ARGUMENT); return K_BELONGS_TO; }
<KEYWORD>bit              { BEGIN(ARGUMENT); return K_BIT; }
<KEYWORD>case             { BEGIN(ARGUMENT); return K_CASE; }
<KEYWORD>choice           { BEGIN(ARGUMENT); return K_CHOICE; }
<KEYWORD>config           { BEGIN(ARGUMENT); return K_CONFIG; }
<KEYWORD>contact          { BEGIN(STRING0);  return K_CONTACT; }
<KEYWORD>container        { BEGIN(ARGUMENT); return K_CONTAINER; }
<KEYWORD>default          { BEGIN(STRING0);  return K_DEFAULT; }
<KEYWORD>description      { BEGIN(STRING0);  return K_DESCRIPTION; }
<KEYWORD>deviate          { BEGIN(ARGUMENT); return K_DEVIATE; }
<KEYWORD>deviation        { BEGIN(ARGUMENT); return K_DEVIATION; }
<KEYWORD>enum             { BEGIN(STRING0);  return K_ENUM; }
<KEYWORD>error-app-tag    { BEGIN(STRING0);  return K_ERROR_APP_TAG; }
<KEYWORD>error-message    { BEGIN(STRING0);  return K_ERROR_MESSAGE; }
<KEYWORD>extension        { BEGIN(ARGUMENT); return K_EXTENSION; }
<KEYWORD>feature          { BEGIN(ARGUMENT); return K_FEATURE; }
<KEYWORD>fraction-digits  { BEGIN(ARGUMENT); return K_FRACTION_DIGITS; }
<KEYWORD>grouping         { BEGIN(ARGUMENT); return K_GROUPING; }
<KEYWORD>identity         { BEGIN(ARGUMENT); return K_IDENTITY; }
<KEYWORD>if-feature       { BEGIN(ARGUMENT); return K_IF_FEATURE; }
<KEYWORD>import           { BEGIN(ARGUMENT); return K_IMPORT; }
<KEYWORD>include          { BEGIN(ARGUMENT); return K_INCLUDE; }
<KEYWORD>input            { BEGIN(ARGUMENT); return K_INPUT; }
<KEYWORD>key              { BEGIN(ARGUMENT); return K_KEY; }
<KEYWORD>leaf             { BEGIN(ARGUMENT); return K_LEAF; }
<KEYWORD>leaf-list        { BEGIN(ARGUMENT); return K_LEAF_LIST; }
<KEYWORD>length           { BEGIN(ARGUMENT); return K_LENGTH; }
<KEYWORD>list             { BEGIN(ARGUMENT); return K_LIST; }
<KEYWORD>mandatory        { BEGIN(ARGUMENT); return K_MANDATORY; }
<KEYWORD>max-elements     { BEGIN(ARGUMENT); return K_MAX_ELEMENTS; }
<KEYWORD>min-elements     { BEGIN(ARGUMENT); return K_MIN_ELEMENTS; }
<KEYWORD>module           { BEGIN(ARGUMENT); return K_MODULE; }
<KEYWORD>must             { BEGIN(STRING0);  return K_MUST; }
<KEYWORD>namespace        { BEGIN(ARGUMENT); return K_NAMESPACE; }
<KEYWORD>notification     { BEGIN(ARGUMENT); return K_NOTIFICATION; }
<KEYWORD>ordered-by       { BEGIN(ARGUMENT); return K_ORDERED_BY; }
<KEYWORD>organization     { BEGIN(STRING0);  return K_ORGANIZATION; }
<KEYWORD>output           { BEGIN(ARGUMENT); return K_OUTPUT; }
<KEYWORD>path             { BEGIN(ARGUMENT); return K_PATH; }
<KEYWORD>pattern          { BEGIN(STRING0);  return K_PATTERN; }
<KEYWORD>position         { BEGIN(ARGUMENT); return K_POSITION; }
<KEYWORD>prefix           { BEGIN(ARGUMENT); return K_PREFIX; }
<KEYWORD>presence         { BEGIN(STRING0);  return K_PRESENCE; }
<KEYWORD>range            { BEGIN(ARGUMENT); return K_RANGE; }
<KEYWORD>reference        { BEGIN(STRING0);  return K_REFERENCE; }
<KEYWORD>refine           { BEGIN(ARGUMENT); return K_REFINE; }
<KEYWORD>require-instance { BEGIN(ARGUMENT); return K_REQUIRE_INSTANCE; }
<KEYWORD>revision         { BEGIN(ARGUMENT); return K_REVISION; }
<KEYWORD>revision-date    { BEGIN(ARGUMENT); return K_REVISION_DATE; }
<KEYWORD>rpc              { BEGIN(ARGUMENT); return K_RPC; }
<KEYWORD>status           { BEGIN(ARGUMENT); return K_STATUS; }
<KEYWORD>submodule        { BEGIN(ARGUMENT); return K_SUBMODULE; }
<KEYWORD>type             { BEGIN(ARGUMENT); return K_TYPE; }
<KEYWORD>typedef          { BEGIN(ARGUMENT); return K_TYPEDEF; }
<KEYWORD>unique           { BEGIN(ARGUMENT); return K_UNIQUE; }
<KEYWORD>units            { BEGIN(STRING0);  return K_UNITS; }
<KEYWORD>uses             { BEGIN(ARGUMENT); return K_USES; }
<KEYWORD>value            { BEGIN(ARGUMENT); return K_VALUE; }
<KEYWORD>when             { BEGIN(STRING0);  return K_WHEN; }
<KEYWORD>yang-version     { BEGIN(ARGUMENT); return K_YANG_VERSION; }
<KEYWORD>yin-element      { BEGIN(ARGUMENT); return K_YIN_ELEMENT; }

<KEYWORD>:                { return *yytext; }
<KEYWORD>;                { return *yytext; }
<KEYWORD>.                { clixon_yang_parselval.string = strdup(yytext);
                             return CHAR;}


<ARGUMENT>;                { BEGIN(KEYWORD); return *yytext; }
<ARGUMENT>\{               { BEGIN(KEYWORD); return *yytext; }
<ARGUMENT>\"               { _YY->yy_lex_string_state =ARGUMENT; BEGIN(STRING1); return DQ; }
<ARGUMENT>\'               { _YY->yy_lex_string_state =ARGUMENT; BEGIN(STRING2); return DQ; }
<ARGUMENT>\+               { return *yytext; /* many arg rules dont like this */ }
<ARGUMENT>:                { return *yytext; /* many arg rules dont like this */ }
<ARGUMENT>.                { clixon_yang_parselval.string = strdup(yytext);
                             return CHAR;}

<STRING0>\{                { BEGIN(KEYWORD); return *yytext; }
<STRING0>;                 { BEGIN(KEYWORD); return *yytext; }
<STRING0>\"                { _YY->yy_lex_string_state =STRING0; BEGIN(STRING1); return DQ; }
<STRING0>\'                { _YY->yy_lex_string_state =STRING0; BEGIN(STRING2); return DQ; }
<STRING0>\+               { return *yytext; }
<STRING0>.                 { clixon_yang_parselval.string = strdup(yytext);
                            return CHAR;}

<STRING1>\\                { _YY->yy_lex_state = STRING1; BEGIN(ESCAPE); }
<STRING1>\"                { BEGIN(_YY->yy_lex_string_state); return DQ; }
<STRING1>\n                { _YY->yy_linenum++; clixon_yang_parselval.string = strdup(yytext); return CHAR;}
<STRING1>.                 { clixon_yang_parselval.string = strdup(yytext);
                            return CHAR;}

<STRING2>\'                { BEGIN(_YY->yy_lex_string_state); return DQ; }
<STRING2>\n                { _YY->yy_linenum++; clixon_yang_parselval.string = strdup(yytext); return CHAR;}
<STRING2>.                 { clixon_yang_parselval.string = strdup(yytext);
                             return CHAR;}

<ESCAPE>.                 { BEGIN(_YY->yy_lex_state); 
                             clixon_yang_parselval.string = strdup(yytext); 
                             return CHAR; }
<COMMENT1>[^*\n]*        /* eat anything that's not a '*' */
<COMMENT1>"*"+[^*/\n]*   /* eat up '*'s not followed by '/'s */
<COMMENT1>"*"+"/"        BEGIN(_YY->yy_lex_state);

<COMMENT2>[^\n]*        /* eat anything that's not a '/' */
<COMMENT2>\n             { _YY->yy_linenum++; BEGIN(_YY->yy_lex_state); }
%%

/*
 * yang_parse_init
 * Initialize scanner.
 */
int
yang_scan_init(struct clicon_yang_yacc_arg *yy)
{
  BEGIN(KEYWORD);
  yy->yy_lexbuf = yy_scan_string (yy->yy_parse_string);
#if 1 /* XXX: just to use unput to avoid warning  */
  if (0)
    yyunput(0, ""); 
#endif

  return 0;
}

/*
 * yang_parse_exit
 * free buffers
 * Even within Flex version 2.5 (this is assumed), freeing buffers is different.
 */
int
yang_scan_exit(struct clicon_yang_yacc_arg *yy)
{
    yy_delete_buffer(yy->yy_lexbuf);
    clixon_yang_parselex_destroy();  /* modern */
    return 0;
}

