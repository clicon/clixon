/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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

 * XML parser
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208
 * 

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
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
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

/*
 * From https://www.w3.org/TR/2008/REC-xml-20081126:
 * [4]* NameStartChar ::= ":" | [A-Z] | "_" | [a-z]   | [#xC0-#xD6] | [#xD8-#xF6] ...
 * [4a] NameChar      ::= NameStartChar | "-" | "." | [0-9]     | #xB7| 
 * [5]  Name	      ::= NameStartChar (NameChar)*
 * NOTE: From https://www.w3.org/TR/2009/REC-xml-names-20091208:
 * [4] 	NCName	      ::= Name - (Char* ':' Char*)  An XML Name, minus the ":"
 * --> namestart and name below is NCNAME
 */

%}

namestart  [A-Z_a-z]
namechar   [A-Z_a-z\-\.0-9]
ncname     {namestart}{namechar}*

%x START
%s STATEA
%s AMPERSAND
%s CDATA
%s CMNT
%s STR
%s TEXTDECL
%s PIDECL
%s PIDECL2
%s STRDQ
%s STRSQ

%%

<START,TEXTDECL>[ \t]   ;
<START,STATEA,CMNT,TEXTDECL>\n   { _YA->ya_linenum++; }
<START,STATEA,CMNT,TEXTDECL>\r

<START>{ncname}        { clixon_xml_parselval.string = strdup(yytext);
                            return NAME; /* rather be catch-all */
                          }
<START>\:               return *clixon_xml_parsetext;
<START>\n             { _YA->ya_linenum++;}
<START><<EOF>>        { return MY_EOF; }
<START>"<?xml"        { BEGIN(TEXTDECL); return BXMLDCL;}
<START>"<?"           { BEGIN(PIDECL); return BQMARK;}
<START>"/>"           { BEGIN(STATEA); return ESLASH; }
<START>"<!--"         { BEGIN(CMNT); return BCOMMENT; }
<START>"</"             return BSLASH;
<START>[/=]             return *clixon_xml_parsetext; 
<START>\<               return *clixon_xml_parsetext;
<START>\>             { BEGIN(STATEA); return *clixon_xml_parsetext; }
<START>\"             { _YA->ya_lex_state=START;BEGIN(STRDQ); return *clixon_xml_parsetext; }
<START>\'             { _YA->ya_lex_state=START;BEGIN(STRSQ); return *clixon_xml_parsetext; }
<START>.              { clixon_xml_parselval.string = yytext; return CHARDATA; /* optimize? */}

<STATEA>"</"          { BEGIN(START); return BSLASH; }
<STATEA><<EOF>>       { return MY_EOF; }
<STATEA>"<!--"        { BEGIN(CMNT); return BCOMMENT; }
<STATEA>"<![CDATA["   { BEGIN(CDATA); _YA->ya_lex_state = STATEA; clixon_xml_parselval.string = yytext; return CHARDATA;}
<STATEA>"<?"          { BEGIN(PIDECL); return BQMARK; }
<STATEA>\<            { BEGIN(START); return *clixon_xml_parsetext; }
<STATEA>&             { _YA->ya_lex_state =STATEA;BEGIN(AMPERSAND);}
<STATEA>.             { clixon_xml_parselval.string = yytext; return CHARDATA; }

	/* @see xml_chardata_encode */
<AMPERSAND>"amp;"    { BEGIN(_YA->ya_lex_state); clixon_xml_parselval.string = "&"; return CHARDATA;}
<AMPERSAND>"lt;"     { BEGIN(_YA->ya_lex_state); clixon_xml_parselval.string = "<"; return CHARDATA;}
<AMPERSAND>"gt;"     { BEGIN(_YA->ya_lex_state); clixon_xml_parselval.string = ">"; return CHARDATA;}
<AMPERSAND>"apos;"   { BEGIN(_YA->ya_lex_state); clixon_xml_parselval.string = "'"; return CHARDATA;}
<AMPERSAND>"quot;"   { BEGIN(_YA->ya_lex_state); clixon_xml_parselval.string = "\""; return CHARDATA;}

<CDATA>.              { clixon_xml_parselval.string = yytext; return CHARDATA;}
<CDATA>\n             { clixon_xml_parselval.string = yytext;_YA->ya_linenum++; return (CHARDATA);}
<CDATA>"]]>"          { BEGIN(_YA->ya_lex_state); clixon_xml_parselval.string = yytext; return CHARDATA;}

<CMNT>"-->"           { BEGIN(START); return ECOMMENT; }
<CMNT>.               
<TEXTDECL>encoding      return ENC;
<TEXTDECL>version       return VER; 
<TEXTDECL>standalone    return SD; 
<TEXTDECL>"="         { return *clixon_xml_parsetext; }
<TEXTDECL>"?>"        { BEGIN(START);return EQMARK;}
<TEXTDECL>\"          { _YA->ya_lex_state =TEXTDECL;BEGIN(STRDQ); return *clixon_xml_parsetext; }
<TEXTDECL>\'          { _YA->ya_lex_state =TEXTDECL;BEGIN(STRSQ); return *clixon_xml_parsetext; }
<TEXTDECL>.           { clixon_xml_parselval.string = yytext; return CHARDATA; /* optimize? */}

<PIDECL>{ncname}      { clixon_xml_parselval.string = strdup(yytext);
                            return NAME; /* rather be catch-all */
                          }
<PIDECL>[ \t]         { BEGIN(PIDECL2);}
<PIDECL>.             { clixon_xml_parselval.string = yytext; return CHARDATA; /* optimize? */}
<PIDECL2>"?>"         { BEGIN(START);return EQMARK;}
<PIDECL2>[^{?>}]+     { clixon_xml_parselval.string = strdup(yytext);  return STRING; }

<STRDQ>1\.[0-9]+      { clixon_xml_parselval.string = strdup(yytext);  return STRING; }
<STRDQ>[^\"]+         { clixon_xml_parselval.string = strdup(yytext); return STRING; }
<STRDQ>\"             { BEGIN(_YA->ya_lex_state); return *clixon_xml_parsetext; }

<STRSQ>1\.[0-9]+      { clixon_xml_parselval.string = strdup(yytext); return STRING; }
<STRSQ>[^\']+         { clixon_xml_parselval.string = strdup(yytext); return STRING; }
<STRSQ>\'             { BEGIN(_YA->ya_lex_state); return *clixon_xml_parsetext; }

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
   clixon_xml_parselex_destroy();  /* modern */

  return 0;
}
