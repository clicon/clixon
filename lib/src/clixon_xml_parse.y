/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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

 * XML parser
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208
 */
%union {
  char *string;
}

%start topxml

%token <string> NAME CHAR 
%token VER ENC
%token BSLASH ESLASH 
%token BTEXT ETEXT
%token BCOMMENT ECOMMENT 


%type <string> attvalue attqname

%lex-param     {void *_ya} /* Add this argument to parse() and lex() function */
%parse-param   {void *_ya}

%{

/* typecast macro */
#define _YA ((struct xml_parse_yacc_arg *)_ya)

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_xml_parse.h"

void 
clixon_xml_parseerror(void *_ya, char *s) 
{ 
  clicon_err(OE_XML, 0, "xml_parse: line %d: %s: at or before: %s", 
	      _YA->ya_linenum, s, clixon_xml_parsetext); 
  return;
}

/*
 * Note that we dont handle escaped characters correctly 
 * there may also be some leakage here on NULL return
 */
static int
xml_parse_content(struct xml_parse_yacc_arg *ya, 
		  char                      *str)
{
    cxobj *xn = ya->ya_xelement;
    cxobj *xp = ya->ya_xparent;
    int    retval = -1;

    ya->ya_xelement = NULL; /* init */
    if (xn == NULL){
	if ((xn = xml_new("body", xp, NULL)) == NULL)
	    goto done; 
	xml_type_set(xn, CX_BODY);
    }
    if (xml_value_append(xn, str)==NULL)
	goto done; 
    ya->ya_xelement = xn;
    retval = 0;
  done:
    return retval;
}

static int
xml_parse_version(struct xml_parse_yacc_arg *ya,
		  char                      *ver)
{
    if(strcmp(ver, "1.0")){
	clicon_err(OE_XML, errno, "Wrong XML version %s expected 1.0\n", ver);
	free(ver);
	return -1;
    }
    free(ver);
    return 0;
}

/*! Parse Qualified name
 * @param[in] ya        XML parser yacc handler struct 
 * @param[in] prefix    Prefix, namespace, or NULL
 * @param[in] localpart Name
 */
static int
xml_parse_qname(struct xml_parse_yacc_arg *ya,
		char                      *prefix,
		char                      *name)
{
    int        retval = -1;
    cxobj     *x;
    yang_stmt *y=NULL;  /* yang node */   
    cxobj     *xp;      /* xml parent */ 

    xp = ya->ya_xparent;
    if (xml_child_spec(name, xp, ya->ya_yspec, &y) < 0)
	goto done;
    if ((x = xml_new(name, xp, y)) == NULL) 
	goto done;
    if (xml_namespace_set(x, prefix) < 0)
	goto done;
    ya->ya_xelement = x;
    retval = 0;
 done:
    if (prefix)
	free(prefix);
    free(name);
    return retval;
}

static int
xml_parse_endslash_pre(struct xml_parse_yacc_arg *ya)
{
    ya->ya_xparent = ya->ya_xelement;
    ya->ya_xelement = NULL;
    return 0;
}

static int
xml_parse_endslash_mid(struct xml_parse_yacc_arg *ya)
{
    if (ya->ya_xelement != NULL)
	ya->ya_xelement = xml_parent(ya->ya_xelement);
    else
	ya->ya_xelement = ya->ya_xparent;
    ya->ya_xparent = xml_parent(ya->ya_xelement);
    return 0;
}

static int
xml_parse_endslash_post(struct xml_parse_yacc_arg *ya)
{
    ya->ya_xelement = NULL;
    return 0;
}

/*! Called at </name> */
static int
xml_parse_bslash1(struct xml_parse_yacc_arg *ya, 
		  char                      *name)
{
    int    retval = -1;
    cxobj *x = ya->ya_xelement;
    cxobj *xc;

    if (strcmp(xml_name(x), name)){
	clicon_err(OE_XML, 0, "XML parse sanity check failed: %s vs %s", 
		xml_name(x), name);
	goto done;
    }
    if (xml_namespace(x)!=NULL){
	clicon_err(OE_XML, 0, "XML parse sanity check failed: %s:%s vs %s\n", 
		xml_namespace(x), xml_name(x), name);
	goto done;
    }
    /* Strip pretty-print. Ad-hoc algorithm
     * It ok with x:[body], but not with x:[ex,body]
     * It is also ok with x:[attr,body]
     * So the rule is: if there is at least on element, then remove all bodies?
     */
    if (ya->ya_skipspace){
	xc = NULL;
	while ((xc = xml_child_each(x, xc, CX_ELMNT)) != NULL) 
	    break;
	if (xc != NULL){ /* at least one element */
	    xc = NULL;
	    while ((xc = xml_child_each(x, xc, CX_BODY)) != NULL) {
		xml_purge(xc);
		xc = NULL; /* reset iterator */
	    }	    
	}
    }
    retval = 0;
  done:
    free(name);
    return retval;
}

/*! Called at </namespace:name> */
static int
xml_parse_bslash2(struct xml_parse_yacc_arg *ya, 
		  char                      *namespace, 
		  char                      *name)
{
    int    retval = -1;
    cxobj *x = ya->ya_xelement;
    cxobj *xc;

    if (strcmp(xml_name(x), name)){
	clicon_err(OE_XML, 0, "Sanity check failed: %s:%s vs %s:%s\n", 
		xml_namespace(x), 
		xml_name(x), 
		namespace, 
		name);
	goto done;
    }
    if (xml_namespace(x)==NULL ||
	strcmp(xml_namespace(x), namespace)){
	clicon_err(OE_XML, 0, "Sanity check failed: %s:%s vs %s:%s\n", 
		xml_namespace(x), 
		xml_name(x), 
		namespace, 
		name);
	goto done;
    }
    /* Strip pretty-print. Ad-hoc algorithm
     * It ok with x:[body], but not with x:[ex,body]
     * It is also ok with x:[attr,body]
     * So the rule is: if there is at least on element, then remove all bodies?
     */
    if (ya->ya_skipspace){
	xc = NULL;
	while ((xc = xml_child_each(x, xc, CX_ELMNT)) != NULL) 
	    break;
	if (xc != NULL){ /* at least one element */
	    xc = NULL;
	    while ((xc = xml_child_each(x, xc, CX_BODY)) != NULL) {
		xml_value_set(xc, ""); /* XXX remove */
	    }	    
	}
    }
    retval = 0;
  done:
    free(name);
    free(namespace);
    return retval;
}

static int
xml_parse_attr(struct xml_parse_yacc_arg *ya,
	       char                      *qname,
	       char                      *attval)
{
    int    retval = -1;
    cxobj *xa; 

    if ((xa = xml_new(qname, ya->ya_xelement, NULL)) == NULL)
	goto done;
    xml_type_set(xa, CX_ATTR);
    if (xml_value_set(xa, attval) < 0)
	goto done;
    retval = 0;
  done:
    free(qname); 
    free(attval);
    return retval;
}

/*! Parse Attribue Qualified name, Just transform prefix:name into a new string
 *
 */
static char*
xml_merge_attqname(struct xml_parse_yacc_arg *ya,
		   char                      *prefix,
		   char                      *name)
{
    char *str;
    int len = strlen(prefix)+strlen(name)+2;

    if ((str=malloc(len)) == NULL)
	return NULL;
    snprintf(str, len, "%s:%s", prefix, name);
    free(prefix);
    free(name);
    return str;
}

 
%} 
 
%%

topxml      : list
                    { clicon_debug(3, "topxml->list ACCEPT"); 
                      YYACCEPT; }
            | dcl list
	            { clicon_debug(3, "topxml->dcl list ACCEPT"); 
                      YYACCEPT; }
            ;

dcl         : BTEXT info encode ETEXT { clicon_debug(3, "dcl->info encode"); }
            ;

info        : VER '=' '\"' CHAR '\"' 
                 { if (xml_parse_version(_YA, $4) <0) YYABORT; }
            | VER '=' '\'' CHAR '\'' 
         	 { if (xml_parse_version(_YA, $4) <0) YYABORT; }
            |
            ;

encode      : ENC '=' '\"' CHAR '\"' {free($4);}
            | ENC '=' '\'' CHAR '\'' {free($4);}
            ;

element     : '<' qname  attrs element1 
                   { clicon_debug(3, "element -> < qname attrs element1"); }
	      ;

qname       : NAME           { if (xml_parse_qname(_YA, NULL, $1) < 0) YYABORT; 
                                clicon_debug(3, "qname -> NAME %s", $1);}
            | NAME ':' NAME  { if (xml_parse_qname(_YA, $1, $3) < 0) YYABORT; 
                                clicon_debug(3, "qname -> NAME : NAME");}
            ;

element1    :  ESLASH         {_YA->ya_xelement = NULL; 
                               clicon_debug(3, "element1 -> />");} 
            | '>'             { xml_parse_endslash_pre(_YA); }
              list            { xml_parse_endslash_mid(_YA); }
              etg             { xml_parse_endslash_post(_YA); 
                               clicon_debug(3, "element1 -> > list etg");} 
            ;

etg         : BSLASH NAME '>'          
{ 			   clicon_debug(3, "etg -> < </ NAME %s>", $2); if (xml_parse_bslash1(_YA, $2) < 0) YYABORT; }

            | BSLASH NAME ':' NAME '>' 
                       { if (xml_parse_bslash2(_YA, $2, $4) < 0) YYABORT; 
			 clicon_debug(3, "etg -> < </ NAME:NAME >"); }
            ;

list        : list content { clicon_debug(3, "list -> list content"); }
            | content      { clicon_debug(3, "list -> content"); }
            ;

content     : element      { clicon_debug(3, "content -> element"); }
            | comment      { clicon_debug(3, "content -> comment"); }
            | CHAR         { if (xml_parse_content(_YA, $1) < 0) YYABORT;  
                             clicon_debug(3, "content -> CHAR %s", $1); }
            |              { clicon_debug(3, "content -> "); }
            ;

comment     : BCOMMENT ECOMMENT
            ;


attrs       : attrs attr
            |
            ;

attr        : attqname '=' attvalue { if (xml_parse_attr(_YA, $1, $3) < 0) YYABORT; }
            ;

attqname    : NAME   {$$ = $1;}
            | NAME ':' NAME  
                     { if (($$ = xml_merge_attqname(_YA, $1, $3)) == NULL) YYABORT; }
            ;


attvalue    : '\"' CHAR '\"'   { $$=$2; /* $2 must be consumed */}
            | '\"'  '\"'       { $$=strdup(""); /* $2 must be consumed */}
            ;

%%

