/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2020 Olof Hagsand

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
#include "clixon_log.h"
#include "clixon_string.h"
#include "clixon_xml.h"
#include "clixon_xpath_ctx.h"
#include "clixon_xpath.h"
#include "clixon_xpath_parse.h"
#include "clixon_xpath_eval.h"

/* Redefine main lex function so that you can send arguments to it: _yy is added to arg list */
#define YY_DECL int clixon_xpath_parselex(void *_yy)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _XY ((struct clicon_xpath_yacc_arg *)_yy)

#define     MAXBUF  4*4*64*1024

#undef clixon_xpath_parsewrap
int 
clixon_xpath_parsewrap(void)
{
    return 1;
}

%}

digit [0-9]
integer {digit}+
real ({digit}+[.]{digit}*)|({digit}*[.]{digit}+)

namestart  [A-Z_a-z]
namechar   [A-Z_a-z\-\.0-9]
ncname     {namestart}{namechar}*

%x TOKEN
%s QLITERAL
%s ALITERAL

%%
<TOKEN>[ \t]            
<TOKEN>\n               { _XY->xy_linenum++; }
<TOKEN>\r               { }
<TOKEN><<EOF>>          { return X_EOF; }
<TOKEN>".."             { return DOUBLEDOT; }
<TOKEN>[()\[\]\.,/:|]   { return *yytext; }
<TOKEN>and              { clixon_xpath_parselval.intval = clicon_str2int(xpopmap, yytext); return LOGOP; }
<TOKEN>or               { clixon_xpath_parselval.intval = clicon_str2int(xpopmap, yytext); return LOGOP; }
<TOKEN>div              { clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN>mod              { clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN>[+*\-]           { clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return ADDOP; }
<TOKEN>\?               { return *yytext; }
<TOKEN>"//"             { return DOUBLESLASH; }
<TOKEN>"!="             { clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext); return RELOP; }
<TOKEN>">="             { clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }
<TOKEN>"<="             { clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }
<TOKEN>[<>=]            { clixon_xpath_parselval.intval = clicon_str2int(xpopmap,yytext);return RELOP; }
<TOKEN>last	        { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>position	        { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>count	        { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>re-match         { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>deref            { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>derived-from     { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>derived-from-or-self { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>enum-value       { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }
<TOKEN>bit-is-set       { clixon_xpath_parselval.string = strdup(yytext); return FUNCTIONNAME; }

<TOKEN>@                { return *yytext; }
<TOKEN>ancestor::       { clixon_xpath_parselval.intval = A_ANCESTOR; return AXISNAME; }
<TOKEN>ancestor-or-self:: { clixon_xpath_parselval.intval = A_ANCESTOR_OR_SELF; return AXISNAME; }
<TOKEN>attribute::        { clixon_xpath_parselval.intval = A_ATTRIBUTE; return AXISNAME; }
<TOKEN>child::            { clixon_xpath_parselval.intval = A_CHILD; return AXISNAME; }
<TOKEN>descendant::       { clixon_xpath_parselval.intval = A_DESCENDANT; return AXISNAME; }
<TOKEN>descendant-or-self:: { clixon_xpath_parselval.intval = A_DESCENDANT_OR_SELF; return AXISNAME; }
<TOKEN>following::        { clixon_xpath_parselval.intval = A_FOLLOWING; return AXISNAME; }
<TOKEN>following-sibling:: { clixon_xpath_parselval.intval = A_FOLLOWING_SIBLING; return AXISNAME; }
<TOKEN>namespace::        { clixon_xpath_parselval.intval = A_NAMESPACE; return AXISNAME; }
<TOKEN>parent::           { clixon_xpath_parselval.intval = A_PARENT; return AXISNAME; }
<TOKEN>preceding::        { clixon_xpath_parselval.intval = A_PRECEDING; return AXISNAME; }
<TOKEN>preceding-sibling:: { clixon_xpath_parselval.intval = A_PRECEDING_SIBLING; return AXISNAME; }
<TOKEN>self::             { clixon_xpath_parselval.intval = A_SELF; return AXISNAME; }

<TOKEN>current          { clixon_xpath_parselval.string = strdup(yytext); return NODETYPE; }
<TOKEN>comment          { clixon_xpath_parselval.string = strdup(yytext); return NODETYPE; }
<TOKEN>text             { clixon_xpath_parselval.string = strdup(yytext); return NODETYPE; }
<TOKEN>processing-instructions { clixon_xpath_parselval.string = strdup(yytext); return NODETYPE; }
<TOKEN>node             { clixon_xpath_parselval.string = strdup(yytext); return NODETYPE; }

<TOKEN>\"               { BEGIN(QLITERAL); return QUOTE; }
<TOKEN>\'               { BEGIN(ALITERAL); return APOST; }
<TOKEN>\-?({integer}|{real}) { clixon_xpath_parselval.string = strdup(yytext); return NUMBER; }
<TOKEN>{ncname}         { clixon_xpath_parselval.string = strdup(yytext);
                            return NAME; /* rather be catch-all */
                        } 
<TOKEN>.                { fprintf(stderr,"LEXICAL ERROR\n"); return -1; }

<QLITERAL>\"            { BEGIN(TOKEN); return QUOTE; }
<QLITERAL>[^"]+         { clixon_xpath_parselval.string = strdup(yytext);
                            return CHARS;}
<ALITERAL>\'            { BEGIN(TOKEN); return APOST; }
<ALITERAL>[^']+         { clixon_xpath_parselval.string = strdup(yytext);
                            return CHARS;}

%%


/*! Initialize scanner.
 */
int
xpath_scan_init(struct clicon_xpath_yacc_arg *xy)
{
  BEGIN(TOKEN);
  xy->xy_lexbuf = yy_scan_string (xy->xy_parse_string);
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
xpath_scan_exit(struct clicon_xpath_yacc_arg *xy)
{
    yy_delete_buffer(xy->xy_lexbuf);
    clixon_xpath_parselex_destroy();  /* modern */
    return 0;
}

