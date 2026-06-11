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

 * @see http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
 *  and RFC 7951 JSON Encoding of Data Modeled with YANG
 *  and RFC 8259 The JavaScript Object Notation (JSON) Data Interchange Format
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <sys/param.h>
#include <netinet/in.h>

#include "clixon_json_parse.tab.h" /* generated */

#include <cligen/cligen.h>

#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_string.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_json_parse.h"
#include "banned.h"

/* typecast macro */
#define _JY ((clixon_json_yacc *)yyget_extra(yyscanner))

%}

%option reentrant
%option bison-bridge
%option noyywrap
%option nounput
%option noinput
%option extra-type="clixon_json_yacc *"


digit [0-9]
integer {digit}+
real ({digit}+[.]{digit}*)|({digit}*[.]{digit}+)
exp ({integer}|{real})[eE][+-]{integer}
hex [A-Fa-f0-9]

%x START
%s STRING
%s ESCAPE
%s HEXDIG

%%

<START>[ \t]
<START>\n               { _JY->jy_linenum++; }
<START>\r
<START><<EOF>>          { return J_EOF; }
<START>\{               { return *yytext; }
<START>\}               { return *yytext; }
<START>\[               { return *yytext; }
<START>\]               { return *yytext; }
<START>\:               { return *yytext; }
<START>\,               { return *yytext; }
<START>\"               { BEGIN(STRING); return J_DQ; }
<START>null             { return J_NULL; }
<START>false            { return J_FALSE; }
<START>true             { return J_TRUE; }
<START>\-?({integer}|{real}|{exp}) { yylval->string = strdup(yytext); return J_NUMBER;}
<START>.                { return -1; }
<STRING>\"              { BEGIN(START); return J_DQ; }
<STRING>\\              { BEGIN(ESCAPE); }
<STRING>[^\"\\\b\f\n\r\t]+ { BEGIN(STRING); yylval->string = yytext; return J_STRING; }
<STRING>\n              { return -1; }
<STRING>.               { return -1; }
<ESCAPE>\"              { BEGIN(STRING); yylval->string = yytext; return J_STRING; }
<ESCAPE>\\              { BEGIN(STRING); yylval->string = yytext; return J_STRING; }
<ESCAPE>\/              { BEGIN(STRING); yylval->string = yytext; return J_STRING; }
<ESCAPE>b               { BEGIN(STRING); yylval->string = "\b";   return J_STRING; }
<ESCAPE>f               { BEGIN(STRING); yylval->string = "\f";   return J_STRING; }
<ESCAPE>n               { BEGIN(STRING); yylval->string = "\n";   return J_STRING; }
<ESCAPE>r               { BEGIN(STRING); yylval->string = "\r";   return J_STRING; }
<ESCAPE>t               { BEGIN(STRING); yylval->string = "\t";   return J_STRING; }
<ESCAPE>u               { BEGIN(HEXDIG); }
<ESCAPE>\n              { return -1; }
<ESCAPE>.               { return -1; }
<HEXDIG>{hex}{hex}{hex}{hex} {
                               char buf[5] = {0, };
                               BEGIN(STRING);
                               if (clixon_unicode2utf8(yytext, buf, 5) < 0)
                                  return -1;
                               strncpy(yytext, buf, 5);
                               yylval->string = yytext;
                               return J_STRING;
                              }
<HEXDIG>\n              { return -1;}
<HEXDIG>.               { return -1; }

%%

/*! Initialize scanner.
 */
int
json_scan_init(clixon_json_yacc *jy)
{
    struct yyguts_t *yyg;   /* needed for BEGIN() in reentrant mode */

    if (clixon_json_parselex_init(&jy->jy_scanner) != 0)
        return -1;
    yyg = (struct yyguts_t *)jy->jy_scanner;
    BEGIN(START);
    clixon_json_parseset_extra(jy, jy->jy_scanner);
    jy->jy_lexbuf = yy_scan_string(jy->jy_parse_string, jy->jy_scanner);
    return 0;
}

/*
 * free buffers
 * Even within Flex version 2.5 (this is assumed), freeing buffers is different.
 */
int
json_scan_exit(clixon_json_yacc *jy)
{
    yy_delete_buffer(jy->jy_lexbuf, jy->jy_scanner);
    clixon_json_parselex_destroy(jy->jy_scanner);
    return 0;
}
