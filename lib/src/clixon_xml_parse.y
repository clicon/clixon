/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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

%token <string> NAME CHARDATA ENCODED WHITESPACE STRING
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
#include <strings.h>
#include <errno.h>
#include <stdlib.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_string.h"
#include "clixon_handle.h"
#include "clixon_xml_sort.h"
#include "clixon_xml_parse.h"

/* Enable for debugging, steals some cycles otherwise */
#if 0
#define _PARSE_DEBUG(s) clixon_debug(CLIXON_DBG_PARSE|CLIXON_DBG_DETAIL,(s))
#else
#define _PARSE_DEBUG(s)
#endif

void
clixon_xml_parseerror(void *_xy,
                      char *s)
{
    clixon_err(OE_XML, XMLPARSE_ERRNO, "xml_parse: line %d: %s: at or before: %s",
               _XY->xy_linenum,
               s,
               clixon_xml_parsetext);
    return;
}

/*! Flush accumulated body content from xy_cbuf to a CX_BODY child of xy_xparent
 *
 * Called before any context transition that changes xy_xparent, to ensure
 * accumulated CHARDATA/WHITESPACE tokens are attached to the correct parent.
 * No-op if nothing has been accumulated.
 * @param[in]  xy    XML parser yacc handler struct
 * @retval     0     OK
 * @retval    -1     Error
 */
static int
xml_parse_flush_content(clixon_xml_yacc *xy)
{
    int    retval = -1;
    cxobj *xn;

    if (cbuf_len(xy->xy_cbuf) == 0){
        retval = 0;
        goto done;
    }
    if ((xn = xml_new("body", xy->xy_xparent, CX_BODY)) == NULL)
        goto done;
    if (xml_value_append(xn, cbuf_get(xy->xy_cbuf)) < 0)
        goto done;
    cbuf_reset(xy->xy_cbuf);
    retval = 0;
  done:
    return retval;
}

/*! Parse XML content, eg chars between >...<
 *
 * Tokens are accumulated in xy_cbuf; a body node is created by
 * xml_parse_flush_content() at the next context transition.
 * @param[in]  xy
 * @param[in]  encoded set if ampersand-encoded numeric character reference (&#N; or &#xN;)
 * @param[in]  str     Body string, direct pointer (copy before use, dont free)
 * @retval     0       OK
 * @retval    -1       Error
 */
static int
xml_parse_content(clixon_xml_yacc *xy,
                  int              encoded,
                  const char      *str)
{
    if (encoded)
        cprintf(xy->xy_cbuf, "&%s", str);
    else
        cprintf(xy->xy_cbuf, "%s", str);
    return 0;
}

/*! Add whitespace
 *
 * If text, ie only body, keep as is.
 * But if there is an element, then skip all whitespace.
 * @retval     0       OK
 * @retval    -1       Error
 */
static int
xml_parse_whitespace(clixon_xml_yacc *xy,
                     char            *str)
{
    int    retval = -1;
    cxobj *xp = xy->xy_xparent;
    int    i;

    /* If there is an element child already, skip whitespace.
     * Note that this xml element is not aware of YANG yet.
     * For example, if xp is LEAF then a body child is OK, but if xp is CONTAINER
     * then the whitespace body is pretty-print and should be stripped (later).
     */
    for (i=0; i<xml_child_nr(xp); i++){
        if (xml_type(xml_child_i(xp, i)) == CX_ELMNT)
            goto ok; /* Skip if already element */
    }
    cprintf(xy->xy_cbuf, "%s", str);
 ok:
    retval = 0;
    return retval;
}

static int
xml_parse_version(clixon_xml_yacc *xy,
                  char            *ver)
{
    if(strcmp(ver, "1.0")){
        clixon_err(OE_XML, XMLPARSE_ERRNO, "Unsupported XML version: %s expected 1.0", ver);
        free(ver);
        return -1;
    }
    if (ver)
        free(ver);
    return 0;
}

/*! Parse XML encoding
 *
 * From under Encoding Declaration:
 * In an encoding declaration, the values UTF-8, UTF-16, ISO-10646-UCS-2, and ISO-10646-UCS-4
 * SHOULD be used for the various encodings and transformations of Unicode / ISO/IEC 10646, the 
 * values ISO-8859-1, ISO-8859-2, ... ISO-8859- n (where n is the part number) SHOULD be used for
 * the parts of ISO 8859, and the values ISO-2022-JP, Shift_JIS, and EUC-JP " SHOULD be used for
 * the various encoded forms of JIS X-0208-1997.
 * [UTF-8 is default]
 * Note that since ASCII is a subset of UTF-8, ordinary ASCII entities do not strictly need an
 * encoding declaration.
 *
 * Clixon supports only UTF-8 (or no declaration)
 */
static int
xml_parse_encoding(clixon_xml_yacc *xy,
                   char            *enc)
{
    if(strcasecmp(enc, "UTF-8")){
        clixon_err(OE_XML, XMLPARSE_ERRNO, "Unsupported XML encoding: %s expected UTF-8", enc);
        free(enc);
        return -1;
    }
    return 0;
}

/*! Parse Qualified name -> (Un)PrefixedName
 *
 * This is where all (parsed) xml elements are created
 * @param[in] xy        XML parser yacc handler struct 
 * @param[in] prefix    Prefix, namespace, or NULL
 * @param[in] localpart Name
 * @retval    0         OK
 * @retval   -1         Error
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
    /* Flush any accumulated body content before attaching a new child element */
    if (xml_parse_flush_content(xy) < 0)
        goto done;
    if ((x = xml_new(name, xp, CX_ELMNT)) == NULL)
        goto done;
    /* Cant check namespaces here since local xmlns attributes loaded after */
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
    /* Flush accumulated body content before navigating up to parent */
    if (xml_parse_flush_content(xy) < 0)
        return -1;
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
 * @retval    0        OK
 * @retval   -1        Error
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
    int    ix;

    /* These are existing tags */
    prefix0 = xml_prefix(x);
    name0 = xml_name(x);
    /* Check name or prerix unequal from begin-tag */
    if (clicon_strcmp(name0, name) ||
        clicon_strcmp(prefix0, prefix)){
        clixon_err(OE_XML, XMLPARSE_ERRNO, "Sanity check failed: %s%s%s vs %s%s%s",
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
    ix = 0;
    while ((xc = xml_child_iter(x, &ix, CX_ELMNT)) != NULL)
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
 *
 * Special cases:
 *  - DefaultAttName:  xmlns
 *  - PrefixedAttName: xmlns:NAME
 * @retval     0       OK
 * @retval    -1       Error
 */
static int
xml_parse_attr(clixon_xml_yacc *xy,
               char            *prefix,
               char            *name,
               char            *attval)
{
    int    retval = -1;
    cxobj *xa = NULL;

    /* XXX: here duplicates of same attributes are removed 
     * This is probably not according standard?
     */
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
                 { _PARSE_DEBUG("document->prolog element misc* ACCEPT");
                   YYACCEPT; }
            | elist MY_EOF
            { _PARSE_DEBUG("document->elist ACCEPT");  /* internal exception*/
                   YYACCEPT; }
            ;
/* [22] prolog ::=  XMLDecl? Misc* (doctypedecl Misc*)? */
prolog      : xmldcl misclist
                { _PARSE_DEBUG("prolog->xmldcl misc*"); }
            | misclist
                { _PARSE_DEBUG("prolog->misc*"); }
            ;

misclist    : misclist misc { _PARSE_DEBUG("misclist->misclist misc"); }
            |     { _PARSE_DEBUG("misclist->"); }
            ;

/* [27] Misc ::=  Comment | PI | S */
misc        : comment    { _PARSE_DEBUG("misc->comment"); }
            | pi         { _PARSE_DEBUG("misc->pi"); }
            | WHITESPACE { _PARSE_DEBUG("misc->white space"); }
            ;

/* [23] XMLDecl ::=     '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'*/
xmldcl      : BXMLDCL verinfo encodingdecl sddecl EQMARK
                  { _PARSE_DEBUG("xmldcl->verinfo encodingdecl? sddecl?"); }
            ;

verinfo     : VER '=' '\"' STRING '\"'
                 { if (xml_parse_version(_XY, $4) <0) YYABORT;
                     _PARSE_DEBUG("verinfo->version=\"STRING\"");}
            | VER '=' '\'' STRING '\''
                 { if (xml_parse_version(_XY, $4) <0) YYABORT;
                     _PARSE_DEBUG("verinfo->version='STRING'");}
            ;

encodingdecl : ENC '=' '\"' STRING '\"'
                 { if (xml_parse_encoding(_XY, $4) <0) YYABORT; if ($4)free($4);
                     _PARSE_DEBUG("encodingdecl-> encoding = \" STRING \"");}
            | ENC '=' '\'' STRING '\''
                 { if (xml_parse_encoding(_XY, $4) <0) YYABORT; if ($4)free($4);
                     _PARSE_DEBUG("encodingdecl-> encoding = ' STRING '");}
            |
            ;

sddecl      : SD '=' '\"' STRING '\"' {if ($4)free($4);}
            | SD '=' '\'' STRING '\'' {if ($4)free($4);}
            |
            ;
/* [39] element ::= EmptyElemTag | STag content ETag */
element     : '<' qname  attrs element1
                   { _PARSE_DEBUG("element -> < qname attrs element1"); }
            ;

qname       : NAME           { if (xml_parse_prefixed_name(_XY, NULL, $1) < 0) YYABORT;
                                _PARSE_DEBUG("qname -> NAME");}
            | NAME ':' NAME  { if (xml_parse_prefixed_name(_XY, $1, $3) < 0) YYABORT;
                                _PARSE_DEBUG("qname -> NAME : NAME");}
            ;

element1    :  ESLASH         {_XY->xy_xelement = NULL;
                               _PARSE_DEBUG("element1 -> />");}
            | '>'             { xml_parse_endslash_pre(_XY); }
              elist           { xml_parse_endslash_mid(_XY); }
              endtag          { xml_parse_endslash_post(_XY);
                               _PARSE_DEBUG("element1 -> elist endtag");}
            ;

endtag      : BSLASH NAME '>'
                       { _PARSE_DEBUG("endtag -> < </ NAME>");
                           if (xml_parse_bslash(_XY, NULL, $2) < 0) YYABORT; }

            | BSLASH NAME ':' NAME '>'
                       { if (xml_parse_bslash(_XY, $2, $4) < 0) YYABORT;
                         _PARSE_DEBUG("endtag -> < </ NAME:NAME >"); }
            ;

elist       : elist content { _PARSE_DEBUG("elist -> elist content"); }
            | content       { _PARSE_DEBUG("elist -> content"); }
            ;

/* Rule 43 */
content     : element      { _PARSE_DEBUG("content -> element"); }
            | comment      { _PARSE_DEBUG("content -> comment"); }
            | pi           { _PARSE_DEBUG("content -> pi"); }
            | CHARDATA     { if (xml_parse_content(_XY, 0, $1) < 0) YYABORT;
                             _PARSE_DEBUG("content -> CHARDATA"); }
            | ENCODED      { if (xml_parse_content(_XY, 1, $1) < 0) YYABORT;
                             _PARSE_DEBUG("content -> ENCODED"); }
            | WHITESPACE   { if (xml_parse_whitespace(_XY, $1) < 0) YYABORT;
                             _PARSE_DEBUG("content -> WHITESPACE"); }
            |              { _PARSE_DEBUG("content -> "); }
            ;

comment     : BCOMMENT ECOMMENT
            ;

pi          : BQMARK NAME EQMARK {_PARSE_DEBUG("pi -> <? NAME ?>"); free($2); }
            | BQMARK NAME STRING EQMARK
                { _PARSE_DEBUG("pi -> <? NAME STRING ?>"); free($2); free($3);}
            ;

attrs       : attrs attr { _PARSE_DEBUG("attrs -> attrs attr"); }
            |            { _PARSE_DEBUG("attrs ->"); }
            ;

attr        : NAME '=' attvalue          { if (xml_parse_attr(_XY, NULL, $1, $3) < 0) YYABORT;
                                           _PARSE_DEBUG("attr -> NAME = attvalue"); }
            | NAME ':' NAME '=' attvalue { if (xml_parse_attr(_XY, $1, $3, $5) < 0) YYABORT;
                                           _PARSE_DEBUG("attr -> NAME : NAME = attvalue"); }
            ;

attvalue    : '\"' STRING '\"'   { $$=$2; /* $2 must be consumed */}
            | '\"'  '\"'       { $$=strdup(""); /* $2 must be consumed */}
            | '\'' STRING '\''   { $$=$2; /* $2 must be consumed */}
            | '\''  '\''       { $$=strdup(""); /* $2 must be consumed */}
            ;

%%
