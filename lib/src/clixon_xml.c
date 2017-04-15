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

/* clixon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
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
    cg_var           *x_cv;           /* If body this contains the typed value */
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
xml_name_set(cxobj *xn, 
	     char  *name)
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
xml_namespace_set(cxobj *xn, 
		  char  *namespace)
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
xml_parent_set(cxobj *xn, 
	       cxobj *parent)
{
    xn->x_up = parent;
    return 0;
}

/*! Get xml node flags, used for internal algorithms
 * @param[in]  xn    xml node
 * @retval     flag  Flags value, see XML_FLAG_*
 */
uint16_t
xml_flag(cxobj   *xn, 
	 uint16_t flag)
{
    return xn->x_flags&flag;
}

/*! Set xml node flags, used for internal algorithms
 * @param[in]  xn      xml node
 * @param[in]  flag    Flags value to set, see XML_FLAG_*
 */
int
xml_flag_set(cxobj   *xn, 
	     uint16_t flag)
{
    xn->x_flags |= flag;
    return 0;
}

/*! Reset xml node flags, used for internal algorithms
 * @param[in]  xn      xml node
 * @param[in]  flag    Flags value to reset, see XML_FLAG_*
 */
int
xml_flag_reset(cxobj   *xn, 
	       uint16_t flag)
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

/*! Set value of xml node, value is copied
 * @param[in]  xn    xml node
 * @param[in]  val  new value, null-terminated string, copied by function
 * @retval     -1    on error with clicon-err set
 * @retval     0     OK
 */
int
xml_value_set(cxobj *xn, 
	      char  *val)
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
xml_value_append(cxobj *xn, 
		 char  *val)
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
xml_type_set(cxobj          *xn, 
	     enum cxobj_type type)
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
xml_index_set(cxobj *xn, 
	      int    index)
{
    int old = xn->x_index;

    xn->x_index = index;
    return old;
}

/*! Get cligen variable associated with node
 * @param[in]  xn    xml node
 * @retval     cv    Cligen variable if set
 * @retval     NULL  If not set, or not applicable
 */
cg_var *
xml_cv_get(cxobj *xn)
{
  if (xn->x_cv)
    return xn->x_cv;
  else
    return NULL;
}

/*! Set cligen variable associated with node
 * @param[in]  xn    xml node
 * @param[in]  cv    Cligen variable or NULL
 * @retval     0     if OK
 */
int
xml_cv_set(cxobj  *xn, 
	   cg_var *cv)
{
  if (xn->x_cv)
    free(xn->x_cv);
  xn->x_cv = cv;
  return 0;
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
xml_child_i(cxobj *xn, 
	    int    i)
{
    if (i < xn->x_childvec_len)
	return xn->x_childvec[i];
    return NULL;
}

/*! Set specific child
 * @param[in]  xn    xml node
 * @param[in]  i     the number of the child, eg order in children vector
 * @param[in]  xc    The child to set at position i
 * @retval     0     OK
 */
cxobj *
xml_child_i_set(cxobj *xt, 
		int    i, 
		cxobj *xc)
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
xml_child_append(cxobj *x, 
		 cxobj *xc)
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
xml_childvec_set(cxobj *x, 
		 int    len)
{
    x->x_childvec_len = len;
    if ((x->x_childvec = calloc(len, sizeof(cxobj*))) == NULL){
	clicon_err(OE_XML, errno, "calloc");
	return -1;
    }
    return 0;
}

cxobj **
xml_childvec_get(cxobj *x)
{
    return x->x_childvec;
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
xml_new(char  *name, 
	cxobj *xp)
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

/*! Create new xml node given a name, parent and spec. 
 * @param[in] name Name of new xml node
 * @param[in] xp   XML parent
 * @param[in] spec Yang spec
 * @retval    NULL Error
 * @retval    x    XML tree. Free with xml_free().
 */
cxobj *
xml_new_spec(char  *name, 
	     cxobj *xp, 
	     void  *spec)
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
xml_find(cxobj *x_up, 
	 char  *name)
{
    cxobj *x = NULL;

    while ((x = xml_child_each(x_up, x, -1)) != NULL) 
	if (strcmp(name, xml_name(x)) == 0)
	    return x;
    return NULL;
}

/*! Append xc as child to xp. Remove xc from previous parent.
 * @param[in] xp  Parent xml node
 * @param[in] xc  Child xml node to insert under xp
 * @retval    0   OK
 * @retval    -1  Error
 * @see xml_insert
 */
int
xml_addsub(cxobj *xp, 
	   cxobj *xc)
{
    cxobj *oldp;
    int    i;

    if ((oldp = xml_parent(xc)) != NULL){
	/* Find child order i in old parent*/
	for (i=0; i<xml_child_nr(oldp); i++)
	    if (xml_child_i(oldp, i) == xc)
		break;
	/* Remove xc from old parent */
	if (i < xml_child_nr(oldp))
	    xml_child_rm(oldp, i);
    }
    /* Add xc to new parent */
    if (xml_child_append(xp, xc) < 0)
	return -1;
    /* Set new parent in child */
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
xml_insert(cxobj *xp, 
	   char  *tag)
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

/*! Remove and free an xml node child from xml parent
 * @param[in]   xc          xml child node (to be removed and freed)
 * @retval      0           OK
 * @retval      -1
 * @note you cannot remove xchild in the loop (unless yoy keep track of xprev)
 *
 * @see xml_free      Free, dont remove from parent
 * @see xml_child_rm  Only remove dont free
 * Differs from xml_free it is removed from parent.
 */
int
xml_purge(cxobj *xc)
{
    int       retval = -1;
    int       i;
    cxobj    *xp;

    if ((xp = xml_parent(xc)) != NULL){
	/* Find child order i in parent*/
	for (i=0; i<xml_child_nr(xp); i++)
	    if (xml_child_i(xp, i) == xc)
		break;
	/* Remove xc from parent */
	if (i < xml_child_nr(xp))
	    if (xml_child_rm(xp, i) < 0)
		goto done;
    }
    xml_free(xc);	    
    retval = 0;
 done:
    return retval; 
}

/*! Remove child xml node from parent xml node. No free and child is root
 * @param[in]   xp     xml parent node
 * @param[in]   i      Number of xml child node (to remove)
 * @retval      0      OK
 * @retval      -1
 * @note you should not remove xchild in loop (unless yoy keep track of xprev)
 *
 * @see xml_rootchild
 * @see xml_rm     Remove the node itself from parent
 */
int
xml_child_rm(cxobj *xp, 
	     int    i)
{
    int    retval = -1;
    cxobj *xc = NULL;

    if ((xc = xml_child_i(xp, i)) == NULL){
	clicon_err(OE_XML, 0, "Child not found");
	goto done;
    }
    xp->x_childvec[i] = NULL;
    xml_parent_set(xc, NULL);
    xp->x_childvec_len--;
    /* shift up, note same index i used but ok since we break */
    for (; i<xp->x_childvec_len; i++)
	xp->x_childvec[i] = xp->x_childvec[i+1];
    retval = 0;
 done:
    return retval;
}

/*! Remove this xml node from parent xml node. No freeing and node is new root
 * @param[in]   xc     xml child node to be removed
 * @retval      0      OK
 * @retval      -1
 * @note you should not remove xchild in loop (unless yoy keep track of xprev)
 *
 * @see xml_child_rm  Remove a child of a node
 */
int
xml_rm(cxobj *xc)
{
    int    retval = 0;
    cxobj *xp;
    cxobj *x;
    int    i;

    if ((xp = xml_parent(xc)) == NULL)
	goto done;
    retval = -1;
    /* Find child in parent */
    x = NULL; i = 0;
    while ((x = xml_child_each(xp, x, -1)) != NULL) {
	if (x == xc)
	    break;
	i++;
    }
    if (x != NULL)
	retval = xml_child_rm(xp, i);
 done:
    return retval;
}

/*! Return a child sub-tree, while removing parent and all other children
 * Given a root xml node, and the i:th child, remove the child from its parent
 * and return it, remove the parent and all other children.
 * Before: xp-->[..xc..]
 * After: xc
 * @param[in]  xp   xml parent node. Will be deleted
 * @param[in]  i    Child nr in parent child vector
 * @param[out] xcp  xml child node. New root
 * @retval     0    OK
 * @retval    -1    Error
 * @see xml_child_rm
 */
int
xml_rootchild(cxobj  *xp, 
	      int     i,
	      cxobj **xcp)
{
    int    retval = -1;
    cxobj *xc;

    if (xml_parent(xp) != NULL){
	clicon_err(OE_XML, 0, "Parent is not root");
	goto done;
    }
    if ((xc = xml_child_i(xp, i)) == NULL){
	clicon_err(OE_XML, 0, "Child not found");
	goto done;
    }
    if (xml_child_rm(xp, i) < 0)
	goto done;
    if (xml_free(xp) < 0)
	goto done;
    *xcp = xc;
    retval = 0;
 done:
    return retval;
}

/*! Get the first sub-node which is an XML body.
 * @param[in]   xn          xml tree node
 * @retval  The returned body as a pointer to the name string
 * @retval  NULL if no such node or no body in found node
 * Note, make a copy of the return value to use it properly
 * @see xml_find_body
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
xml_find_value(cxobj *x_up, 
	       char  *name)
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
 * @note, make a copy of the return value to use it properly
 * @see xml_find_value
 */
char *
xml_find_body(cxobj *xn, 
	      char  *name)
{
    cxobj *x;

    if ((x = xml_find(xn, name)) != NULL)
	return xml_body(x);
    return NULL;
}

/*! Free an xl sub-tree recursively, but do not remove it from parent
 * @param[in]  x  the xml tree to be freed.
 * @see xml_purge where x is also removed from parent
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
    if (x->x_cv)
	cv_free(x->x_cv);
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
	clicon_err(OE_XML, errno, "cbuf_new");
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

/*! Print an XML tree structure to an output stream
 *
 * Uses clicon_xml2file internally
 *
 * @param[in]   f           UNIX output stream
 * @param[in]   xn          clicon xml tree
 * @see clicon_xml2cbuf
 * @see clicon_xml2file
 */
int
xml_print(FILE  *f, 
	  cxobj *xn)
{
    return clicon_xml2file(f, xn, 0, 1);
}

#define XML_INDENT 3 /* maybe we should set this programmatically? */

/*! Print an XML tree structure to a cligen buffer
 *
 * @param[in,out] cb          Cligen buffer to write to
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
	while ((xc = xml_child_each(cx, xc, CX_ATTR)) != NULL) 
	    clicon_xml2cbuf(cb, xc, level+1, prettyprint);
	/* Check for special case <a/> instead of <a></a> */
	if (xml_body(cx)==NULL && xml_child_nr(cx)==0) 
	    cprintf(cb, "/>");
	else{
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
	}
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
xml_parse(char  *str, 
	  cxobj *x_up)
{
    int                       retval = -1;
    struct xml_parse_yacc_arg ya = {0,};

    if ((ya.ya_parse_string = strdup(str)) == NULL){
	clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	return -1;
    }
    ya.ya_xparent = x_up;
    ya.ya_skipspace = 1;  /* remove all non-terminal bodies (strip pretty-print) */
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
FSM(char *tag, 
    char  ch, 
    int   state)
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
 *  * @see clicon_xml_parse_str
 * Note, you need to free the xml parse tree after use, using xml_free()
 * Note, xt will add a top-level symbol called "top" meaning that <tree../> will look as:
 *  <top><tree.../></tree>
 * XXX: There is a potential leak here on some return values.
 * XXX: What happens if endtag is different?
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
    int   oldmaxbuf;

    if (endtag == NULL){
	clicon_err(OE_XML, 0, "%s: endtag required\n", __FUNCTION__);
	goto done;
    }
    *cx = NULL;
    if ((xmlbuf = malloc(maxbuf)) == NULL){
	clicon_err(OE_XML, errno, "%s: malloc", __FUNCTION__);
	goto done;
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
	    if (xml_parse(ptr, *cx) < 0){
		goto done;
		return -1;
	    }
	    break;
	}
	if (len>=maxbuf-1){ /* Space: one for the null character */
	    oldmaxbuf = maxbuf;
	    maxbuf *= 2;
	    if ((xmlbuf = realloc(xmlbuf, maxbuf)) == NULL){
		clicon_err(OE_XML, errno, "%s: realloc", __FUNCTION__);
		goto done;
	    }
	    memset(xmlbuf+oldmaxbuf, 0, maxbuf-oldmaxbuf);
	    ptr = xmlbuf;
	}
    } /* while */
    retval = 0;
 done:
    if (retval < 0 && *cx){
	free(*cx);
	*cx = NULL;
    }
    if (xmlbuf)
	free(xmlbuf);
    return retval;
    //    return (*cx)?0:-1;
}

/*! Read an XML definition from string and parse it into a parse-tree. 
 *
 * @param[in]  str   Pointer to string containing XML definition. 
 * @param[out] xml_top  Top of XML parse tree. Will add extra top element called 'top'.
 *                       you must free it after use, using xml_free()
 * @retval  0  OK
 * @retval -1  Error with clicon_err called
 *
 * @code
 *  cxobj *cx = NULL;
 *  if (clicon_xml_parse_str(str, &cx) < 0)
 *    err;
 *  xml_free(cx);
 * @endcode
 * @see clicon_xml_parse_file
 * @note  you need to free the xml parse tree after use, using xml_free()
 */
int 
clicon_xml_parse_str(char   *str, 
		     cxobj **cxtop)
{
  if ((*cxtop = xml_new("top", NULL)) == NULL)
    return -1;
  return xml_parse(str, *cxtop);
}


/*! Read XML definition from variable argument string and parse it into parse-tree. 
 *
 * Utility function using stdarg instead of static string.
 * @param[out] xml_top  Top of XML parse tree. Will add extra top element called 'top'.
 *                      you must free it after use, using xml_free()
 * @param[in]  format   Pointer to string containing XML definition. 

 * @retval  0  OK
 * @retval -1  Error with clicon_err called
 *
 * @code
 *  cxobj *cx = NULL;
 *  if (clicon_xml_parse(&cx, "<xml>%d</xml>", 22) < 0)
 *    err;
 *  xml_free(cx);
 * @endcode
 * @see clicon_xml_parse_str
 * @note  you need to free the xml parse tree after use, using xml_free()
 */
int 
clicon_xml_parse(cxobj **cxtop,
		 char *format, ...)
{
    int     retval = -1;
    va_list args;
    char   *str = NULL;
    int     len;

    va_start(args, format);
    len = vsnprintf(NULL, 0, format, args) + 1;
    va_end(args);
    if ((str = malloc(len)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    memset(str, 0, len);
    va_start(args, format);
    len = vsnprintf(str, len, format, args) + 1;
    va_end(args);
    if ((*cxtop = xml_new("top", NULL)) == NULL)
	return -1;
    if (xml_parse(str, *cxtop) < 0)
	goto done;
    retval = 0;
 done:
    if (str)
	free(str);
    return retval;
}

/*! Copy single xml node without copying children
 */
static int
copy_one(cxobj *xn0, 
	 cxobj *xn1)
{
    cg_var *cv1;

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
    if (xml_cv_get(xn0)){
      if ((cv1 = cv_dup(xml_cv_get(xn0))) == NULL){
	clicon_err(OE_XML, errno, "%s: cv_dup", __FUNCTION__);
	return -1;
      }
      if ((xml_cv_set(xn1, cv1)) < 0)
	return -1;
    }
    return 0;
}

/*! Copy xml tree x0 to other existing tree x1
 *
 * x1 should be a created placeholder. If x1 is non-empty,
 * the copied tree is appended to the existing tree.
 * @code
 *   x1 = xml_new("new", xc);
 *   xml_copy(x0, x1);
 * @endcode
 */
int
xml_copy(cxobj *x0, 
	 cxobj *x1)
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
 * @see xml_apply0 including top object
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

/*! Apply a function call on top object and all xml node children recursively 
 * @see xml_apply not including top object
 */
int
xml_apply0(cxobj          *xn, 
	  enum cxobj_type type, 
	  xml_applyfn_t   fn, 
	  void           *arg)
{
    int        retval = -1;

    if (fn(xn, arg) < 0)
	goto done;
    retval = xml_apply(xn, type, fn, arg);
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
	xn = xp;
    }
    retval = 0;
  done:
    return retval;   
}

/*! Generic parse function for xml values
 * @param[in]   xb       xml tree body node, ie containing a value to be parsed
 * @param[in]   type     Type of value to be parsed in value
 * @param[out]  cvp      CLIgen variable containing the parsed value
 * @note free cv with cv_free after use.
 * @see xml_body_int32   etc, for type-specific parse functions
 */
int
xml_body_parse(cxobj       *xb,
	       enum cv_type type,
	       cg_var     **cvp)
{
    int     retval = -1;
    cg_var *cv = NULL;
    int     cvret;
    char   *bstr;
    char   *reason = NULL;

    if ((bstr = xml_body(xb)) == NULL){
	clicon_err(OE_XML, 0, "No body found");
	goto done;
    }
    if ((cv = cv_new(type)) == NULL){
	clicon_err(OE_XML, errno, "cv_new");
	goto done;
    }
    if ((cvret = cv_parse1(bstr, cv, &reason)) < 0){
	clicon_err(OE_XML, errno, "cv_parse");
	goto done;
    }
    if (cvret == 0){  /* parsing failed */
	clicon_err(OE_XML, errno, "Parsing CV: %s", &reason);
	if (reason)
	    free(reason);
    }
    *cvp = cv;
    retval = 0;
 done:
    if (retval < 0 && cv != NULL)
	cv_free(cv);
    return retval;

}

/*! Parse an xml body as int32
 * The real parsing functions are in the cligen code
 * @param[in]   xb          xml tree body node, ie containing a value to be parsed
 * @param[out]  val         Value after parsing
 * @retval      0           OK, parsed value in 'val'
 * @retval     -1           Error, one of: body not found, parse error, 
 *                          alloc error.
 * @note extend to all other cligen var types and generalize
 * @note use yang type info?
 */
int
xml_body_int32(cxobj    *xb,
	       int32_t *val)
{
    cg_var *cv = NULL;

    if (xml_body_parse(xb, CGV_INT32, &cv) < 0)
	return -1;
    *val = cv_int32_get(cv);
    cv_free(cv);
    return 0;
}

/*! Parse an xml body as uint32
 * The real parsing functions are in the cligen code
 * @param[in]   xb          xml tree body node, ie containing a value to be parsed
 * @param[out]  val         Value after parsing
 * @retval      0           OK, parsed value in 'val'
 * @retval     -1           Error, one of: body not found, parse error, 
 *                          alloc error.
 * @note extend to all other cligen var types and generalize
 * @note use yang type info?
 */
int
xml_body_uint32(cxobj    *xb,
		uint32_t *val)
{
    cg_var *cv = NULL;

    if (xml_body_parse(xb, CGV_UINT32, &cv) < 0)
	return -1;
    *val = cv_uint32_get(cv);
    cv_free(cv);
    return 0;
}

/*! Map xml operation from string to enumeration
 * @param[in]   opstr  String, eg "merge"
 * @param[out]  op     Enumeration, eg OP_MERGE
 * @code
 *   enum operation_type op;
 *   xml_operation("replace", &op)
 * @endcode
 */
int
xml_operation(char                *opstr, 
	      enum operation_type *op)
{
    if (strcmp("merge", opstr) == 0)
	*op = OP_MERGE;
    else if (strcmp("replace", opstr) == 0)
	*op = OP_REPLACE;
    else if (strcmp("create", opstr) == 0)
	*op = OP_CREATE;
    else if (strcmp("delete", opstr) == 0)
	*op = OP_DELETE;
    else if (strcmp("remove", opstr) == 0)
	*op = OP_REMOVE;
    else if (strcmp("none", opstr) == 0)
	*op = OP_NONE;
    else{
	clicon_err(OE_XML, 0, "Bad-attribute operation: %s", opstr);
	return -1;
    }
    return 0;
}

/*! Map xml operation from enumeration to string
 * @param[in]   op   enumeration operation, eg OP_MERGE,...
 * @retval      str  String, eg "merge". Static string, no free necessary
 * @code
 *   enum operation_type op;
 *   xml_operation("replace", &op)
 * @endcode
 */
char *
xml_operation2str(enum operation_type op)
{
    switch (op){
    case OP_MERGE:
	return "merge";
	break;
    case OP_REPLACE:
	return "replace";
	break;
    case OP_CREATE:
	return "create";
	break;
    case OP_DELETE:
	return "delete";
	break;
    case OP_REMOVE:
	return "remove";
	break;
    default:
	return "none";
    }
}

