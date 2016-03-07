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

 * XML support functions.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <limits.h>
#include <fnmatch.h>
#include <stdint.h>
#include <assert.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_chunk.h"
#include "clixon_xml.h"
#include "clixon_xml_parse.h"

/*
 * Constants
 */
#define BUFLEN 1024  /* Size of xml read buffer */

/*
 * Types
 */

/*! xml tree node, with name, type, parent, children, etc 
 * Note that this is a private type not visible from externally, use
 * access functions.
 */
struct xml{
    char             *x_name;       /* name of node */
    char             *x_namespace;  /* namespace, if any */
    struct xml       *x_up;         /* parent node in hierarchy if any */
    struct xml      **x_childvec;   /* vector of children nodes */
    int               x_childvec_len; /* length of vector */
    enum cxobj_type   x_type;       /* type of node: element, attribute, body */
    char             *x_value;      /* attribute and body nodes have values */
    int               x_index;      /* key node, cf sql index */
    int              _x_vector_i;   /* internal use: xml_child_each */
    int               x_flags;      /* Flags according to XML_FLAG_* above */
    void             *x_spec;       /* Pointer to specification, eg yang, by 
				       reference, dont free */
};

/*
 * Access functions
 */
/*! Get name of xnode
 * @param[in]  xn    xml node
 * @retval     name of xml node
 */
char*
xml_name(cxobj *xn)
{
    return xn->x_name;
}

/*! Set name of xnode, name is copied
 * @param[in]  xn    xml node
 * @param[in]  name  new name, null-terminated string, copied by function
 * @retval     -1    on error with clicon-err set
 * @retval     0     OK
 */
int
xml_name_set(cxobj *xn, char *name)
{
    if (xn->x_name){
	free(xn->x_name);
	xn->x_name = NULL;
    }
    if (name){
	if ((xn->x_name = strdup(name)) == NULL){
	    clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	    return -1;
	}
    }
    return 0;
}

/*! Get namespace of xnode
 * @param[in]  xn    xml node
 * @retval     namespace of xml node
 */
char*
xml_namespace(cxobj *xn)
{
    return xn->x_namespace;
}

/*! Set name of xnode, name is copied
 * @param[in]  xn         xml node
 * @param[in]  namespace  new namespace, null-terminated string, copied by function
 * @retval     -1         on error with clicon-err set
 * @retval     0          OK
 */
int
xml_namespace_set(cxobj *xn, char *namespace)
{
    if (xn->x_namespace){
	free(xn->x_namespace);
	xn->x_namespace = NULL;
    }
    if (namespace){
	if ((xn->x_namespace = strdup(namespace)) == NULL){
	    clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	    return -1;
	}
    }
    return 0;
}

/*! Get parent of xnode
 * @param[in]  xn    xml node
 * @retval     parent xml node
 */
cxobj*
xml_parent(cxobj *xn)
{
    return xn->x_up;
}

/*! Set parent of xnode, parent is copied.
 * @param[in]  xn      xml node
 * @param[in]  parent  pointer to new parent xml node
 * @retval     0       OK
 */
int
xml_parent_set(cxobj *xn, cxobj *parent)
{
    xn->x_up = parent;
    return 0;
}

/*! Get xml node flags, used for internal algorithms
 * @param[in]  xn    xml node
 * @retval     flag  Flags value, see XML_FLAG_*
 */
uint16_t
xml_flag(cxobj *xn, uint16_t flag)
{
    return xn->x_flags&flag;
}

/*! Set xml node flags, used for internal algorithms
 * @param[in]  xn      xml node
 * @param[in]  flag    Flags value to set, see XML_FLAG_*
 */
int
xml_flag_set(cxobj *xn, uint16_t flag)
{
    xn->x_flags |= flag;
    return 0;
}

/*! Reset xml node flags, used for internal algorithms
 * @param[in]  xn      xml node
 * @param[in]  flag    Flags value to reset, see XML_FLAG_*
 */
int
xml_flag_reset(cxobj *xn, uint16_t flag)
{
    xn->x_flags &= ~flag;
    return 0;
}

/*! Get value of xnode
 * @param[in]  xn    xml node
 * @retval     value of xml node
 */
char*
xml_value(cxobj *xn)
{
    return xn->x_value;
}

/*! Set value of xnode, value is copied
 * @param[in]  xn    xml node
 * @param[in]  val  new value, null-terminated string, copied by function
 * @retval     -1    on error with clicon-err set
 * @retval     0     OK
 */
int
xml_value_set(cxobj *xn, char *val)
{
    if (xn->x_value){
	free(xn->x_value);
	xn->x_value = NULL;
    }
    if (val){
	if ((xn->x_value = strdup(val)) == NULL){
	    clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	    return -1;
	}
    }
    return 0;
}

/*! Append value of xnode, value is copied
 * @param[in]  xn    xml node
 * @param[in]  val   appended value, null-terminated string, copied by function
 * @retval     NULL  on error with clicon-err set, or if value is set to NULL
 * @retval     new value
 */
char *
xml_value_append(cxobj *xn, char *val)
{
    int len0;
    int len;
    
    len0 = xn->x_value?strlen(xn->x_value):0;
    if (val){
	len = len0 + strlen(val);
	if ((xn->x_value = realloc(xn->x_value, len+1)) == NULL){
	    clicon_err(OE_XML, errno, "realloc");
	    return NULL;
	}
	strncpy(xn->x_value + len0, val, len-len0+1);
    }
    return xn->x_value;
}

/*! Get type of xnode
 * @param[in]  xn    xml node
 * @retval     type of xml node
 */
enum cxobj_type
xml_type(cxobj *xn)
{
    return xn->x_type;
}

/*! Set type of xnode
 * @param[in]  xn    xml node
 * @param[in]  type  new type
 * @retval     type  old type
 */
enum cxobj_type 
xml_type_set(cxobj *xn, enum cxobj_type type)
{
    enum cxobj_type old = xn->x_type;

    xn->x_type = type;
    return old;
}

/*! Get index/key of xnode
 * @param[in]  xn    xml node
 * @retval     index of xml node
 * index/key is used in case of yang list constructs where one element is key
 */
int
xml_index(cxobj *xn)
{
    return xn->x_index;
}

/*! Set index of xnode
 * @param[in]  xn    xml node
 * @param[in]  index new index
 * @retval     index  old index
 * index/key is used in case of yang list constructs where one element is key
 */
int
xml_index_set(cxobj *xn, int index)
{
    int old = xn->x_index;

    xn->x_index = index;
    return old;
}

/*! Get number of children
 * @param[in]  xn    xml node
 * @retval     number of children in XML tree
 */
int   
xml_child_nr(cxobj *xn)
{
    return xn->x_childvec_len;
}

/*! Get a specific child
 * @param[in]  xn    xml node
 * @param[in]  i     the number of the child, eg order in children vector
 * @retval     child in XML tree, or NULL if no such child, or empty child
 */
cxobj *
xml_child_i(cxobj *xn, int i)
{
    if (i < xn->x_childvec_len)
	return xn->x_childvec[i];
    return NULL;
}

cxobj *
xml_child_i_set(cxobj *xt, int i, cxobj *xc)
{
    if (i < xt->x_childvec_len)
	xt->x_childvec[i] = xc;
    return 0;
}

/*! Iterator over xml children objects
 *
 * NOTE: Never manipulate the child-list during operation or using the
 * same object recursively, the function uses an internal field to remember the
 * index used. It works as long as the same object is not iterated concurrently. 
 *
 * @param[in] xparent xml tree node whose children should be iterated
 * @param[in] xprev   previous child, or NULL on init
 * @param[in] type    matching type or -1 for any
 * @code
 *   cxobj *x = NULL;
 *   while ((x = xml_child_each(x_top, x, -1)) != NULL) {
 *     ...
 *   }
 * @endcode
 */
cxobj *
xml_child_each(cxobj           *xparent, 
	       cxobj           *xprev, 
	       enum cxobj_type  type)
{
    int i;
    cxobj *xn = NULL; 

    for (i=xprev?xprev->_x_vector_i+1:0; i<xparent->x_childvec_len; i++){
	xn = xparent->x_childvec[i];
	if (xn == NULL)
	    continue;
	if (type != CX_ERROR && xml_type(xn) != type)
	    continue;
	break; /* this is next object after previous */
    }
    if (i < xparent->x_childvec_len) /* found */
	xn->_x_vector_i = i;
    else
	xn = NULL;
    return xn;
}

/*! Extend child vector with one and insert xml node there
 * Note: does not do anything with child, you may need to set its parent, etc
 */
static int
xml_child_append(cxobj *x, cxobj *xc)
{
    x->x_childvec_len++;
    x->x_childvec = realloc(x->x_childvec, x->x_childvec_len*sizeof(cxobj*));
    if (x->x_childvec == NULL){
	clicon_err(OE_XML, errno, "%s: realloc", __FUNCTION__);
	return -1;
    }
    x->x_childvec[x->x_childvec_len-1] = xc;
    return 0;
}

/*! Set a a childvec to a speciufic size, fill with children after
 * @code
 *   xml_childvec_set(x, 2);
 *   xml_child_i(x, 0) = xc0;
 *   xml_child_i(x, 1) = xc1;
 * @endcode
 */
int
xml_childvec_set(cxobj *x, int len)
{
    x->x_childvec_len = len;
    if ((x->x_childvec = calloc(len, sizeof(cxobj*))) == NULL){
	clicon_err(OE_XML, errno, "calloc");
	return -1;
    }
    return 0;
}

/*! Create new xml node given a name and parent. Free it with xml_free().
 *
 * @param[in]  name      Name of new 
 * @param[in]  xp        The parent where the new xml node should be inserted
 *
 * @retval created xml object if successful
 * @retval NULL          if error and clicon_err() called
 */
cxobj *
xml_new(char *name, cxobj *xp)
{
    cxobj *xn;

    if ((xn=malloc(sizeof(cxobj))) == NULL){
	clicon_err(OE_XML, errno, "%s: malloc", __FUNCTION__);
	return NULL;
    }
    memset(xn, 0, sizeof(cxobj));
    if ((xml_name_set(xn, name)) < 0)
	return NULL;

    xml_parent_set(xn, xp);
    if (xp)
	if (xml_child_append(xp, xn) < 0)
	    return NULL;
    return xn;
}

/*! Create new xml node given a name, parent and spec. Free it with xml_free().
 */
cxobj *
xml_new_spec(char *name, cxobj *xp, void *spec)
{
    cxobj *x;
    
    if ((x = xml_new(name, xp)) == NULL)
	return NULL;
    x->x_spec = spec;
    return x;
}

void *
xml_spec(cxobj *x)
{
    return x->x_spec;
}

/*! Find an XML node matching name among a parent's children.
 *
 * Get first XML node directly under x_up in the xml hierarchy with
 * name "name".
 *
 * @param[in]  x_up   Base XML object
 * @param[in]  name   shell wildcard pattern to match with node name
 *
 * @retval xmlobj     if found.
 * @retval NULL       if no such node found.
 */
cxobj *
xml_find(cxobj *x_up, char *name)
{
    cxobj *x = NULL;

    while ((x = xml_child_each(x_up, x, -1)) != NULL) 
	if (strcmp(name, xml_name(x)) == 0)
	    return x;
    return NULL;
}

/*! Add xc as child to xp. Remove xc from previous parent.
 * @param[in] xp  Parent xml node
 * @param[in] xc  Child xml node to insert under xp
 * @retval    0   OK
 * @retval    -1  Error
 * @see xml_insert
 */
int
xml_addsub(cxobj *xp, cxobj *xc)
{
    cxobj *oldp;

    if ((oldp = xml_parent(xc)) != NULL)
	xml_prune(oldp, xc, 0);
    if (xml_child_append(xp, xc) < 0)
	return -1;
    xml_parent_set(xc, xp); 
    return 0;
}

/*! Insert a new element (xc) under an xml node (xp), move all children to xc.
 *  Before:  xp --> xt
 *  After:   xp --> xc --> xt
 * @param[in] xp  Parent xml node
 * @param[in] tag Name of new xml child
 * @retval    xc  Return the new child (xc)
 * @see xml_addsub
 * The name of the function is somewhat misleading
 */
cxobj *
xml_insert(cxobj *xp, char *tag)
{
    cxobj *xc; /* new child */

    if ((xc = xml_new(tag, NULL)) == NULL)
	goto catch;
    while (xp->x_childvec_len)
	if (xml_addsub(xc, xml_child_i(xp, 0)) < 0)
	    goto catch;
    if (xml_addsub(xp, xc) < 0)
	goto catch;
  catch:
    return xc;
}

/*! Get the first sub-node which is an XML body.
 * @param[in]   xn          xml tree node
 * @retval  The returned body as a pointer to the name string
 * @retval  NULL if no such node or no body in found node
 * Note, make a copy of the return value to use it properly
 * See also xml_find_body
 */
char *
xml_body(cxobj *xn)
{
    cxobj *xb = NULL;

    while ((xb = xml_child_each(xn, xb, CX_BODY)) != NULL) 
	return xml_value(xb);
    return NULL;
}


/*! Find and return the value of a sub xml node
 *
 * The value can be of an attribute or body.
 * @param[in]   xn          xml tree node
 * @param[in]   name        name of xml tree nod (eg attr name or "body")
 * @retval  The returned value as a pointer to the name string
 * @retval  NULL if no such node or no value in found node
 *
 * Note, make a copy of the return value to use it properly
 * See also xml_find_body
 */
char *
xml_find_value(cxobj *x_up, char *name)
{
    cxobj *x;
    
    if ((x = xml_find(x_up, name)) != NULL)
	return xml_value(x);
    return NULL;
}


/*! Find and return a body (string) of a sub xml node
 * @param[in]   xn          xml tree node
 * @param[in]   name        name of xml tree node
 * @retval  The returned body as a pointer to the name string
 * @retval  NULL if no such node or no body in found node
 * Note, make a copy of the return value to use it properly
 * See also xml_find_value
 */
char *
xml_find_body(cxobj *xn, char *name)
{
    cxobj *x;

    if ((x = xml_find(xn, name)) != NULL)
	return xml_body(x);
    return NULL;
}

/*! Remove an xml node from a parent xml node.
 * @param[in]   xparent     xml parent node
 * @param[in]   xchild      xml child node (to remove)
 * @param[in]   purge       if 1, free the child node, not just remove from parent
 * @retval      0           OK
 * @retval      -1
 * @note you cannot remove xchild in the loop (unless yoy keep track of xprev)
 *
 * @see xml_free
 * Differs from xml_free in two ways:
 *  1. It is removed from parent.
 *  2. If you set the purge flag to 1, the child tree will be freed 
 *     (otherwise it will not)
 */
int
xml_prune(cxobj *xparent, 
	  cxobj *xchild, 
	  int    purge)
{
    int       i;
    cxobj *xc = NULL;

    for (i=0; i<xml_child_nr(xparent); i++){
	xc = xml_child_i(xparent, i);
	if (xc != xchild)
	    continue;
	/* matching child */
	xparent->x_childvec[i] = NULL;
	xml_parent_set(xc, NULL);
	if (purge)
	    xml_free(xchild);	    
	xparent->x_childvec_len--;
	/* shift up, note same index i used but ok since we break */
	for (;i<xparent->x_childvec_len; i++)
	    xparent->x_childvec[i] = xparent->x_childvec[i+1];
	return 0;
    }
    clicon_err(OE_XML, 0, "%s: child not found", __FUNCTION__);
    return -1; 
}

/*! Free an xl sub-tree recursively, but do not remove it from parent
 * @param[in]  x  the xml tree to be freed.
 * @see xml_prune
 * Differs from xml_prune in that it is _not_ removed from parent.
 */
int
xml_free(cxobj *x)
{
    int i;
    cxobj *xc;

    if (x->x_name)
	free(x->x_name);
    if (x->x_value)
	free(x->x_value);
    if (x->x_namespace)
	free(x->x_namespace);
    for (i=0; i<x->x_childvec_len; i++){
	xc = x->x_childvec[i];
	xml_free(xc);
	x->x_childvec[i] = NULL;
    }
    if (x->x_childvec)
	free(x->x_childvec);
    free(x);
    return 0;
}

/*! Print an XML tree structure to an output stream
 *
 * Uses clicon_xml2cbuf internally
 *
 * @param[in]   f           UNIX output stream
 * @param[in]   xn          clicon xml tree
 * @param[in]   level       how many spaces to insert before each line
 * @param[in]   prettyprint insert \n and spaces tomake the xml more readable.
 * @see clicon_xml2cbuf
 */
int
clicon_xml2file(FILE  *f, 
		cxobj *xn, 
		int    level, 
		int    prettyprint)
{
    cbuf  *cb;
    int    retval = -1;

    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_XML, errno, "%s: cbuf_new", __FUNCTION__);
	goto done;
    }
    if (clicon_xml2cbuf(cb, xn, level, prettyprint) < 0)
	goto done;
    fprintf(f, "%s", cbuf_get(cb));
    retval = 0;
  done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

#define XML_INDENT 3 /* maybve we should set this programmatically? */

/*! Print an XML tree structure to a clicon buffer
 *
 * @param[in,out] cb          Clicon buffer to write to
 * @param[in]     xn          clicon xml tree
 * @param[in]     level       how many spaces to insert before each line
 * @param[in]     prettyprint insert \n and spaces tomake the xml more readable.
 *
 * @code
 * cbuf *cb;
 * cb = cbuf_new();
 * if (clicon_xml2cbuf(cb, xn, 0, 1) < 0)
 *   goto err;
 * cbuf_free(cb);
 * @endcode
 * See also clicon_xml2file
 */
int
clicon_xml2cbuf(cbuf  *cb, 
		cxobj *cx, 
		int    level, 
		int    prettyprint)
{
    cxobj *xc;

    switch(xml_type(cx)){
    case CX_BODY:
	cprintf(cb, "%s", xml_value(cx));
	break;
    case CX_ATTR:
	cprintf(cb, " ");
	if (xml_namespace(cx))
	    cprintf(cb, "%s:", xml_namespace(cx));
	cprintf(cb, "%s=\"%s\"", xml_name(cx), xml_value(cx));
	break;
    case CX_ELMNT:
	cprintf(cb, "%*s<", prettyprint?(level*XML_INDENT):0, "");
	if (xml_namespace(cx))
	    cprintf(cb, "%s:", xml_namespace(cx));
	cprintf(cb, "%s", xml_name(cx));
	xc = NULL;
	while ((xc = xml_child_each(cx, xc, -1)) != NULL) {
	    if (xml_type(xc) != CX_ATTR)
		continue;
	    clicon_xml2cbuf(cb, xc, level+1, prettyprint);
	}
	cprintf(cb, ">");
	if (prettyprint && xml_body(cx)==NULL)
	    cprintf(cb, "\n");
	xc = NULL;
	while ((xc = xml_child_each(cx, xc, -1)) != NULL) {
	    if (xml_type(xc) == CX_ATTR)
		continue;
	    else
		clicon_xml2cbuf(cb, xc, level+1, prettyprint);
	}
	if (prettyprint && xml_body(cx)==NULL)
	    cprintf(cb, "%*s", level*XML_INDENT, "");
	cprintf(cb, "</%s>", xml_name(cx));
	if (prettyprint)
	    cprintf(cb, "\n");
	break;
    default:
	break;
    }/* switch */
    return 0;
}

/*! Internal xml parsing function.
 * @see clicon_xml_parse_file clicon_xml_parse_string
 */
static int 
xml_parse(char **str, cxobj *x_up)
{
    int                       retval = -1;
    struct xml_parse_yacc_arg ya = {0,};

    if ((ya.ya_parse_string = strdup(*str)) == NULL){
	clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	return -1;
    }
    ya.ya_xparent = x_up;
    if (clixon_xml_parsel_init(&ya) < 0)
	goto done;
    if (clixon_xml_parseparse(&ya) != 0)  /* yacc returns 1 on error */
	goto done;

    retval = 0;
  done:
    clixon_xml_parsel_exit(&ya);
    if(ya.ya_parse_string != NULL)
	free(ya.ya_parse_string);
    return retval; 
}

/*
 * FSM to detect a substring
 */
static inline int
FSM(char *tag, char ch, int state)
{
    if (tag[state] == ch)
	return state+1;
    else
	return 0;
}

/*! Read an XML definition from file and parse it into a parse-tree. 
 *
 * @param[in]  fd  A file descriptor containing the XML file (as ASCII characters)
 * @param[out] xt  Pointer to an (on entry empty) pointer to an XML parse tree 
 *                 _created_ by this function.
 * @param  endtag  Read until you encounter "endtag" in the stream
 * @retval  0  OK
 * @retval -1  Error with clicon_err called
 *
 * @code
 *  cxobj *xt;
 *  clicon_xml_parse_file(0, &xt, "</clicon>");
 *  xml_free(xt);
 * @endcode
 *  * @see clicon_xml_parse_string
 * Note, you need to free the xml parse tree after use, using xml_free()
 * Note, xt will add a top-level symbol called "top" meaning that <tree../> will look as:
 *  <top><tree.../></tree>
 * XXX: There is a potential leak here on some return values.
 * May block
 */
int 
clicon_xml_parse_file(int     fd, 
		      cxobj **cx, 
		      char   *endtag)
{
    int   len = 0;
    char  ch;
    int   retval;
    char *xmlbuf;
    char *ptr;
    int   maxbuf = BUFLEN;
    int   endtaglen = strlen(endtag);
    int   state = 0;

    if (endtag == NULL){
	clicon_err(OE_XML, 0, "%s: endtag required\n", __FUNCTION__);
	return -1;
    }
    *cx = NULL;
    if ((xmlbuf = malloc(maxbuf)) == NULL){
	clicon_err(OE_XML, errno, "%s: malloc", __FUNCTION__);
	return -1;
    }
    memset(xmlbuf, 0, maxbuf);
    ptr = xmlbuf;
    while (1){
	if ((retval = read(fd, &ch, 1)) < 0){
	    clicon_err(OE_XML, errno, "%s: read: [pid:%d]\n", 
		    __FUNCTION__,
		    (int)getpid());
	    break;
	}
	if (retval != 0){
	    state = FSM(endtag, ch, state);
	    xmlbuf[len++] = ch;
	}
	if (retval == 0 || state == endtaglen){
	    state = 0;
	    if ((*cx = xml_new("top", NULL)) == NULL)
		break;
	    if (xml_parse(&ptr, *cx) < 0)
		return -1;
	    break;
	}
	if (len>=maxbuf-1){ /* Space: one for the null character */
	    int oldmaxbuf = maxbuf;

	    maxbuf *= 2;
	    if ((xmlbuf = realloc(xmlbuf, maxbuf)) == NULL){
		clicon_err(OE_XML, errno, "%s: realloc", __FUNCTION__);
		return -1;
	    }
	    memset(xmlbuf+oldmaxbuf, 0, maxbuf-oldmaxbuf);
	    ptr = xmlbuf;
	}
    } /* while */
    free(xmlbuf);
    return (*cx)?0:-1;
}


/*! Read an XML definition from string and parse it into a parse-tree. 
 *
 * @param[in] str   Pointer to string containing XML definition. NOTE: destructively
 *          modified. This means if str is malloced, you need to make a copy
 *          of str before use and free that. 
 * @param[out]  xml_top  Top of XML parse tree. Will add extra top element called 'top'.
 *                       you must free it after use, using xml_free()
 * @retval  0  OK
 * @retval -1  Error with clicon_err called
 *
 * @code
 *  cxobj *cx = NULL;
 *  str = strdup(...);
 *  str0 = str;
 *  if (clicon_xml_parse_string(&str0, &cx) < 0)
 *    err;
 *  free(str0);
 *  xml_free(cx);
 * @endcode
 * @see clicon_xml_parse_file
 * Note, you need to free the xml parse tree after use, using xml_free()
 * Update: with yacc parser I dont think it changes,....
 */
int 
clicon_xml_parse_string(char  **str, 
			cxobj **cxtop)
{
  if ((*cxtop = xml_new("top", NULL)) == NULL)
    return -1;
  return xml_parse(str, *cxtop);
}

/*! Copy single xml node without copying children
 */
static int
copy_one(cxobj *xn0, cxobj *xn1)
{
    xml_type_set(xn1, xml_type(xn0));
    if (xml_value(xn0)){ /* malloced string */
	if ((xn1->x_value = strdup(xn0->x_value)) == NULL){
	    clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	    return -1;
	}
    }
    if (xml_name(xn0)) /* malloced string */
	if ((xml_name_set(xn1, xml_name(xn0))) < 0)
	    return -1;
    return 0;
}

/*! Copy xml tree to other existing tree
 *
 * x1 should be a created placeholder. If x1 is non-empty,
 * the copied tree is appended to the existing tree.
 * @code
 *   x1 = xml_new("new", xc);
 *   xml_copy(x0, x1);
 * @endcode
 */
int
xml_copy(cxobj *x0, cxobj *x1)
{
    int retval = -1;
    cxobj *x;
    cxobj *xcopy;

    if (copy_one(x0, x1) <0)
	goto done;
    x = NULL;
    while ((x = xml_child_each(x0, x, -1)) != NULL) {
	if ((xcopy = xml_new(xml_name(x), x1)) == NULL)
	    goto done;
	if (xml_copy(x, xcopy) < 0) /* recursion */
	    goto done;
    }
    retval = 0;
  done:
    return retval;
}

/*! Create and return a copy of xml tree.
 *
 * @code
 *   cxobj *x1;
 *   x1 = xml_dup(x0);
 * @endcode
 * Note, returned tree should be freed as: xml_free(x1)
 */
cxobj *
xml_dup(cxobj *x0)
{
    cxobj *x1;

    if ((x1 = xml_new("new", NULL)) == NULL)
	return NULL;
    if (xml_copy(x0, x1) < 0)
	return NULL;
    return x1;
}

/*! Copy XML vector from vec0 to vec1
 * @param[in]  vec0    Source XML tree vector
 * @param[in]  len0    Length of source XML tree vector
 * @param[out] vec1    Destination XML tree vector
 * @param[out] len1    Length of destination XML tree vector
 */
int
cxvec_dup(cxobj  **vec0, 
	  size_t   len0, 
	  cxobj ***vec1, 
	  size_t  *len1)
{
    int retval = -1;

    *len1 = len0;
    if ((*vec1 = calloc(len0, sizeof(cxobj*))) == NULL)
	goto done;
    memcpy(*vec1, vec0, len0*sizeof(cxobj*));
    retval = 0;
 done:
    return retval;
}

/*! Append a new xml tree to an existing xml vector
 * @param[in]      x      XML tree (append this to vector)
 * @param[in,out]  vec    XML tree vector
 * @param[in,out]  len    Length of XML tree vector
 */
int
cxvec_append(cxobj   *x, 
	     cxobj ***vec, 
	     size_t  *len)
{
    int retval = -1;

    if ((*vec = realloc(*vec, sizeof(cxobj *) * (*len+1))) == NULL){
	clicon_err(OE_XML, errno, "%s: realloc", __FUNCTION__);
	goto done;
    }
    (*vec)[(*len)++] = x;
    retval = 0;
 done:
    return retval;
}

/*! Apply a function call recursively on all xml node children recursively
 * Recursively traverse all xml nodes in a parse-tree and apply fn(arg) for 
 * each object found. The function is called with the xml node and an 
 * argument as args.
 * The tree is traversed depth-first, which at least guarantees that a parent is
 * traversed before a child.
 * @param[in]  xn   XML node
 * @param[in]  type matching type or -1 for any
 * @param[in]  fn   Callback
 * @param[in]  arg  Argument
 * @code
 * int x_fn(cxobj *x, void *arg)
 * {
 *   return 0;
 * }
 * xml_apply(xn, CX_ELMNT, x_fn, NULL);
 * @endcode
 * @note do not delete or move around any children during this function
 * @note It does not apply fn to the root node,..
 */
int
xml_apply(cxobj          *xn, 
	  enum cxobj_type type, 
	  xml_applyfn_t   fn, 
	  void           *arg)
{
    int        retval = -1;
    cxobj     *x = NULL;

    while ((x = xml_child_each(xn, x, type)) != NULL) {
	if (fn(x, arg) < 0)
	    goto done;
	if (xml_apply(x, type, fn, arg) < 0)
	    goto done;
    }
    retval = 0;
  done:
    return retval;   
}

/*! Apply a function call recursively on all ancestors
 * Recursively traverse upwards to all ancestor nodes in a parse-tree and apply fn(arg) for 
 * each object found. The function is called with the xml node and an 
 * argument as args.
 * @param[in]  xn   XML node
 * @param[in]  fn   Callback
 * @param[in]  arg  Argument
 * @code
 * int x_fn(cxobj *x, void *arg)
 * {
 *   return 0;
 * }
 * xml_apply_ancestor(xn, x_fn, NULL);
 * @endcode
 * @see xml_apply
 * @note do not delete or move around any children during this function
 * @note It does not apply fn to the root node,..
 */
int
xml_apply_ancestor(cxobj          *xn, 
		   xml_applyfn_t   fn, 
		   void           *arg)
{
    int        retval = -1;
    cxobj     *xp = NULL;

    while ((xp = xml_parent(xn)) != NULL) {
	if (fn(xp, arg) < 0)
	    goto done;
	if (xml_apply_ancestor(xp, fn, arg) < 0)
	    goto done;
    }
    retval = 0;
  done:
    return retval;   
}
