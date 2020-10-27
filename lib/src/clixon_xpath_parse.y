/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
    char     *string;
    void     *stack; /* xpath_tree */
}

%token <intval> AXISNAME
%token <intval> LOGOP
%token <intval> ADDOP
%token <intval> RELOP

%token <string> NUMBER
%token <string> X_EOF
%token <string> QUOTE
%token <string> APOST
%token <string> CHARS
%token <string> NAME
%token <string> DOUBLEDOT
%token <string> DOUBLESLASH
%token <string> FUNCTIONNAME

%type <intval>    axisspec

%type <string>    string
%type <stack>     args
%type <stack>     expr
%type <stack>     andexpr
%type <stack>     relexpr
%type <stack>     addexpr
%type <stack>     unionexpr
%type <stack>     pathexpr
%type <stack>     filterexpr
%type <stack>     locationpath
%type <stack>     abslocpath
%type <stack>     rellocpath
%type <stack>     step
%type <stack>     nodetest
%type <stack>     predicates
%type <stack>     primaryexpr

%lex-param     {void *_xpy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_xpy}

%{
/* Here starts user C-code */

/* typecast macro */
#define _XPY ((clixon_xpath_yacc *)_xpy)

#define _YYERROR(msg) {clicon_err(OE_XML, 0, "YYERROR %s '%s' %d", (msg), clixon_xpath_parsetext, _XPY->xpy_linenum); YYERROR;}

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
#include "clixon_xpath_ctx.h"
#include "clixon_xpath.h"
#include "clixon_xpath_function.h"

#include "clixon_xpath_parse.h"

extern int clixon_xpath_parseget_lineno  (void); /*XXX obsolete ? */

/* 
   also called from yacc generated code *
*/

void 
clixon_xpath_parseerror(void *_xpy,
			char *s) 
{ 
    errno = 0;
    clicon_err(OE_XML, 0, "%s on line %d: %s at or before: '%s'",  /* Note lineno here is xpath, not yang */
	       _XPY->xpy_name,
	       _XPY->xpy_linenum ,
	       s, 
	       clixon_xpath_parsetext); 
  return;
}

int
xpath_parse_init(clixon_xpath_yacc *xpy)
{
    //        clicon_debug_init(3, NULL);
    return 0;
}

int
xpath_parse_exit(clixon_xpath_yacc *xpy)
{
    return 0;
}
 
/*! Generic creator function for an xpath tree object
 *
 * @param[in]  type   XPATH tree node type
 * @param[in]  i0     step-> axis_type 
 * @param[in]  numstr original string xs_double: numeric value 
 * @param[in]  s0     String 0 set if XP_PRIME_STR, XP_PRIME_FN, XP_NODE[_FN] prefix
 * @param[in]  s1     String 1 set if XP_NODE NAME
 * @param[in]  c0     Child 0
 * @param[in]  c1     Child 1
 */
static xpath_tree *
xp_new(enum xp_type  type,
       int           i0,
       char         *numstr,
       char         *s0,
       char         *s1,
       xpath_tree   *c0,
       xpath_tree   *c1)
{
    xpath_tree *xs = NULL;
    
    if ((xs = malloc(sizeof(xpath_tree))) == NULL){
	clicon_err(OE_XML, errno, "malloc");
	goto done;
    }
    memset(xs, 0, sizeof(*xs));
    xs->xs_type = type;
    xs->xs_int  = i0;
    if (numstr){
	xs->xs_strnr = numstr;
	if (sscanf(numstr, "%lf", &xs->xs_double) == EOF){
	    clicon_err(OE_XML, errno, "sscanf");
	    goto done;
	}
    }
    else
	xs->xs_double = 0.0;
    xs->xs_s0  = s0;
    xs->xs_s1  = s1;
    xs->xs_c0  = c0;
    xs->xs_c1  = c1;
 done:
    return xs;
}

/*! Specialized xpath-tree creation for xpath functions (wrapper for functions around xp_new)
 *
 * Sanity check xpath functions before adding them
 * @param[in]   xpy   XPath parse handle
 * @param[in]   name  Name of function
 * @param[in]   xpt   Sub-parse-tree
 */
static xpath_tree *
xp_primary_function(clixon_xpath_yacc *xpy,
		    char              *name,
		    xpath_tree        *xpt)
{
    xpath_tree                *xtret = NULL;
    enum clixon_xpath_function fn;
    cbuf                      *cb = NULL;
    int                        ret;
    
    if ((ret = xp_fnname_str2int(name)) < 0){
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	cprintf(cb, "Unknown xpath function \"%s\"", name);
	clixon_xpath_parseerror(xpy, cbuf_get(cb));
	goto done;
    }
    fn = ret;
    switch (fn){
    case XPATHFN_RE_MATCH:  /* Group of NOT IMPLEMENTED xpath functions */
    case XPATHFN_ENUM_VALUE:
    case XPATHFN_BIT_IS_SET:
    case XPATHFN_LAST: 
    case XPATHFN_ID:
    case XPATHFN_LOCAL_NAME:
    case XPATHFN_NAMESPACE_URI:
    case XPATHFN_STRING:
    case XPATHFN_CONCAT:
    case XPATHFN_STARTS_WITH:
    case XPATHFN_SUBSTRING_BEFORE:
    case XPATHFN_SUBSTRING_AFTER:
    case XPATHFN_SUBSTRING:
    case XPATHFN_STRING_LENGTH:
    case XPATHFN_NORMALIZE_SPACE:
    case XPATHFN_TRANSLATE:
    case XPATHFN_BOOLEAN:
    case XPATHFN_TRUE:
    case XPATHFN_FALSE:
    case XPATHFN_LANG:
    case XPATHFN_NUMBER:
    case XPATHFN_SUM:
    case XPATHFN_FLOOR:
    case XPATHFN_CEILING:
    case XPATHFN_ROUND:
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	cprintf(cb, "XPATH function \"%s\" is not implemented", name);
	clixon_xpath_parseerror(xpy, cbuf_get(cb));
	goto done;
	break;
    case XPATHFN_CURRENT:  /* Group of implemented xpath functions */
    case XPATHFN_DEREF:
    case XPATHFN_DERIVED_FROM:
    case XPATHFN_DERIVED_FROM_OR_SELF:
    case XPATHFN_POSITION:
    case XPATHFN_COUNT:
    case XPATHFN_NAME:
    case XPATHFN_CONTAINS:
    case XPATHFN_NOT:
	break;
    default: 
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	cprintf(cb, "Unknown xpath function \"%s\"", name);
	clixon_xpath_parseerror(xpy, cbuf_get(cb));
	goto done; 
	break;
    }
    if (cb)
	cbuf_free(cb);
    xtret = xp_new(XP_PRIME_FN, fn, NULL, name, NULL, xpt, NULL);
    name = NULL;
 done:
    if (name)
	free(name);
    if (cb)
	cbuf_free(cb);
    return xtret;
}

/*! Specialized xpath-tree creation for xpath nodetest functions (wrapper for functions around xp_new)
 *
 * Sanity check xpath functions before adding them
 * @param[in]   xpy   XPath parse handle
 * @param[in]   name  Name of function
 * @param[in]   xpt   Sub-parse-tree
 */
static xpath_tree *
xp_nodetest_function(clixon_xpath_yacc *xpy,
		     char              *name,
		     xpath_tree        *xpt)
{
    xpath_tree                *xtret = NULL;
    enum clixon_xpath_function fn;
    cbuf                      *cb = NULL;
    int                        ret;
    
    if ((ret = xp_fnname_str2int(name)) < 0){
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	cprintf(cb, "Unknown xpath function \"%s\"", name);
	clixon_xpath_parseerror(xpy, cbuf_get(cb));
	goto done;
    }
    fn = ret;
    switch (fn){
    case XPATHFN_COMMENT:  /* Group of not implemented node functions */
    case XPATHFN_PROCESSING_INSTRUCTIONS:
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	cprintf(cb, "XPATH function \"%s\" is not implemented", name);
	clixon_xpath_parseerror(xpy, cbuf_get(cb));
	goto done;
	break;
    case XPATHFN_TEXT:     /* Group of implemented node functions */
    case XPATHFN_NODE:       
	break;
    default: 
	if ((cb = cbuf_new()) == NULL){
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	cprintf(cb, "Unknown xpath nodetest function \"%s\"", name);
	clixon_xpath_parseerror(xpy, cbuf_get(cb));
	goto done; 
	break;
    }
    if (cb)
	cbuf_free(cb);
    xtret = xp_new(XP_NODE_FN, fn, NULL, name, NULL, xpt, NULL);
    name = NULL; /* Consumed by xp_new */
 done:
    if (cb)
	cbuf_free(cb);
    if (name)
	free(name);
    return xtret;
}

%} 
 
%%

/*
*/

start       : expr X_EOF         { _XPY->xpy_top=$1;clicon_debug(3,"start->expr"); YYACCEPT; } 
            | locationpath X_EOF { _XPY->xpy_top=$1;clicon_debug(3,"start->locationpath"); YYACCEPT; } 
            ;

expr        : expr LOGOP andexpr { $$=xp_new(XP_EXP,$2,NULL,NULL,NULL,$1, $3);clicon_debug(3,"expr->expr or andexpr");  } 
            | andexpr { $$=xp_new(XP_EXP,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"expr-> andexpr"); } 
            ;

andexpr     : andexpr LOGOP relexpr { $$=xp_new(XP_AND,$2,NULL,NULL,NULL,$1, $3);clicon_debug(3,"andexpr-> andexpr and relexpr"); } 
            | relexpr { $$=xp_new(XP_AND,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"andexpr-> relexpr"); } 
            ;

relexpr     : relexpr RELOP addexpr { $$=xp_new(XP_RELEX,$2,NULL,NULL,NULL,$1, $3);clicon_debug(3,"relexpr-> relexpr relop addexpr"); } 
            | addexpr { $$=xp_new(XP_RELEX,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"relexpr-> addexpr"); } 
            ;

addexpr     : addexpr ADDOP unionexpr { $$=xp_new(XP_ADD,$2,NULL,NULL,NULL,$1, $3);clicon_debug(3,"addexpr-> addexpr ADDOP unionexpr"); } 
            | unionexpr { $$=xp_new(XP_ADD,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"addexpr-> unionexpr"); } 
            ;

/* node-set */
unionexpr   : unionexpr '|' pathexpr { $$=xp_new(XP_UNION,A_NAN,NULL,NULL,NULL,$1, $3);clicon_debug(3,"unionexpr-> unionexpr | pathexpr"); } 
            | pathexpr { $$=xp_new(XP_UNION,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"unionexpr-> pathexpr"); } 
            ;

pathexpr    : locationpath { $$=xp_new(XP_PATHEXPR,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"pathexpr-> locationpath"); } 
            | filterexpr { $$=xp_new(XP_PATHEXPR,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"pathexpr-> filterexpr"); }
            | filterexpr '/' rellocpath { $$=xp_new(XP_PATHEXPR,A_NAN,NULL,NULL,NULL,$1, $3);clicon_debug(3,"pathexpr-> filterexpr / rellocpath"); } 
            /* Filterexpr // relativelocationpath */
            ;

filterexpr  : primaryexpr { $$=xp_new(XP_FILTEREXPR,A_NAN,NULL,NULL,NULL,$1, NULL);clicon_debug(3,"filterexpr-> primaryexpr"); } 
            /* Filterexpr predicate */
            ;

/* location path returns a node-set  */
locationpath : rellocpath { $$=xp_new(XP_LOCPATH,A_NAN,NULL,NULL,NULL,$1, NULL); clicon_debug(3,"locationpath-> rellocpath"); } 
            | abslocpath  { $$=xp_new(XP_LOCPATH,A_NAN,NULL,NULL,NULL,$1, NULL); clicon_debug(3,"locationpath-> abslocpath"); } 
            ;

abslocpath  : '/'            { $$=xp_new(XP_ABSPATH,A_ROOT,NULL,NULL,NULL,NULL, NULL);clicon_debug(3,"abslocpath-> /"); }
            | '/' rellocpath { $$=xp_new(XP_ABSPATH,A_ROOT,NULL,NULL,NULL,$2, NULL);clicon_debug(3,"abslocpath->/ rellocpath");}
            /* // is short for /descendant-or-self::node()/ */
            | DOUBLESLASH rellocpath  {$$=xp_new(XP_ABSPATH,A_DESCENDANT_OR_SELF,NULL,NULL,NULL,$2, NULL); clicon_debug(3,"abslocpath-> // rellocpath"); } 
            ;

rellocpath  : step                 { $$=xp_new(XP_RELLOCPATH,A_NAN,NULL,NULL,NULL,$1, NULL); clicon_debug(3,"rellocpath-> step"); } 
            | rellocpath '/' step  { $$=xp_new(XP_RELLOCPATH,A_NAN,NULL,NULL,NULL,$1, $3);clicon_debug(3,"rellocpath-> rellocpath / step"); } 
            | rellocpath DOUBLESLASH step { $$=xp_new(XP_RELLOCPATH,A_DESCENDANT_OR_SELF,NULL,NULL,NULL,$1, $3); clicon_debug(3,"rellocpath-> rellocpath // step"); } 
            ;

step        : axisspec nodetest predicates {$$=xp_new(XP_STEP,$1,NULL, NULL, NULL, $2, $3);clicon_debug(3,"step->axisspec(%d) nodetest", $1); }
            | '.' predicates              { $$=xp_new(XP_STEP,A_SELF, NULL,NULL, NULL, NULL, $2); clicon_debug(3,"step-> ."); } 
            | DOUBLEDOT predicates        { $$=xp_new(XP_STEP, A_PARENT, NULL,NULL, NULL, NULL, $2); clicon_debug(3,"step-> .."); } 
            ;

axisspec    : AXISNAME { clicon_debug(3,"axisspec-> AXISNAME(%d) ::", $1); $$=$1;}
            | '@'      { $$=A_ATTRIBUTE; clicon_debug(3,"axisspec-> @"); } 
            |          { clicon_debug(3,"axisspec-> "); $$=A_CHILD;} 
           ;

nodetest    : '*'              { $$=xp_new(XP_NODE,A_NAN,NULL, NULL, NULL, NULL, NULL); clicon_debug(3,"nodetest-> *"); } 
            | NAME             { $$=xp_new(XP_NODE,A_NAN,NULL, NULL, $1, NULL, NULL); clicon_debug(3,"nodetest-> name(%s)",$1); } 
            | NAME ':' NAME    { $$=xp_new(XP_NODE,A_NAN,NULL, $1, $3, NULL, NULL);clicon_debug(3,"nodetest-> name(%s) : name(%s)", $1, $3); } 
            | NAME ':' '*'     { $$=xp_new(XP_NODE,A_NAN,NULL, $1, NULL, NULL, NULL);clicon_debug(3,"nodetest-> name(%s) : *", $1); } 
            | FUNCTIONNAME ')' { if (($$ = xp_nodetest_function(_XPY, $1, NULL)) == NULL) YYERROR;; clicon_debug(3,"nodetest-> nodetype():%s", $1); } 
            ;

/* evaluates to boolean */
predicates  : predicates '[' expr ']' { $$=xp_new(XP_PRED,A_NAN,NULL, NULL, NULL, $1, $3); clicon_debug(3,"predicates-> [ expr ]"); } 
            |                         { $$=xp_new(XP_PRED,A_NAN,NULL, NULL, NULL, NULL, NULL); clicon_debug(3,"predicates->"); } 
            ;
primaryexpr : '(' expr ')'         { $$=xp_new(XP_PRI0,A_NAN,NULL, NULL, NULL, $2, NULL); clicon_debug(3,"primaryexpr-> ( expr )"); } 
            | NUMBER               { $$=xp_new(XP_PRIME_NR,A_NAN, $1, NULL, NULL, NULL, NULL);clicon_debug(3,"primaryexpr-> NUMBER(%s)", $1); /*XXX*/} 
            | QUOTE string QUOTE   { $$=xp_new(XP_PRIME_STR,A_NAN,NULL, $2, NULL, NULL, NULL);clicon_debug(3,"primaryexpr-> \" string \""); }
            | QUOTE QUOTE          { $$=xp_new(XP_PRIME_STR,A_NAN,NULL, NULL, NULL, NULL, NULL);clicon_debug(3,"primaryexpr-> \" \""); } 
            | APOST string APOST   { $$=xp_new(XP_PRIME_STR,A_NAN,NULL, $2, NULL, NULL, NULL);clicon_debug(3,"primaryexpr-> ' string '"); }
            | APOST APOST          { $$=xp_new(XP_PRIME_STR,A_NAN,NULL, NULL, NULL, NULL, NULL);clicon_debug(3,"primaryexpr-> ' '"); } 
            | FUNCTIONNAME ')'      { if (($$ = xp_primary_function(_XPY, $1, NULL)) == NULL) YYERROR; clicon_debug(3,"primaryexpr-> functionname ()"); }
            | FUNCTIONNAME args ')' { if (($$ = xp_primary_function(_XPY, $1, $2)) == NULL) YYERROR;  clicon_debug(3,"primaryexpr-> functionname (arguments)"); } 
            ;

args        : args ',' expr { $$=xp_new(XP_EXP,A_NAN,NULL,NULL,NULL,$1, $3);
                              clicon_debug(3,"args -> args expr");}
            | expr          { $$=xp_new(XP_EXP,A_NAN,NULL,NULL,NULL,$1, NULL);
                              clicon_debug(3,"args -> expr "); }
	    ;

string      : string CHARS  { 
     			 int len = strlen($1);
			 $$ = realloc($1, len+strlen($2) + 1); 
			 sprintf($$+len, "%s", $2); 
			 free($2);
			 clicon_debug(3,"string-> string CHAR");
               }
            | CHARS         { clicon_debug(3,"string-> "); } 
            ;


%%

