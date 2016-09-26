/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

  * For unit testing compile with -_MAIN:
  * 
 * JSON support functions.

curl -G http://localhost/api/data/sender/userid=a4315f60-e890-4f8f-9a0b-eb53d4da2d3a

[{
  "sender": {
    "name": "dk-ore",
    "userid": "a4315f60-e890-4f8f-9a0b-eb53d4da2d3a",
    "ipv4_daddr": "109.105.110.78",
    "template": "nordunet",
    "version": "0",
    "description": "Nutanix ORE",
    "start": "true",
    "udp_dport": "43713",
    "debug": "0",
    "proto": "udp"
  }

is translated into this:
[
    {"sender":
     ["name":"dk-ore",
      "userid":"a4315f60-e890-4f8f-9a0b-eb53d4da2d3a",
      "ipv4_daddr":"109.105.110.78",
      "template":"nordunet",
      "version":"0",
      "description":"Nutanix ORE",
      "start":"true",
      "udp_dport":"43713",
      "debug":"0",
      "proto":"udp"}
     ,
     {"name":"dk-uni",


-------------------------

<t>
  <sender>
    <name>hunerik</name>
  </sender>
  <sender>
    <name>foo</name>
  </sender>
</t>

{ "t":
 {
  "sender": {
    "name": "hunerik"
   },
  "sender": {
    "name": "foo"
   }
 }
}

{
  "t": {
    "sender": [
      { "name": "hunerik" },
      { "name": "foo" }
    ]
  }
}

OK, still something wrong with grafana plots

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
#include "clixon_xml.h"
#include "clixon_json.h"
#include "clixon_json_parse.h"

#define JSON_INDENT 3 /* maybe we should set this programmatically? */

/*! x is element and has eactly one child which in turn has none 
 * Clone from clixon_xml_map.c
 */
static int
tleaf(cxobj *x)
{
    cxobj *c;

    if (xml_type(x) != CX_ELMNT)
	return 0;
    if (xml_child_nr(x) != 1)
	return 0;
    c = xml_child_i(x, 0);
    return (xml_child_nr(c) == 0);
}


enum list_element_type{
    LIST_NO,
    LIST_FIRST,
    LIST_MIDDLE,
    LIST_LAST
};

static enum list_element_type
list_eval(cxobj *x)
{
    enum list_element_type list = LIST_NO;
    cxobj                 *xp;
    cxobj                 *xprev=NULL;
    cxobj                 *xnext=NULL;
    int                    i;
    int                    eqprev=0;
    int                    eqnext=0;

    assert(xml_type(x)==CX_ELMNT);
    if ((xp = xml_parent(x)) == NULL)
	goto done;
    for (i=0; i<xml_child_nr(xp); i++)
	if (x == xml_child_i(xp, i))
	    break;
    assert(i<xml_child_nr(xp));
    if (i < xml_child_nr(xp)-1){
	xnext = xml_child_i(xp, i+1);
	if (xml_type(xnext)==CX_ELMNT &&
	    strcmp(xml_name(x),xml_name(xnext))==0)
	    eqnext++;
    }
    if (i){
	xprev = xml_child_i(xp, i-1);
	if (xml_type(xprev)==CX_ELMNT &&
	    strcmp(xml_name(x),xml_name(xprev))==0)
	    eqprev++;
    }
    if (eqprev && eqnext)
	list = LIST_MIDDLE;
    else if (eqprev)
	list = LIST_LAST;
    else if (eqnext)
	list = LIST_FIRST;
    else
	list = LIST_NO;
 done:
    return list;
}

/*!
 * @param[in]     pretty set if the output should be pretty-printed
 * List only if adjacent,
 * ie <a>1</a><a>2</a><b>3</b> -> {"a":[1,2],"b":3}
 * ie <a>1</a><b>3</b><a>2</a> -> {"a":1,"b":3,"a":2}
 */
static int 
xml2json1_cbuf(cbuf  *cb,
	       cxobj *x,
	       int    level,
	       int    pretty)
{
    int                    retval = -1;
    int                    i;
    cxobj                 *xc;
    enum list_element_type list;

    switch(xml_type(x)){
    case CX_BODY:
	if (xml_value(x))
	    cprintf(cb, "\"%s\"", xml_value(x));
	else
	    cprintf(cb, "null");
	break;
    case CX_ELMNT:
	list = list_eval(x);
	switch (list){
	case LIST_NO:
	    cprintf(cb, "%*s\"%s\": ", 
		    pretty?(level*JSON_INDENT):0, "", 
		    xml_name(x));
	    if (!tleaf(x))
		cprintf(cb, "{%s", 
			pretty?"\n":"");
	    break;
	case LIST_FIRST:
	    cprintf(cb, "%*s\"%s\": [%s", 
		    pretty?(level*JSON_INDENT):0, "", 
		    xml_name(x),
		    pretty?"\n":"");
	    if (!tleaf(x)){
		level++;
		cprintf(cb, "%*s{%s", 
			pretty?(level*JSON_INDENT):0, "",
			pretty?"\n":"");
	    }
	    break;
	case LIST_MIDDLE:
	case LIST_LAST:
	    level++;
	    cprintf(cb, "%*s", 
		    pretty?(level*JSON_INDENT):0, "");
	    if (!tleaf(x))
		cprintf(cb, "{%s", 
			pretty?"\n":"");
	    break;
	default:
	    break;
	}
	for (i=0; i<xml_child_nr(x); i++){
	    xc = xml_child_i(x, i);
	    if (xml2json1_cbuf(cb, xc, level+1, pretty) < 0)
		goto done;
	    if (i<xml_child_nr(x)-1){
		cprintf(cb, ",");
		cprintf(cb, "%s", pretty?"\n":"");
	    }
	}
	switch (list){
	case LIST_NO:
	    if (!tleaf(x)){
		if (pretty)
		    cprintf(cb, "%*s}\n", 
			    (level*JSON_INDENT), "");
		else
		    cprintf(cb, "}");
	    }
	    break;
	case LIST_MIDDLE:
	case LIST_FIRST:
	    if (pretty)
		cprintf(cb, "\n%*s}", 
			(level*JSON_INDENT), "");
	    else
		cprintf(cb, "}");
	    break;
	case LIST_LAST:
	    if (!tleaf(x)){
		if (pretty)
		    cprintf(cb, "\n%*s}\n", 
			    (level*JSON_INDENT), "");
		else
		    cprintf(cb, "}");
		level--;
	    }
	    cprintf(cb, "%*s]%s",
		    pretty?(level*JSON_INDENT):0,"",
		    pretty?"\n":"");
	    break;
	default:
	    break;
	}
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
 * @param[in]  top    By default only children are printed, set if include top
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
 * See also xml2json
 */
int 
xml2json_cbuf(cbuf  *cb, 
	      cxobj *x, 
	      int    pretty)
{
    int    retval = 1;
    int    level = 0;

    cprintf(cb, "%*s{%s",
	    pretty?(level*JSON_INDENT):0,"",
	    pretty?"\n":"");
    if (xml2json1_cbuf(cb, x, level+1, pretty) < 0)
	goto done;
    cprintf(cb, "%*s}%s", 
	    pretty?(level*JSON_INDENT):0,"",
	    pretty?"\n":"");
    retval = 0;
 done:
    return retval;
}

/*!
 * @note can be a problem with vector since xml2json1_cbuf checks parents
 */
int 
xml2json_cbuf_vec(cbuf   *cb, 
		  cxobj **vec,
		  size_t  veclen,
		  int     pretty)
{
    int    retval = 1;
    int    level = 0;
    int    i;
    cxobj *xc;

    cprintf(cb, "%*s{%s",
	    pretty?(level*JSON_INDENT):0,"",
	    pretty?"\n":"");
    for (i=0; i<veclen; i++){
	xc = vec[i];
	if (xml2json1_cbuf(cb, xc, level, pretty) < 0)
	    goto done;
	if (i<veclen-1){
	    if (xml_type(xc)==CX_BODY)
		cprintf(cb, "},{");
	    else
		cprintf(cb, ",");
	    cprintf(cb, "%s", pretty?"\n":"");
	}
    }
    cprintf(cb, "%*s}%s", 
	    pretty?(level*JSON_INDENT):0,"",
	    pretty?"\n":"");
    retval = 0;
 done:
    return retval;
}

/*! Translate from xml tree to JSON and print to file
 * @param[in]  f      File to print to
 * @param[in]  x      XML tree to translate from
 * @param[in]  pretty Set if output is pretty-printed
 * @param[in]  top    By default only children are printed, set if include top
 * @retval     0      OK
 * @retval    -1      Error
 *
 * @code
 * if (xml2json(stderr, xn, 0) < 0)
 *   goto err;
 * @endcode
 */
int 
xml2json(FILE  *f, 
	 cxobj *x, 
	 int    pretty)
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
 * @retval -1  Error with clicon_err called
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
    if ((*xt = xml_new("top", NULL)) == NULL)
	return -1;
    return json_parse(str, "", *xt);
}

