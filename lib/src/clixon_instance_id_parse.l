/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC

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
 * "instance-id" is a subset of XPath and defined in RF7950 Sections 9.13 and 14. 
 * BNF:
 *  instance-identifier = ("/" (node-identifier [key-predicate+ | leaf-list-predicate | pos]))+
 *  key-predicate       = "[" key-predicate-expr "]"
 *  key-predicate-expr  = node-identifier "=" quoted-string
 *  leaf-list-predicate = "[" leaf-list-predicate-expr  "]"
 *  leaf-list-predicate-expr = "." "=" quoted-string
 *  pos                 = "[" positive-integer-value "]"
 *  node-identifier     = [prefix ":"] identifier
 *  quoted-string       = (DQUOTE string DQUOTE) / (SQUOTE string SQUOTE)
 *  positive-integer-value = (non-zero-digit DIGIT*)
 *  prefix              = identifier
 *  identifier          = (ALPHA | "_")(ALPHA | DIGIT | "_" | "-" | ".")*
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>

#include "clixon_instance_id_parse.tab.h" /* generated */

#include <cligen/cligen.h>

#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_log.h"
#include "clixon_string.h"
#include "clixon_xml.h"
#include "clixon_path.h"
#include "clixon_instance_id_parse.h"

/* Redefine main lex function so that you can send arguments to it: _yy is added to arg list */
#define YY_DECL int clixon_instance_id_parselex(void *_iy)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _IY ((clixon_instance_id_yacc *)_iy)

#define     MAXBUF  4*4*64*1024

#undef clixon_instance_id_parsewrap
int 
clixon_instance_id_parsewrap(void)
{
    return 1;
}

%}

namestart  [A-Z_a-z]
namechar   [A-Z_a-z\-\.0-9]
identifier {namestart}{namechar}*
uint       [1-9][0-9]*

%x INIT
%s STRDQ
%s STRSQ

%%

<INIT,STRDQ,STRSQ>[ \t]            
<INIT,STRDQ,STRSQ>\n       { _IY->iy_linenum++; }
<INIT,STRDQ,STRSQ>\r
<INIT,STRDQ,STRSQ><<EOF>>  { return X_EOF; }

<INIT>\/           { return SLASH;}
<INIT>\[           { return LSQBR;}
<INIT>\]           { return RSQBR;}
<INIT>\=           { return EQUAL; }
<INIT>\:           { return COLON; }
<INIT>\.           { return DOT; }
<INIT>\"           { _IY->iy_lex_state=INIT;BEGIN(STRDQ); return DQUOTE; }
<INIT>\'           { _IY->iy_lex_state=INIT;BEGIN(STRSQ); return SQUOTE; }
<INIT>{identifier} { clixon_instance_id_parselval.string = strdup(yytext); 
                     return IDENTIFIER; } 
<INIT>{uint}       { clixon_instance_id_parselval.string = strdup(yytext); 
                     return UINT; } 
<INIT>.            { clixon_instance_id_parseerror(_IY, "LEXICAL ERROR\n"); return -1; }

<STRDQ>[^\"]+         { clixon_instance_id_parselval.string = strdup(yytext); return STRING; }
<STRDQ>\"             { BEGIN(_IY->iy_lex_state); return DQUOTE; }

<STRSQ>[^\']+         { clixon_instance_id_parselval.string = strdup(yytext); return STRING; }
<STRSQ>\'             { BEGIN(_IY->iy_lex_state); return SQUOTE; }

		     
%%

/*! Initialize scanner.
 */
int
instance_id_scan_init(clixon_instance_id_yacc *iy)
{
  BEGIN(INIT);
  iy->iy_lexbuf = yy_scan_string(iy->iy_parse_string);
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
instance_id_scan_exit(clixon_instance_id_yacc *iy)
{
    yy_delete_buffer(iy->iy_lexbuf);
    clixon_instance_id_parselex_destroy();  /* modern */
    return 0;
}

