/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

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
<START>[-+]?[0-9]+      { clixon_json_parselval.string = strdup(yytext); 
                          return J_NUMBER;}
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
#if defined(YY_FLEX_SUBMINOR_VERSION) && YY_FLEX_SUBMINOR_VERSION >= 9
    clixon_json_parselex_destroy();  /* modern */
#else
    yy_init = 1;      /* This does not quite free all buffers */
#endif
    return 0;
}

