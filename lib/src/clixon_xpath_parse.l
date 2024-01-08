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

There are some special lexical rules in https://www.w3.org/TR/xpath-10

1. If there is a preceding token and the preceding token is not one of
  @, ::, (, [, , or an Operator, then a * must be recognized as a
  MultiplyOperator and an NCName must be recognized as an
  OperatorName. (and,or,div,mod)
2. If the character following an NCName (possibly after intervening
  ExprWhitespace) is (, then the token must be recognized as a
  NodeType or a FunctionName.
3. If the two characters following an NCName (possibly after
  intervening ExprWhitespace) are ::, then the token must be
  recognized as an AxisName.
4. Otherwise, the token must not be recognized as a MultiplyOperator,
  an OperatorName, a NodeType, a FunctionName, or an AxisName.

  These rules are implemented in this parser by two states: TOKEN0 and TOKEN2.
  TOKEN0 is the start and normative state and has only a basic NCNAME rule
  TOKEN2 is only entered after some of the rules above, and has special nodetest rules
         (maybe function/axisname as well?).
         This state is left immediately to TOKEN0 after a single token
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <netinet/in.h>

#include "clixon_xpath_parse.tab.h" /* generated */

#include <cligen/cligen.h>

#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_string.h"
#include "clixon_xml.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_xpath_ctx.h"
#include "clixon_xpath.h"
#include "clixon_xpath_parse.h"
#include "clixon_xpath_function.h"
#include "clixon_xpath_eval.h"

/* Redefine main lex function so that you can send arguments to it: _yy is added to arg list */
#define YY_DECL int clixon_xpath_parselex(void *_yy)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _XPY ((clixon_xpath_yacc *)_yy)

#undef clixon_xpath_parsewrap
int
clixon_xpath_parsewrap(void)
{
    return 1;
}

/* strip last char: kludge to peek to next character */
static void
striplast(char *s)
{
   s[strlen(s)-1] = 0;
}

%}

digit [0-9]
integer {digit}+
real ({digit}+[.]{digit}*)|({digit}*[.]{digit}+)

namestart  [A-Z_a-z]
namechar   [A-Z_a-z\-\.0-9]
ncname     {namestart}{namechar}*

%s TOKEN0
%s TOKEN2
%s QLITERAL
%s ALITERAL

%%
<TOKEN0>[ \t]
<TOKEN0>\n               { _XPY->xpy_linenum++; }
<TOKEN0>\r               { }
<TOKEN0><<EOF>>          { return X_EOF; }
<TOKEN0>".."             { return DOUBLEDOT; }
<TOKEN0>::               { BEGIN(TOKEN2); return DOUBLECOLON; /* axisname */ }
<TOKEN0>[(\[]            { BEGIN(TOKEN2); return *yytext; }
<TOKEN0>[)\]\.,/:|]      { return *yytext; }
<TOKEN0>and              { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap, yytext); return LOGOP; }
<TOKEN0>or               { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap, yytext); return LOGOP; }
<TOKEN0>div              { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN0>mod              { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN0>[+*\-]           { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN0>\?               { return *yytext; }
<TOKEN0>"//"             { BEGIN(TOKEN2);return DOUBLESLASH; }
<TOKEN0>"!="             { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return RELOP; }
<TOKEN0>">="             { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }
<TOKEN0>"<="             { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }
<TOKEN0>[<>=]            { BEGIN(TOKEN2);clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }

<TOKEN0>@                { BEGIN(TOKEN2); return *yytext; }
<TOKEN0>\"               { _XPY->xpy_lex_string_state = TOKEN0; BEGIN(QLITERAL); return QUOTE; }
<TOKEN0>\'               { _XPY->xpy_lex_string_state = TOKEN0; BEGIN(ALITERAL); return APOST; }
<TOKEN0>\-?({integer}|{real}) { clixon_xpath_parselval.string = strdup(yytext); return NUMBER; }

<TOKEN0>{ncname}         { /* See lexical rules 2 and 3 in the file header */
                           clixon_xpath_parselval.string = strdup(yytext);
                           return NCNAME;
                         }
<TOKEN0>.                { fprintf(stderr,"LEXICAL ERROR\n"); return -1; }

<TOKEN2>[ \t]
<TOKEN2>\n               { _XPY->xpy_linenum++; }
<TOKEN2>\r               { }
<TOKEN2><<EOF>>          { return X_EOF; }
<TOKEN2>".."             { BEGIN(TOKEN0); return DOUBLEDOT; }
<TOKEN2>::               { BEGIN(TOKEN0); return DOUBLECOLON; /* axisname */ }
<TOKEN2>[()\[\]\.,/:|]   { BEGIN(TOKEN0); return *yytext; }
<TOKEN2>and              { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap, yytext); return LOGOP; }
<TOKEN2>or               { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap, yytext); return LOGOP; }
<TOKEN2>div              { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN2>mod              { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN2>[+*\-]           { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN2>\?               { BEGIN(TOKEN0); return *yytext; }
<TOKEN2>"//"             { BEGIN(TOKEN0); return DOUBLESLASH; }
<TOKEN2>"!="             { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return RELOP; }
<TOKEN2>">="             { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }
<TOKEN2>"<="             { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }
<TOKEN2>[<>=]            { BEGIN(TOKEN0); clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }

<TOKEN2>@                { BEGIN(TOKEN0); return *yytext; }
<TOKEN2>\"               { BEGIN(TOKEN0); _XPY->xpy_lex_string_state=TOKEN2; BEGIN(QLITERAL); return QUOTE; }
<TOKEN2>\'               { BEGIN(TOKEN0); _XPY->xpy_lex_string_state=TOKEN2; BEGIN(ALITERAL); return APOST; }
<TOKEN2>\-?({integer}|{real}) { BEGIN(TOKEN0); clixon_xpath_parselval.string = strdup(yytext); return NUMBER; }

<TOKEN2>comment\(        { BEGIN(TOKEN0); clixon_xpath_parselval.string = strdup(yytext);  striplast(clixon_xpath_parselval.string); return NODETYPE; }
<TOKEN2>text\(           { BEGIN(TOKEN0); clixon_xpath_parselval.string = strdup(yytext);  striplast(clixon_xpath_parselval.string); return NODETYPE; }
<TOKEN2>processing-instructions\( { BEGIN(TOKEN0); clixon_xpath_parselval.string = strdup(yytext); striplast(clixon_xpath_parselval.string); return NODETYPE; }
<TOKEN2>node\(          { BEGIN(TOKEN0); clixon_xpath_parselval.string = strdup(yytext);  striplast(clixon_xpath_parselval.string); return NODETYPE; }
<TOKEN2>{ncname}         { /* See lexical rules 2 and 3 in the file header */
                           BEGIN(TOKEN0);
                           clixon_xpath_parselval.string = strdup(yytext);
                           return NCNAME;
                        }
<TOKEN2>.                { fprintf(stderr,"LEXICAL ERROR\n"); return -1; }

<QLITERAL>\"            { BEGIN(_XPY->xpy_lex_string_state); return QUOTE; }
<QLITERAL>[^"]+         { clixon_xpath_parselval.string = strdup(yytext);
                            return CHARS;}
<ALITERAL>\'            { BEGIN(_XPY->xpy_lex_string_state); return APOST; }
<ALITERAL>[^']+         { clixon_xpath_parselval.string = strdup(yytext);
                            return CHARS;}

%%


/*! Initialize scanner.
 */
int
xpath_scan_init(clixon_xpath_yacc *xpy)
{
  BEGIN(TOKEN0);
  xpy->xpy_lexbuf = yy_scan_string (xpy->xpy_parse_string);
#if 1 /* XXX: just to use unput to avoid warning  */
  if (0)
    yyunput(0, "");
#endif

  return 0;
}

/*
 * free buffers
 * Even within Flex version 2.5 (this is assumed), freeing buffers is different.
 */
int
xpath_scan_exit(clixon_xpath_yacc *xpy)
{
    yy_delete_buffer(xpy->xpy_lexbuf);
    clixon_xpath_parselex_destroy();  /* modern */
    return 0;
}

