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

static int
text_add_value(cxobj *xn,
	       char   *value)
{
    int    retval = -1;
    cxobj *xb = NULL;

    if ((xb = xml_new("body", xn, CX_BODY)) == NULL)
	goto done;
    if (xml_value_set(xb,  value) < 0){
	xml_free(xb);
	goto done;
    }
    retval = 0;
 done:
    return retval;
}

static cxobj*
text_create_node(clixon_text_syntax_yacc *ts,
		 char                    *module,
		 char                    *name)
{
    cxobj     *xn;
    yang_stmt *ymod;
    char      *ns;

    if ((xn = xml_new(name, NULL, CX_ELMNT)) == NULL)
	goto done;
    if (module && ts->ts_yspec){
	/* Silently ignore if module name not found */
	if ((ymod = yang_find(ts->ts_yspec, Y_MODULE, NULL)) != NULL){
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
    return xn;
}
 
%} 
 
%%

top        : stmt MY_EOF       { _PARSE_DEBUG("top->stmt");
                                 if (xml_addsub(_TS->ts_xtop, $1) < 0) YYERROR;
                                 YYACCEPT; }
           ;

stmts      : stmts stmt        { _PARSE_DEBUG("stmts->stmts stmt");
                                 if (clixon_xvec_append($1, $2) < 0) YYERROR;
				 $$ = $1;
                               } 
           |                   { _PARSE_DEBUG("stmts->stmt");
                                 if (($$ = clixon_xvec_new()) == NULL) YYERROR;
                               }
           ;

stmt       : id value ';'      { _PARSE_DEBUG("stmt-> id value ;");
                                 if (text_add_value($1, $2) < 0) YYERROR;
				 $$ = $1;
                               }
           | id '{' stmts '}'  { _PARSE_DEBUG("stmt-> id { stmts }");
				 if (clixon_child_xvec_append($1, $3) < 0) YYERROR;
				 clixon_xvec_free($3);
				 $$ = $1;
 	                       }

           | id '[' values ']' { _PARSE_DEBUG("stmt-> id [ values ]"); }
           ;

id         : TOKEN             { _PARSE_DEBUG("id->TOKEN");
                                  if (($$ = text_create_node(_TS, NULL, $1)) == NULL) YYERROR;;
                               }
           | TOKEN ':' TOKEN   { _PARSE_DEBUG("id->TOKEN : TOKEN");
                                 if (($$ = text_create_node(_TS, $1, $3)) == NULL) YYERROR;;
	                       }
           ;

values     : values TOKEN      { _PARSE_DEBUG("values->values TOKEN"); } 
           |                   { _PARSE_DEBUG("values->"); } 
           ;

value      : TOKEN             { _PARSE_DEBUG("value->TOKEN"); $$ = $1; } 
           ;


%%

