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

 * XML parser
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "clixon_xml_parse.tab.h"   /* generated file */

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_xml.h"
#include "clixon_xml_parse.h"

/* Redefine main lex function so that you can send arguments to it: _ya is added to arg list */
#define YY_DECL int clixon_xml_parselex(void *_ya)

/* Dont use input function (use user-buffer) */
#define YY_NO_INPUT

/* typecast macro */
#define _YA ((struct xml_parse_yacc_arg *)_ya) 

#undef clixon_xml_parsewrap
int clixon_xml_parsewrap(void)
{
  return 1;
}

%}

%x START
%s STATEA
%s CMNT
%s STR
%s TEXTDECL
%s STRDQ
%s STRSQ

%%
<START>[0-9A-Za-z_\-]+ { clixon_xml_parselval.string = strdup(yytext);
                            return NAME; /* rather be catch-all */
                          }
<START>[ \t]+          ;
<START>\:              return *clixon_xml_parsetext;
<START>\n              { _YA->ya_linenum++;}
<START>"<?xml"         { BEGIN(TEXTDECL); return BTEXT;}
<START>"/>"            { BEGIN(STATEA); return ESLASH; }
<START>"<!--"          { BEGIN(CMNT); return BCOMMENT; }
<START>"</"            return BSLASH;
<START>[/=]            return *clixon_xml_parsetext; 
<START>\<              return *clixon_xml_parsetext;
<START>\>              { BEGIN(STATEA); return *clixon_xml_parsetext; }

<START>\"              { BEGIN(STR); return *clixon_xml_parsetext; }
<START>.               { clixon_xml_parselval.string = yytext; return CHAR; /*XXX:optimize*/ }


<STATEA>"</"               { BEGIN(START); return BSLASH; }
<STATEA>"<!--"             { BEGIN(CMNT); return BCOMMENT; }
<STATEA>\<                 { BEGIN(START); return *clixon_xml_parsetext; }
<STATEA>\n                 { clixon_xml_parselval.string = yytext;_YA->ya_linenum++; return (CHAR);}
<STATEA>.                  { clixon_xml_parselval.string = yytext; return CHAR; /*XXX:optimize*/}

<CMNT>"-->"           { BEGIN(START); return ECOMMENT; }
<CMNT>\n              _YA->ya_linenum++;
<CMNT>.               
<TEXTDECL>encoding       return ENC;
<TEXTDECL>version        return VER; 
<TEXTDECL>"="            return *clixon_xml_parsetext;
<TEXTDECL>"?>"           { BEGIN(START);return ETEXT;}
<TEXTDECL>\"             { BEGIN(STRDQ); return *clixon_xml_parsetext; }
<TEXTDECL>\'             { BEGIN(STRSQ); return *clixon_xml_parsetext; }

<STR>[^\"]+           { clixon_xml_parselval.string = strdup(yytext); return CHAR; }
<STR>\"               { BEGIN(START); return *clixon_xml_parsetext; }

<STRDQ>1\.[0-9]+       { clixon_xml_parselval.string = strdup(yytext);  return CHAR; }
<STRDQ>[^\"]+          { clixon_xml_parselval.string = strdup(yytext);  return CHAR; }
<STRDQ>\"              { BEGIN(TEXTDECL); return *clixon_xml_parsetext; }

<STRSQ>1\.[0-9]+       { clixon_xml_parselval.string = strdup(yytext);   return CHAR; }
<STRSQ>[^\']+          { clixon_xml_parselval.string = strdup(yytext);   return CHAR; }
<STRSQ>\'              { BEGIN(TEXTDECL); return *clixon_xml_parsetext; }

%%

/*! Initialize XML scanner.
 */
int
clixon_xml_parsel_init(struct xml_parse_yacc_arg *ya)
{
  BEGIN(START);
  ya->ya_lexbuf = yy_scan_string (ya->ya_parse_string);
  if (0)
    yyunput(0, "");  /* XXX: just to use unput to avoid warning  */
  return 0;
}

/*! Exit xml scanner */
int
clixon_xml_parsel_exit(struct xml_parse_yacc_arg *ya)
{
   yy_delete_buffer(ya->ya_lexbuf);
#if defined(YY_FLEX_SUBMINOR_VERSION) && YY_FLEX_SUBMINOR_VERSION >= 9
   clixon_xml_parselex_destroy();  /* modern */
#else
    yy_init = 1;      /* This does not quite free all buffers */
#endif

  return 0;
}
