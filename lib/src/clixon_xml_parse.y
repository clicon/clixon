/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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

 * XML parser
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208
 * Canonical XML version (just for info)
 *      https://www.w3.org/TR/xml-c14n
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

%lex-param     {void *_xy} /* Add this argument to parse() and lex() function */
%parse-param   {void *_xy}

%{

/* typecast macro */
#define _XY ((clixon_xml_yacc *)_xy)

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
#include "clixon_string.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_xml_sort.h"
#include "clixon_xml_parse.h"

void 
clixon_xml_parseerror(void *_xy,
		      char *s) 
{ 
    clicon_err(OE_XML, XMLPARSE_ERRNO, "xml_parse: line %d: %s: at or before: %s", 
	       _XY->xy_linenum,
	       s,
	       clixon_xml_parsetext); 
    return;
}

/*
 * Note that we dont handle escaped characters correctly 
 * there may also be some leakage here on NULL return
 */
static int
xml_parse_content(clixon_xml_yacc *xy, 
		  char            *str)
{
    cxobj *xn = xy->xy_xelement;
    cxobj *xp = xy->xy_xparent;
    int    retval = -1;

    xy->xy_xelement = NULL; /* init */
    if (xn == NULL){
	if ((xn = xml_new("body", xp, CX_BODY)) == NULL)
	    goto done; 
    }
    if (xml_value_append(xn, str) < 0)
	goto done; 
    xy->xy_xelement = xn;
    retval = 0;
  done:
    return retval;
}

/*! Add whitespace
 * If text, ie only body, keep as is.
 * But if there is an element, then skip all whitespace.
 */
static int
xml_parse_whitespace(clixon_xml_yacc *xy,
		     char            *str)
{
    cxobj *xn = xy->xy_xelement;
    cxobj *xp = xy->xy_xparent;
    int    retval = -1;
    int    i;

    xy->xy_xelement = NULL; /* init */
    /* If there is an element already, only add one whitespace child 
     * otherwise, keep all whitespace. See code in xml_parse_bslash
     * Note that this xml element is not aware of YANG yet. 
     * For example, if xp is LEAF then a body child is OK, but if xp is CONTAINER
     * then the whitespace body is pretty-prints and should be stripped (later)
     */
    for (i=0; i<xml_child_nr(xp); i++){
	if (xml_type(xml_child_i(xp, i)) == CX_ELMNT)
	    goto ok; /* Skip if already element */
    }
    if (xn == NULL){
	if ((xn = xml_new("body", xp, CX_BODY)) == NULL)
	    goto done; 
    }
    if (xml_value_append(xn, str) < 0)
	goto done; 
    xy->xy_xelement = xn;
 ok:
    retval = 0;
  done:
    return retval;
}
 
static int
xml_parse_version(clixon_xml_yacc *xy,
		  char            *ver)
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

/*! Parse Qualified name -> (Un)PrefixedName
 *
 * This is where all (parsed) xml elements are created
 * @param[in] xy        XML parser yacc handler struct 
 * @param[in] prefix    Prefix, namespace, or NULL
 * @param[in] localpart Name
 */
static int
xml_parse_prefixed_name(clixon_xml_yacc *xy,
			char            *prefix,
			char            *name)
{
    int        retval = -1;
    cxobj     *x;
    cxobj     *xp;      /* xml parent */ 

    xp = xy->xy_xparent;
    if ((x = xml_new(name, xp, CX_ELMNT)) == NULL) 
	goto done;
    if (xml_prefix_set(x, prefix) < 0)
	goto done;

    xy->xy_xelement = x;
    /* If topmost, add to top-list created list */
    if (xp == xy->xy_xtop){
	if (cxvec_append(x, &xy->xy_xvec, &xy->xy_xlen) < 0)
	    goto done;
    }
    retval = 0;
 done:
    if (prefix)
	free(prefix);
    if (name)
	free(name);
    return retval;
}

static int
xml_parse_endslash_pre(clixon_xml_yacc *xy)
{
    xy->xy_xparent = xy->xy_xelement;
    xy->xy_xelement = NULL;
    return 0;
}

static int
xml_parse_endslash_mid(clixon_xml_yacc *xy)
{
    if (xy->xy_xelement != NULL)
	xy->xy_xelement = xml_parent(xy->xy_xelement);
    else
	xy->xy_xelement = xy->xy_xparent;
    xy->xy_xparent = xml_parent(xy->xy_xelement);
    return 0;
}

static int
xml_parse_endslash_post(clixon_xml_yacc *xy)
{
    xy->xy_xelement = NULL;
    return 0;
}

/*! A content terminated by <name>...</name> or <prefix:name>...</prefix:name> is ready
 *
 * Any whitespace between the subelements to a non-leaf is
 * insignificant, i.e., an implementation MAY insert whitespace
 * characters between subelements and are therefore stripped, but see comment in code below.
 * @param[in] xy      XML parser yacc handler struct 
 * @param[in] prefix  
 * @param[in] name
 */
static int
xml_parse_bslash(clixon_xml_yacc *xy, 
		 char            *prefix,
		 char            *name)
{
    int    retval = -1;
    cxobj *x = xy->xy_xelement;
    cxobj *xc;
    char  *prefix0;
    char  *name0;

    /* These are existing tags */
    prefix0 = xml_prefix(x);
    name0 = xml_name(x);
    /* Check name or prerix unequal from begin-tag */
    if (clicon_strcmp(name0, name) || 
	clicon_strcmp(prefix0, prefix)){ 
	clicon_err(OE_XML, XMLPARSE_ERRNO, "Sanity check failed: %s%s%s vs %s%s%s", 
		   prefix0?prefix0:"", prefix0?":":"", name0,
		   prefix?prefix:"", prefix?":":"", name);
	goto done;
    }
    /* Strip pretty-print. Ad-hoc algorithm
     * It ok with x:[body], but not with x:[ex,body]
     * It is also ok with x:[attr,body]
     * So the rule is: if there is at least on element, then remove all bodies.
     * See also code in xml_parse_whitespace
     * But there is more: when YANG is assigned, if not leaf/leaf-lists, then all contents should
     * be stripped, see xml_bind_yang()
     */
    xc = NULL;
    while ((xc = xml_child_each(x, xc, CX_ELMNT)) != NULL) 
	break;
    if (xc != NULL){ /* at least one element */
	if (xml_rm_children(x, CX_BODY) < 0) /* remove all bodies */
	    goto done;
    }
    retval = 0;
  done:
    if (prefix)
	free(prefix);
    if (name)
	free(name);
    return retval;
}

/*! Parse XML attribute
 * Special cases:
 *  - DefaultAttName:  xmlns
 *  - PrefixedAttName: xmlns:NAME 
 */
static int
xml_parse_attr(clixon_xml_yacc *xy,
	       char            *prefix,
	       char            *name,
	       char            *attval)
{
    int    retval = -1;
    cxobj *xa = NULL; 

    if ((xa = xml_find_type(xy->xy_xelement, prefix, name, CX_ATTR)) == NULL){
	if ((xa = xml_new(name, xy->xy_xelement, CX_ATTR)) == NULL)
	    goto done;
	if (xml_prefix_set(xa, prefix) < 0)
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
                 { if (xml_parse_version(_XY, $4) <0) YYABORT;
		     clicon_debug(2, "verinfo->version=\"STRING\"");}
            | VER '=' '\'' STRING '\'' 
         	 { if (xml_parse_version(_XY, $4) <0) YYABORT;
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

qname       : NAME           { if (xml_parse_prefixed_name(_XY, NULL, $1) < 0) YYABORT; 
                                clicon_debug(2, "qname -> NAME %s", $1);}
            | NAME ':' NAME  { if (xml_parse_prefixed_name(_XY, $1, $3) < 0) YYABORT; 
                                clicon_debug(2, "qname -> NAME : NAME");}
            ;

element1    :  ESLASH         {_XY->xy_xelement = NULL; 
                               clicon_debug(2, "element1 -> />");} 
            | '>'             { xml_parse_endslash_pre(_XY); }
              elist           { xml_parse_endslash_mid(_XY); }
              endtag          { xml_parse_endslash_post(_XY); 
                               clicon_debug(2, "element1 -> > elist endtag");} 
            ;

endtag      : BSLASH NAME '>'          
                       { clicon_debug(2, "endtag -> < </ NAME>");
			   if (xml_parse_bslash(_XY, NULL, $2) < 0) YYABORT; }

            | BSLASH NAME ':' NAME '>' 
                       { if (xml_parse_bslash(_XY, $2, $4) < 0) YYABORT; 
			 clicon_debug(2, "endtag -> < </ NAME:NAME >"); }
            ;

elist       : elist content { clicon_debug(2, "elist -> elist content"); }
            | content       { clicon_debug(2, "elist -> content"); }
            ;

/* Rule 43 */
content     : element      { clicon_debug(2, "content -> element"); }
            | comment      { clicon_debug(2, "content -> comment"); }
            | pi           { clicon_debug(2, "content -> pi"); }
            | CHARDATA     { if (xml_parse_content(_XY, $1) < 0) YYABORT;  
                             clicon_debug(2, "content -> CHARDATA %s", $1); }
            | WHITESPACE   { if (xml_parse_whitespace(_XY, $1) < 0) YYABORT;  
                             clicon_debug(2, "content -> WHITESPACE %s", $1); }
            |              { clicon_debug(2, "content -> "); }
            ;

comment     : BCOMMENT ECOMMENT
            ;

pi          : BQMARK NAME EQMARK {clicon_debug(2, "pi -> <? NAME ?>"); free($2); }
            | BQMARK NAME STRING EQMARK
 	        { clicon_debug(2, "pi -> <? NAME STRING ?>"); free($2); free($3);}
            ;


attrs       : attrs attr
            |
            ;

attr        : NAME '=' attvalue          { if (xml_parse_attr(_XY, NULL, $1, $3) < 0) YYABORT; }
            | NAME ':' NAME '=' attvalue { if (xml_parse_attr(_XY, $1, $3, $5) < 0) YYABORT; }
            ;

attvalue    : '\"' STRING '\"'   { $$=$2; /* $2 must be consumed */}
            | '\"'  '\"'       { $$=strdup(""); /* $2 must be consumed */}
            | '\'' STRING '\''   { $$=$2; /* $2 must be consumed */}
            | '\''  '\''       { $$=strdup(""); /* $2 must be consumed */}
            ;

%%

