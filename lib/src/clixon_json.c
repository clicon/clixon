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

 * JSON support functions.
 * JSON syntax is according to:
 * http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <fnmatch.h>
#include <stdint.h>
#include <syslog.h>
#include <assert.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_string.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_netconf_lib.h"
#include "clixon_json.h"
#include "clixon_json_parse.h"

#define JSON_INDENT 2 /* maybe we should set this programmatically? */

/* Let xml2json_cbuf_vec() return json array: [a,b].
   ALternative is to create a pseudo-object and return that: {top:{a,b}}
*/
#define VEC_ARRAY 1

/* Size of json read buffer when reading from file*/
#define BUFLEN 1024

/* Name of xml top object created by xml parse functions */
#define JSON_TOP_SYMBOL "top"

enum array_element_type{
    NO_ARRAY=0,
    FIRST_ARRAY,  /* [a, */
    MIDDLE_ARRAY, /*  a, */
    LAST_ARRAY,   /*  a] */
    SINGLE_ARRAY, /* [a] */
    BODY_ARRAY
};

enum childtype{
    NULL_CHILD=0, /* eg <a/> no children */
    BODY_CHILD,   /* eg one child which is a body, eg <a>1</a> */
    ANY_CHILD,    /* eg <a><b/></a> or <a><b/><c/></a> */
};

/*! x is element and has exactly one child which in turn has none 
 * remove attributes from x
 * Clone from clixon_xml_map.c
 */
static enum childtype
child_type(cxobj *x)
{
    cxobj *xc;   /* the only child of x */
    int    clen; /* nr of children */

    clen = xml_child_nr_notype(x, CX_ATTR);
    if (xml_type(x) != CX_ELMNT)
	return -1; /* n/a */
    if (clen == 0)
    	return NULL_CHILD;
    if (clen > 1)
	return ANY_CHILD;
    /* From here exactly one noattr child, get it */
    xc = NULL;
    while ((xc = xml_child_each(x, xc, -1)) != NULL)
	if (xml_type(xc) != CX_ATTR)
	    break;
    if (xc == NULL)
	return -2; /* n/a */
    if (xml_child_nr_notype(xc, CX_ATTR) == 0 && xml_type(xc)==CX_BODY)
	return BODY_CHILD;
    else
	return ANY_CHILD;
}

static char*
childtype2str(enum childtype lt)
{
    switch(lt){
    case NULL_CHILD:
	return "null";
	break;
    case BODY_CHILD:
	return "body";
	break;
    case ANY_CHILD:
	return "any";
	break;
    }
    return "";
}

static char*
arraytype2str(enum array_element_type lt)
{
    switch(lt){
    case NO_ARRAY:
	return "no";
	break;
    case FIRST_ARRAY:
	return "first";
	break;
    case MIDDLE_ARRAY:
	return "middle";
	break;
    case LAST_ARRAY:
	return "last";
	break;
    case SINGLE_ARRAY:
	return "single";
	break;
    case BODY_ARRAY:
	return "body";
	break;
    }
    return "";
}

/*! Check typeof x in array
 * Some complexity when x is in different namespaces
 */
static enum array_element_type
array_eval(cxobj *xprev, 
	   cxobj *x, 
	   cxobj *xnext)
{
    enum array_element_type array = NO_ARRAY;
    int                     eqprev=0;
    int                     eqnext=0;
    yang_stmt              *ys;
    char                   *nsx; /* namespace of x */
    char                   *ns2;

    nsx = xml_find_type_value(x, NULL, "xmlns", CX_ATTR);
    if (xml_type(x)!=CX_ELMNT){
	array=BODY_ARRAY;
	goto done;
    }
    ys = xml_spec(x);
    if (xnext && 
	xml_type(xnext)==CX_ELMNT &&
	strcmp(xml_name(x),xml_name(xnext))==0){
        ns2 = xml_find_type_value(xnext, NULL, "xmlns", CX_ATTR);
	if ((!nsx && !ns2)
	    || (nsx && ns2 && strcmp(nsx,ns2)==0))
	    eqnext++;
    }
    if (xprev &&
	xml_type(xprev)==CX_ELMNT &&
	strcmp(xml_name(x),xml_name(xprev))==0){
	ns2 = xml_find_type_value(xprev, NULL, "xmlns", CX_ATTR);
	if ((!nsx && !ns2)
	    || (nsx && ns2 && strcmp(nsx,ns2)==0))
	    eqprev++;
    }
    if (eqprev && eqnext)
	array = MIDDLE_ARRAY;
    else if (eqprev)
	array = LAST_ARRAY;
    else if (eqnext)
	array = FIRST_ARRAY;
    else  if (ys && ys->ys_keyword == Y_LIST)
	array = SINGLE_ARRAY;
    else
	array = NO_ARRAY;
 done:
    return array;
}

/*! Escape a json string as well as decode xml cdata
 * And a
 */
static int
json_str_escape_cdata(cbuf *cb,
		      char *str)
{
    int   retval = -1;
    int   i;
    int   esc = 0; /* cdata escape */

    for (i=0;i<strlen(str);i++)
	switch (str[i]){
	case '\n':
	    cprintf(cb, "\\n");
	    break;
	case '\"':
	    cprintf(cb, "\\\"");
	    break;
	case '\\':
	    cprintf(cb, "\\\\");
	    break;
	case '<':
	    if (!esc &&
		strncmp(&str[i], "<![CDATA[", strlen("<![CDATA[")) == 0){
		esc=1;
		i += strlen("<![CDATA[")-1;
	    }
	    else
		cprintf(cb, "%c", str[i]);
	    break;
	case ']':
	    if (esc &&
		strncmp(&str[i], "]]>", strlen("]]>")) == 0){
		esc=0;
		i += strlen("]]>")-1;
	    }
	    else
		cprintf(cb, "%c", str[i]);
	    break;
	default: /* fall thru */
	    cprintf(cb, "%c", str[i]);
	    break;
	}
    retval = 0;
    // done:
    return retval;
}

/*! Do the actual work of translating XML to JSON 
 * @param[out]   cb        Cligen text buffer containing json on exit
 * @param[in]    x         XML tree structure containing XML to translate
 * @param[in]    arraytype Does x occur in a array (of its parent) and how?
 * @param[in]    level     Indentation level
 * @param[in]    pretty    Pretty-print output (2 means debug)
 * @param[in]    flat      Dont print NO_ARRAY object name (for _vec call)
 * @param[in]    bodystr   Set if value is string, 0 otherwise. Only if body
 *
 * @note Does not work with XML attributes
 * The following matrix explains how the mapping is done.
 * You need to understand what arraytype means (no/first/middle/last)
 * and what childtype is (null,body,any)
  +----------+--------------+--------------+--------------+
  |array,leaf| null         | body         | any          |
  +----------+--------------+--------------+--------------+
  |no        | <a/>         |<a>1</a>      |<a><b/></a>   |
  |          |              |              |              |
  |  json:   |\ta:null      |\ta:          |\ta:{\n       |
  |          |              |              |\n}           |
  +----------+--------------+--------------+--------------+
  |first     |<a/><a..      |<a>1</a><a..  |<a><b/></a><a.|
  |          |              |              |              |
  |  json:   |\ta:[\n\tnull |\ta:[\n\t     |\ta:[\n\t{\n  |
  |          |              |              |\n\t}         |
  +----------+--------------+--------------+--------------+
  |middle    |..a><a/><a..  |.a><a>1</a><a.|              |
  |          |              |              |              |
  |  json:   |\tnull        |\t            |\t{a          |
  |          |              |              |\n\t}         |
  +----------+--------------+--------------+--------------+
  |last      |..a></a>      |..a><a>1</a>  |              |
  |          |              |              |              |
  |  json:   |\tnull        |\t            |\t{a          |
  |          |\n\t]         |\n\t]         |\n\t}\t]      |
  +----------+--------------+--------------+--------------+
 */
static int 
xml2json1_cbuf(cbuf                   *cb,
	       cxobj                  *x,
	       enum array_element_type arraytype,
	       int                     level,
	       int                     pretty,
	       int                     flat,
	       int                     bodystr)
{
    int              retval = -1;
    int              i;
    cxobj           *xc;
    enum childtype   childt;
    enum array_element_type xc_arraytype;
    yang_stmt       *ys;
    yang_stmt       *ymod; /* yang module */
    yang_stmt       *yspec = NULL; /* yang spec */
    int              bodystr0=1;
    char            *prefix=NULL;    /* prefix / local namespace name */
    char            *namespace=NULL; /* namespace uri */
    char            *modname=NULL;   /* Module name */
    int              commas;

    /* If x is labelled with a default namespace, it should be translated
     * to a module name. 
     * Harder if x has a prefix, then that should also be translated to associated
     * module name
     */
    prefix = xml_prefix(x);
    namespace = xml_find_type_value(x, prefix, "xmlns", CX_ATTR);

    if ((ys = xml_spec(x)) != NULL) /* yang spec associated with x */
	yspec = ys_spec(ys);
    /* Find module name associated with namspace URI */
    if (namespace && yspec &&
	(ymod = yang_find_module_by_namespace(yspec, namespace)) != NULL){
	modname = ymod->ys_argument;
    }
    childt = child_type(x);
    if (pretty==2)
	cprintf(cb, "#%s_array, %s_child ", 
		arraytype2str(arraytype),
		childtype2str(childt));
    switch(arraytype){
    case BODY_ARRAY:{
	if (bodystr){
	    /* XXX String if right type */
	    cprintf(cb, "\"");
	    if (json_str_escape_cdata(cb, xml_value(x)) < 0)
		goto done;
	    cprintf(cb, "\"");
	}
	else
	    cprintf(cb, "%s", xml_value(x));
	break;
    }
    case NO_ARRAY:
	if (!flat){
	    cprintf(cb, "%*s\"", pretty?(level*JSON_INDENT):0, "");
	    if (modname) /* XXX should remove this? */
		cprintf(cb, "%s:", modname);
	    cprintf(cb, "%s\": ", xml_name(x));
	}
	switch (childt){
	case NULL_CHILD:
	    cprintf(cb, "null");
	    break;
	case BODY_CHILD:
	    break;
	case ANY_CHILD:
	    cprintf(cb, "{%s", pretty?"\n":"");
	    break;
	default:
	    break;
	}
	break;
    case FIRST_ARRAY:
    case SINGLE_ARRAY:
	cprintf(cb, "%*s\"", pretty?(level*JSON_INDENT):0, "");
	if (modname)
	    cprintf(cb, "%s:", modname);
	cprintf(cb, "%s\": ", xml_name(x));
	level++;
	cprintf(cb, "[%s%*s", 
		pretty?"\n":"",
		pretty?(level*JSON_INDENT):0, "");
	switch (childt){
	case NULL_CHILD:
	    cprintf(cb, "null");
	    break;
	case BODY_CHILD:
	    break;
	case ANY_CHILD:
	    cprintf(cb, "{%s", pretty?"\n":"");
	    break;
	default:
	    break;
	}
	break;
    case MIDDLE_ARRAY:
    case LAST_ARRAY:
	level++;
	cprintf(cb, "%*s", 
		pretty?(level*JSON_INDENT):0, "");
	switch (childt){
	case NULL_CHILD:
	    cprintf(cb, "null");
	    break;
	case BODY_CHILD:
	    break;
	case ANY_CHILD:
	    cprintf(cb, "{ %s", pretty?"\n":"");
	    break;
	default:
	    break;
	}
	break;
    default:
	break;
    }
    /* Check for typed sub-body if:
     * arraytype=* but child-type is BODY_CHILD 
     * This is code for writing <a>42</a> as "a":42 and not "a":"42"
     */
    if (childt == BODY_CHILD && ys!=NULL &&
	(ys->ys_keyword == Y_LEAF || ys->ys_keyword == Y_LEAF_LIST))
	switch (cv_type_get(ys->ys_cv)){
	case CGV_INT8:
	case CGV_INT16:
	case CGV_INT32:
	case CGV_INT64:
	case CGV_UINT8:
	case CGV_UINT16:
	case CGV_UINT32:
	case CGV_UINT64:
	case CGV_DEC64:
	case CGV_BOOL:
	    bodystr0 = 0;
	    break;
	default:
	    bodystr0 = 1;
	    break;
	}

    commas = xml_child_nr_notype(x, CX_ATTR) - 1;
    for (i=0; i<xml_child_nr(x); i++){
	xc = xml_child_i(x, i);
	if (xml_type(xc) == CX_ATTR)
	    continue; /* XXX Only xmlns attributes mapped */
	xc_arraytype = array_eval(i?xml_child_i(x,i-1):NULL, 
				xc, 
				xml_child_i(x, i+1));
	if (xml2json1_cbuf(cb, 
			   xc, 
			   xc_arraytype,
			   level+1, pretty, 0, bodystr0) < 0)
	    goto done;
	if (commas > 0) {
	    cprintf(cb, ",%s", pretty?"\n":"");
	    --commas;
	}
    }
    switch (arraytype){
    case BODY_ARRAY:
	break;
    case NO_ARRAY:
	switch (childt){
	case NULL_CHILD:
	case BODY_CHILD:
	    break;
	case ANY_CHILD:
	    cprintf(cb, "%s%*s}", 
		    pretty?"\n":"",
		    pretty?(level*JSON_INDENT):0, "");
	    break;
	default:
	    break;
	}
	level--;
	break;
    case FIRST_ARRAY:
    case MIDDLE_ARRAY:
	switch (childt){
	case NULL_CHILD:
	case BODY_CHILD:
	    break;
	case ANY_CHILD:
	    cprintf(cb, "%s%*s}", 
		    pretty?"\n":"",
		    pretty?(level*JSON_INDENT):0, "");
	    level--;
	    break;
	default:
	    break;
	}
	break;
    case SINGLE_ARRAY:
    case LAST_ARRAY:
	switch (childt){
	case NULL_CHILD:
	case BODY_CHILD:
	    cprintf(cb, "%s",pretty?"\n":"");
	    break;
	case ANY_CHILD:
	    cprintf(cb, "%s%*s}", 
		    pretty?"\n":"",
		    pretty?(level*JSON_INDENT):0, "");
	    cprintf(cb, "%s",pretty?"\n":"");
	    level--;
	    break;
	default:
	    break;
	}
	cprintf(cb, "%*s]",
		pretty?(level*JSON_INDENT):0,"");
	break;
    default:
	break;
    }
    retval = 0;
 done:
    return retval;
}

/*! Translate an XML tree to JSON in a CLIgen buffer
 *
 * @param[in,out] cb     Cligen buffer to write to
 * @param[in]     x      XML tree to translate from
 * @param[in]     pretty Set if output is pretty-printed
 * @param[in]     top    By default only children are printed, set if include top
 * @retval        0      OK
 * @retval       -1      Error
 *
 * @code
 * cbuf *cb;
 * cb = cbuf_new();
 * if (xml2json_cbuf(cb, xn, 0, 1) < 0)
 *   goto err;
 * cbuf_free(cb);
 * @endcode
 * @see clicon_xml2cbuf
 */
int 
xml2json_cbuf(cbuf      *cb, 
	      cxobj     *x, 
	      int        pretty)
{
    int    retval = 1;
    int    level = 0;
    char  *prefix;
    char  *namespace;

    cprintf(cb, "%*s{%s", 
	    pretty?level*JSON_INDENT:0,"", 
	    pretty?"\n":"");
    /* If x is labelled with a default namespace, it should be translated
     * to a module name. 
     * Harder if x has a prefix, then that should also be translated to associated
     * module name
     */
    prefix = xml_prefix(x);
    if (xml2ns(x, prefix, &namespace) < 0)
	goto done;
    /* Some complexities in grafting namespace in existing trees to new */
    if (xml_find_type_value(x, prefix, "xmlns", CX_ATTR) == NULL && namespace)
	if (xmlns_set(x, prefix, namespace) < 0)
		goto done;
    if (xml2json1_cbuf(cb, 
		       x, 
		       NO_ARRAY,
		       level+1, pretty,0,1) < 0)
	goto done;
    cprintf(cb, "%s%*s}%s", 
	    pretty?"\n":"",
	    pretty?level*JSON_INDENT:0,"",
	    pretty?"\n":"");

    retval = 0;
 done:
    return retval;
}

/*! Translate a vector of xml objects to JSON Cligen buffer.
 * This is done by adding a top pseudo-object, and add the vector as subs,
 * and then not printing the top pseudo-object using the 'flat' option.
 * @param[out] cb     Cligen buffer to write to
 * @param[in]  vec    Vector of xml objecst
 * @param[in]  veclen Length of vector
 * @param[in]  pretty Set if output is pretty-printed (2 for debug)
 * @retval     0      OK
 * @retval    -1      Error
 * @note This only works if the vector is uniform, ie same object name.
 * Example: <b/><c/> --> <a><b/><c/></a> --> {"b" : null,"c" : null}
 * @see xml2json1_cbuf
 */
int 
xml2json_cbuf_vec(cbuf      *cb, 
		  cxobj    **vec,
		  size_t     veclen,
		  int        pretty)
{
    int    retval = -1;
    int    level = 0;
    int    i;
    cxobj *xp = NULL;
    cxobj *xc;
    char  *prefix;
    char  *namespace;

    if ((xp = xml_new("xml2json", NULL, NULL)) == NULL)
	goto done;
    /* Some complexities in grafting namespace in existing trees to new */
    for (i=0; i<veclen; i++){
	prefix = xml_prefix(vec[i]);
	if (xml2ns(vec[i], prefix, &namespace) < 0)
	    goto done;
	xc = xml_dup(vec[i]);
	xml_addsub(xp, xc);
	if (xml_find_type_value(xc, prefix, "xmlns", CX_ATTR) == NULL && namespace)
	    if (xmlns_set(xc, prefix, namespace) < 0)
		goto done;
    }
    if (0){
	cprintf(cb, "[%s", pretty?"\n":" ");
	level++;
    }
    if (xml2json1_cbuf(cb, 
		       xp, 
		       NO_ARRAY,
		       level+1, pretty,1, 1) < 0)
	goto done;

    if (0){
	level--;
	cprintf(cb, "%s]%s", 
	    pretty?"\n":"",
	    pretty?"\n":""); /* top object */
    }
    retval = 0;
 done:
    if (xp)
	xml_free(xp);
    return retval;
}

/*! Translate from xml tree to JSON and print to file
 * @param[in]  f      File to print to
 * @param[in]  x      XML tree to translate from
 * @param[in]  pretty Set if output is pretty-printed
 * @retval     0      OK
 * @retval    -1      Error
 *
 * @note yang is necessary to translate to one-member lists,
 * eg if a is a yang LIST <a>0</a> -> {"a":["0"]} and not {"a":"0"}
 * @code
 * if (xml2json(stderr, xn, 0) < 0)
 *   goto err;
 * @endcode
 */
int 
xml2json(FILE      *f, 
	 cxobj     *x, 
	 int        pretty)
{
    int   retval = 1;
    cbuf *cb = NULL;

    if ((cb = cbuf_new()) ==NULL){
	clicon_err(OE_XML, errno, "cbuf_new");
	goto done;
    }
    if (xml2json_cbuf(cb, x, pretty) < 0)
	goto done;
    fprintf(f, "%s", cbuf_get(cb));
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Translate a vector of xml objects to JSON File.
 * This is done by adding a top pseudo-object, and add the vector as subs,
 * and then not pritning the top pseudo-.object using the 'flat' option.
 * @param[out] cb     Cligen buffer to write to
 * @param[in]  vec    Vector of xml objecst
 * @param[in]  veclen Length of vector
 * @param[in]  pretty Set if output is pretty-printed (2 for debug)
 * @retval     0      OK
 * @retval    -1      Error
 * @note This only works if the vector is uniform, ie same object name.
 * Example: <b/><c/> --> <a><b/><c/></a> --> {"b" : null,"c" : null}
 * @see xml2json1_cbuf
 */
int 
xml2json_vec(FILE      *f, 
	     cxobj    **vec,
	     size_t     veclen,
	     int        pretty)
{
    int   retval = 1;
    cbuf *cb = NULL;

    if ((cb = cbuf_new()) ==NULL){
	clicon_err(OE_XML, errno, "cbuf_new");
	goto done;
    }
    if (xml2json_cbuf_vec(cb, vec, veclen, pretty) < 0)
	goto done;
    fprintf(f, "%s", cbuf_get(cb));
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Translate from JSON module:name to XML name xmlns="uri" recursively
 * @param[in]     yspec Yang spec
 * @param[in,out] x     XML tree. Translate it in-line
 * @param[out]    xerr  If namespace not set, create xml error tree
 * @retval        0     OK (if xerr set see above)
 * @retval       -1     Error
 * @note the opposite - xml2ns is made inline in xml2json1_cbuf
 */
int
json2xml_ns(yang_stmt *yspec,
	    cxobj     *x,
	    cxobj    **xerr)
{
    int        retval = -1;
    yang_stmt *ymod;
    char      *namespace0;
    char      *namespace;
    char      *name = NULL;
    char      *prefix = NULL;
    cxobj     *xc;
    
    if (nodeid_split(xml_name(x), &prefix, &name) < 0)
	goto done;
    if (prefix != NULL){
	if ((ymod = yang_find_module_by_name(yspec, prefix)) == NULL){
	    if (netconf_unknown_namespace_xml(xerr, "application",
					      prefix,
					      "No yang module found corresponding to prefix") < 0)
		goto done;
	    goto ok;
	}
	namespace = yang_find_mynamespace(ymod);
	/* Get existing default namespace in tree */
	if (xml2ns(x, NULL, &namespace0) < 0)
	    goto done;
	/* Set xmlns="" default namespace attribute (if diff from default) */
	if (namespace0==NULL || strcmp(namespace0, namespace))
	    if (xmlns_set(x, NULL, namespace) < 0)
		goto done;
	/* Remove prefix from name */
	if (xml_name_set(x, name) < 0)
	    goto done;
    }
    xc = NULL;
    while ((xc = xml_child_each(x, xc, CX_ELMNT)) != NULL){
	if (json2xml_ns(yspec, xc, xerr) < 0)
	    goto done;
	if (*xerr != NULL)
	    break;
    }
 ok:
    retval = 0;
 done:
    if (prefix)
	free(prefix);
    if (name)
	free(name);
    return retval;
}

/*! Parse a string containing JSON and return an XML tree
 * @param[in]  str    Input string containing JSON
 * @param[in]  name   Log string, typically filename
 * @param[out] xt     XML top of tree typically w/o children on entry (but created)
 */
static int 
json_parse(char       *str, 
	   const char *name, 
	   cxobj      *xt)
{
    int                         retval = -1;
    struct clicon_json_yacc_arg jy = {0,};

    //    clicon_debug(1, "%s", __FUNCTION__);
    jy.jy_parse_string = str;
    jy.jy_name = name;
    jy.jy_linenum = 1;
    jy.jy_current = xt;
    if (json_scan_init(&jy) < 0)
	goto done;
    if (json_parse_init(&jy) < 0)
	goto done;
    if (clixon_json_parseparse(&jy) != 0) { /* yacc returns 1 on error */
	clicon_log(LOG_NOTICE, "JSON error: %s on line %d", name, jy.jy_linenum);
	if (clicon_errno == 0)
	    clicon_err(OE_XML, 0, "JSON parser error with no error code (should not happen)");
	goto done;
    }
    retval = 0;
 done:
    //    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    json_parse_exit(&jy);
    json_scan_exit(&jy);
    return retval; 
}

/*! Parse string containing JSON and return an XML tree
 *
 * @param[in]  str   String containing JSON
 * @param[out] xt    On success a top of XML parse tree is created with name 'top'
 * @retval  0  OK
 * @retval -1  Error with clicon_err called. Includes parse errors
 *
 * @code
 *  cxobj *cx = NULL;
 *  if (json_parse_str(str, &cx) < 0)
 *    err;
 *  xml_free(cx);
 * @endcode
 * @note  you need to free the xml parse tree after use, using xml_free()
 */
int 
json_parse_str(char   *str, 
	       cxobj **xt)
{
    if (*xt == NULL)
	if ((*xt = xml_new("top", NULL, NULL)) == NULL)
	    return -1;
    return json_parse(str, "", *xt);
}

/*! Read a JSON definition from file and parse it into a parse-tree. 
 *
 * @param[in]  fd  A file descriptor containing the JSON file (as ASCII characters)
 * @param[in]  yspec   Yang specification, or NULL XXX Not yet used
 * @param[in,out] xt   Pointer to (XML) parse tree. If empty, create.
 * @retval        0  OK
 * @retval       -1  Error with clicon_err called
 *
 * @code
 *  cxobj *xt = NULL;
 *  if (json_parse_file(0, NULL, &xt) < 0)
 *    err;
 *  xml_free(xt);
 * @endcode
 * @note  you need to free the xml parse tree after use, using xml_free()
 * @note, If xt empty, a top-level symbol will be added so that <tree../> will be:  <top><tree.../></tree></top>
 * @note May block on file I/O
 */
int 
json_parse_file(int        fd,
		yang_stmt *yspec,
		cxobj    **xt)
{
    int   retval = -1;
    int   ret;
    char *jsonbuf = NULL;
    int   jsonbuflen = BUFLEN; /* start size */
    int   oldjsonbuflen;
    char *ptr;
    char  ch;
    int   len = 0;
    
    if ((jsonbuf = malloc(jsonbuflen)) == NULL){
	clicon_err(OE_XML, errno, "malloc");
	goto done;
    }
    memset(jsonbuf, 0, jsonbuflen);
    ptr = jsonbuf;
    while (1){
	if ((ret = read(fd, &ch, 1)) < 0){
	    clicon_err(OE_XML, errno, "read");
	    break;
	}
	if (ret != 0)
	    jsonbuf[len++] = ch;
	if (ret == 0){
	    if (*xt == NULL)
		if ((*xt = xml_new(JSON_TOP_SYMBOL, NULL, NULL)) == NULL)
		    goto done;
	    if (len && json_parse(ptr, "", *xt) < 0)
		goto done;
	    break;
	}
	if (len>=jsonbuflen-1){ /* Space: one for the null character */
	    oldjsonbuflen = jsonbuflen;
	    jsonbuflen *= 2;
	    if ((jsonbuf = realloc(jsonbuf, jsonbuflen)) == NULL){
		clicon_err(OE_XML, errno, "realloc");
		goto done;
	    }
	    memset(jsonbuf+oldjsonbuflen, 0, jsonbuflen-oldjsonbuflen);
	    ptr = jsonbuf;
	}
    }
    retval = 0;
 done:
    if (retval < 0 && *xt){
	free(*xt);
	*xt = NULL;
    }
    if (jsonbuf)
	free(jsonbuf);
    return retval;    
}


