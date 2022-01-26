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
 */

%start http_message

 /* Must be here to define YYSTYPE */
%union {
    char *string;
    int   intval;
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

%token <string> PCHARS
%token <string> QUERY
%token <string> TOKEN
%token <string> VCHAR
%token <intval> DIGIT

%type <string> absolute_paths
%type <string> absolute_path

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
 * Disable it to stop any calls to clicon_debug. Having it on by default would mean very large debug outputs.
 */
#if 0
#define _PARSE_DEBUG(s) clicon_debug(1,(s))
#define _PARSE_DEBUG1(s, s1) clicon_debug(1,(s), (s1))
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
	       _HY->hy_linenum ,
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

    if ((sd = restconf_stream_find(hy->hy_rc, 0)) == NULL)
	goto ok;
    if (uri_str2cvec(query, '&', '=', 1, &sd->sd_qvec) < 0)
	goto done;
 ok:
    retval = 0;
 done:
    return retval;
}

%} 

%%

/* start-line *( header-field CRLF ) CRLF [ message-body ] 
 * start-line     = request-line / status-line  (only request-line here, ignore status-line)
 */
http_message  :  request_line header_fields CRLF
                { _HY->hy_top=NULL; _PARSE_DEBUG("http-message -> request-line header-fields ACCEPT"); YYACCEPT; } 
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
		      _PARSE_DEBUG("method -> TOKEN");
		  }
;

/* request-target = origin-form / absolute-form / authority-form / asterisk-form *
 * origin-form = absolute-path [ "?" query ] */
request_target : absolute_paths
                 {
		      if (restconf_param_set(_HY->hy_h, "REQUEST_URI", $1) < 0)
			  YYABORT;
		     _PARSE_DEBUG("request-target -> absolute-paths");
		 }
	        | absolute_paths QMARK QUERY
		  {
		      if (restconf_param_set(_HY->hy_h, "REQUEST_URI", $1) < 0)
			  YYABORT;
		      if (http1_parse_query(_HY->hy_h, $3) < 0)
			  YYABORT;
		      _PARSE_DEBUG("request-target -> absolute-paths ? query");
		  }
;

/* query = <query, see [RFC3986], Section 3.4>
 *    query       = *( pchar / "/" / "?" )
 */
/*
query           : query query1  { _PARSE_DEBUG("query -> query1"); }
                |               { _PARSE_DEBUG("query -> "); }
                ;

query1          : PCHARS  { _PARSE_DEBUG("query1 -> PCHARS"); }
                | SLASH   { _PARSE_DEBUG("query1 -> /"); }
	        | QMARK   { _PARSE_DEBUG("query1 -> ?"); }
;
*/

/* absolute-path = 1*( "/" segment ) */
absolute_paths : absolute_paths absolute_path
                 {
		     if (($$ = clixon_string_del_join($1, "/", $2)) == NULL) YYABORT;
		     _PARSE_DEBUG("absolute-paths -> absolute-paths absolute -path");
		  }
               | absolute_path
	         {    $$ = strdup($1);
		     _PARSE_DEBUG("absolute-paths -> absolute -path");
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
                    { $$=$2; _PARSE_DEBUG("absolute-path -> PCHARS"); }
;

HTTP_version    : HTTP SLASH DIGIT DOT DIGIT
                                { _PARSE_DEBUG("HTTP-version -> HTTP / DIGIT . DIGIT"); }
;

/*------------------------------------------ hdr fields 
  *( header-field CRLF ) */
header_fields : header_fields header_field CRLF
                           { _PARSE_DEBUG("header-fields -> header-fields header-field CRLF"); }
              |            { _PARSE_DEBUG("header-fields -> "); }
;

/* header-field = field-name ":" OWS field-value OWS */
header_field  : field_name COLON ows field_values ows
                           { _PARSE_DEBUG("header-field -> field-name : field-values"); }
;

/* field-name = token */
field_name    : TOKEN      { _PARSE_DEBUG("field-name -> TOKEN"); }
;

/* field-value = *( field-content / obs-fold ) */
field_values   : field_values field_content
                           { _PARSE_DEBUG("field-values -> field-values field-content"); }
               |           { _PARSE_DEBUG("field-values -> "); }
;

/* field-content = field-vchar [ 1*( SP / HTAB ) field-vchar ] */
field_content  : field_vchars  { _PARSE_DEBUG("field-content -> field-vchars"); }
;

/* field-vchar = VCHAR / obs-text */
field_vchars   : field_vchars RWS VCHAR
                            { _PARSE_DEBUG("field-vchars -> field-vchars VCHAR"); }
               | VCHAR      { _PARSE_DEBUG("field-vchars -> VCHAR"); }
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

