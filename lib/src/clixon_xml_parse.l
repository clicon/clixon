/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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

 * XML parser
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208
 * Canonical XML version (just for info)
 *      https://www.w3.org/TR/xml-c14n
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "clixon_xml_parse.tab.h"   /* generated file */

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_xml_parse.h"
#include "banned.h"

/* Retrieve the clixon_xml_yacc context from the reentrant scanner's extra data */
#define _XY ((clixon_xml_yacc *)yyget_extra(yyscanner))

/*
 * From https://www.w3.org/TR/2008/REC-xml-20081126:
 * [4]* NameStartChar ::= ":" | [A-Z] | "_" | [a-z]   | [#xC0-#xD6] | [#xD8-#xF6] ...
 * [4a] NameChar      ::= NameStartChar | "-" | "." | [0-9]     | #xB7| 
 * [5]  Name          ::= NameStartChar (NameChar)*
 * NOTE: From https://www.w3.org/TR/2009/REC-xml-names-20091208:
 * [4]  NCName        ::= Name - (Char* ':' Char*)  An XML Name, minus the ":"
 * --> namestart and name below is NCNAME
 */

%}

%option reentrant
%option bison-bridge
%option noyywrap
%option nounput
%option noinput
%option extra-type="clixon_xml_yacc *"

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
<START,CMNT,TEXTDECL>\n   { _XY->xy_linenum++; }
<START,CMNT,TEXTDECL>\r

<START>{ncname}        { yylval->string = strdup(yytext);
                            return NAME; /* rather be catch-all */
                          }
<START>\:               return *yytext;
<START><<EOF>>        { return MY_EOF; }
<START>"<?xml"        { BEGIN(TEXTDECL); return BXMLDCL;}
<START>"<?"           { BEGIN(PIDECL); return BQMARK;}
<START>"/>"           { BEGIN(STATEA); return ESLASH; }
<START>"<!--"         { BEGIN(CMNT); return BCOMMENT; }
<START>"</"             return BSLASH;
<START>[/=]             return *yytext;
<START>\<               return *yytext;
<START>\>             { BEGIN(STATEA); return *yytext; }
<START>\"             { _XY->xy_lex_state=START;BEGIN(STRDQ); return *yytext; }
<START>\'             { _XY->xy_lex_state=START;BEGIN(STRSQ); return *yytext; }
<START>.              { yylval->string = yytext; return CHARDATA; /* optimize? */}

<STATEA>"</"          { BEGIN(START); return BSLASH; }
<STATEA><<EOF>>       { return MY_EOF; }
<STATEA>"<!--"        { BEGIN(CMNT); return BCOMMENT; }
<STATEA>"<![CDATA["   { BEGIN(CDATA); _XY->xy_lex_state = STATEA; yylval->string = yytext; return CHARDATA;}
<STATEA>"<?"          { BEGIN(PIDECL); return BQMARK; }
<STATEA>\<            { BEGIN(START); return *yytext; }
<STATEA>&             { _XY->xy_lex_state =STATEA;BEGIN(AMPERSAND);}
<STATEA>[ \t]+        { yylval->string = yytext;return WHITESPACE; }
<STATEA>\r\n          { yylval->string = "\n"; _XY->xy_linenum++; return WHITESPACE; }
<STATEA>\r            { yylval->string = "\n";return WHITESPACE; }
<STATEA>\n            { yylval->string = "\n"; _XY->xy_linenum++;return WHITESPACE; }
<STATEA>[^&\r\n \t\<]+ { yylval->string = yytext; return CHARDATA; /* Optimized */}

        /* @see xml_chardata_encode */
<AMPERSAND>"amp;"    { BEGIN(_XY->xy_lex_state); yylval->string = "&"; return CHARDATA;}
<AMPERSAND>"lt;"     { BEGIN(_XY->xy_lex_state); yylval->string = "<"; return CHARDATA;}
<AMPERSAND>"gt;"     { BEGIN(_XY->xy_lex_state); yylval->string = ">"; return CHARDATA;}
<AMPERSAND>"apos;"   { BEGIN(_XY->xy_lex_state); yylval->string = "'"; return CHARDATA;}
<AMPERSAND>"quot;"   { BEGIN(_XY->xy_lex_state); yylval->string = "\""; return CHARDATA;}
<AMPERSAND>"#"[0-9]+";"  { BEGIN(_XY->xy_lex_state); yylval->string = yytext; return ENCODED; /*  ISO/IEC 10646 */ }
<AMPERSAND>"#x"[0-9a-fA-F]+";" { BEGIN(_XY->xy_lex_state); yylval->string = yytext; return ENCODED;}

<CDATA>\n             { yylval->string = yytext;_XY->xy_linenum++; return (CHARDATA);}
<CDATA>"]]>"          { BEGIN(_XY->xy_lex_state); yylval->string = yytext; return CHARDATA;}
<CDATA>\]             { yylval->string = yytext; return CHARDATA;}
<CDATA>[^]\n]+         { yylval->string = yytext; return CHARDATA;}

<CMNT>"-->"           { BEGIN(START); return ECOMMENT; }
<CMNT>.
<TEXTDECL>encoding      return ENC;
<TEXTDECL>version       return VER;
<TEXTDECL>standalone    return SD;
<TEXTDECL>"="         { return *yytext; }
<TEXTDECL>"?>"        { BEGIN(START);return EQMARK;}
<TEXTDECL>\"          { _XY->xy_lex_state =TEXTDECL;BEGIN(STRDQ); return *yytext; }
<TEXTDECL>\'          { _XY->xy_lex_state =TEXTDECL;BEGIN(STRSQ); return *yytext; }
<TEXTDECL>.           { yylval->string = yytext; return CHARDATA; /* optimize? */}

<PIDECL>{ncname}      { yylval->string = strdup(yytext);
                            return NAME; /* rather be catch-all */
                          }
<PIDECL>[ \t]         { BEGIN(PIDECL2);}
<PIDECL>.             { yylval->string = yytext; return CHARDATA; /* optimize? */}
<PIDECL2>"?>"         { BEGIN(START);return EQMARK;}
<PIDECL2>[^{?>}]+     { yylval->string = strdup(yytext);  return STRING; }

<STRDQ>1\.[0-9]+      { yylval->string = strdup(yytext);  return STRING; }
<STRDQ>[^\"]+         { yylval->string = strdup(yytext); return STRING; }
<STRDQ>\"             { BEGIN(_XY->xy_lex_state); return *yytext; }

<STRSQ>1\.[0-9]+      { yylval->string = strdup(yytext); return STRING; }
<STRSQ>[^\']+         { yylval->string = strdup(yytext); return STRING; }
<STRSQ>\'             { BEGIN(_XY->xy_lex_state); return *yytext; }

%%

/*! Initialize XML scanner.
 */
int
clixon_xml_parsel_init(clixon_xml_yacc *xy)
{
    struct yyguts_t *yyg;   /* needed for BEGIN() in reentrant mode */

    if (clixon_xml_parselex_init(&xy->xy_scanner) != 0)
        return -1;
    yyg = (struct yyguts_t *)xy->xy_scanner;
    BEGIN(START);           /* set initial start condition */
    clixon_xml_parseset_extra(xy, xy->xy_scanner);
    xy->xy_lexbuf = yy_scan_string(xy->xy_parse_string, xy->xy_scanner);
    if ((xy->xy_cbuf = cbuf_new()) == NULL)
        return -1;
    return 0;
}

/*! Exit xml scanner */
int
clixon_xml_parsel_exit(clixon_xml_yacc *xy)
{
    yy_delete_buffer(xy->xy_lexbuf, xy->xy_scanner);
    clixon_xml_parselex_destroy(xy->xy_scanner);
    if (xy->xy_cbuf){
        cbuf_free(xy->xy_cbuf);
        xy->xy_cbuf = NULL;
    }
    return 0;
}
