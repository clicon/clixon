/*
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
 * @note differences in double quoted strings: 1.1 does not allow \x, but 1.0
 * does (where x is not n|t|<double quote)|\). See mode DQESC
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
#define _YY ((clixon_yang_yacc *)_yy)

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
*/


%}

identifier      [A-Za-z_][A-Za-z0-9_\-\.]*

%x KEYWORD
%x DEVIATE
%x DEVIATESTR
%s BOOLEAN
%s INTEGER
%s STRARG
%s STRING
%s STRINGDQ
%s STRINGSQ
%s DQESC
%s COMMENT1
%s COMMENT2
%s UNKNOWN
%s UNKNOWN2

%%
 /* Common tokens */
<KEYWORD,DEVIATE,DEVIATESTR,BOOLEAN,INTEGER,STRARG,STRING>[ \t]+
<KEYWORD,DEVIATE,DEVIATESTR,STRING,UNKNOWN,UNKNOWN2,COMMENT2><<EOF>> { return MY_EOF; }
<KEYWORD,DEVIATE,DEVIATESTR,BOOLEAN,INTEGER,STRARG,STRING,COMMENT1,UNKNOWN,UNKNOWN2>\n   { _YY->yy_linenum++; }
<KEYWORD,DEVIATE,DEVIATESTR,BOOLEAN,INTEGER,STRARG,STRING,COMMENT1,UNKNOWN,UNKNOWN2>\r   
<KEYWORD,DEVIATE,DEVIATESTR,STRARG,STRING,UNKNOWN,UNKNOWN2>"/*"    { _YY->yy_lex_state = YYSTATE; BEGIN(COMMENT1); }
<KEYWORD,DEVIATE,DEVIATESTR,STRARG,STRING,UNKNOWN,UNKNOWN2>"//"    { _YY->yy_lex_state = YYSTATE; BEGIN(COMMENT2); }


<KEYWORD>input            { return K_INPUT; } /* No argument */
<KEYWORD>output           { return K_OUTPUT;} /* No argument */

 /* RFC 7950 keywords using identifier */
<KEYWORD>action           { BEGIN(STRARG);  return K_ACTION; }
<KEYWORD>anydata          { BEGIN(STRARG);  return K_ANYDATA; }
<KEYWORD>anyxml           { BEGIN(STRARG);  return K_ANYXML; }
<KEYWORD>argument         { BEGIN(STRARG);  return K_ARGUMENT; }
<KEYWORD>belongs-to       { BEGIN(STRARG);  return K_BELONGS_TO; }
<KEYWORD>bit              { BEGIN(STRARG);  return K_BIT; }
<KEYWORD>case             { BEGIN(STRARG);  return K_CASE; }
<KEYWORD>choice           { BEGIN(STRARG);  return K_CHOICE; }
<KEYWORD>container        { BEGIN(STRARG);  return K_CONTAINER; }
<KEYWORD>extension        { BEGIN(STRARG);  return K_EXTENSION; }
<KEYWORD>feature          { BEGIN(STRARG);  return K_FEATURE; }
<KEYWORD>grouping         { BEGIN(STRARG);  return K_GROUPING; }
<KEYWORD>identity         { BEGIN(STRARG);  return K_IDENTITY; }
<KEYWORD>import           { BEGIN(STRARG);  return K_IMPORT; }
<KEYWORD>include          { BEGIN(STRARG);  return K_INCLUDE; }
<KEYWORD>leaf             { BEGIN(STRARG);  return K_LEAF; }
<KEYWORD>leaf-list        { BEGIN(STRARG);  return K_LEAF_LIST; }
<KEYWORD>list             { BEGIN(STRARG);  return K_LIST; }
<KEYWORD>module           { BEGIN(STRARG);  return K_MODULE; }
<KEYWORD>notification     { BEGIN(STRARG);  return K_NOTIFICATION; }
<KEYWORD>prefix           { BEGIN(STRARG);  return K_PREFIX; }
<KEYWORD>rpc              { BEGIN(STRARG);  return K_RPC; }
<KEYWORD>submodule        { BEGIN(STRARG);  return K_SUBMODULE; }
<KEYWORD>typedef          { BEGIN(STRARG);  return K_TYPEDEF; }

 /* RFC 7950 keywords using boolean string arguments */
<KEYWORD>config           { BEGIN(BOOLEAN); return K_CONFIG; }
<KEYWORD>mandatory        { BEGIN(BOOLEAN); return K_MANDATORY; }
<KEYWORD>require-instance { BEGIN(BOOLEAN); return K_REQUIRE_INSTANCE; }
<KEYWORD>yin-element      { BEGIN(BOOLEAN); return K_YIN_ELEMENT;  }

 /* RFC 7950 keywords using integer string argument */
<KEYWORD>min-elements     { BEGIN(INTEGER);  return K_MIN_ELEMENTS; }
<KEYWORD>position         { BEGIN(INTEGER);  return K_POSITION; }
<KEYWORD>value            { BEGIN(INTEGER);  return K_VALUE; }

 /* RFC 7950 keywords using strings  */
<KEYWORD>augment          { BEGIN(STRING);  return K_AUGMENT; }
<KEYWORD>base             { BEGIN(STRING);  return K_BASE; }
<KEYWORD>contact          { BEGIN(STRING);  return K_CONTACT; }
<KEYWORD>default          { BEGIN(STRING);  return K_DEFAULT; }
<KEYWORD>description      { BEGIN(STRING);  return K_DESCRIPTION; }
<KEYWORD>deviate          { BEGIN(DEVIATE); return K_DEVIATE; }
<KEYWORD>deviation        { BEGIN(STRING);  return K_DEVIATION; }
<KEYWORD>enum             { BEGIN(STRING);  return K_ENUM; }
<KEYWORD>error-app-tag    { BEGIN(STRING);  return K_ERROR_APP_TAG; }
<KEYWORD>error-message    { BEGIN(STRING);  return K_ERROR_MESSAGE; }
<KEYWORD>fraction-digits  { BEGIN(STRING);  return K_FRACTION_DIGITS; }
<KEYWORD>if-feature       { BEGIN(STRING);  return K_IF_FEATURE; }
<KEYWORD>key              { BEGIN(STRING);  return K_KEY; }
<KEYWORD>length           { BEGIN(STRING);  return K_LENGTH; }
<KEYWORD>max-elements     { BEGIN(STRING);  return K_MAX_ELEMENTS; }
<KEYWORD>modifier         { BEGIN(STRING);  return K_MODIFIER; }
<KEYWORD>must             { BEGIN(STRING);  return K_MUST; }
<KEYWORD>namespace        { BEGIN(STRING);  return K_NAMESPACE; }
<KEYWORD>ordered-by       { BEGIN(STRING);  return K_ORDERED_BY; }
<KEYWORD>organization     { BEGIN(STRING);  return K_ORGANIZATION; }
<KEYWORD>path             { BEGIN(STRING);  return K_PATH; }
<KEYWORD>pattern          { BEGIN(STRING);  return K_PATTERN; }
<KEYWORD>presence         { BEGIN(STRING);  return K_PRESENCE; }
<KEYWORD>type             { BEGIN(STRING);  return K_TYPE; }
<KEYWORD>unique           { BEGIN(STRING);  return K_UNIQUE; }
<KEYWORD>range            { BEGIN(STRING);  return K_RANGE; }
<KEYWORD>reference        { BEGIN(STRING);  return K_REFERENCE; }
<KEYWORD>refine           { BEGIN(STRING);  return K_REFINE; }
<KEYWORD>revision         { BEGIN(STRING);  return K_REVISION; }
<KEYWORD>revision-date    { BEGIN(STRING);  return K_REVISION_DATE; }
<KEYWORD>status           { BEGIN(STRING);  return K_STATUS; }
<KEYWORD>units            { BEGIN(STRING);  return K_UNITS; }
<KEYWORD>uses             { BEGIN(STRING);  return K_USES; }
<KEYWORD>when             { BEGIN(STRING);  return K_WHEN; }
<KEYWORD>yang-version     { BEGIN(STRING);  return K_YANG_VERSION; }
<KEYWORD>:                { return *yytext; }
<KEYWORD>\{               { return *yytext; }
<KEYWORD>\}               { return *yytext; }
<KEYWORD>;                { return *yytext; }
<KEYWORD>.                { clixon_yang_parselval.string = strdup(yytext);
                            BEGIN(UNKNOWN); return CHARS; }

<DEVIATE>not-supported    { BEGIN(KEYWORD); return D_NOT_SUPPORTED; }
<DEVIATE>add              { BEGIN(KEYWORD); return D_ADD; }
<DEVIATE>delete           { BEGIN(KEYWORD); return D_DELETE; }
<DEVIATE>replace          { BEGIN(KEYWORD); return D_REPLACE; }
<DEVIATE>\"               { BEGIN(DEVIATESTR); return *yytext; }
<DEVIATE>\'               { BEGIN(DEVIATESTR); return *yytext; }
<DEVIATE>.                { BEGIN(KEYWORD); return *yytext; }
<DEVIATESTR>not-supported { return D_NOT_SUPPORTED; }
<DEVIATESTR>add           { return D_ADD; }
<DEVIATESTR>delete        { return D_DELETE; }
<DEVIATESTR>replace       { return D_REPLACE; }
<DEVIATESTR>.             { BEGIN(KEYWORD); return *yytext; }
<UNKNOWN>:                { return *yytext; }
<UNKNOWN>;                { BEGIN(KEYWORD); return *yytext; }
<UNKNOWN>\{               { BEGIN(KEYWORD); return *yytext; }
<UNKNOWN>[ \t\n]+         { BEGIN(UNKNOWN2); return WS; /* mandatory sep for string */ }
<UNKNOWN>[^{"';: \t\n\r]+ { clixon_yang_parselval.string = strdup(yytext);
                            return CHARS; }

<UNKNOWN2>;                { BEGIN(KEYWORD); return *yytext; }
<UNKNOWN2>\"               { _YY->yy_lex_string_state =STRING; BEGIN(STRINGDQ); return *yytext; }
<UNKNOWN2>\'               { _YY->yy_lex_string_state =STRING; BEGIN(STRINGSQ); return *yytext; }
<UNKNOWN2>\{               { BEGIN(KEYWORD); return *yytext; }
<UNKNOWN2>[ \t\n]+         { return WS; }
<UNKNOWN2>[^{"'; \t\n\r]+  { clixon_yang_parselval.string = strdup(yytext);
                             return CHARS; }

<BOOLEAN>true             { clixon_yang_parselval.string = strdup(yytext);
                            return BOOL; }
<BOOLEAN>false            { clixon_yang_parselval.string = strdup(yytext);
                            return BOOL; }
<BOOLEAN>;                { BEGIN(KEYWORD); return *yytext; }
<BOOLEAN>\{               { BEGIN(KEYWORD); return *yytext; }
<BOOLEAN>.                { return *yytext; }

<INTEGER>\-?[0-9][0-9]*   { clixon_yang_parselval.string = strdup(yytext);
                            return INT; }
<INTEGER>;                { BEGIN(KEYWORD); return *yytext; }
<INTEGER>\{                { BEGIN(KEYWORD); return *yytext; }
<INTEGER>.                { return *yytext; }

<STRARG>\{                 { BEGIN(KEYWORD); return *yytext; }
<STRARG>;                  { BEGIN(KEYWORD); return *yytext; }
<STRARG>{identifier}       { clixon_yang_parselval.string = strdup(yytext);
                             return IDENTIFIER;}
<STRARG>.                  { return *yytext; }

<STRING>\{                { BEGIN(KEYWORD); return *yytext; }
<STRING>;                 { BEGIN(KEYWORD); return *yytext; }
<STRING>\"                { _YY->yy_lex_string_state =STRING; BEGIN(STRINGDQ); return *yytext; }
<STRING>\'                { _YY->yy_lex_string_state =STRING; BEGIN(STRINGSQ); return *yytext; }
<STRING>\+                { return *yytext; }
<STRING>[^\"\'\{\;\n \t\r]+ { clixon_yang_parselval.string = strdup(yytext); /* XXX [.]+ */
                            return CHARS;}

<STRINGDQ>\\              { _YY->yy_lex_state = STRINGDQ; BEGIN(DQESC); }
<STRINGDQ>\"              { BEGIN(_YY->yy_lex_string_state); return *yytext; }
<STRINGDQ>\n              { _YY->yy_linenum++;
                            clixon_yang_parselval.string = strdup(yytext);
                            return CHARS;}
<STRINGDQ>[^\\"\n]+      { clixon_yang_parselval.string = strdup(yytext);
                            return CHARS;}

<STRINGSQ>\'              { BEGIN(_YY->yy_lex_string_state); return *yytext; }
<STRINGSQ>\n              { _YY->yy_linenum++;
                            clixon_yang_parselval.string = strdup(yytext);
                            return CHARS;}
<STRINGSQ>[^'\n]+         { clixon_yang_parselval.string = strdup(yytext);
                            return CHARS;}

<DQESC>[nt"\\]            { BEGIN(_YY->yy_lex_state); 
                             clixon_yang_parselval.string = strdup(yytext); 
                             return CHARS; }
<DQESC>[^nt"\\]           { char *str = malloc(3);
                            /* This is for Yang 1.0 double-quoted strings */
                            BEGIN(_YY->yy_lex_state); 
                            str[0] = '\\';
                            str[1] = yytext[0];
			    str[2] = '\0';
                            clixon_yang_parselval.string = str; 
                            return CHARS; }
			     
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
yang_scan_init(clixon_yang_yacc *yy)
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
yang_scan_exit(clixon_yang_yacc *yy)
{
    yy_delete_buffer(yy->yy_lexbuf);
    clixon_yang_parselex_destroy();  /* modern */
    return 0;
}

