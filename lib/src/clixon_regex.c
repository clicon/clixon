/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
  *
  * Clixon regular expression code for Yang type patterns following XML Schema
  * regex. 
  * Two modes: libxml2 and posix-translation
 * @see http://www.w3.org/TR/2004/REC-xmlschema-2-20041028
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <regex.h>
#include <ctype.h>

#include <cligen/cligen.h>

/* clicon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_yang.h"
#include "clixon_options.h"
#include "clixon_regex.h"

/*-------------------------- POSIX translation -------------------------*/

/*! Transform from XSD regex to posix ERE
 * The usecase is that Yang (RFC7950) supports XSD regular expressions but
 * CLIgen supports POSIX ERE
 * POSIX ERE regexps according to man regex(3).
 * @param[in]  xsd    Input regex string according XSD
 * @param[out] posix  Output (malloced) string according to POSIX ERE
 * @see https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#regexs
 * @see https://www.regular-expressions.info/posixbrackets.html#class translation
 * @see https://www.regular-expressions.info/xml.html
 * Translation is not complete but covers some character sequences:
 * \d decimal digit
 * \w all characters except the set of "punctuation", "separator" and 
 *    "other" characters: #x0000-#x10FFFF]-[\p{P}\p{Z}\p{C}]
 * \i letters + underscore and colon
 * \c XML Namechar, see: https://www.w3.org/TR/2008/REC-xml-20081126/#NT-NameChar
 *
 * \p{X} category escape.  the ones identified in openconfig and yang-models are: 
 *   \p{L} Letters     [ultmo]?
 *   \p{M} Marks       [nce]?
 *   \p{N} Numbers     [dlo]?
 *   \p{P} Punctuation [cdseifo]?
 *   \p{Z} Separators  [slp]?
 *   \p{S} Symbols     [mcko]?
 *   \p{O} Other       [cfon]?
 */
int
regexp_xsd2posix(char  *xsd,
		 char **posix)
{
    int   retval = -1;
    cbuf *cb = NULL;
    char  x;
    int   i;
    int   j; /* lookahead */
    int   esc;
    int   minus = 0;

    if ((cb = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    esc=0;
    for (i=0; i<strlen(xsd); i++){
	x = xsd[i];
	if (esc){
	    esc = 0;
	    switch (x){
	    case '-': /* \- is translated to -], ie must be last in bracket */
		minus++;
		break;
	    case 'c': /* xml namechar */
		cprintf(cb, "[0-9a-zA-Z._:-]"); /* also interpunct */
		break;
	    case 'd':
		cprintf(cb, "[0-9]");
		break;
	    case 'i': /* initial */
		cprintf(cb, "[a-zA-Z_:]");
		break;
	    case 'p': /* category escape: \p{IsCategory} */
		j = i+1;
		if (j+2 < strlen(xsd) &&
		    xsd[j] == '{' &&
		    (xsd[j+2] == '}' || xsd[j+3] == '}')){
		    switch (xsd[j+1]){
		    case 'L': /* Letters */
			cprintf(cb, "a-zA-Z"); /* assume in [] */
			break;
		    case 'M': /* Marks */
			cprintf(cb, "\?!"); /* assume in [] */
			break;
		    case 'N': /* Numbers */
			cprintf(cb, "0-9");
			break;
		    case 'P': /* Punctuation */
			cprintf(cb, "a-zA-Z"); /* assume in [] */
			break;
		    case 'Z': /* Separators */
			cprintf(cb, "\t "); /* assume in [] */
			break;
		    case 'S': /* Symbols */
			 /* assume in [] */
			break;
		    case 'C': /* Others */
			 /* assume in [] */
			break;
		    default:
			break;
		    }
		    if (xsd[j+2] == '}')
			i = j+2;
		    else
			i = j+3;
		}
		/* if syntax error, just leave it */
		break;
	    case 's':
		cprintf(cb, "[ \t\r\n]");
		break;
	    case 'S':
		cprintf(cb, "[^ \t\r\n]");
		break;
	    case 'w': /* word */
		//cprintf(cb, "[0-9a-zA-Z_\\\\-]")
		cprintf(cb, "[^[:punct:][:space:][:cntrl:]]"); 
		break;
	    case 'W': /* inverse of \w */
		cprintf(cb, "[[:punct:][:space:][:cntrl:]]"); 
		break;
	    default:
		cprintf(cb, "\\%c", x);
		break;
	    }
	}
	else if (x == '\\')
	    esc++;
	else if (x == '$' && i != strlen(xsd)-1) /* Escape $ unless it is last */
	    cprintf(cb, "\\%c", x);
	else if (x == ']' && minus){
	    cprintf(cb, "-]");
	    minus = 0;
	}
	else
	    cprintf(cb, "%c", x);
    }
    if ((*posix = strdup(cbuf_get(cb))) == NULL){
	clicon_err(OE_UNIX, errno, "strdup");
	goto done;
    }
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*-------------------------- Generic API functions ------------------------*/

/*! Compilation of regular expression / pattern
 * @param[in]   h       Clicon handle
 * @param[in]   regexp  Regular expression string in XSD regex format
 * @param[out]  recomp  Compiled regular expression (malloc:d, should be freed)
 * @retval      1       OK
 * @retval      0       Invalid regular expression (syntax error?)
 * @retval     -1       Error
 * @note Clixon supports Yang's XSD regexp only. But CLIgen can support both
 *       POSIX and XSD(using libxml2). But to use CLIgen's POSIX, Clixon must
 *       translate from XSD to POSIX.
 */
int
regex_compile(clicon_handle h,
	      char         *regexp,
	      void        **recomp)
{
    int              retval = -1;
    char            *posix = NULL;    /* Transform to posix regex */

    switch (clicon_yang_regexp(h)){
    case REGEXP_POSIX:
	if (regexp_xsd2posix(regexp, &posix) < 0)
	    goto done;
	retval = cligen_regex_posix_compile(posix, recomp);
	break;
    case REGEXP_LIBXML2:
	retval = cligen_regex_libxml2_compile(regexp, recomp);
	break;
    default:
    	clicon_err(OE_CFG, 0, "clicon_yang_regexp invalid value: %d", clicon_yang_regexp(h));
	break;
    }
    /* retval from fns above */
 done:
    if (posix)
	free(posix);
    return retval;
}

/*! Execution of (pre-compiled) regular expression / pattern
 * @param[in]  h       Clicon handle
 * @param[in]  recomp  Compiled regular expression 
 * @param[in]  string  Content string to match
 */
int
regex_exec(clicon_handle h,
	   void         *recomp,
	   char         *string)
{
    int   retval = -1;

    switch (clicon_yang_regexp(h)){
    case REGEXP_POSIX:
	retval = cligen_regex_posix_exec(recomp, string);
	break;
    case REGEXP_LIBXML2:
	retval = cligen_regex_libxml2_exec(recomp, string);
	break;
    default:
    	clicon_err(OE_CFG, 0, "clicon_yang_regexp invalid value: %d",
		   clicon_yang_regexp(h));
	goto done;
    }
    /* retval from fns above */
 done:
    return retval;
}

/*! Free of (pre-compiled) regular expression / pattern
 * @param[in]  h       Clicon handle
 * @param[in]  recomp  Compiled regular expression 
 */
int
regex_free(clicon_handle h,
	   void         *recomp)
{
    int   retval = -1;

    switch (clicon_yang_regexp(h)){
    case REGEXP_POSIX:
	retval = cligen_regex_posix_free(recomp);
	break;
    case REGEXP_LIBXML2:
	retval = cligen_regex_libxml2_free(recomp);
	break;
    default:
    	clicon_err(OE_CFG, 0, "clicon_yang_regexp invalid value: %d", clicon_yang_regexp(h));
	goto done;
    }
    /* retval from fns above */
 done:
    return retval;
}

