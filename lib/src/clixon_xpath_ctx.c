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
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 * Clixon XML XPATH 1.0 according to https://www.w3.org/TR/xpath-10
 * This file defines XPATH contexts using in traversing the XPATH parse tree.
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
#include <math.h>

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
#include "clixon_xpath_parse.h"
#include "clixon_xpath_ctx.h"

/*
 * Variables
 */
const map_str2int ctxmap[] = {
    {"nodeset",   XT_NODESET},
    {"bool",      XT_BOOL},
    {"number",    XT_NUMBER},
    {"string",    XT_STRING}, 
    {NULL,        -1}
};

/*! Free xpath context */
int
ctx_free(xp_ctx *xc)
{
    if (xc->xc_nodeset)
	free(xc->xc_nodeset);
    if (xc->xc_string)
	free(xc->xc_string);
    free(xc);
    return 0;
}

/*! Duplicate xpath context */
xp_ctx *
ctx_dup(xp_ctx *xc0)
{
    static xp_ctx *xc = NULL;
    
    if ((xc = malloc(sizeof(*xc))) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    memset(xc, 0, sizeof(*xc));
    *xc = *xc0;
    if (xc0->xc_size){
	if ((xc->xc_nodeset = calloc(xc0->xc_size, sizeof(cxobj*))) == NULL){
	    clicon_err(OE_UNIX, errno, "calloc");
	    goto done;
	}
	memcpy(xc->xc_nodeset, xc0->xc_nodeset, xc->xc_size*sizeof(cxobj*));
    }
    if (xc0->xc_string)
	if ((xc->xc_string = strdup(xc0->xc_string)) == NULL){
	    clicon_err(OE_UNIX, errno, "strdup");
	    goto done;
	}
 done:
    return xc;
}

/*! Print XPATH context */
int
ctx_print(cbuf   *cb,
	  int     id,
	  xp_ctx *xc,
	  char   *str)
{
    static int ident = 0;
    int        i;

    if (id<0)
	ident += id;
    cprintf(cb, "%*s%s ", ident, "", str?str:"");
    if (id>0)
	ident += id;
    if (xc){
	cprintf(cb, "%s: ", (char*)clicon_int2str(ctxmap, xc->xc_type));
	switch (xc->xc_type){
	case XT_NODESET:
	    for (i=0; i<xc->xc_size; i++)
		cprintf(cb, "%s ", xml_name(xc->xc_nodeset[i]));
	    break;
	case XT_BOOL:
	    cprintf(cb, "%s", xc->xc_bool?"true":"false");
	    break;
	case XT_NUMBER:
	    cprintf(cb, "%lf", xc->xc_number);
	    break;
	case XT_STRING:
	    cprintf(cb, "%s", xc->xc_string);
	    break;
	}
    }
    return 0;
}

/*! Convert xpath context to boolean according to boolean() function in XPATH spec
 * @param[in]   xc  XPATH context
 * @retval      0   False
 * @retval      1   True
 * a number is true if and only if it is neither positive or negative zero nor NaN
 * a node-set is true if and only if it is non-empty
 * a string is true if and only if its length is non-zero
 * an object of a type other than the four basic types is converted to a boolean 
 * in a way that is dependent on that type
 */
int
ctx2boolean(xp_ctx *xc)
{
    int b = -1;
    switch (xc->xc_type){
    case XT_NODESET:
	b = (xc->xc_size != 0);
	break;
    case XT_BOOL:
	b = xc->xc_bool;
	break;
    case XT_NUMBER:
	b = (xc->xc_number != 0.0 && xc->xc_number != NAN);
	break;
    case XT_STRING:
	b = (xc->xc_string && strlen(xc->xc_string));
	break;
    }
    return b;
}

/*! Convert xpath context to string according to string() function in XPATH spec
 * @param[in]   xc    XPATH context
 * @param[out]  str0  Malloced result string
 * @retval      0     OK
 * @retval     -1     Error
 * @note string malloced.
 */
int
ctx2string(xp_ctx *xc,
	   char  **str0)
{
    int     retval = -1;
    char   *str = NULL;
    int     len;
    char   *b;
    
    switch (xc->xc_type){
    case XT_NODESET:
	if (xc->xc_size && (b = xml_body(xc->xc_nodeset[0]))){
	    if ((str = strdup(b)) == NULL){
		clicon_err(OE_XML, errno, "strdup");
		goto done;
	    }
	}
	else
	   if ((str = strdup("")) == NULL){
		clicon_err(OE_XML, errno, "strdup");
		goto done;
	    } 
	break;
    case XT_BOOL:
	if ((str = strdup(xc->xc_bool == 0?"false":"true")) == NULL){
	    clicon_err(OE_XML, errno, "strdup");
	    goto done;
	}
	break;
    case XT_NUMBER:
	len = snprintf(NULL, 0, "%0lf", xc->xc_number);
	len++;
	if ((str = malloc(len)) == NULL){
	    clicon_err(OE_XML, errno, "malloc");
	    goto done;
	}
	snprintf(str, len, "%0lf", xc->xc_number);
	break;
    case XT_STRING:
	if ((str = strdup(xc->xc_string)) == NULL){
	    clicon_err(OE_XML, errno, "strdup");
	    goto done;
	}
	break;
    }
    *str0 = str;
    retval = 0;
 done:
    return retval;
}

/*! Convert xpath context to number according to number() function in XPATH spec
 * @param[in]   xc  XPATH context
 * @param[out]  n0  Floating point or NAN
 * @retval      0   OK
 * @retval     -1   Error
 */
int
ctx2number(xp_ctx *xc,
	   double *n0)
{
    int     retval = -1;
    char   *str = NULL;
    double  n;
    
    switch (xc->xc_type){
    case XT_NODESET:
	if (ctx2string(xc, &str) < 0)
	    goto done;
	if (sscanf(str, "%lf",&n) != 1)
	    n = NAN;
	break;
    case XT_BOOL:
	n = (double)xc->xc_bool;
	break;
    case XT_NUMBER:
	n = xc->xc_number;
	break;
    case XT_STRING:
	if (sscanf(xc->xc_string, "%lf",&n) != 1)
	    n = NAN;
	break;
    }
    *n0 = n;
    retval = 0;
 done:
    if (str)
	free(str);
    return retval;
}

/*! Replace a nodeset of a XPATH context with a new nodeset 
 */
int
ctx_nodeset_replace(xp_ctx   *xc,
		    cxobj   **vec,
		    size_t    veclen)
{
    if (xc->xc_nodeset)
	free(xc->xc_nodeset);
    xc->xc_nodeset = vec;
    xc->xc_size = veclen;
    return 0;
}

