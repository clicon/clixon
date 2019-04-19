/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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

%start document

%token <string> NAME CHARDATA WHITESPACE STRING
%token MY_EOF
%token VER ENC SD
%token BSLASH ESLASH
%token BXMLDCL BQMARK EQMARK
%token BCOMMENT ECOMMENT 

%type <string> attvalue 

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
#include "clixon_xml_sort.h"
#include "clixon_xml_parse.h"

void 
clixon_xml_parseerror(void *_ya, char *s) 
{ 
  clicon_err(OE_XML, XMLPARSE_ERRNO, "xml_parse: line %d: %s: at or before: %s", 
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

/*! Add whitespace
 * If text, ie only body, keep as is.
 * But if there is an element, then skip all whitespace.
 */
static int
xml_parse_whitespace(struct xml_parse_yacc_arg *ya,
		     char                      *str)
{
    cxobj *xn = ya->ya_xelement;
    cxobj *xp = ya->ya_xparent;
    int    retval = -1;
    int    i;

    ya->ya_xelement = NULL; /* init */
    /* If there is an element already, only add one whitespace child 
     * otherwise, keep all whitespace.
     */
#if 1
    for (i=0; i<xml_child_nr(xp); i++){
	if (xml_type(xml_child_i(xp, i)) == CX_ELMNT)
	    goto ok; /* Skip if already element */
    }
#endif
    if (xn == NULL){
	if ((xn = xml_new("body", xp, NULL)) == NULL)
	    goto done; 
	xml_type_set(xn, CX_BODY);
    }
    if (xml_value_append(xn, str)==NULL)
	goto done; 
    ya->ya_xelement = xn;
 ok:
    retval = 0;
  done:
    return retval;
}

 
static int
xml_parse_version(struct xml_parse_yacc_arg *ya,
		  char                      *ver)
{
    if(strcmp(ver, "1.0")){
	clicon_err(OE_XML, XMLPARSE_ERRNO, "Wrong XML version %s expected 1.0", ver);
	free(ver);
	return -1;
    }
    if (ver)
	free(ver);
    return 0;
}

/*! Parse Qualified name --> Unprefixed name
 * @param[in] ya        XML parser yacc handler struct 
 * @param[in] prefix    Prefix, namespace, or NULL
 * @param[in] localpart Name
 * @note the call to xml_child_spec() may not have xmlns attribute read yet XXX
 */
static int
xml_parse_unprefixed_name(struct xml_parse_yacc_arg *ya,
			  char                      *name)
{
    int        retval = -1;
    cxobj     *x;
    yang_stmt *y = NULL;  /* yang node */   
    cxobj     *xp;        /* xml parent */ 

    xp = ya->ya_xparent;
    if ((x = xml_new(name, xp, NULL)) == NULL) 
	goto done;
    if (xml_child_spec(x, xp, ya->ya_yspec, &y) < 0)
	goto done;
    if (y && xml_spec_set(x, y) < 0)
	goto done;
    ya->ya_xelement = x;
    retval = 0;
 done:
    free(name);
    return retval;
}

/*! Parse Qualified name -> PrefixedName
 * @param[in] ya        XML parser yacc handler struct 
 * @param[in] prefix    Prefix, namespace, or NULL
 * @param[in] localpart Name
 */
static int
xml_parse_prefixed_name(struct xml_parse_yacc_arg *ya,
			char                      *prefix,
			char                      *name)
{
    int        retval = -1;
    cxobj     *x;
    yang_stmt *y = NULL;  /* yang node */   
    cxobj     *xp;      /* xml parent */ 

    xp = ya->ya_xparent;
    if ((x = xml_new(name, xp, NULL)) == NULL) 
	goto done;
    if (xml_child_spec(x, xp, ya->ya_yspec, &y) < 0)
	goto done;
    if (y && xml_spec_set(x, y) < 0)
	goto done;
    if (xml_prefix_set(x, prefix) < 0)
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
	clicon_err(OE_XML, XMLPARSE_ERRNO, "XML parse sanity check failed: %s vs %s", 
		xml_name(x), name);
	goto done;
    }
    if (xml_prefix(x)!=NULL){
	clicon_err(OE_XML, XMLPARSE_ERRNO, "XML parse sanity check failed: %s:%s vs %s", 
		xml_prefix(x), xml_name(x), name);
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
	    int i;
	    for (i=0; i<xml_child_nr(x);){
		xc = xml_child_i(x, i);
		if (xml_type(xc) != CX_BODY){
		    i++;
		    continue;
		}
		if (xml_child_rm(x, i) < 0)
		    goto done;
		xml_free(xc);
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
	clicon_err(OE_XML, XMLPARSE_ERRNO, "Sanity check failed: %s:%s vs %s:%s", 
		xml_prefix(x), 
		xml_name(x), 
		namespace, 
		name);
	goto done;
    }
    if (xml_prefix(x)==NULL ||
	strcmp(xml_prefix(x), namespace)){
	clicon_err(OE_XML, XMLPARSE_ERRNO, "Sanity check failed: %s:%s vs %s:%s", 
		xml_prefix(x), 
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

/*! Parse XML attribute
 * Special cases:
 *  - DefaultAttName:  xmlns
 *  - PrefixedAttName: xmlns:NAME 
 */
static int
xml_parse_attr(struct xml_parse_yacc_arg *ya,
	       char                      *prefix,
	       char                      *name,
	       char                      *attval)
{
    int    retval = -1;
    cxobj *xa = NULL; 

    if ((xa = xml_find_type(ya->ya_xelement, prefix, name, CX_ATTR)) == NULL){
	if ((xa = xml_new(name, ya->ya_xelement, NULL)) == NULL)
	    goto done;
	xml_type_set(xa, CX_ATTR);
	if (prefix && xml_prefix_set(xa, prefix) < 0)
	    goto done;
    }
    if (xml_value_set(xa, attval) < 0)
	goto done;
    retval = 0;
  done:
    free(name);
    if (prefix)
	free(prefix);
    free(attval);
    return retval;
}

%} 
 
%%
 /* [1] document ::= prolog element Misc* */
document    : prolog element misclist  MY_EOF
                 { clicon_debug(2, "document->prolog element misc* ACCEPT"); 
		   YYACCEPT; }
            | elist MY_EOF
	    { clicon_debug(2, "document->elist ACCEPT");  /* internal exception*/
		   YYACCEPT; }
            ;
/* [22] prolog ::=  XMLDecl? Misc* (doctypedecl Misc*)? */
prolog      : xmldcl misclist
                { clicon_debug(2, "prolog->xmldcl misc*"); }
            | misclist
	        { clicon_debug(2, "prolog->misc*"); }
            ;

misclist    : misclist misc { clicon_debug(2, "misclist->misclist misc"); }
            |     { clicon_debug(2, "misclist->"); }
            ;

/* [27]	Misc ::=  Comment | PI | S */
misc        : comment    { clicon_debug(2, "misc->comment"); }
	    | pi         { clicon_debug(2, "misc->pi"); }
            | WHITESPACE { clicon_debug(2, "misc->white space"); }
	    ;

xmldcl      : BXMLDCL verinfo encodingdecl sddecl EQMARK
	          { clicon_debug(2, "xmldcl->verinfo encodingdecl? sddecl?"); }
            ;

verinfo     : VER '=' '\"' STRING '\"' 
                 { if (xml_parse_version(_YA, $4) <0) YYABORT;
		     clicon_debug(2, "verinfo->version=\"STRING\"");}
            | VER '=' '\'' STRING '\'' 
         	 { if (xml_parse_version(_YA, $4) <0) YYABORT;
		     clicon_debug(2, "verinfo->version='STRING'");}
            ;

encodingdecl : ENC '=' '\"' STRING '\"' {if ($4)free($4);}
            | ENC '=' '\'' STRING '\'' {if ($4)free($4);}
            |
            ;

sddecl      : SD '=' '\"' STRING '\"' {if ($4)free($4);}
            | SD '=' '\'' STRING '\'' {if ($4)free($4);}
            |
            ;
/* [39] element ::= EmptyElemTag | STag content ETag */
element     : '<' qname  attrs element1 
                   { clicon_debug(2, "element -> < qname attrs element1"); }
	    ;

qname       : NAME           { if (xml_parse_unprefixed_name(_YA, $1) < 0) YYABORT; 
                                clicon_debug(2, "qname -> NAME %s", $1);}
            | NAME ':' NAME  { if (xml_parse_prefixed_name(_YA, $1, $3) < 0) YYABORT; 
                                clicon_debug(2, "qname -> NAME : NAME");}
            ;

element1    :  ESLASH         {_YA->ya_xelement = NULL; 
                               clicon_debug(2, "element1 -> />");} 
            | '>'             { xml_parse_endslash_pre(_YA); }
              elist           { xml_parse_endslash_mid(_YA); }
              endtag          { xml_parse_endslash_post(_YA); 
                               clicon_debug(2, "element1 -> > elist endtag");} 
            ;

endtag      : BSLASH NAME '>'          
                       { clicon_debug(2, "endtag -> < </ NAME>");
		         if (xml_parse_bslash1(_YA, $2) < 0) YYABORT; }

            | BSLASH NAME ':' NAME '>' 
                       { if (xml_parse_bslash2(_YA, $2, $4) < 0) YYABORT; 
			 clicon_debug(2, "endtag -> < </ NAME:NAME >"); }
            ;

elist       : elist content { clicon_debug(2, "elist -> elist content"); }
            | content      { clicon_debug(2, "elist -> content"); }
            ;

/* Rule 43 */
content     : element      { clicon_debug(2, "content -> element"); }
            | comment      { clicon_debug(2, "content -> comment"); }
            | pi           { clicon_debug(2, "content -> pi"); }
            | CHARDATA     { if (xml_parse_content(_YA, $1) < 0) YYABORT;  
                             clicon_debug(2, "content -> CHARDATA %s", $1); }
            | WHITESPACE   { if (xml_parse_whitespace(_YA, $1) < 0) YYABORT;  
                             clicon_debug(2, "content -> WHITESPACE %s", $1); }
            |              { clicon_debug(2, "content -> "); }
            ;

comment     : BCOMMENT ECOMMENT
            ;

pi          : BQMARK NAME EQMARK {clicon_debug(2, "pi -> <? NAME ?>"); free($2); }
            | BQMARK NAME STRING EQMARK
	    {clicon_debug(2, "pi -> <? NAME STRING ?>"); free($2); free($3);}
            ;


attrs       : attrs attr
            |
            ;

attr        : NAME '=' attvalue          { if (xml_parse_attr(_YA, NULL, $1, $3) < 0) YYABORT; }
            | NAME ':' NAME '=' attvalue { if (xml_parse_attr(_YA, $1, $3, $5) < 0) YYABORT; }
            ;

attvalue    : '\"' STRING '\"'   { $$=$2; /* $2 must be consumed */}
            | '\"'  '\"'       { $$=strdup(""); /* $2 must be consumed */}
            | '\'' STRING '\''   { $$=$2; /* $2 must be consumed */}
            | '\''  '\''       { $$=strdup(""); /* $2 must be consumed */}
            ;

%%

