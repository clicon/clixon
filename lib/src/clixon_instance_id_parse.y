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

 * "instance-id" is a subset of XPath and defined in RF7950 Sections 9.13 and 14. 
 * BNF:
 *  instance-identifier = ("/" (node-identifier [key-predicate+ | leaf-list-predicate | pos]))+
 *  node-identifier     = [prefix ":"] identifier
 *  prefix              = identifier
 *  key-predicate       = "[" key-predicate-expr "]"
 *  key-predicate-expr  = node-identifier "=" quoted-string
 *  leaf-list-predicate = "[" leaf-list-predicate-expr  "]"
 *  leaf-list-predicate-expr = "." "=" quoted-string
 *  pos                 = "[" positive-integer-value "]"
 *  quoted-string       = (DQUOTE string DQUOTE) / (SQUOTE string SQUOTE)
 *  positive-integer-value = (non-zero-digit DIGIT*)
 *  identifier          = (ALPHA | "_")(ALPHA | DIGIT | "_" | "-" | ".")*
 *
 * RFC 8341: All the same rules as an instance-identifier apply, except that predicates
 *           for keys are optional.  If a key predicate is missing, then the 
 *           node-instance-identifier represents all possible server instances for that key.
 */

%start start

 /* Must be here to define YYSTYPE */
%union {
    char     *string;
    void     *stack; /* cv / cvec */
}

%token <string> UINT
%token <string> IDENTIFIER
%token <string> STRING
%token <string> SLASH
%token <string> COLON
%token <string> EQUAL
%token <string> LSQBR
%token <string> RSQBR
%token <string> DOT
%token <string> DQUOTE
%token <string> SQUOTE
%token <string> X_EOF

%type  <stack>  list
%type  <stack>  element
%type  <stack>  node_id
%type  <string> prefix
%type  <stack>  element2
%type  <stack>  leaf_list_pred
%type  <stack>  leaf_list_pred_expr
%type  <stack>  pos
%type  <stack>  key_preds
%type  <stack>  key_pred
%type  <stack>  key_pred_expr
%type  <string> node_id_k
%type  <string> qstring

%lex-param     {void *_iy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_iy}

%{
/* Here starts user C-code */

/* typecast macro */
#define _IY ((clixon_instance_id_yacc *)_iy)

#define _YYERROR(msg) {clicon_err(OE_XML, 0, "YYERROR %s '%s' %d", (msg), clixon_instance_id_parsetext, _IY->iy_linenum); YYERROR;}

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
#include "clixon_path.h"
#include "clixon_instance_id_parse.h"

/* 
   also called from yacc generated code *
*/

void 
clixon_instance_id_parseerror(void *_iy,
			      char *s) 
{ 
    clicon_err(OE_XML, 0, "%s on line %d: %s at or before: '%s'", 
	       _IY->iy_name,
	       _IY->iy_linenum ,
	       s, 
	       clixon_instance_id_parsetext); 
  return;
}

int
instance_id_parse_init(clixon_instance_id_yacc *iy)
{
    return 0;
}

int
instance_id_parse_exit(clixon_instance_id_yacc *iy)
{
    return 0;
}

/*! Append new path structure to clixon path list
 */
static clixon_path *
path_append(clixon_path *list,
	    clixon_path *new)
{
    clicon_debug(2, "%s()", __FUNCTION__);
    if (new == NULL)
	return NULL;
    ADDQ(new, list);
    return list;
}

/*! Add keyvalue to existing clixon path 
 * If cvk has one integer argument, interpret as position, eg x/y[42] 
 * else as keyvalue strings, eg x/y[k1="foo"][k2="bar"]
 */
static clixon_path *
path_add_keyvalue(clixon_path *cp,
		  cvec        *cvk)
{
    clicon_debug(2, "%s()", __FUNCTION__);
    if (cp == NULL)
	goto done;
    cp->cp_cvk = cvk;
 done:
    return cp;
}

static clixon_path *
path_new(char *prefix,
	 char *id)
{
    clixon_path *cp = NULL;

    clicon_debug(2, "%s(%s,%s)", __FUNCTION__, prefix, id);
    if ((cp = malloc(sizeof(*cp))) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    memset(cp, 0, sizeof(*cp));
    if (prefix)
	if ((cp->cp_prefix = strdup(prefix)) == NULL){
	    clicon_err(OE_UNIX, errno, "strdup");
	    goto done;
	}
    if ((cp->cp_id = strdup(id)) == NULL){
	clicon_err(OE_UNIX, errno, "strdup");
	goto done;
    }
    return cp;
 done:
    return NULL;
}

/*! Create a single key-value positions (int) cv + cvv and return it
 */
static cvec *
keyval_pos(char *uint)
{
    cg_var *cv = NULL;
    cvec   *cvv = NULL;
    char   *reason=NULL;
    int     ret;
    
    clicon_debug(2, "%s(%s)", __FUNCTION__, uint);
    if ((cvv = cvec_new(1)) == NULL) {
	clicon_err(OE_UNIX, errno, "cvec_new");
	goto done;
    }
    cv = cvec_i(cvv, 0);
    cv_type_set(cv, CGV_UINT32);
    if ((ret = cv_parse1(uint, cv, &reason)) < 0){
	clicon_err(OE_UNIX, errno, "cv_parse1");
	cvv = NULL;
	goto done;
    }
    if (ret == 0){
	clicon_err(OE_UNIX, errno, "cv_parse1: %s", reason);
	cvv = NULL;
	goto done;
    }
 done:
    if (reason)
	free(reason);
    return cvv;
}

/*! Append a key-value cv to a cvec, create the cvec if not exist
 * @param[in] cvv  Either created cvv or NULL, in whihc case it is created
 * @param[in] cv   Is consumed by thius function (if appended)
 * @retval    NULL Error
 * @retval    cvv  Cvec
 */
static cvec *
keyval_add(cvec   *cvv,
	   cg_var *cv)
{
    clicon_debug(2, "%s()", __FUNCTION__);
    if (cv == NULL)
	goto done;
    if (cvv == NULL &&
	(cvv = cvec_new(0)) == NULL) {
	clicon_err(OE_UNIX, errno, "cvec_new");
	goto done;
    }
    if (cvec_append_var(cvv, cv) == NULL){
	clicon_err(OE_UNIX, errno, "cvec_append_var");
	cvv = NULL;
	goto done;
    }
    cv_free(cv);
 done:
    return cvv;
}

/*! Create a single key-value as cv and return it
 */
static cg_var *
keyval_set(char *name,
           char *val)
{
    cg_var *cv = NULL;

    clicon_debug(2, "%s(%s=%s)", __FUNCTION__, name, val);
    if ((cv = cv_new(CGV_STRING)) == NULL){
	clicon_err(OE_UNIX, errno, "cv_new");
	goto done;
    }
    if (name && cv_name_set(cv, name) == NULL){
	clicon_err(OE_UNIX, errno, "cv_string_set");
	cv = NULL;
	goto done;
    }
    if (cv_string_set(cv, val) == NULL){
	clicon_err(OE_UNIX, errno, "cv_string_set");
	cv = NULL;
	goto done;
    }
 done:
    return cv;
}



%} 
 

%%

/*
*/

start          : list X_EOF         { clicon_debug(3,"top"); _IY->iy_top=$1; YYACCEPT; } 
               ;

list           : list SLASH element { if (($$ = path_append($1, $3)) == NULL) YYABORT;
                                      clicon_debug(3,"list = list / element");}
               | SLASH element      { if (($$ = path_append(NULL, $2)) == NULL) YYABORT;
                                      clicon_debug(3,"list = / element");}
               ;

element        : node_id element2   { $$ = path_add_keyvalue($1, $2);
                                      clicon_debug(3,"element = node_id element2");}
               ;

node_id        : IDENTIFIER               { $$ = path_new(NULL, $1); free($1);
                                            clicon_debug(3,"node_id = IDENTIFIER");}
               | prefix COLON IDENTIFIER  { $$ = path_new($1, $3); free($1); free($3);
	                                    clicon_debug(3,"node_id = prefix : IDENTIFIER");} 
               ;

prefix         : IDENTIFIER               { $$=$1; clicon_debug(3,"prefix = IDENTIFIER");}

element2       : key_preds      { $$=$1; clicon_debug(3,"element2 = key_preds"); }
               | leaf_list_pred { $$=$1; clicon_debug(3,"element2 = leaf_list_pred"); }
               | pos            { $$=$1; clicon_debug(3,"element2 = key_preds"); }
               |                { $$=NULL; clicon_debug(3,"element2 = "); }
               ;

leaf_list_pred : LSQBR leaf_list_pred_expr RSQBR
                                 { if (($$ = keyval_add(NULL, $2)) == NULL) YYABORT;
				   clicon_debug(3,"leaf_list_pred = [ leaf_list_pred_expr ]"); }
               ;

leaf_list_pred_expr : DOT EQUAL qstring  { $$ = keyval_set(".", $3); free($3);
	                                   clicon_debug(3,"leaf_list_pred_expr = '.=' qstring"); }
               ;

pos            : LSQBR UINT RSQBR        { $$ = keyval_pos($2); free($2);
                                           clicon_debug(3,"pos = [ UINT ]"); }
               ;

key_preds      : key_preds key_pred      { if (($$ = keyval_add($1, $2)) == NULL) YYABORT;
                                           clicon_debug(3,"key_preds = key_pred key_preds"); }
               | key_pred                { if (($$ = keyval_add(NULL, $1)) == NULL) YYABORT;
                                           clicon_debug(3,"key_preds = key_pred");} 
               ;

key_pred       : LSQBR key_pred_expr RSQBR  { $$ = $2;
                                              clicon_debug(3,"key_pred = [ key_pred_expr ]"); }
               ;

key_pred_expr  : node_id_k EQUAL qstring   { $$ = keyval_set($1, $3); free($1); free($3);
                          clicon_debug(3,"key_pred_expr = node_id_k = qstring");  }
               ;

node_id_k      : IDENTIFIER               { $$ = $1; 
                                            clicon_debug(3,"node_id_k = IDENTIFIER %s", $1); }
               | prefix COLON IDENTIFIER  { $$ = $3;  /* ignore prefix in key? */
                          clicon_debug(3,"node_id_k = prefix %s : IDENTIFIER %s", $1, $3); free($1);} 
               ;

qstring        : DQUOTE STRING DQUOTE { $$=$2;
                                        clicon_debug(3,"qstring = \" string \""); }
               | DQUOTE DQUOTE        { $$=strdup("");
                                             clicon_debug(3,"qstring = \" \""); }
               | SQUOTE STRING SQUOTE { $$=$2;
                                             clicon_debug(3,"qstring = ' string '"); }
               | SQUOTE SQUOTE        { $$=strdup("");
                                             clicon_debug(3,"qstring = ''"); }
               ;

%%

