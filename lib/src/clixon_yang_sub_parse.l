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

 * if-feature-expr RFC7950 14
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "clixon_yang_sub_parse.tab.h"   /* generated file */

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_yang_sub_parse.h"
#include "banned.h"

/* typecast macro */
#define _IF ((clixon_yang_sub_parse_yacc *)yyget_extra(yyscanner))

/*
 */

%}

%option reentrant
%option bison-bridge
%option noyywrap
%option nounput
%option noinput
%option extra-type="clixon_yang_sub_parse_yacc *"


%x COMMENT
%x STRING

identifier      [A-Za-z_][A-Za-z0-9_\-\.]*

%%

<INITIAL>[ \t\r]*         { return SEP; }
<INITIAL>\n               { _IF->if_linenum++; return SEP; }
<INITIAL>\(               { return *yytext; }
<INITIAL>\)               { return *yytext; }
<INITIAL>:                { return *yytext; }
<INITIAL>not              { return NOT; }
<INITIAL>and              { return AND; }
<INITIAL>or               { return OR; }
<INITIAL>{identifier}     { yylval->string = strdup(yytext);
                            return IDENTIFIER;}
<INITIAL><<EOF>>          { return MY_EOF; }
<INITIAL>.                { return -1; }

%%

/*! Initialize XML scanner.
 */
int
clixon_yang_sub_parsel_init(clixon_yang_sub_parse_yacc *ife)
{
    if (clixon_yang_sub_parselex_init(&ife->if_scanner) != 0)
        return -1;
    clixon_yang_sub_parseset_extra(ife, ife->if_scanner);
    ife->if_lexbuf = yy_scan_string(ife->if_parse_string, ife->if_scanner);
    return 0;
}

/*! Exit xml scanner */
int
clixon_yang_sub_parsel_exit(clixon_yang_sub_parse_yacc *ife)
{
    yy_delete_buffer(ife->if_lexbuf, ife->if_scanner);
    clixon_yang_sub_parselex_destroy(ife->if_scanner);
    return 0;
}
