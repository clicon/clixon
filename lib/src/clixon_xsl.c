/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 * Limited XML XPATH and XSLT functions.
 * NOTE: there is a main function at the end of this file where you can test out
 * different xpath expressions.
 * Look at the end of the file for a test unit program
 */
/*
See https://www.w3.org/TR/xpath/

Implementation of a limited xslt xpath syntax. Some examples. Given the following
xml tree:
<aaa>
  <bbb x="hello"><ccc>42</ccc></bbb>
  <bbb x="bye"><ccc>99</ccc></bbb>
  <ddd><ccc>22</ccc></ddd>
</aaa>

With the following xpath examples. There are some diffs and many limitations compared
to the xml standards:
	/	        whole tree <aaa>...</aaa>
	/bbb            
	/aaa/bbb        <bbb x="hello"><ccc>42</ccc></bbb>
	                <bbb x="bye"><ccc>99</ccc></bbb>
	//bbb           as above
	//b?b	        as above
	//b\*	        as above
	//b\*\/ccc      <ccc>42</ccc>
	                <ccc>99</ccc>
	//\*\/ccc       <ccc>42</ccc>
                        <ccc>99</ccc>
                        <ccc>22</ccc>
--	//bbb@x         x="hello"
	//bbb[@x]       <bbb x="hello"><ccc>42</ccc></bbb>
	                <bbb x="bye"><ccc>99</ccc></bbb>
	//bbb[@x=hello] <bbb x="hello"><ccc>42</ccc></bbb>
	//bbb[@x="hello"] as above
	//bbb[0]        <bbb x="hello"><ccc>42</ccc></bbb>
	//bbb[ccc=99]   <bbb x="bye"><ccc>99</ccc></bbb>
---     //\*\/[ccc=99]  same as above
	'//bbb | //ddd' <bbb><ccc>42</ccc></bbb>
	                <bbb x="hello"><ccc>99</ccc></bbb>
		        <ddd><ccc>22</ccc></ddd> (NB spaces)
	etc
 For xpath v1.0 see http://www.w3.org/TR/xpath/
record[name=c][time=d]
in
<record>
   <name>c</name>
   <time>d</time>
   <userid>45654df4-2292-45d3-9ca5-ee72452568a8</userid>
</record>


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
#include <syslog.h>
#include <fcntl.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_string.h"
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_xsl.h"

/* Constants */
#define XPATH_VEC_START 128

/*
 * Types 
 */
struct searchvec{
    cxobj    **sv_v0;   /* here is result */
    int        sv_v0len;
    cxobj    **sv_v1;   /* this is tmp storage */
    int        sv_v1len;
    int        sv_max;
};
typedef struct searchvec searchvec;

/* Local types 
 */
enum axis_type{
    A_SELF,
    A_CHILD,
    A_PARENT,
    A_ROOT,
    A_ANCESTOR,
    A_DESCENDANT_OR_SELF, /* actually descendant-or-self */
};

/* Mapping between axis type string <--> int  */
static const map_str2int axismap[] = {
    {"self",             A_SELF}, 
    {"child",            A_CHILD}, 
    {"parent",           A_PARENT},
    {"root",             A_ROOT},
    {"ancestor",         A_ANCESTOR}, 
    {"descendant-or-self", A_DESCENDANT_OR_SELF}, 
    {NULL,               -1}
};

struct xpath_predicate{
    struct xpath_predicate *xp_next;
    char                   *xp_expr;
};

struct xpath_element{
    struct xpath_element   *xe_next;
    enum axis_type          xe_type;
    char                   *xe_prefix; /* eg for namespaces */
    char                   *xe_str; /* eg for child */
    struct xpath_predicate *xe_predicate; /* eg within [] */
};

static int xpath_split(char *xpathstr, char **pathexpr);

static int 
xpath_print(FILE *f, struct xpath_element *xplist)
{
    struct xpath_element   *xe;
    struct xpath_predicate *xp;

    for (xe=xplist; xe; xe=xe->xe_next){
	fprintf(f, "\t:%s %s ", clicon_int2str(axismap, xe->xe_type),
		xe->xe_str?xe->xe_str:"");
        for (xp=xe->xe_predicate; xp; xp=xp->xp_next)
	    fprintf(f, "[%s]", xp->xp_expr);
    }
    return 0;
}

/*! Extract PredicateExpr (Expr) from a Predicate within [] 
 * @see xpath_expr  For evaluation of predicate 
 */
static int
xpath_parse_predicate(struct xpath_element *xe,
		      char                 *pred)
{
    int                     retval = -1;
    struct xpath_predicate *xp;
    char                   *s;
    int                     i;
    int                     len;

    len = strlen(pred);
    for (i=len-1; i>=0; i--){ /* -1 since we search for ][ */
	s = &pred[i];
	if (i==0 || 
	    (*(s)==']' && *(s+1)=='[')){
	    if (i) {
		*(s)= '\0';
		s += 2;
	    }
	    if ((xp = malloc(sizeof(*xp))) == NULL){
		clicon_err(OE_UNIX, errno, "malloc");
		goto done;
	    }	
	    memset(xp, 0, sizeof(*xp));    
	    if ((xp->xp_expr = strdup(s)) == NULL){	    
		clicon_err(OE_XML, errno, "strdup");
		goto done;
	    }
	    xp->xp_next = xe->xe_predicate;
	    xe->xe_predicate = xp;
	}
    }
    retval = 0;
 done:
    return retval;
}

static int
xpath_element_new(enum axis_type          atype, 
		  char                   *str,
		  struct xpath_element ***xpnext)
{
    int                     retval = -1;
    struct xpath_element   *xe;
    char                   *str1 = NULL;
    char                   *pred;
    char                   *local;

    if ((xe = malloc(sizeof(*xe))) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    memset(xe, 0, sizeof(*xe));
    xe->xe_type = atype;
    if (str){
	if ((str1 = strdup(str)) == NULL){
	    clicon_err(OE_XML, errno, "strdup");
	    goto done;
	}
	if (xpath_split(str1, &pred) < 0) /* Can be more predicates */
	    goto done;
	if (strlen(str1)){
	    /* Split into prefix and localname */
	    if ((local = index(str1, ':')) != NULL){
		*local = '\0';
		local++;
		if ((xe->xe_prefix = strdup(str1)) == NULL){
		    clicon_err(OE_XML, errno, "strdup");
		    goto done;
		}
	    }
	    else
		local = str1;
	    if ((xe->xe_str = strdup(local)) == NULL){
		clicon_err(OE_XML, errno, "strdup");
		goto done;
	    }
	}
	else{
	    if ((xe->xe_str = strdup("*")) == NULL){
		clicon_err(OE_XML, errno, "strdup");
		goto done;
	    }
	}
	if (pred && strlen(pred)){
	    if (xpath_parse_predicate(xe, pred) < 0)
		goto done;
	}
    }
    (**xpnext) = xe;
    *xpnext = &xe->xe_next;
    retval = 0;
 done:
    if (str1)
	free(str1);
    return retval;
}

static int
xpath_element_free(struct xpath_element *xe)
{
    struct xpath_predicate *xp;

    if (xe->xe_str)
	free(xe->xe_str);
    if (xe->xe_prefix)
	free(xe->xe_prefix);
    while ((xp = xe->xe_predicate) != NULL){
	xe->xe_predicate = xp->xp_next;
	if (xp->xp_expr)
	    free(xp->xp_expr);
	free(xp);
    }
    free(xe);
    return 0;
}

static int
xpath_free(struct xpath_element *xplist)
{
    struct xpath_element *xe, *xe_next;

    for (xe=xplist; xe; xe=xe_next){
	xe_next = xe->xe_next;
	xpath_element_free(xe);
    }
    return 0;
}

/*
 * // is short for /descendant-or-self::node()/
 */
static int
xpath_parse(char                  *xpath, 
	    struct xpath_element **xplist0)
{
    int                    retval = -1;
    int                    nvec = 0;
    char                  *s;
    char                  *s0;
    int                    i;
    struct xpath_element  *xplist = NULL;
    struct xpath_element **xpnext = &xplist;
    int                    esc = 0;

    if ((s0 = strdup(xpath)) == NULL){
	clicon_err(OE_XML, errno, "strdup");
	goto done;
    }
    s = s0;
    if (strlen(s))
	nvec = 1;
    /* Chop up LocationPath in Steps delimited by '/' (unless [] predicate) 
     * Eg, "/a/b[/c]/d" -> "a" "b[/c]" "d"
     */
    esc = 0;
    while (*s != '\0'){
	switch (*s){
	case '/':
	    if (esc)
		break;
	    nvec++;
	    *s = '\0';
	    break;
	case '[':
	    esc++;
	    break;
	case ']':
	    esc--;
	    break;
	default:
	    break;
	}
	s++;
    }
    s = s0;
    for (i=0; i<nvec; i++){
	if ((i==0 && strcmp(s,"")==0)) /* Initial / or // */
	    xpath_element_new(A_ROOT, NULL, &xpnext);
	else if (i!=nvec-1 && strcmp(s,"")==0)
	    xpath_element_new(A_DESCENDANT_OR_SELF, NULL, &xpnext);
	else if (strncmp(s,"descendant-or-self::", strlen("descendant-or-self::"))==0){ 
	    xpath_element_new(A_DESCENDANT_OR_SELF, s+strlen("descendant-or-self::"), &xpnext);
	}
#if 1
	else if (strncmp(s,"..", strlen(".."))==0) /* abbreviatedstep */
	    xpath_element_new(A_PARENT, s+strlen(".."), &xpnext);
#else
	else if (strncmp(s,"..", strlen(s))==0) /* abbreviatedstep */
	    xpath_element_new(A_PARENT, NULL, &xpnext);
#endif
#if 1 /* Problems with .[userid=1321] */
	else if (strncmp(s,".", strlen("."))==0)
	    xpath_element_new(A_SELF, s+strlen("."), &xpnext);
#else
	else if (strncmp(s,".", strlen(s))==0) /* abbreviatedstep */
	    xpath_element_new(A_SELF, NULL, &xpnext);
#endif

	else if (strncmp(s,"self::", strlen("self::"))==0)
	    xpath_element_new(A_SELF, s+strlen("self::"), &xpnext);

	else if (strncmp(s,"parent::", strlen("parent::"))==0)
	    xpath_element_new(A_PARENT, s+strlen("parent::"), &xpnext);
	else if (strncmp(s,"ancestor::", strlen("ancestor::"))==0)
	    xpath_element_new(A_ANCESTOR, s+strlen("ancestor::"), &xpnext);
	else if (strncmp(s,"child::", strlen("child::"))==0)
	    xpath_element_new(A_CHILD, s+strlen("child::"), &xpnext);
	else 
	    xpath_element_new(A_CHILD, s, &xpnext);
	s += strlen(s) + 1;
    }
    retval = 0;
 done:
    if (s0)
	free(s0);
    if (retval == 0)
	*xplist0 = xplist;
    return retval;
}

/*! Find a node 'deep' in an XML tree
 *
 * The xv_* arguments are filled in  nodes found earlier.
 * args:
 *  @param[in]    xn_parent  Base XML object
 *  @param[in]    name       shell wildcard pattern to match with node name
 *  @param[in]    node_type  CX_ELMNT, CX_ATTR or CX_BODY
 *  @param[in,out] vec1      internal buffers with results
 *  @param[in,out] vec0      internal buffers with results
 *  @param[in,out] vec_len   internal buffers with length of vec0,vec1
 *  @param[in,out] vec_max   internal buffers with max of vec0,vec1
 * returns:
 *  0 on OK, -1 on error
 */
static int
recursive_find(cxobj   *xn, 
	       char    *pattern, 
	       int      node_type,
	       uint16_t flags,
	       cxobj ***vec0,
	       size_t  *vec0len)
{
    int     retval = -1;
    cxobj  *xsub; 
    cxobj **vec = *vec0;
    size_t  veclen = *vec0len;
    char   *name;

    xsub = NULL;
    while ((xsub = xml_child_each(xn, xsub, node_type)) != NULL) {
	name = xml_name(xsub);
	if (fnmatch(pattern, name, 0) == 0){
	    clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(xsub, flags));
	    if (flags==0x0 || xml_flag(xsub, flags))
		if (cxvec_append(xsub, &vec, &veclen) < 0)
		    goto done;
	    //	    continue; /* Dont go deeper */
	}
	if (recursive_find(xsub, pattern, node_type, flags, &vec, &veclen) < 0)
	    goto done;
    }
    retval = 0;
    *vec0 = vec;
    *vec0len = veclen;
  done:
    return retval;
}

/* forward */
static int
xpath_exec(cxobj *xcur, char *xpath, cxobj **vec0, size_t vec0len,
	   uint16_t flags, cxobj ***vec2, size_t *vec2len);

/*! XPath predicate expression check
 * @param[in]  xcur  xml-tree where to search
 * @param[in]  predicate_expression     xpath expression as a string
 * @param[in]  flags   Extra xml flag checks that must match (apart from predicate)
 * @param[in,out] vec0    Vector or xml nodes that are checked. Not matched are filtered
 * @param[in,out] vec0len Length of vector or matches
 * On input, vec0 contains a list of xml nodes to match. 
 * On output, vec0 contains only the subset that matched the expression.
 * The predicate expression is a subset of the standard, namely:
 *  - @<attr>=<value>
 *  - <number>
 *  - <name>=<value> # RelationalExpr '=' RelationalExpr
 *  - <name>=current()<xpath> XXX
 * @see https://www.w3.org/TR/xpath/#predicates
 */
static int
xpath_expr(cxobj    *xcur, 
	   char     *predicate_expression, 	   
	   uint16_t  flags,
	   cxobj  ***vec0,
	   size_t   *vec0len)
{
    char      *e_a;
    char      *e_v;
    int        i;
    int        j;
    int        retval = -1;
    cxobj     *x;
    cxobj     *xv;
    cxobj    **vec = NULL;
    size_t     veclen = 0;
    int        oplen;
    char      *tag;
    char      *val;
    char      *e0;
    char      *e;
    char      *name;

    if ((e0 = strdup(predicate_expression)) == NULL){
	clicon_err(OE_UNIX, errno, "strdup");
	goto done;
    }
    e = e0;
    if (*e == '@'){ /* @ attribute */
	e++;
	e_v=e;
	e_a = strsep(&e_v, "=");
	if (e_a == NULL){
	    clicon_err(OE_XML, errno, "malformed expression: [@%s]", e);
	    goto done;
	}
	for (i=0; i<*vec0len; i++){
	    xv = (*vec0)[i];
	    if ((x = xml_find(xv, e_a)) != NULL &&
		(xml_type(x) == CX_ATTR)){
		if (!e_v || strcmp(xml_value(x), e_v) == 0){
		    clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(xv, flags));
		    if (flags==0x0 || xml_flag(xv, flags)){
			if (cxvec_append(xv, &vec, &veclen) < 0)
			    goto done;
			break; /* xv added */
		    }
		}
	    }
	}
    }
    else{ /* either <n> or <tag><op><value>, where <op>='=' for now */
	oplen = strcspn(e, "=");
	if (strlen(e+oplen)==0){ /* no operator */
	    if (sscanf(e, "%d", &i) == 1){ /* number */
		if (i < *vec0len){
		    xv = (*vec0)[i]; /* XXX: cant compress: gcc breaks */
	    clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(xv, flags));
		    if (flags==0x0 || xml_flag(xv, flags))
			if (cxvec_append(xv, &vec, &veclen) < 0)
			    goto done;
		}
	    }
	    else{
		clicon_err(OE_XML, errno, "malformed expression: [%s]", e);
		goto done;
	    }
	}
	else{ /* name = expr */
	    if ((tag = strsep(&e, "=")) == NULL){
		clicon_err(OE_XML, errno, "malformed expression: [%s]", e);
		goto done;
	    }
	    /* Strip trailing spaces */
	    while (tag[strlen(tag)-1] == ' ')
		tag[strlen(tag)-1] = '\0';
	    /* Strip heading spaces */
	    while (e[0]==' ')
		e++;
	    if (strncmp(e, "current()", strlen("current()")) == 0){
		/* name = current()xpath */
		cxobj    **svec0 = NULL;
		size_t     svec0len = 0;
		cxobj    **svec1 = NULL;
		size_t     svec1len = 0;
		char      *ebody;

		e += strlen("current("); /* e is path expression */
		*e = '.';
		if ((svec0 = calloc(1, sizeof(cxobj *))) == NULL){
		    clicon_err(OE_UNIX, errno, "calloc");
		    goto done;
		}
		svec0[0] = xcur;
		svec0len++;
		/* Recursive invocation */
		if (xpath_exec(xcur, e, svec0, svec0len,
			       flags, &svec1, &svec1len) < 0)
		    goto done;
		for (j=0; j<svec1len; j++){
		    ebody = xml_body(svec1[j]);
		    for (i=0; i<*vec0len; i++){
			xv = (*vec0)[i];
			x = NULL;
			while ((x = xml_child_each(xv, x, CX_ELMNT)) != NULL) {
			    name = xml_name(x);
			    if (name==NULL || strcmp(tag, name) != 0)
				continue;
			    if ((val = xml_body(x)) != NULL &&
				strcmp(val, ebody) == 0){	
				clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(xv, flags));
				if (flags==0x0 || xml_flag(xv, flags))
				    if (cxvec_append(xv, &vec, &veclen) < 0)
					goto done;
			    }
			}
		    }
		}
	    }
	    else { /* name = value */
		for (i=0; i<*vec0len; i++){
		    xv = (*vec0)[i];
		    /* Check if more may match,... */
		    x = NULL;
		    while ((x = xml_child_each(xv, x, CX_ELMNT)) != NULL) {
			name = xml_name(x);
			if (name==NULL || strcmp(tag, name) != 0)
			    continue;
			if ((val = xml_body(x)) != NULL &&
			    strcmp(val, e) == 0){
			    clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(xv, flags));
			    if (flags==0x0 || xml_flag(xv, flags))
				if (cxvec_append(xv, &vec, &veclen) < 0)
				    goto done;
			}
		    }
		}
	    }
	}
    }
    /* copy the array from 1 to 0 */
    free(*vec0);
    *vec0 = vec;
    *vec0len = veclen;
    retval = 0;
  done:
    if (e0)
	free(e0);
    return retval;
}

/*! Given vec0, add matches to vec1
 * @param[in]   xcur  xml-tree where to search
 * @param[in]   xe      XPATH in structured (parsed) form
 * @param[in]   descendants0
 * @param[in]   vec0    vector of XML trees
 * @param[in]   vec0len length of XML trees
 * @param[in]   flags   if != 0, only match xml nodes matching flags
 * @param[out]  vec2    Result XML node vector
 * @param[out]  vec2len Length of result vector.
 */
static int
xpath_find(cxobj                *xcur, 
	   struct xpath_element *xe,
	   int                   descendants0,
	   cxobj               **vec0,
	   size_t                vec0len,
	   uint16_t              flags,
	   cxobj              ***vec2,
	   size_t               *vec2len
	   )
{
    int            retval = -1;
    int            i;
    int            j;
    cxobj         *x = NULL;
    cxobj         *xv;
    int            descendants = 0;
    cxobj        **vec1 = NULL;
    cxobj         *xparent;
    size_t         vec1len = 0;
    struct xpath_predicate *xp;
    char          *name;

    if (xe == NULL){
	for (i=0; i<vec0len; i++){
	    xv = vec0[i];
	    if (flags==0x0 || xml_flag(xv, flags))
		cxvec_append(xv, vec2, vec2len);
	}
	free(vec0);
	return 0;
    }
#if 0
    fprintf(stderr, "%s: %s: \"%s\"\n", __FUNCTION__, 
	    clicon_int2str(axismap, xe->xe_type), xe->xe_str?xe->xe_str:"");
#endif
    switch (xe->xe_type){
    case A_SELF:
	break;
    case A_PARENT:
	j = 0;
	for (i=0; i<vec0len; i++){
	    xv = vec0[i];
	    if ((xparent = xml_parent(xv)) != NULL)
		vec0[j++] = xparent;
	}
	vec0len = j;
	break;
    case A_ROOT: /* set list to NULL */
	x = vec0[0];
	assert(x != NULL);
	while (xml_parent(x) != NULL)
	    x = xml_parent(x);
	free(vec0);
	if ((vec0 = calloc(1, sizeof(cxobj *))) == NULL){
	    clicon_err(OE_UNIX, errno, "calloc");
	    goto done;
	}
	vec0[0] = x;
	vec0len = 1;
	break;
    case A_CHILD:
	if (descendants0){
	    for (i=0; i<vec0len; i++){
		xv = vec0[i];
		if (recursive_find(xv, xe->xe_str, CX_ELMNT, flags, &vec1, &vec1len) < 0)
		    goto done;
	    }
	}
	else{
	    for (i=0; i<vec0len; i++){
		xv = vec0[i];
		x = NULL;
		while ((x = xml_child_each(xv, x, -1)) != NULL) {
		    name = xml_name(x);
		    if (name && fnmatch(xe->xe_str, name, 0) == 0) {
				clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(x, flags));
				if (flags==0x0 || xml_flag(x, flags))
				    if (cxvec_append(x, &vec1, &vec1len) < 0)
					goto done;
			    }
		}	    
	    }
	}
	free(vec0);
	vec0 = vec1;
	vec0len = vec1len;
	break;
    case A_DESCENDANT_OR_SELF: 	
	/* Instead of collecting all descendants (which we could)
	   just set a flag and treat that in the next operation */
	descendants++;
	break;
    default:
	break;
    }
    /* remove duplicates 
     *   This is cycle-heavy and I dont know when it is needed? 
     */
    if (0)
	for (i=0; i<vec0len; i++){
	    for (j=i+1; j<vec0len; j++){
		if (vec0[i] == vec0[j]){
		    memmove(vec0[j], vec0[j+1], (vec0len-j)*sizeof(cxobj*));
		    vec0len--;
		}
	    }
	}

    for (xp = xe->xe_predicate; xp; xp = xp->xp_next){
	if (xpath_expr(xcur, xp->xp_expr, flags, &vec0, &vec0len) < 0)
	    goto done;
    }

    if (xpath_find(xcur, xe->xe_next, descendants, 
		   vec0, vec0len, flags,
		   vec2, vec2len) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! Transform eg "a/b[kalle]" -> "a/b" e="kalle" 
 * @param[in,out] xpathstr  Eg "a/b[kalle]" -> "a/b"
 * @param[out]    pathexpr  Eg "kalle"
 * Which also means:
 *  "a/b[foo][bar]" -> pathexpr: "foo][bar" 
 * @note destructively modify xpathstr, no new strings allocated
 */
static int
xpath_split(char  *xpathstr, 
	    char **pathexpr)
{
    int   retval = -1;
    int   last;
    char *pe = NULL;

    if (strlen(xpathstr)){
	last = strlen(xpathstr) - 1; /* XXX: this could be -1.. */
	if (xpathstr[last] == ']'){
	    xpathstr[last] = '\0';
	    if (strlen(xpathstr)){
		if ((pe = index(xpathstr,'[')) != NULL){
		    *pe = '\0';
		    pe++;
		}
	    }
	    if (pe==NULL){
		clicon_err(OE_XML, errno, "mismatched []: %s", xpathstr);
		goto done;
	    }
	}
    }
    retval = 0;
  done:
    *pathexpr = pe;
    return retval;
}

/*! Process single xpath expression on xml tree
 * @param[in]  xcur  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @param[in]  vec0    vector of XML trees
 * @param[in]  vec0len length of XML trees
 * @param[in]  flags   if != 0, only match xml nodes matching flags
 * @param[out] vec2    Result XML node vector
 * @param[out] vec2len Length of result vector.
 */
static int
xpath_exec(cxobj        *xcur, 
	   char         *xpath, 
	   cxobj       **vec0, 
	   size_t        vec0len,
	   uint16_t      flags,
	   cxobj      ***vec2, 
	   size_t       *vec2len)
{
    struct xpath_element *xplist;
    cxobj               **vec1;
    size_t                vec1len;

    if (cxvec_dup(vec0, vec0len, &vec1, &vec1len) < 0)
	goto done;
    if (xpath_parse(xpath, &xplist) < 0)
	goto done;
    if (debug > 1)
	xpath_print(stderr, xplist);
    if (xpath_find(xcur, xplist, 0, vec1, vec1len, flags, vec2, vec2len) < 0)
	goto done;
    if (xpath_free(xplist) < 0)
	goto done;
  done:
    return 0;
} /* xpath_exec */


/*! Intermediate xpath function to handle 'conditional' cases. 
 * @param[in]  xcur  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @param[in]  flags   if != 0, only match xml nodes matching flags
 * @param[in]  vec1    vector of XML trees
 * @param[in]  vec1len length of XML trees
 * For example: xpath = //a | //b. 
 * xpath_first+ splits xpath up in several subcalls
 * (eg xpath=//a and xpath=//b) and collects the results.
 * Note: if a match is found in both, two (or more) same results will be 
 * returned.
 * Note, this could be 'folded' into xpath1 but I judged it too complex.
 */
static int
xpath_choice(cxobj   *xcur, 
	     char    *xpath0, 
	     uint16_t flags,
	     cxobj ***vec1, 
	     size_t  *vec1len)
{
    int               retval = -1;
    char             *s0;
    char             *s1;
    char             *s2;
    char             *xpath;
    cxobj           **vec0 = NULL;
    size_t            vec0len = 0;

    if ((s0 = strdup(xpath0)) == NULL){
	clicon_err(OE_XML, errno, "strdup");
	goto done;
    }
    s2 = s1 = s0;
    if ((vec0 = calloc(1, sizeof(cxobj *))) == NULL){
	clicon_err(OE_UNIX, errno, "calloc");
	goto done;
    }
    vec0[0] = xcur;
    vec0len++;
    while (s1 != NULL){
	s2 = strstr(s1, " | ");
	if (s2 != NULL){
	    *s2 = '\0'; /* terminate xpath */
	    s2 += 3;
	}
	xpath = s1;
	s1 = s2;
	if (xpath_exec(xcur, xpath, vec0, vec0len, flags, vec1, vec1len) < 0)
	    goto done;
    }
    retval = 0;
  done:
    if (s0)
	free(s0);
    if (vec0)
	free(vec0);
    return retval;
}

/*! Help function to  xpath_first
 */
static cxobj *
xpath_first0(cxobj *xcur, 
	     char  *xpath)
{
    cxobj **vec1 = NULL;
    size_t  vec1len = 0;
    cxobj  *xn = NULL;

    if (xpath_choice(xcur, xpath, 0, &vec1, &vec1len) < 0)
	goto done;
    if (vec1len)
	xn = vec1[0];
    else
	xn = NULL;
  done:
    if (vec1)
	free(vec1);
    return xn;
}

/*! A restricted xpath function where the first matching entry is returned
 * See xpath1() on details for subset.
 * args:
 * @param[in]  xcur  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @retval     xml-tree of first match
 * @retval     NULL    Error or not found
 *
 * @code
 *   cxobj *x;
 *   if ((x = xpath_first(xtop, "//symbol/foo")) != NULL) {
 *         ...
 *   }
 * @endcode
 * @note  the returned pointer points into the original tree so should not be freed after use.
 * @note return value does not see difference between error and not found
 * @see also xpath_vec.
 */
cxobj *
xpath_first(cxobj   *xcur, 
	    char    *format, 
	    ...)
{
    cxobj  *retval = NULL;
    va_list ap;
    size_t  len;
    char   *xpath;

    va_start(ap, format);    
    len = vsnprintf(NULL, 0, format, ap);
    va_end(ap);
    /* allocate a message string exactly fitting the message length */
    if ((xpath = malloc(len+1)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    /* second round: compute write message from reason and args */
    va_start(ap, format);    
    if (vsnprintf(xpath, len+1, format, ap) < 0){
	clicon_err(OE_UNIX, errno, "vsnprintf");
	va_end(ap);
	goto done;
    }
    va_end(ap);
    retval = xpath_first0(xcur, xpath);
 done:
    if (xpath)
	free(xpath);
    return retval;
}

/*! A restricted xpath iterator that loops over all matching entries. Dont use.
 *
 * See xpath1() on details for subset.
 * @param[in]  xcur  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @param[in]  xprev   iterator/result should be initiated to NULL
 * @retval     xml-tree of n:th match, or NULL on error. 
 *
 * @code
 *   cxobj *x = NULL;
 *   while ((x = xpath_each(xcur, "//symbol/foo", x)) != NULL) {
 *     ...
 *   }
 * @endcode
 *
 * @note The returned pointer points into the original tree so should not be freed
 * after use.
 * @see also xpath, xpath_vec.
 * @note uses a static variable: consider replacing with xpath_vec() instead
 */
cxobj *
xpath_each(cxobj *xcur, 
	   char  *xpath, 
	   cxobj *xprev)
{
    static cxobj    **vec1 = NULL; /* XXX */
    static size_t     vec1len = 0;
    cxobj            *xn = NULL;
    int i;
    
    if (xprev == NULL){
	if (vec1) {
	    free(vec1);
	    vec1 = NULL;
	}
	vec1len = 0;
	if (xpath_choice(xcur, xpath, 0, &vec1, &vec1len) < 0)
	    goto done;
    }
    if (vec1len){
	if (xprev==NULL)
	    xn = vec1[0];
	else{
	    for (i=0; i<vec1len; i++)
		if (vec1[i] == xprev)
		    break;
	    if (i>=vec1len-1)
		xn = NULL; 
	    else
		xn = vec1[i+1];
	}
    }
    else
	xn = NULL;
  done:
    return xn;
}

/*! A restricted xpath that returns a vector of matches
 *
 * See xpath1() on details for subset
. * @param[in]  xcur  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @param[out] vec     vector of xml-trees. Vector must be free():d after use
 * @param[out] veclen  returns length of vector in return value
 * @retval     0       OK
 * @retval     -1      error.
 *
 * @code
 *   cxobj **xvec = NULL;
 *   size_t  xlen;
 *   if (xpath_vec(xcur, "//symbol/foo", &xvec, &xlen) < 0) 
 *      goto err;
 *   for (i=0; i<xlen; i++){
 *      xn = xvec[i];
 *         ...
 *   }
 *   free(xvec);
 * @endcode
 * @note Although the returned vector must be freed after use, 
 *       the returned xml trees should not.
 * @see also xpath_first, xpath_each.
 */
int
xpath_vec(cxobj    *xcur, 
	  char     *format, 
	  cxobj  ***vec, 
	  size_t   *veclen,
	  ...)
{
    int     retval = -1;
    va_list ap;
    size_t  len;
    char   *xpath;

    va_start(ap, veclen);    
    len = vsnprintf(NULL, 0, format, ap);
    va_end(ap);
    /* allocate a message string exactly fitting the message length */
    if ((xpath = malloc(len+1)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    /* second round: compute write message from reason and args */
    va_start(ap, veclen);    
    if (vsnprintf(xpath, len+1, format, ap) < 0){
	clicon_err(OE_UNIX, errno, "vsnprintf");
	va_end(ap);
	goto done;
    }
    va_end(ap);
    *vec = NULL;
    *veclen = 0;
    retval = xpath_choice(xcur, xpath, 0x0, vec, veclen);
 done:
    if (xpath)
	free(xpath);
    return retval;
}

/* A restricted xpath that returns a vector of matches (only nodes marked with flags)
 * @param[in]  xcur  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @param[in]  flags   Set of flags that return nodes must match (0 if all)
 * @param[out] vec     vector of xml-trees. Vector must be free():d after use
 * @param[out] veclen  returns length of vector in return value
 * @retval     0       OK
 * @retval     -1      error.
 * @code
 *   cxobj **vec;
 *   size_t  veclen;
 *   if (xpath_vec_flag(xcur, "//symbol/foo", XML_FLAG_ADD, &vec, &veclen) < 0) 
 *      goto err;
 *   for (i=0; i<veclen; i++){
 *      xn = vec[i];
 *         ...
 *   }
 *   free(vec);
 * @endcode
 * @Note that although the returned vector must be freed after use, the returned xml
 * trees need not be.
 * @see also xpath_vec This is a specialized version.
 */
int
xpath_vec_flag(cxobj   *xcur, 
	       char    *format, 
	       uint16_t flags,
	       cxobj ***vec, 
	       size_t  *veclen,
	       ...)
{
    int retval = -1;
    va_list ap;
    size_t  len;
    char   *xpath;

    va_start(ap, veclen);    
    len = vsnprintf(NULL, 0, format, ap);
    va_end(ap);
    /* allocate a message string exactly fitting the message length */
    if ((xpath = malloc(len+1)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    /* second round: compute write message from reason and args */
    va_start(ap, veclen);    
    if (vsnprintf(xpath, len+1, format, ap) < 0){
	clicon_err(OE_UNIX, errno, "vsnprintf");
	va_end(ap);
	goto done;
    }
    va_end(ap);
    *vec=NULL;
    *veclen = 0;
    retval = xpath_choice(xcur, xpath, flags, vec, veclen);
 done:
    if (xpath)
	free(xpath);
    return retval;
}

/*
 * Turn this on to get an xpath test program 
 * Usage: xpath [<xpath>] 
 * read xpath on first line and xml on rest of lines from input
 * Example compile:
 gcc -g -o xpath -I. -I../clixon ./clixon_xsl.c -lclixon -lcligen
 * Example run:
echo "a\n<a><b/></a>" | xpath
*/
#if 0 /* Test program */


static int
usage(char *argv0)
{
    fprintf(stderr, "usage:%s <xml file name>.\n\tInput on stdin\n", argv0);
    exit(0);
}

int
main(int argc, char **argv)
{
    int         retval = -1;
    int         i;
    cxobj     **xv;
    cxobj      *x;
    cxobj      *xn;
    size_t      xlen = 0;
    int         c;
    int         len;
    char       *buf = NULL;
    char       *filename;
    int         fd;
	
    if (argc != 2){
	usage(argv[0]);
	goto done;
    }
    filename = argv[1];
    if ((fd = open(filename, O_RDONLY)) < 0){
      clicon_err(OE_UNIX, errno, "open(%s)", filename);
      goto done;
    }    
    /* Read xpath */
    len = 1024; /* any number is fine */
    if ((buf = malloc(len)) == NULL){
	perror("pt_file malloc");
	return -1;
    }
    memset(buf, 0, len);
    i = 0;
    while (1){ /* read the whole file */
      if ((c =  fgetc(stdin)) == EOF)
	return -1;
      if (c == '\n')
	break;
      if (len==i){
	if ((buf = realloc(buf, 2*len)) == NULL){
	  fprintf(stderr, "%s: realloc: %s\n", __FUNCTION__, strerror(errno));
	  return -1;
	}	    
	memset(buf+len, 0, len);
	len *= 2;
      }
      buf[i++] = (char)(c&0xff);
    }
    x = NULL;
    if (xml_parse_file(fd, "</clicon>", NULL, &x) < 0){
      fprintf(stderr, "Error: parsing: %s\n", clicon_err_reason);
	return -1;
    }
    close (fd);
    printf("\n");

    if (xpath_vec(x, "%s", &xv, &xlen, buf) < 0)
	return -1;
    if (xv){
	for (i=0; i<xlen; i++){
	    xn = xv[i];
	    fprintf(stdout, "[%d]:\n", i);
	    clicon_xml2file(stdout, xn, 0, 1);	
	}
	free(xv);
    }
    if (x)
	xml_free(x);
    retval = 0;
 done:
    return retval;
}

#endif /* Test program */

