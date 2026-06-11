/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
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
 * HTTP/1.1 parser according to RFC 7230
*
   The following core rules are included by reference, as defined in
   [RFC5234], Appendix B.1: ALPHA (letters), CR (carriage return), CRLF
   (CR LF), CTL (controls), DIGIT (decimal 0-9), DQUOTE (double quote),
   HEXDIG (hexadecimal 0-9/A-F/a-f), HTAB (horizontal tab), LF (line
   feed), OCTET (any 8-bit sequence of data), SP (space), and VCHAR (any
   visible [USASCII] character).
 */

%{

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <signal.h>
#include <openssl/ssl.h>

#ifdef HAVE_LIBNGHTTP2
#include <nghttp2/nghttp2.h>
#endif

#include "clixon_http1_parse.tab.h" /* generated */

#include <cligen/cligen.h>
#include <clixon/clixon.h>

#include "restconf_lib.h"
#include "restconf_native.h"
#include "clixon_http1_parse.h"
#include "banned.h"

/* typecast macro */
#define _HY ((clixon_http1_yacc *)yyget_extra(yyscanner))

%}

%option reentrant
%option bison-bridge
%option noyywrap
%option nounput
%option noinput
%option extra-type="clixon_http1_yacc *"


tchar   [!#$%&'*+\-\.^_`|~0-9A-Za-z]
token   {tchar}{tchar}*
pchar   [A-Za-z0-9\-\._~!$&'()*+,;=:@]|%[0-9a-fA-F][0-9a-fA-F]
query   [A-Za-z0-9\-\._~!$&'()*+,;=:@?/]|%[0-9a-fA-F][0-9a-fA-F]

%x REQLINE
%x REQTARG
%x REQUERY
%x REQHTTP
%x FLDNAME
%x FLDVALUE
%x BODYM

%%
<REQLINE,REQTARG,REQUERY,REQHTTP,FLDNAME,FLDVALUE><<EOF>> { return X_EOF; }
<REQLINE>[ ]       { BEGIN(REQTARG); return SP; }
<REQLINE>{token}   { yylval->string = strdup(yytext);
                     return TOKEN; }
<REQLINE>.         { clixon_http1_parseerror(_HY, yyscanner, "LEXICAL ERROR\n"); return -1; }

<REQTARG>\?        { BEGIN(REQUERY); return QMARK; }
<REQTARG>\/        { return SLASH; }
<REQTARG>[ ]       { BEGIN(REQHTTP); return SP; }
<REQTARG>{pchar}+  { yylval->string = yytext;
                     return PCHARS; }
<REQTARG>.         { clixon_http1_parseerror(_HY, yyscanner, "LEXICAL ERROR\n"); return -1; }

<REQUERY>\/        { return SLASH; }
<REQUERY>[ ]       { BEGIN(REQHTTP); return SP; }
<REQUERY>{query}+  { yylval->string = strdup(yytext);
                     return QUERY; }
<REQUERY>.         { clixon_http1_parseerror(_HY, yyscanner, "LEXICAL ERROR\n"); return -1; }

<REQHTTP>\r\n      { BEGIN(FLDNAME); return CRLF; _HY->hy_linenum++; }
<REQHTTP>\/        { return SLASH; }
<REQHTTP>\.        { return DOT; }
<REQHTTP>HTTP      { BEGIN(REQHTTP); return HTTP; }
<REQHTTP>[0-9]     { yylval->intval = atoi(yytext);
                     return DIGIT; }
<REQHTTP>.         { clixon_http1_parseerror(_HY, yyscanner, "LEXICAL ERROR\n"); return -1; }

<FLDNAME>:         { BEGIN(FLDVALUE); return COLON; }
<FLDNAME>\r\n      { BEGIN(BODYM); return CRLF; _HY->hy_linenum++; }
<FLDNAME>[ \t]+    { return RWS; }
<FLDNAME>{token}   { yylval->string = strdup(yytext);
                     return TOKEN; }
<FLDNAME>.         { clixon_http1_parseerror(_HY, yyscanner, "LEXICAL ERROR\n"); return -1; }

<FLDVALUE>\r\n     { BEGIN(FLDNAME); return CRLF; _HY->hy_linenum++; }
<FLDVALUE>[ \t]+   { return RWS; }
<FLDVALUE>[^ \t\n\r]+ { yylval->string = strdup(yytext);
                      return VCHARS; }
<FLDVALUE>.        { clixon_http1_parseerror(_HY, yyscanner, "LEXICAL ERROR\n"); return -1; }

<BODYM>.+          { yylval->string = strdup(yytext); /* note \n not . */
                     return BODY; }
<BODYM>\n          { yylval->string = strdup(yytext);
                     _HY->hy_linenum++;
                     return BODY; }
<BODYM><<EOF>>     { return X_EOF; }

%%

/*! Initialize scanner.
 */
int
http1_scan_init(clixon_http1_yacc *hy)
{
    struct yyguts_t *yyg;   /* needed for BEGIN() in reentrant mode */

    if (clixon_http1_parselex_init(&hy->hy_scanner) != 0)
        return -1;
    yyg = (struct yyguts_t *)hy->hy_scanner;
    BEGIN(REQLINE);
    clixon_http1_parseset_extra(hy, hy->hy_scanner);
    hy->hy_lexbuf = yy_scan_string(hy->hy_parse_string, hy->hy_scanner);
    return 0;
}

/*
 * free buffers
 * Even within Flex version 2.5 (this is assumed), freeing buffers is different.
 */
int
http1_scan_exit(clixon_http1_yacc *hy)
{
    yy_delete_buffer(hy->hy_lexbuf, hy->hy_scanner);
    clixon_http1_parselex_destroy(hy->hy_scanner);
    return 0;
}
