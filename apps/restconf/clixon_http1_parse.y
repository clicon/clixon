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

 * HTTP/1.1 parser according to RFC 7230  Appendix B
 * XXX field_values   : field_values field_vchars : Only handle one field
 */

%start http_message

 /* Must be here to define YYSTYPE */
%union {
    char *string;
    int   intval;
    void *stack;
}

%token SP
%token CRLF
%token RWS
%token SLASH
%token QMARK
%token DOT
%token HTTP
%token COLON
%token X_EOF
%token ERROR

%token <string> PCHARS
%token <string> QUERY
%token <string> TOKEN
%token <string> VCHARS
%token <string> BODY
%token <intval> DIGIT

%type <string> body
%type <stack>  absolute_paths
%type <stack>  absolute_paths1
%type <string> absolute_path
%type <string> field_vchars
%type <string> field_values

%lex-param     {void *_hy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_hy}

%{
/* Here starts user C-code */

/* typecast macro */
#define _HY ((clixon_http1_yacc *)_hy)

#define _YYERROR(msg) {clicon_err(OE_XML, 0, "YYERROR %s '%s' %d", (msg), clixon_http1_parsetext, _HY->hy_linenum); YYERROR;}

/* add _yy to error parameters */
#define YY_(msgid) msgid

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

#include <cligen/cligen.h>
#include <clixon/clixon.h>

#include "restconf_lib.h"
#include "restconf_handle.h"
#include "restconf_native.h"
#include "clixon_http1_parse.h"

/* Best debugging is to enable PARSE_DEBUG below and add -d to the LEX compile statement in the Makefile
 * And then run the testcase with -D 1
 * Disable it to stop any calls to clixon_debug. Having it on by default would mean very large debug outputs.
 */
#if 0
#define _PARSE_DEBUG(s) clixon_debug(1,(s))
#define _PARSE_DEBUG1(s, s1) clixon_debug(1,(s), (s1))
#else
#define _PARSE_DEBUG(s)
#define _PARSE_DEBUG1(s, s1)
#endif

/*
   also called from yacc generated code *
*/

void
clixon_http1_parseerror(void *_hy,
                        char *s)
{
    clicon_err(OE_RESTCONF, 0, "%s on line %d: %s at or before: '%s'",
               _HY->hy_name,
               _HY->hy_linenum,
               s,
               clixon_http1_parsetext);
  return;
}

int
http1_parse_init(clixon_http1_yacc *hy)
{
    return 0;
}

int
http1_parse_exit(clixon_http1_yacc *hy)
{
    return 0;
}

static int
http1_parse_query(clixon_http1_yacc *hy,
                  char              *query)
{
    int                   retval = -1;
    restconf_stream_data *sd = NULL;

    clixon_debug(CLIXON_DBG_DEFAULT, "%s: ?%s ", __FUNCTION__, query);
    if ((sd = restconf_stream_find(hy->hy_rc, 0)) == NULL){
        clicon_err(OE_RESTCONF, 0, "stream 0 not found");
        goto done;
    }
    if (uri_str2cvec(query, '&', '=', 1, &sd->sd_qvec) < 0)
        goto done;
    retval = 0;
 done:
    return retval;
}

static int
http1_body(clixon_http1_yacc *hy,
           char              *body)
{
    int                   retval = -1;
    restconf_stream_data *sd = NULL;

    clixon_debug(CLIXON_DBG_DEFAULT, "%s: %s ", __FUNCTION__, body);
    if ((sd = restconf_stream_find(hy->hy_rc, 0)) == NULL){
        clicon_err(OE_RESTCONF, 0, "stream 0 not found");
        goto done;
    }
    if (cbuf_append_buf(sd->sd_indata, body, strlen(body)) < 0){
        clicon_err(OE_RESTCONF, errno, "cbuf_append_buf");
        goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*!
 */
static int
http1_parse_header_field(clixon_http1_yacc *hy,
                         char              *name,
                         char              *field)
{
    int retval = -1;

    if (restconf_convert_hdr(hy->hy_h, name, field) < 0)
        goto done;
    retval = 0;
 done:
    return retval;
}

%}

%%

/* start-line *( header-field CRLF ) CRLF [ message-body ]
 * start-line     = request-line / status-line  (only request-line here, ignore status-line)
 */
http_message  :  request_line header_fields CRLF body X_EOF
                   {
                       if ($4) {
                           if (http1_body(_HY, $4) < 0) YYABORT;
                           free($4);
                       }
                       _PARSE_DEBUG("http-message -> request-line header-fields body");
                       YYACCEPT;
                   }
;

body          : body BODY
                 {
                     if (($$ = clixon_string_del_join($1, "", $2)) == NULL) {
                         free($2);
                         YYABORT;
                     }
                     else
                         free($2);
                     _PARSE_DEBUG("body -> body BODY");
                 }
              | ERROR   { _PARSE_DEBUG("body -> ERROR"); YYABORT; /* shouldnt happen */ }
              |         { _PARSE_DEBUG("body -> "); $$ = NULL; }
;

/* request-line = method SP request-target SP HTTP-version CRLF */
request_line  : method SP request_target SP HTTP_version CRLF
               {
                   _PARSE_DEBUG("request-line -> method request-target HTTP_version CRLF");
               }
;

/*
The request methods defined by this specification can be found in
   Section 4 of [RFC7231], along with information regarding the HTTP
  http://www.iana.org/assignments/http-methods/http-methods.xhtml
*/
method        : TOKEN
                  {
                      if (restconf_param_set(_HY->hy_h, "REQUEST_METHOD", $1) < 0)
                          YYABORT;
                      free($1);
                      _PARSE_DEBUG("method -> TOKEN");
                  }
;

/* request-target = origin-form / absolute-form / authority-form / asterisk-form *
 * origin-form = absolute-path [ "?" query ] 
 * query = <query, see [RFC3986], Section 3.4>
 * query       = *( pchar / "/" / "?" )
 */
request_target : absolute_paths1
                 {
                     if (restconf_param_set(_HY->hy_h, "REQUEST_URI", cbuf_get($1)) < 0)
                          YYABORT;
                      cbuf_free($1);
                     _PARSE_DEBUG("request-target -> absolute-paths1");
                 }
                | absolute_paths1 QMARK QUERY
                  {
                      if (restconf_param_set(_HY->hy_h, "REQUEST_URI", cbuf_get($1)) < 0)
                          YYABORT;
                      cbuf_free($1);
                      if (http1_parse_query(_HY, $3) < 0)
                          YYABORT;
                      free($3);
                      _PARSE_DEBUG("request-target -> absolute-paths1 ? query");
                  }
;

/* absolute-paths1 = absolute-paths ["/"] 
 * Not according to standards: trailing /
 */
absolute_paths1 : absolute_paths
                      { $$ = $1;_PARSE_DEBUG("absolute-paths1 -> absolute-paths "); }
                | absolute_paths SLASH
                      { $$ = $1;_PARSE_DEBUG("absolute-paths1 -> absolute-paths / "); }
;

/* absolute-path = 1*( "/" segment ) 
*/
absolute_paths : absolute_paths absolute_path
                 {
                     $$ = $1;
                     cprintf($$, "/");
                     if ($2)
                         cprintf($$, "%s", $2);
                     _PARSE_DEBUG("absolute-paths -> absolute-paths absolute-path");
                  }
               | absolute_path
                 {
                     if (($$ = cbuf_new()) == NULL){ YYABORT;}
                     cprintf($$, "/");
                     if ($1)
                         cprintf($$, "%s", $1);
                     _PARSE_DEBUG("absolute-paths -> absolute-path");
                 }
;
/* segment = <segment, see [RFC3986], Section 3.3> 
 * segment = *pchar
 * pchar   = unreserved / pct-encoded / sub-delims / ":" / "@"
 * unreserved  = ALPHA / DIGIT / "-" / "." / }"_" / "~"
 * pct-encoded = "%" HEXDIG HEXDIG
 * sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
 *                / "*" / "+" / "," / ";" / "="
 */
absolute_path   : SLASH PCHARS
                   {
                       $$ = $2;
                       _PARSE_DEBUG("absolute-path -> / PCHARS");
                   }
                   | SLASH
                   {
                       $$ = NULL;
                       _PARSE_DEBUG("absolute-path -> /");
                   }
;

/* HTTP-version = HTTP-name "/" DIGIT "." DIGIT */
HTTP_version    : HTTP SLASH DIGIT DOT DIGIT
                   {
                       /* make sanity check later */
                       _HY->hy_rc->rc_proto_d1 = $3;
                       _HY->hy_rc->rc_proto_d2 = $5;
                       clixon_debug(CLIXON_DBG_DEFAULT, "clixon_http1_parse: http/%d.%d", $3, $5);
                       _PARSE_DEBUG("HTTP-version -> HTTP / DIGIT . DIGIT");
                   }
;

/*------------------------------------------ hdr fields 
  *( header-field CRLF ) */
header_fields : header_fields header_field CRLF
                           { _PARSE_DEBUG("header-fields -> header-fields header-field CRLF"); }
              |            { _PARSE_DEBUG("header-fields -> "); }
;

/* header-field = field-name ":" OWS field-value OWS 
   field-name = token */
header_field  : TOKEN COLON ows field_values ows
                 {
                     if ($4){
                         if (http1_parse_header_field(_HY, $1, $4) < 0)
                             YYABORT;
                         free($4);
                     }
                     free($1);
                     _PARSE_DEBUG("header-field -> field-name : field-values");
                 }
;

/* field-value = *( field-content / obs-fold ) 
   field-content = field-vchar [ 1*( SP / HTAB ) field-vchar ] 
   field-vchar = VCHAR / obs-text */
field_values   : field_vchars
                           {
                               $$ = $1; // XXX is there more than one??
                               _PARSE_DEBUG("field-values -> field-values field-vchars");
                           }
               |           { $$ = NULL; _PARSE_DEBUG("field-values -> "); }
;


field_vchars   : field_vchars RWS VCHARS
                     {
                         if (($$ = clixon_string_del_join($1, " ", $3)) == NULL) YYABORT;
                         free($3);
                         _PARSE_DEBUG("field-vchars -> field-vchars VCHARS");
                     }
               | VCHARS
                     {
                         $$ = $1;
                         _PARSE_DEBUG("field-vchars -> VCHARS");
                     }
;

/* The OWS rule is used where zero or more linear whitespace octets 
     OWS            = *( SP / HTAB )
                    ; optional whitespace
     RWS            = 1*( SP / HTAB )
                    ; required whitespace
 */
ows          : RWS
             |
;

%%

