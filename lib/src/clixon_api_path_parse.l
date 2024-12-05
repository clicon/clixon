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
 *
 * "api-path" is "URI-encoded path expression" definition in RFC8040 3.53.
 * BNF:
 *  <api-path>       := <root> ("/" (<api-identifier> | <list-instance>))*
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
 * XXX For some reason, I cant use "return *string" in these rules, so I resort to symbols 
 * (eg slash)
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>

#include "clixon_api_path_parse.tab.h" /* generated */

#include <cligen/cligen.h>

#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_string.h"
#include "clixon_xml.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_path.h"
#include "clixon_api_path_parse.h"

/* Redefine main lex function so that you can send arguments to it: _yy is added to arg list */
#define YY_DECL int clixon_api_path_parselex(void *_ay)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _AY ((clixon_api_path_yacc *)_ay)

#undef clixon_api_path_parsewrap
int 
clixon_api_path_parsewrap(void)
{
    return 1;
}

%}

namestart  [A-Z_a-z]
namechar   [A-Z_a-z\-\.0-9]
identifier {namestart}{namechar}*

%x INIT
%s KEYV

%%

<INIT,KEYV>[ \t]            
<INIT,KEYV>\n      { _AY->ay_linenum++; }
<INIT,KEYV>\r
<INIT,KEYV><<EOF>> { return X_EOF; }

<INIT>\/           { return SLASH;}
<INIT>\=           { BEGIN(KEYV); return EQUAL; }
<INIT>\:           { return COLON; }
<INIT>{identifier} { clixon_api_path_parselval.string = strdup(yytext); 
                     return IDENTIFIER; } 
<INIT>.            { clixon_api_path_parseerror(_AY, "LEXICAL ERROR\n"); return -1; }

<KEYV>\,           { return COMMA; }                        
<KEYV>\/           { BEGIN(INIT); return SLASH; }
<KEYV>[^:/?#\[\]@,]+ { clixon_api_path_parselval.string = strdup(yytext);
                     return STRING;}
<KEYV>.            { clixon_api_path_parseerror(_AY, "LEXICAL ERROR\n"); return -1; }
                     
%%

/*! Initialize scanner.
 */
int
api_path_scan_init(clixon_api_path_yacc *ay)
{
  BEGIN(INIT);
  ay->ay_lexbuf = yy_scan_string(ay->ay_parse_string);
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
api_path_scan_exit(clixon_api_path_yacc *ay)
{
    yy_delete_buffer(ay->ay_lexbuf);
    clixon_api_path_parselex_destroy();  /* modern */
    return 0;
}
