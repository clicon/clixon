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

 * JSON Parser
 * From http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf

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
}

%token <string> J_FALSE
%token <string> J_TRUE
%token <string> J_NULL
%token <string> J_EOF
%token <string> J_DQ
%token <string> J_CHAR
%token <string> J_NUMBER

%type <string>    string
%type <string>    ustring
%type <string>    number

%lex-param     {void *_jy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_jy}

%{
/* Here starts user C-code */

/* typecast macro */
#define _JY ((struct clicon_json_yacc_arg *)_jy)

#define _YYERROR(msg) {clicon_debug(2, "YYERROR %s '%s' %d", (msg), clixon_json_parsetext, _JY->jy_linenum); YYERROR;}

/* add _yy to error paramaters */
#define YY_(msgid) msgid 

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if.h>

#include <cligen/cligen.h>
#include <clixon/clixon.h>

#include "clixon_json_parse.h"

extern int clixon_json_parseget_lineno  (void);

/* 
   also called from yacc generated code *
*/

void 
clixon_json_parseerror(void *_jy, char *s) 
{ 
    clicon_err(OE_XML, 0, "%s on line %d: %s at or before: '%s'", 
	       _JY->jy_name,
	       _JY->jy_linenum ,
	       s, 
	       clixon_json_parsetext); 
  return;
}

int
json_parse_init(struct clicon_json_yacc_arg *jy)
{
    //        clicon_debug_init(2, NULL);
    return 0;
}


int
json_parse_exit(struct clicon_json_yacc_arg *jy)
{
    return 0;
}

static int
json_current_new(struct clicon_json_yacc_arg *jy,
		 char                        *name)
{
    int retval = -1;
    cxobj *xn;

    clicon_debug(2, "%s", __FUNCTION__);
    if ((xn = xml_new(name, jy->jy_current)) == NULL)
	goto done; 
    jy->jy_current = xn;
    retval = 0;
 done:
    return retval;
}

static int
json_current_pop(struct clicon_json_yacc_arg *jy)
{
    if (jy->jy_current) 
	jy->jy_current = xml_parent(jy->jy_current);
    return 0;
}

static int
json_current_clone(struct clicon_json_yacc_arg *jy)
{
    cxobj *xn;

    assert(xn = jy->jy_current);
    json_current_pop(jy);
    if (jy->jy_current) 
	json_current_new(jy, xml_name(xn));
    return 0;
}

static int
json_current_body(struct clicon_json_yacc_arg *jy, 
		  char                        *value)
{
    int retval = -1;
    cxobj *xn;

    clicon_debug(2, "%s", __FUNCTION__);
    if ((xn = xml_new("body", jy->jy_current)) == NULL)
	goto done; 
    xml_type_set(xn, CX_BODY);
    if (value && xml_value_append(xn, value)==NULL)
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
json          : object J_EOF { clicon_debug(1,"json->object"); YYACCEPT; } 
              ;

value         : J_TRUE  { json_current_body(_JY, "true");}
              | J_FALSE { json_current_body(_JY, "false");}
              | J_NULL  { json_current_body(_JY, NULL);}
              | object
	      | array
              | number  { json_current_body(_JY, $1); free($1);}
              | string  { json_current_body(_JY, $1); free($1);}

              ;

object        : '{' '}' { clicon_debug(2,"object->{}");}
              | '{' objlist '}' { clicon_debug(2,"object->{ objlist }");}
              ;

objlist       : pair  { clicon_debug(2,"objlist->pair");}
              | objlist ',' pair { clicon_debug(2,"objlist->objlist , pair");}
              ;

pair          : string { json_current_new(_JY, $1);free($1);} ':' 
                value { json_current_pop(_JY);}{ clicon_debug(2,"pair->string : value");}
              ;

array         : '[' ']'
              | '[' valuelist ']'
              ;

valuelist     : value 
              | valuelist { json_current_clone(_JY);} ',' value 
              ;

/* quoted string */
string        : J_DQ ustring J_DQ {  clicon_debug(2,"string->\" ustring \"");$$=$2; }
              ;

/* unquoted string */
ustring       : ustring J_CHAR 
                     {
			 int len = strlen($1);
			 $$ = realloc($1, len+strlen($2) + 1); 
			 sprintf($$+len, "%s", $2); 
			 free($2);
		     }
              | J_CHAR 
	             {$$=$1;} 
              ;

number        : J_NUMBER { $$ = $1; }
              ;

%%

