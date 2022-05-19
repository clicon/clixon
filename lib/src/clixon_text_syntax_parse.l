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

/* clicon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_text_syntax_parse.h"

/* Redefine main lex function so that you can send arguments to it: _ts is added to arg list */
#define YY_DECL int clixon_text_syntax_parselex(void *_ts)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _TS ((clixon_text_syntax_yacc *)_ts) 

#undef clixon_xml_parsewrap
int clixon_text_syntax_parsewrap(void)
{
  return 1;
}

/*
 */

%}

%s COMMENT

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
<INITIAL>\:               { return *yytext; }
<INITIAL>[^\n\r \t\[\]\{\}\;\:]+  {
                          clixon_text_syntax_parselval.string = strdup(yytext);
                            return TOKEN; }
<INITIAL>.                { return -1; }

<COMMENT>\n               { _TS->ts_linenum++; BEGIN(_TS->ts_lex_state);}
<COMMENT><<EOF>>          { return MY_EOF; }
<COMMENT>[^\n]+

%%

/*! Initialize XML scanner.
 */
int
clixon_text_syntax_parsel_init(clixon_text_syntax_yacc *ts)
{
  BEGIN(INITIAL);
  ts->ts_lexbuf = yy_scan_string (ts->ts_parse_string);
  if (0)
    yyunput(0, "");  /* XXX: just to use unput to avoid warning  */
  return 0;
}

/*! Exit xml scanner */
int
clixon_text_syntax_parsel_exit(clixon_text_syntax_yacc *ts)
{
   yy_delete_buffer(ts->ts_lexbuf);
   clixon_text_syntax_parselex_destroy();  /* modern */

  return 0;
}
