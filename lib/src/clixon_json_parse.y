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

 * JSON Parser
 * From http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
 * And RFC7951 JSON Encoding of Data Modeled with YANG

Structural tokens: 
 [   left square bracket 
 {   left curly bracket 
 ]   right square bracket 
 }   right curly bracket 
 :   colon 
 ,   comma  

Literal name tokens: 
 true
 false
 null

A JSON value is an object, array, number, string, true, false, or null

value    ::= object  |
             array   |
	     number  |
	     string  |
	     'true'  |
	     'false' |
	     'null'  ;

object   ::= '{' [objlist] '}';
objlist  ::= pair [',' objlist];
pair     ::= string ':' value;

array    ::= '[' [vallist] ']';
vallist  ::= value [',' vallist];

XML translation:
<a>34</a>  <--> { "a": "34" }
Easiest if top-object is single xml-tree <--> single object
JSON lists are more difficult to translate since they inbtroduce a top
object.

 */

%start json

%union {
    int intval;
    char *string;
    void *cbuf;
}

%token <string> J_FALSE
%token <string> J_TRUE
%token <string> J_NULL
%token <string> J_EOF
%token <string> J_DQ
%token <string> J_CHAR
%token <string> J_NUMBER

%type <cbuf>      string
%type <cbuf>      ustring
%type <string>    number

%lex-param     {void *_jy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_jy}

%{
/* Here starts user C-code */

/* typecast macro */
#define _JY ((clixon_json_yacc *)_jy)

#define _YYERROR(msg) {clicon_err(OE_JSON, 0, "YYERROR %s '%s' %d", (msg), clixon_json_parsetext, _JY->jy_linenum); YYERROR;}

/* add _yy to error parameters */
#define YY_(msgid) msgid 

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if.h>

#include <cligen/cligen.h>

#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_string.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"

#include "clixon_json_parse.h"

/* Enable for debugging, steals some cycles otherwise */
#if 0
#define _PARSE_DEBUG(s) clicon_debug(1,(s))
#else
#define _PARSE_DEBUG(s)
#endif

extern int clixon_json_parseget_lineno  (void);

/* 
   also called from yacc generated code *
*/

void 
clixon_json_parseerror(void *_jy,
		       char *s) 
{ 
    clicon_err(OE_JSON, XMLPARSE_ERRNO, "json_parse: line %d: %s at or before: '%s'", 
	       _JY->jy_linenum ,
	       s, 
	       clixon_json_parsetext); 
  return;
}

int
json_parse_init(clixon_json_yacc *jy)
{
    //        clicon_debug_init(2, NULL);
    return 0;
}

int
json_parse_exit(clixon_json_yacc *jy)
{
    return 0;
}
 
/*! Create xml object from json object name (eg "string") 
 *  Split name into prefix:name (extended JSON RFC7951)
 */
static int
json_current_new(clixon_json_yacc *jy,
		 char             *name)
{
    int        retval = -1;
    cxobj     *x;
    char      *prefix = NULL;
    char      *id = NULL;

    clicon_debug(2, "%s", __FUNCTION__);
    /* Find colon separator and if found split into prefix:name */
    if (nodeid_split(name, &prefix, &id) < 0)
	goto done;
    if ((x = xml_new(id, jy->jy_current, CX_ELMNT)) == NULL)
	goto done;
    if (xml_prefix_set(x, prefix) < 0)
	goto done;

    /* If topmost, add to top-list created list */
    if (jy->jy_current == jy->jy_xtop){
	if (cxvec_append(x, &jy->jy_xvec, &jy->jy_xlen) < 0)
	    goto done;
    }
    jy->jy_current = x;
    retval = 0;
 done:
    if (prefix)
	free(prefix);
    if (id)
	free(id);
    return retval;
}

static int
json_current_pop(clixon_json_yacc *jy)
{
    clicon_debug(2, "%s", __FUNCTION__);
    if (jy->jy_current) 
	jy->jy_current = xml_parent(jy->jy_current);
    return 0;
}

static int
json_current_clone(clixon_json_yacc *jy)
{
    cxobj *xn;

    clicon_debug(2, "%s", __FUNCTION__);
    if (jy->jy_current == NULL){
        return -1;
    }
    xn = jy->jy_current;
    json_current_pop(jy);

    if (jy->jy_current) {
        char* name = xml_name(xn);
        char* prefix = xml_prefix(xn);
        char* maybe_prefixed_name = NULL;

        if (prefix) {
            char* name_parts[] = {prefix, name};
            maybe_prefixed_name = clicon_strjoin(2, name_parts, ":");
        } else {
            maybe_prefixed_name = strdup(name);
        }
        json_current_new(jy, maybe_prefixed_name);
        
        if (maybe_prefixed_name)
            free(maybe_prefixed_name);
    }
    return 0;
}

static int
json_current_body(clixon_json_yacc *jy, 
		  char             *value)
{
    int retval = -1;
    cxobj *xn;

    clicon_debug(2, "%s", __FUNCTION__);
    if ((xn = xml_new("body", jy->jy_current, CX_BODY)) == NULL)
	goto done; 
    if (value && xml_value_append(xn, value) < 0)
	goto done; 
    retval = 0;
 done:
    return retval;
 }

%} 
 
%%

/*
*/

 /* top: json -> value is also possible */
json          : value J_EOF { _PARSE_DEBUG("json->value"); YYACCEPT; } 
              ;

value         : J_TRUE  { json_current_body(_JY, "true");       _PARSE_DEBUG("value->TRUE");}
              | J_FALSE { json_current_body(_JY, "false");      _PARSE_DEBUG("value->FALSE");}
              | J_NULL  { json_current_body(_JY, NULL);         _PARSE_DEBUG("value->NULL");}
              | object                                        { _PARSE_DEBUG("value->object"); }
	      | array                                         { _PARSE_DEBUG("value->array"); }
              | number  { json_current_body(_JY, $1); free($1); _PARSE_DEBUG("value->number");}
              | string  { json_current_body(_JY, cbuf_get($1)); cbuf_free($1); _PARSE_DEBUG("value->string");}

              ;

object        : '{' '}'         { _PARSE_DEBUG("object->{}"); _PARSE_DEBUG("object->{}");}
              | '{' objlist '}' { _PARSE_DEBUG("object->{ objlist }"); _PARSE_DEBUG("object->{ objlist }");}
              ;

objlist       : pair             { _PARSE_DEBUG("objlist->pair");}
              | objlist ',' pair { _PARSE_DEBUG("objlist->objlist , pair");}
              ;

pair          : string { json_current_new(_JY, cbuf_get($1));cbuf_free($1);} ':' 
                value  { json_current_pop(_JY);}{ _PARSE_DEBUG("pair->string : value");}
              ;

array         : '[' ']'           { _PARSE_DEBUG("array->[]"); }
              | '[' valuelist ']' { _PARSE_DEBUG("array->[ valuelist ]"); }
              ;

valuelist     : value             { _PARSE_DEBUG("valuelist->value"); }
              | valuelist         { if (json_current_clone(_JY)< 0) _YYERROR("stack?");}
                ',' value         { _PARSE_DEBUG("valuelist->valuelist , value");}
              ;

/* quoted string */
string        : J_DQ ustring J_DQ { _PARSE_DEBUG("string->\" ustring \"");$$=$2; }
              | J_DQ J_DQ         { _PARSE_DEBUG("string->\" \"");$$=cbuf_new(); }
              ;

/* unquoted string: can be optimized by reading whole string in lex */
ustring       : ustring J_CHAR 
                     {
			 cbuf_append_str($1,$2); $$=$1; free($2);
		     }
              | J_CHAR 
	      { cbuf *cb = cbuf_new(); cbuf_append_str(cb,$1); $$=cb; free($1);} 
              ;

number        : J_NUMBER { $$ = $1; }
              ;

%%

