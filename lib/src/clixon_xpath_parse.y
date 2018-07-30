/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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

 * XPATH Parser
 * From    https://www.w3.org/TR/xpath-10/
 * The primary syntactic construct in XPath is the expression. 
 * An expression matches  the production Expr 
 *    see https://www.w3.org/TR/xpath-10/#NT-Expr)
 * Lexical structure is defined by ExprToken, see
 *    see https://www.w3.org/TR/xpath-10/#exprlex
 */

%start start

%union {
    int       intval;
    double    dval;
    char     *string;
    void     *stack; /* xpath_tree */
}

%token <intval> AXISNAME
%token <intval> LOGOP
%token <intval> ADDOP
%token <intval> RELOP

%token <dval> NUMBER

%token <string> X_EOF
%token <string> QUOTE
%token <string> APOST
%token <string> CHAR
%token <string> NAME
%token <string> NODETYPE
%token <string> DOUBLEDOT
%token <string> DOUBLECOLON
%token <string> DOUBLESLASH
%token <string> FUNCTIONNAME

%type <intval>    axisspec

%type <string>    string
%type <stack>     expr
%type <stack>     andexpr
%type <stack>     relexpr
%type <stack>     addexpr
%type <stack>     unionexpr
%type <stack>     pathexpr
%type <stack>     locationpath
%type <stack>     abslocpath
%type <stack>     rellocpath
%type <stack>     step
%type <stack>     nodetest
%type <stack>     predicates
%type <stack>     primaryexpr

%lex-param     {void *_xy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_xy}

%{
/* Here starts user C-code */

/* typecast macro */
#define _XY ((struct clicon_xpath_yacc_arg *)_xy)

#define _YYERROR(msg) {clicon_err(OE_XML, 0, "YYERROR %s '%s' %d", (msg), clixon_xpath_parsetext, _XY->xy_linenum); YYERROR;}

/* add _yy to error paramaters */
#define YY_(msgid) msgid 

#include "clixon_config.h"

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <fnmatch.h>
#include <assert.h>
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
#include "clixon_xpath_ctx.h"
#include "clixon_xpath.h"

#include "clixon_xpath_parse.h"

extern int clixon_xpath_parseget_lineno  (void);

/* 
   also called from yacc generated code *
*/

void 
clixon_xpath_parseerror(void *_xy,
		       char *s) 
{ 
    clicon_err(OE_XML, 0, "%s on line %d: %s at or before: '%s'", 
	       _XY->xy_name,
	       _XY->xy_linenum ,
	       s, 
	       clixon_xpath_parsetext); 
  return;
}

int
xpath_parse_init(struct clicon_xpath_yacc_arg *xy)
{
    //        clicon_debug_init(2, NULL);
    return 0;
}

int
xpath_parse_exit(struct clicon_xpath_yacc_arg *xy)
{
    return 0;
}

static xpath_tree *
xp_new(enum xp_type  type,
       int           i0,
       double        d0,
       char         *s0,
       char         *s1,
       xpath_tree     *c0,
       xpath_tree     *c1)
{
    xpath_tree     *xs = NULL;
    
    if ((xs = malloc(sizeof(xpath_tree))) == NULL){
	clicon_err(OE_XML, errno, "malloc");
	goto done;
    }
    memset(xs, 0, sizeof(*xs));
    xs->xs_type = type;
    xs->xs_int  = i0;
    xs->xs_double  = d0;
    xs->xs_s0  = s0;
    xs->xs_s1  = s1;
    xs->xs_c0  = c0;
    xs->xs_c1  = c1;
 done:
    return xs;
}

%} 
 
%%

/*
*/

start       : expr X_EOF         { _XY->xy_top=$1;clicon_debug(2,"start->expr"); YYACCEPT; } 
            | locationpath X_EOF { _XY->xy_top=$1;clicon_debug(2,"start->locationpath"); YYACCEPT; } 
            ;

expr        : expr LOGOP andexpr { $$=xp_new(XP_EXP,$2,0.0,NULL,NULL,$1, $3);clicon_debug(2,"expr->expr or andexpr");  } 
            | andexpr { $$=xp_new(XP_EXP,A_NAN,0.0,NULL,NULL,$1, NULL);clicon_debug(2,"expr-> andexpr"); } 
            ;

andexpr     : andexpr LOGOP relexpr { $$=xp_new(XP_AND,$2,0.0,NULL,NULL,$1, $3);clicon_debug(2,"andexpr-> andexpr and relexpr"); } 
            | relexpr { $$=xp_new(XP_AND,A_NAN,0.0,NULL,NULL,$1, NULL);clicon_debug(2,"andexpr-> relexpr"); } 
            ;

relexpr     : relexpr RELOP addexpr { $$=xp_new(XP_RELEX,$2,0.0,NULL,NULL,$1, $3);clicon_debug(2,"relexpr-> relexpr relop addexpr"); } 
            | addexpr { $$=xp_new(XP_RELEX,A_NAN,0.0,NULL,NULL,$1, NULL);clicon_debug(2,"relexpr-> addexpr"); } 
            ;

addexpr     : addexpr ADDOP unionexpr { $$=xp_new(XP_ADD,$2,0.0,NULL,NULL,$1, $3);clicon_debug(2,"addexpr-> addexpr ADDOP unionexpr"); } 
            | unionexpr { $$=xp_new(XP_ADD,A_NAN,0.0,NULL,NULL,$1, NULL);clicon_debug(2,"addexpr-> unionexpr"); } 
            ;

/* node-set */
unionexpr   : unionexpr '|' pathexpr { $$=xp_new(XP_UNION,A_NAN,0.0,NULL,NULL,$1, $3);clicon_debug(2,"unionexpr-> unionexpr | pathexpr"); } 
            | pathexpr { $$=xp_new(XP_UNION,A_NAN,0.0,NULL,NULL,$1, NULL);clicon_debug(2,"unionexpr-> pathexpr"); } 
            ;

pathexpr    : locationpath { $$=xp_new(XP_PATHEXPR,A_NAN,0.0,NULL,NULL,$1, NULL);clicon_debug(2,"pathexpr-> locationpath"); } 
            | primaryexpr { $$=xp_new(XP_PATHEXPR,A_NAN,0.0,NULL,NULL,$1, NULL);clicon_debug(2,"pathexpr-> primaryexpr"); } 
            ;

/* location path returns a node-set  */
locationpath : rellocpath { $$=xp_new(XP_LOCPATH,A_NAN,0.0,NULL,NULL,$1, NULL); clicon_debug(2,"locationpath-> rellocpath"); } 
            | abslocpath  { $$=xp_new(XP_LOCPATH,A_NAN,0.0,NULL,NULL,$1, NULL); clicon_debug(2,"locationpath-> abslocpath"); } 
            ;

abslocpath  : '/'            { $$=xp_new(XP_ABSPATH,A_ROOT,0.0,NULL,NULL,NULL, NULL);clicon_debug(2,"abslocpath-> /"); }
            | '/' rellocpath { $$=xp_new(XP_ABSPATH,A_ROOT,0.0,NULL,NULL,$2, NULL);clicon_debug(2,"abslocpath->/ rellocpath");}
            /* // is short for /descendant-or-self::node()/ */
            | DOUBLESLASH rellocpath  {$$=xp_new(XP_ABSPATH,A_DESCENDANT_OR_SELF,0.0,NULL,NULL,$2, NULL); clicon_debug(2,"abslocpath-> // rellocpath"); } 
            ;

rellocpath  : step                 { $$=xp_new(XP_RELLOCPATH,A_NAN,0.0,NULL,NULL,$1, NULL); clicon_debug(2,"rellocpath-> step"); } 
            | rellocpath '/' step  { $$=xp_new(XP_RELLOCPATH,A_NAN,0.0,NULL,NULL,$1, $3);clicon_debug(2,"rellocpath-> rellocpath / step"); } 
            | rellocpath DOUBLESLASH step { $$=xp_new(XP_RELLOCPATH,A_DESCENDANT_OR_SELF,0.0,NULL,NULL,$1, $3); clicon_debug(2,"rellocpath-> rellocpath // step"); } 
            ;

step        : axisspec nodetest predicates {$$=xp_new(XP_STEP,$1,0.0, NULL, NULL, $2, $3);clicon_debug(2,"step->axisspec(%d) nodetest", $1); }
            | '.' predicates              { $$=xp_new(XP_STEP,A_SELF, 0.0,NULL, NULL, NULL, $2); clicon_debug(2,"step-> ."); } 
            | DOUBLEDOT predicates        { $$=xp_new(XP_STEP, A_PARENT, 0.0,NULL, NULL, NULL, $2); clicon_debug(2,"step-> .."); } 
            ;

axisspec    : AXISNAME DOUBLECOLON { clicon_debug(2,"axisspec-> AXISNAME(%d) ::", $1); $$=$1;}
            | '@'      { $$=A_ATTRIBUTE; clicon_debug(2,"axisspec-> @"); } 
            |          { clicon_debug(2,"axisspec-> "); $$=A_CHILD;} 
            ;

nodetest    : '*'              { $$=xp_new(XP_NODE,A_NAN,0.0, NULL, NULL, NULL, NULL); clicon_debug(2,"nodetest-> *"); } 
            | NAME             { $$=xp_new(XP_NODE,A_NAN,0.0, NULL, $1, NULL, NULL); clicon_debug(2,"nodetest-> name(%s)",$1); } 
            | NAME ':' NAME    { $$=xp_new(XP_NODE,A_NAN,0.0, $1, $3, NULL, NULL);clicon_debug(2,"nodetest-> name(%s) : name(%s)", $1, $3); } 
            | NAME ':' '*'     { $$=xp_new(XP_NODE,A_NAN,0.0, $1, NULL, NULL, NULL);clicon_debug(2,"nodetest-> name(%s) : *", $1); } 
            | NODETYPE '(' ')' { $$=xp_new(XP_NODE_FN,A_NAN,0.0, $1, NULL, NULL, NULL); clicon_debug(2,"nodetest-> nodetype()"); } 
            ;

/* evaluates to boolean */
predicates  : predicates '[' expr ']' { $$=xp_new(XP_PRED,A_NAN,0.0, NULL, NULL, $1, $3); clicon_debug(2,"predicates-> [ expr ]"); } 
            |                         { $$=xp_new(XP_PRED,A_NAN,0.0, NULL, NULL, NULL, NULL); clicon_debug(2,"predicates->"); } 
            ;

primaryexpr : '(' expr ')'         { $$=xp_new(XP_PRI0,A_NAN,0.0, NULL, NULL, $2, NULL); clicon_debug(2,"primaryexpr-> ( expr )"); } 
            | NUMBER               { $$=xp_new(XP_PRIME_NR,A_NAN, $1, NULL, NULL, NULL, NULL);clicon_debug(2,"primaryexpr-> NUMBER(%lf)", $1); } 
            | QUOTE string QUOTE   { $$=xp_new(XP_PRIME_STR,A_NAN,0.0, $2, NULL, NULL, NULL);clicon_debug(2,"primaryexpr-> \" string \""); }
            | QUOTE QUOTE          { $$=xp_new(XP_PRIME_STR,A_NAN,0.0, NULL, NULL, NULL, NULL);clicon_debug(2,"primaryexpr-> \" \""); } 
            | APOST string APOST   { $$=xp_new(XP_PRIME_STR,A_NAN,0.0, $2, NULL, NULL, NULL);clicon_debug(2,"primaryexpr-> ' string '"); }
            | APOST APOST          { $$=xp_new(XP_PRIME_STR,A_NAN,0.0, NULL, NULL, NULL, NULL);clicon_debug(2,"primaryexpr-> ' '"); } 
            | FUNCTIONNAME '(' ')' { $$=xp_new(XP_PRIME_FN,A_NAN,0.0, $1, NULL, NULL, NULL);clicon_debug(2,"primaryexpr-> functionname ( arguments )"); } 
            ;

/* XXX Adding this between FUNCTIONNAME() breaks parser,..
arguments   : arguments expr { clicon_debug(2,"arguments-> arguments expr"); }
            |                { clicon_debug(2,"arguments-> "); }
	    ;
*/
string      : string CHAR  { 
     			 int len = strlen($1);
			 $$ = realloc($1, len+strlen($2) + 1); 
			 sprintf($$+len, "%s", $2); 
			 free($2);
			 clicon_debug(2,"string-> string CHAR");
               }
            | CHAR             { clicon_debug(2,"string-> "); } 
            ;


%%

