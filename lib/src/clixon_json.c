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

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_xml.h"

#include "clixon_json.h"
#include "clixon_json_parse.h"


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
 * List only if adjacent,
 * ie <a>1</a><a>2</a><b>3</b> -> {"a":[1,2],"b":3}
 * ie <a>1</a><b>3</b><a>2</a> -> {"a":1,"b":3,"a":2}
 */
static int 
xml2json1_cbuf(cbuf  *cb,
	       cxobj *x)
{
    int                    retval = -1;
    int                    i;
    cxobj                 *xc;
    enum list_element_type list;

    switch(xml_type(x)){
    case CX_BODY:
	fprintf(stderr, "%s body %s\n", __FUNCTION__, xml_value(x));
	if (xml_value(x))
	    cprintf(cb, "\"%s\"", xml_value(x));
	else
	    cprintf(cb, "null");
	break;
    case CX_ELMNT:
	list = list_eval(x);
	fprintf(stderr, "%s element %s\n", __FUNCTION__, xml_name(x));
	switch (list){
	case LIST_NO:
	    cprintf(cb, "\"%s\":", xml_name(x));
	    if (!tleaf(x))
		cprintf(cb, "{");
	    break;
	case LIST_FIRST:
	    cprintf(cb, "\"%s\":[", xml_name(x));
	    break;
	default:
	    break;
	}
	for (i=0; i<xml_child_nr(x); i++){
	    xc = xml_child_i(x, i);
	    if (xml2json1_cbuf(cb, xc) < 0)
		goto done;
	    if (i<xml_child_nr(x)-1)
		cprintf(cb, ",");
	}
	switch (list){
	case LIST_NO:
	    if (!tleaf(x))
		cprintf(cb, "}");
	    break;
	case LIST_LAST:
	    cprintf(cb, "]");
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
 * @param[in]     level  Indentation level
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
	      int    level)
{
    int retval = 1;

    cprintf(cb, "{");
    if (xml2json1_cbuf(cb, x) < 0)
	goto done;
    cprintf(cb, "}\n");
    retval = 0;
 done:
    return retval;
}

/*! Translate from xml tree to JSON and print to file
 * @param[in]  f     File to print to
 * @param[in]  x     XML tree to translate from
 * @param[in]  level Indentation level
 * @retval     0     OK
 * @retval    -1     Error
 *
 * @code
 * if (xml2json(stderr, xn, 0) < 0)
 *   goto err;
 * @endcode
 */
int 
xml2json(FILE  *f, 
	 cxobj *x, 
	 int    level)
{
    int   retval = 1;
    cbuf *cb;

    if ((cb = cbuf_new()) ==NULL){
	clicon_err(OE_XML, errno, "cbuf_new");
	goto done;
    }
    if (xml2json_cbuf(cb, x, level) < 0)
	goto done;
    retval = 0;
 done:
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
    if (jy.jy_current)
	xml_print(stdout, jy.jy_current);
 done:
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

