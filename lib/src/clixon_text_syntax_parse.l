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

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "clixon_text_syntax_parse.tab.h"   /* generated file */

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_text_syntax_parse.h"
#include "banned.h"

/* typecast macro */
#define _TS ((clixon_text_syntax_yacc *)yyget_extra(yyscanner))

/*
 */

%}

%option reentrant
%option bison-bridge
%option noyywrap
%option nounput
%option noinput
%option extra-type="clixon_text_syntax_yacc *"


%x COMMENT
%x STRING

%%

<INITIAL>[ \t]*
<INITIAL>\n               { _TS->ts_linenum++; }
<INITIAL>\r
<INITIAL><<EOF>>          { return MY_EOF; }
<INITIAL>#                { _TS->ts_lex_state =INITIAL; BEGIN(COMMENT); }
<INITIAL>\{               { return *yytext; }
<INITIAL>\}               { return *yytext; }
<INITIAL>\[               { return *yytext; }
<INITIAL>\]               { return *yytext; }
<INITIAL>\;               { return *yytext; }
<INITIAL>\"               { _TS->ts_lex_state =INITIAL; BEGIN(STRING);  return *yytext; }
<INITIAL>[^\n\r \t\[\]\{\}\;\"]+  {
                            yylval->string = strdup(yytext);
                            return TOKEN; }

<COMMENT>\n               { _TS->ts_linenum++; BEGIN(_TS->ts_lex_state);}
<COMMENT><<EOF>>          { return MY_EOF; }
<COMMENT>[^\n]+

<STRING>\n                { _TS->ts_linenum++;
                            yylval->string = strdup(yytext);
                            return TOKEN;}
<STRING>\"                { BEGIN(_TS->ts_lex_state); return *yytext; }
<STRING>[^\n\"]+          { yylval->string = strdup(yytext);
                            return TOKEN; }

%%

/*! Initialize XML scanner.
 */
int
clixon_text_syntax_parsel_init(clixon_text_syntax_yacc *ts)
{
    if (clixon_text_syntax_parselex_init(&ts->ts_scanner) != 0)
        return -1;
    clixon_text_syntax_parseset_extra(ts, ts->ts_scanner);
    ts->ts_lexbuf = yy_scan_string(ts->ts_parse_string, ts->ts_scanner);
    return 0;
}

/*! Exit xml scanner */
int
clixon_text_syntax_parsel_exit(clixon_text_syntax_yacc *ts)
{
    yy_delete_buffer(ts->ts_lexbuf, ts->ts_scanner);
    clixon_text_syntax_parselex_destroy(ts->ts_scanner);
    return 0;
}
