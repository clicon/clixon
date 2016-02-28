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

 * Limited XML XPATH and XSLT functions.
 * NOTE: there is a main function at the end of this file where you can test out
 * different xpath expressions.
 */
/*
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

struct map_str2int{
    char         *ms_str; /* string as in 4.2.4 in RFC 6020 */
    int           ms_int;
};

/* Mapping between axis type string <--> int  */
static const struct map_str2int atmap[] = {
    {"self",             A_SELF}, 
    {"child",            A_CHILD}, 
    {"parent",           A_PARENT},
    {"root",             A_ROOT},
    {"ancestor",         A_ANCESTOR}, 
    {"descendant-or-self", A_DESCENDANT_OR_SELF}, 
    {NULL,               -1}
};

struct xpath_element{
    struct xpath_element *xe_next;
    enum axis_type        xe_type;
    char                 *xe_str; /* eg for child */
    char                 *xe_predicate; /* eg within [] */
};

static int xpath_split(char *xpathstr, char **pathexpr);

static char *axis_type2str(enum axis_type type) __attribute__ ((unused));

static char *
axis_type2str(enum axis_type type)
{
    const struct map_str2int *at;

    for (at = &atmap[0]; at->ms_str; at++)
	if (at->ms_int == type)
	    return at->ms_str;
    return NULL;
}

static int 
xpath_print(FILE *f, struct xpath_element *xplist)
{
    struct xpath_element *xe;

    for (xe=xplist; xe; xe=xe->xe_next)
	fprintf(f, "\t:%s %s\n", axis_type2str(xe->xe_type),
		xe->xe_str?xe->xe_str:"");
    return 0;
}

static int
xpath_element_new(enum axis_type          atype, 
		  char                   *str,
		  struct xpath_element ***xpnext)
{
    int                   retval = -1;
    struct xpath_element *xe;
    char                 *str1 = NULL;
    char                 *pred;

    if ((xe = malloc(sizeof(*xe))) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    memset(xe, 0, sizeof(*xe));
    xe->xe_type = atype;
    if (str){
	if ((str1 = strdup(str)) == NULL){
	    clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	    goto done;
	}
	if (xpath_split(str1, &pred) < 0)
	    goto done;
	if (strlen(str1)){
	    if ((xe->xe_str = strdup(str1)) == NULL){
		clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
		goto done;
	    }
	}
	else{
	    if ((xe->xe_str = strdup("*")) == NULL){
		clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
		goto done;
	    }
	}
	if (pred && strlen(pred) && (xe->xe_predicate = strdup(pred)) == NULL){
	    clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
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
    if (xe->xe_str)
	free(xe->xe_str);
    if (xe->xe_predicate)
	free(xe->xe_predicate);
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
xpath_parse(char *xpath, struct xpath_element **xplist0)
{
    int                    retval = -1;
    int                    nvec = 0;
    char                  *p;
    char                  *s;
    char                  *s0;
    int                    i;
    struct xpath_element  *xplist = NULL;
    struct xpath_element **xpnext = &xplist;

    if ((s0 = strdup(xpath)) == NULL){
	clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	goto done;
    }
    s = s0;
    if (strlen(s))
	nvec = 1;
    while ((p = index(s, '/')) != NULL){
	nvec++;
	*p = '\0';
	s = p+1;
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
	else if (strncmp(s,".", strlen("."))==0)
	    xpath_element_new(A_SELF, s+strlen("."), &xpnext);
	else if (strncmp(s,"self::", strlen("self::"))==0)
	    xpath_element_new(A_SELF, s+strlen("self::"), &xpnext);
	else if (strncmp(s,"..", strlen(".."))==0)
	    xpath_element_new(A_PARENT, s+strlen(".."), &xpnext);
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
 *  @param[in,out] vec1        internal buffers with results
 *  @param[in,out] vec0        internal buffers with results
 *  @param[in,out] vec_len     internal buffers with length of vec0,vec1
 *  @param[in,out] vec_max     internal buffers with max of vec0,vec1
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

    xsub = NULL;
    while ((xsub = xml_child_each(xn, xsub, node_type)) != NULL) {
	if (fnmatch(pattern, xml_name(xsub), 0) == 0){
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

static int
xpath_expr(char     *e, 	   
	   uint16_t  flags,
	   cxobj  ***vec0,
	   size_t   *vec0len)
{
    char      *e_a;
    char      *e_v;
    int        i;
    int        retval = -1;
    cxobj     *x;
    cxobj     *xv;
    cxobj    **vec = NULL;
    size_t     veclen = 0;
    int        oplen;
    char      *tag;
    char      *val;

    if (*e == '@'){ /* @ attribute */
	e++;
	e_v=e;
	e_a = strsep(&e_v, "=");
	if (e_a == NULL){
	    clicon_err(OE_XML, errno, "%s: malformed expression: [@%s]", 
		       __FUNCTION__, e);
	    goto done;
	}
	for (i=0; i<*vec0len; i++){
	    xv = (*vec0)[i];
	    if ((x = xml_find(xv, e_a)) != NULL &&
		(xml_type(x) == CX_ATTR)){
		if (!e_v || strcmp(xml_value(x), e_v) == 0){
	    clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(xv, flags));
		    if (flags==0x0 || xml_flag(xv, flags))
			if (cxvec_append(xv, &vec, &veclen) < 0)
			    goto done;
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
		clicon_err(OE_XML, errno, "%s: malformed expression: [%s]", 
			   __FUNCTION__, e);
		goto done;
	    }
	}
	else{
	    if ((tag = strsep(&e, "=")) == NULL){
		clicon_err(OE_XML, errno, "%s: malformed expression: [%s]", 
			   __FUNCTION__, e);
		goto done;
	    }
	    for (i=0; i<*vec0len; i++){
		xv = (*vec0)[i];
		if ((x = xml_find(xv, tag)) != NULL &&
		    (xml_type(x) == CX_ELMNT)){
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
    /* copy the array from 1 to 0 */
    free(*vec0);
    *vec0 = vec;
    *vec0len = veclen;
    retval = 0;
  done:
    return retval;
}

/*! Given vec0, add matches to vec1
 * @param[in]   xe 
 * @param[in]   descendants0
 * @param[in]   vec0
 * @param[in]   vec0len
 * @param[out]  vec1
 * @param[out]  vec1len
 * XXX: Kommer in i funktionen med vec0, resultatet appendas i vec1
 * vec0 --> vec
 * Det är nog bra om vec0 inte ändras, är input parameter
 * Vid utgång ska vec1 innehålla resultatet.
 * Internt då?
 * XXX: hantering av (input)vec0-->vec-->vec2-->vec1 (resultat)
 */
static int
xpath_find(struct xpath_element *xe,
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
    size_t         vec1len = 0;

    if (xe == NULL){
	/* append */
	for (i=0; i<vec0len; i++){
	    xv = vec0[i];
	    clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(xv, flags));
	    if (flags==0x0 || xml_flag(xv, flags))
		cxvec_append(xv, vec2, vec2len);
	}
	free(vec0);
	return 0;
    }
#if 0
    fprintf(stderr, "%s: %s: \"%s\"\n", __FUNCTION__, 
	    axis_type2str(xe->xe_type), xe->xe_str?xe->xe_str:"");
#endif
    switch (xe->xe_type){
    case A_SELF:
	break;
    case A_PARENT:
	for (i=0; i<vec0len; i++){
	    xv = vec0[i];
	    vec0[i] = xml_parent(xv);
	}
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
	else
	    for (i=0; i<vec0len; i++){
		xv = vec0[i];
		x = NULL;
		while ((x = xml_child_each(xv, x, -1)) != NULL) {
		    if (fnmatch(xe->xe_str, xml_name(x), 0) == 0){ 
	    clicon_debug(2, "%s %x %x", __FUNCTION__, flags, xml_flag(x, flags));
			if (flags==0x0 || xml_flag(x, flags))
			    if (cxvec_append(x, &vec1, &vec1len) < 0)
				goto done;
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
    /* remove duplicates */
    for (i=0; i<vec0len; i++){
	for (j=i+1; j<vec0len; j++){
	    if (vec0[i] == vec0[j]){
		memmove(vec0[j], vec0[j+1], (vec0len-j)*sizeof(cxobj*));
	        vec0len--;
	    }
	}
    }
    if (xe->xe_predicate)
	if (xpath_expr(xe->xe_predicate, flags, &vec0, &vec0len) < 0)
	    goto done;
    if (xpath_find(xe->xe_next, descendants, 
		   vec0, vec0len, flags,
		   vec2, vec2len) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! Transform eg "a/b[kalle]" -> "a/b" e="kalle" */
static int
xpath_split(char *xpathstr, char **pathexpr)
{
    int   retval = -1;
    int   last;
    int   i;
    char *pe = NULL;

    if (strlen(xpathstr)){
	last = strlen(xpathstr) - 1; /* XXX: this could be -1.. */
	if (xpathstr[last] == ']'){
	    xpathstr[last] = '\0';
	    if (strlen(xpathstr)){
		last = strlen(xpathstr) - 1; /* recompute due to null */
		for (i=last; i>=0; i--){
		    if (xpathstr[i] == '['){
			xpathstr[i] = '\0';
			pe = &xpathstr[i+1];
			break;
		    }
		}
		if (pe==NULL){
		    clicon_err(OE_XML, errno, "%s: mismatched []: %s", __FUNCTION__, xpathstr);
		    goto done;
		}
	    }
	}
    }
    retval = 0;
  done:
    *pathexpr = pe;
    return retval;
}

/*! Process single xpath expression on xml tree
 * @param[in]  xpath 
 * @param[in]  vec0
 * @param[in]  vec0len
 * @param[out] vec
 * @param[out] veclen
 */
static int
xpath_exec(char         *xpath, 
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
    if (0)
	xpath_print(stderr, xplist);
    if (xpath_find(xplist, 0, vec1, vec1len, flags, vec2, vec2len) < 0)
	goto done;
    if (xpath_free(xplist) < 0)
	goto done;
  done:
    return 0;
} /* xpath_exec */


/*! Intermediate xpath function to handle 'conditional' cases. 
 * For example: xpath = //a | //b. 
 * xpath_first+ splits xpath up in several subcalls
 * (eg xpath=//a and xpath=//b) and collects the results.
 * Note: if a match is found in both, two (or more) same results will be 
 * returned.
 * Note, this could be 'folded' into xpath1 but I judged it too complex.
 */
static int
xpath_choice(cxobj   *xtop, 
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
	clicon_err(OE_XML, errno, "%s: strdup", __FUNCTION__);
	goto done;
    }
    s2 = s1 = s0;
    if ((vec0 = calloc(1, sizeof(cxobj *))) == NULL){
	clicon_err(OE_UNIX, errno, "calloc");
	goto done;
    }
    vec0[0] = xtop;
    vec0len++;
    while (s1 != NULL){
	s2 = strstr(s1, " | ");
	if (s2 != NULL){
	    *s2 = '\0'; /* terminate xpath */
	    s2 += 3;
	}
	xpath = s1;
	s1 = s2;
	if (xpath_exec(xpath, vec0, vec0len, flags, vec1, vec1len) < 0)
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

/*! A restricted xpath function where the first matching entry is returned
 * See xpath1() on details for subset.
 * args:
 * @param[in]  cxtop  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @retval     xml-tree of first match, or NULL on error. 
 *
 * @code
 *   cxobj *x;
 *   if ((x = xpath_first(xtop, "//symbol/foo")) != NULL) {
 *         ...
 *   }
 * @endcode
 * Note that the returned pointer points into the original tree so should not be freed
 * after use.
 * @see also xpath_vec.
 */
cxobj *
xpath_first(cxobj *cxtop, 
	    char  *xpath)
{
    cxobj **vec0 = NULL;
    size_t  vec0len = 0;
    cxobj  *xn = NULL;

    if (xpath_choice(cxtop, xpath, 0, &vec0, &vec0len) < 0)
	goto done;
    if (vec0len)
	xn = vec0[0];
    else
	xn = NULL;
  done:
    if (vec0)
	free(vec0);
    return xn;

}

/*! A restricted xpath iterator that loops over all matching entries. Dont use.
 *
 * See xpath1() on details for subset.
 * @param[in]  cxtop  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @param[in]  xprev   iterator/result should be initiated to NULL
 * @retval     xml-tree of n:th match, or NULL on error. 
 *
 * @code
 *   cxobj *x = NULL;
 *   while ((x = xpath_each(cxtop, "//symbol/foo", x)) != NULL) {
 *     ...
 *   }
 * @endcode
 *
 * Note that the returned pointer points into the original tree so should not be freed
 * after use.
 * @see also xpath, xpath_vec.
 * NOTE: uses a static variable: consider replacing with xpath_vec() instead
 */
cxobj *
xpath_each(cxobj *cxtop, 
	   char  *xpath, 
	   cxobj *xprev)
{
    static cxobj    **vec0 = NULL; /* XXX */
    static size_t     vec0len = 0;
    cxobj            *xn = NULL;
    int i;
    
    if (xprev == NULL){
	if (vec0) // XXX
	    free(vec0); // XXX
	vec0len = 0;
	if (xpath_choice(cxtop, xpath, 0, &vec0, &vec0len) < 0)
	    goto done;
    }
    if (vec0len){
	if (xprev==NULL)
	    xn = vec0[0];
	else{
	    for (i=0; i<vec0len; i++)
		if (vec0[i] == xprev)
		    break;
	    if (i>=vec0len-1)
		xn = NULL; 
	    else
		xn = vec0[i+1];
	}
    }
    else
	xn = NULL;
  done:
    return xn;
}

/*! A restricted xpath that returns a vector of matches
 *
 * See xpath1() on details for subset.
 * @param[in]  cxtop  xml-tree where to search
 * @param[in]  xpath   string with XPATH syntax
 * @param[out] xv_len  returns length of vector in return value
 * @retval     vec     vector of xml-trees. Vector must be free():d after use
 * @retval     NULL     NULL on error.
 *
 * @code
 *   cxobj **xv;
 *   int     xlen;
 *   if ((xv = xpath_vec(cxtop, "//symbol/foo", &xlen)) != NULL) {
 *      for (i=0; i<xlen; i++){
 *         xn = xv[i];
 *         ...
 *      }
 *      free(xv);
 *   }
 * @endcode
 * Note that although the returned vector must be freed after use, the returned xml
 * trees need not be.
 * @see also xpath_first, xpath_each.
 */
cxobj **
xpath_vec(cxobj  *cxtop, 
	  char   *xpath, 
	  size_t *veclen)
{
    cxobj **vec=NULL;

    *veclen = 0;
    if (xpath_choice(cxtop, xpath, 0, &vec, (size_t*)veclen) < 0)
	return NULL;
    return vec;
}

/* A restricted xpath that returns a vector of matches (only nodes marked with flags)
 * @param[in]  flags   Set of flags that return nodes must match (0 if all)
 */
cxobj **
xpath_vec_flag(cxobj   *cxtop, 
	       char    *xpath, 
	       uint16_t flags,
	       size_t  *veclen)
{
    cxobj **vec=NULL;

    *veclen = 0;
    if (xpath_choice(cxtop, xpath, flags, &vec, (size_t*)veclen) < 0)
	return NULL;
    return vec;
}

/*
 * Turn this on to get an xpath test program 
 * Usage: clicon_xpath [<xpath>] 
 * read xml from input
 * Example compile:
 gcc -g -o xpath -I. -I../clicon ./clicon_xsl.c -lclicon -lcligen
*/
#if 0 /* Test program */


static int
usage(char *argv0)
{
    fprintf(stderr, "usage:%s <xpath>.\n\tInput on stdin\n", argv0);
    exit(0);
}

int
main(int argc, char **argv)
{
    int i;
    cxobj     **xv;
    cxobj      *x;
    cxobj      *xn;
    int         xlen = 0;

    if (argc != 2){
	usage(argv[0]);
	return 0;
    }
    if (clicon_xml_parse_file(0, &x, "</clicon>") < 0){
	fprintf(stderr, "parsing 2\n");
	return -1;
    }
    printf("\n");

    if ((xv = xpath_vec(x, argv[1], &xlen)) != NULL) {
	for (i=0; i<xlen; i++){
	    xn = xv[i];
	    fprintf(stdout, "[%d]:\n", i);
	    clicon_xml2file(stdout, xn, 0, 1);	
	}
	free(xv);
    }
    if (x)
	xml_free(x);

    return 0;
}

#endif /* Test program */

