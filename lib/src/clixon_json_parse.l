/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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

#include "clixon_json_parse.tab.h" /* generated */

#include <cligen/cligen.h>

#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_log.h"
#include "clixon_xml.h"
#include "clixon_json_parse.h"

/* Redefine main lex function so that you can send arguments to it: _yy is added to arg list */
#define YY_DECL int clixon_json_parselex(void *_yy)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _JY ((struct clicon_json_yacc_arg *)_yy)

#define     MAXBUF  4*4*64*1024

#undef clixon_json_parsewrap
int 
clixon_json_parsewrap(void)
{
    return 1;
}



%}

digit [0-9]
integer {digit}+
real ({digit}+[.]{digit}*)|({digit}*[.]{digit}+)
exp ({integer}|{real})[eE][+-]{integer}

%x START
%s STRING
%s ESCAPE

%%
<START>[ \t]            
<START>\n               { _JY->jy_linenum++; }
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
<START>\-?({integer}|{real}|{exp}) { clixon_json_parselval.string = strdup(yytext); return J_NUMBER;}
<START>.                { return -1; }
<STRING>\"              { BEGIN(START); return J_DQ; }
<STRING>\\              { BEGIN(ESCAPE); }
<STRING>\n              { _JY->jy_linenum++; 
                          clixon_json_parselval.string = strdup(yytext); 
                          return J_CHAR;}
<STRING>.               { clixon_json_parselval.string = strdup(yytext);
                          return J_CHAR;}
<ESCAPE>.               { BEGIN(STRING); 
                          clixon_json_parselval.string = strdup(yytext); 
                          return J_CHAR; }

%%


/*! Initialize scanner.
 */
int
json_scan_init(struct clicon_json_yacc_arg *jy)
{
  BEGIN(START);
  jy->jy_lexbuf = yy_scan_string (jy->jy_parse_string);
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
json_scan_exit(struct clicon_json_yacc_arg *jy)
{
    yy_delete_buffer(jy->jy_lexbuf);
    clixon_json_parselex_destroy();  /* modern */
    return 0;
}

