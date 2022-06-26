/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * TEXT / curly-brace syntax parsing and translations
 */
%union {
  char *string;
  void *stack;
}

%token MY_EOF
%token <string> TOKEN

%type <stack>  stmts
%type <stack>  stmt
%type <stack>  id
%type <string> value
%type <stack>  values
%type <string> substr

%start top

%lex-param     {void *_ts} /* Add this argument to parse() and lex() function */
%parse-param   {void *_ts}

%{

/* typecast macro */
#define _TS ((clixon_text_syntax_yacc *)_ts)

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdlib.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_string.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_xml_vec.h"
#include "clixon_data.h"
#include "clixon_text_syntax_parse.h"

/* Enable for debugging, steals some cycles otherwise */
#if 0
#define _PARSE_DEBUG(s) clicon_debug(1,(s))
#else
#define _PARSE_DEBUG(s)
#endif
    
void 
clixon_text_syntax_parseerror(void *arg,
			      char *s) 
{
    clixon_text_syntax_yacc *ts = (clixon_text_syntax_yacc *)arg;

    clicon_err(OE_XML, XMLPARSE_ERRNO, "text_syntax_parse: line %d: %s: at or before: %s", 
	       ts->ts_linenum,
	       s,
	       clixon_text_syntax_parsetext); 
    return;
}

static cxobj*
text_add_value(cxobj *xn,
	       char  *value)
{
    cxobj *xb = NULL;

    if ((xb = xml_new("body", xn, CX_BODY)) == NULL)
	goto done;
    if (xml_value_set(xb,  value) < 0){
	xml_free(xb);
	xb = NULL;
	goto done;
    }
 done:
    return xb;
}

/*! Create XML node prefix:id
 */
static cxobj*
text_create_node(clixon_text_syntax_yacc *ts,
		 char                    *name)
{
    cxobj     *xn = NULL;
    yang_stmt *ymod;
    char      *ns;
    char      *prefix = NULL;
    char      *id = NULL;

    if (nodeid_split(name, &prefix, &id) < 0)
	goto done;
    if ((xn = xml_new(id, NULL, CX_ELMNT)) == NULL)
	goto done;
    if (prefix && ts->ts_yspec){
	/* Silently ignore if module name not found */
	if ((ymod = yang_find(ts->ts_yspec, Y_MODULE, prefix)) != NULL){
	    if ((ns = yang_find_mynamespace(ymod)) == NULL){
		clicon_err(OE_YANG, 0, "No namespace");
		goto done;
	    }
	    /* Set default namespace */
	    if (xmlns_set(xn, NULL, ns) < 0)
		goto done;
	}
    }
 done:
    if (prefix)
	free(prefix);
    if (id)
	free(id);
    return xn;
}

static char*
strjoin(char *str0,
        char *str1)
{
    size_t len0;
    size_t len;

    len0 = str0?strlen(str0):0;
    len = len0 + strlen(str1) + 1;
    if ((str0 = realloc(str0, len)) == NULL){
	clicon_err(OE_YANG, errno, "realloc");
	return NULL;
    }
    strcpy(str0+len0, str1);
    return str0;
}

/*! Given a vector of XML bodies, transform it to a vector of ELEMENT entries copied from x1
 */
static int
text_element_create(clixon_xvec *xvec0,
		     cxobj       *x1,
		     clixon_xvec *xvec1)
{
    int    retval = -1;
    cxobj *xb;
    cxobj *x2;
    int    i;

    for (i=0; i<clixon_xvec_len(xvec1); i++){
	xb = clixon_xvec_i(xvec1, i);
	if ((x2 = xml_dup(x1)) == NULL)
	    goto done;
	if (xml_addsub(x2, xb) < 0)
	    goto done;
	if (clixon_xvec_append(xvec0, x2) < 0)
	    goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Special mechanism to mark bodies so they will not be filtered as whitespace
 * @see strip_body_objects text_populate_list
 */
static int
text_mark_bodies(clixon_xvec *xv)
{
    int    i;
    cxobj *xb;
    
    for (i=0; i<clixon_xvec_len(xv); i++){
	xb = clixon_xvec_i(xv, i);
	xml_flag_set(xb, XML_FLAG_BODYKEY);
    }
    return 0;
}
 
%} 
 
%%

top        : stmt MY_EOF       { _PARSE_DEBUG("top->stmt");
				 if (clixon_child_xvec_append(_TS->ts_xtop, $1) < 0) YYERROR;
				 clixon_xvec_free($1);
                                 YYACCEPT; }
           ;

stmts      : stmts stmt        { _PARSE_DEBUG("stmts->stmts stmt");
                                 if (clixon_xvec_merge($1, $2) < 0) YYERROR;
				 clixon_xvec_free($2);
				 $$ = $1;
                               } 
           |                   { _PARSE_DEBUG("stmts->stmt");
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
                               }
           ;

stmt       : id values ';'     { _PARSE_DEBUG("stmt-> id value ;");
                                 text_mark_bodies($2);
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
				 if (text_element_create($$, $1, $2) < 0) YYERROR;
				 xml_free($1);
				 clixon_xvec_free($2);
                               }
           | id values '{' stmts '}'  { _PARSE_DEBUG("stmt-> id values { stmts }");
                                 text_mark_bodies($2);
     				 if (clixon_child_xvec_append($1, $2) < 0) YYERROR;
				 clixon_xvec_free($2);
     				 if (clixon_child_xvec_append($1, $4) < 0) YYERROR;
				 clixon_xvec_free($4);
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
				 if (clixon_xvec_append($$, $1) < 0) YYERROR;
	                       }
           | id '[' values ']'
		               { _PARSE_DEBUG("stmt-> id [ values ]");
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
				 if (text_element_create($$, $1, $3) < 0) YYERROR;
				 xml_free($1);
				 clixon_xvec_free($3);
	                       }
           ;

id         : TOKEN             { _PARSE_DEBUG("id->TOKEN");
                                 if (($$ = text_create_node(_TS, $1)) == NULL) YYERROR;
				 free($1);
                               }
           ;

/* Array of body objects, possibly empty */
values     : values value      { _PARSE_DEBUG("values->values value");
                                 cxobj* x;
				 if ((x = text_add_value(NULL, $2)) == NULL) YYERROR;;
				 free($2);
                                 if (clixon_xvec_append($1, x) < 0) YYERROR;
				 $$ = $1;
                               }
           |                   { _PARSE_DEBUG("values->value");
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
	                       }
	   ;

/* Returns single string either as a single token or contained by double quotes  */
value      : TOKEN             { _PARSE_DEBUG("value->TOKEN");
                                 $$=$1;
                               }
           | '"' substr '"'  { _PARSE_DEBUG("value-> \" substr \"");
                                 $$=$2;
	                       }
           ;

/* Value within quotes merged to single string, has separate lexical scope  */
substr     : substr TOKEN      { _PARSE_DEBUG("substr->substr TOKEN");
                                 $$ = strjoin($1, $2); free($2);}
           |                   { _PARSE_DEBUG("substr->");
                                 $$ = NULL; } 
           ;

%%

