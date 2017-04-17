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

 */
/* Error handling: dont use clicon_err, treat as unix system calls. That is,
   ensure errno is set and return -1/NULL */

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
#include "clixon_string.h"
#include "clixon_err.h"


/*! Split string into a vector based on character delimiters. Using malloc
 *
 * The given string is split into a vector where the delimiter can be
 * any of the characters in the specified delimiter string. 
 *
 * The vector returned is one single memory block that must be freed
 * by the caller
 *
 * @param[in]   string     String to be split
 * @param[in]   delim      String of delimiter characters
 * @param[out]  nvec       Number of entries in returned vector
 * @retval      vec        Vector of strings. NULL terminated. Free after use
 * @retval      NULL       Error * 
 */
char **
clicon_strsep(char *string, 
	      char *delim, 
	      int  *nvec0)
{
    char **vec = NULL;
    char  *ptr;
    char  *p;
    int   nvec = 1;
    int   i;
    size_t siz;
    char *s;
    char *d;
    
    if ((s = string)==NULL)
	goto done;
    while (*s){
	if ((d = index(delim, *s)) != NULL)
	    nvec++;
	s++;
    }
    /* alloc vector and append copy of string */
    siz = (nvec+1)* sizeof(char*) + strlen(string)+1;
    if ((vec = (char**)malloc(siz)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc"); 
	goto done;
    } 
    memset(vec, 0, siz);
    ptr = (char*)vec + (nvec+1)* sizeof(char*); /* this is where ptr starts */
    strncpy(ptr, string, strlen(string)+1);
    i = 0;
    while ((p = strsep(&ptr, delim)) != NULL)
	vec[i++] = p;
    *nvec0 = nvec;
 done:
    return vec;
}

/*! Concatenate elements of a string array into a string. 
 * An optional delimiter string can be specified which will be inserted betwen 
 * each element. 
 * @retval  str   Joined string. Free after use.
 * @retval  NULL  Failure
 */
char *
clicon_strjoin(int         argc, 
	       char      **argv, 
	       char       *delim)
{
    int i;
    int len;
    char *str;

    len = 0;
    for (i = 0; i < argc; i++)
	len += strlen(argv[i]);
    if (delim)
	len += (strlen(delim) * argc);
    len += 1; /* '\0' */
    if ((str = malloc(len)) == NULL)
	return NULL;
    memset (str, '\0', len);
    for (i = 0; i < argc; i++) {
	if (i != 0)
	    strncat (str, delim, len - strlen(str));
	strncat (str, argv[i], len - strlen(str));
    }
    return str;
}

static int
unreserved(unsigned char in)
{
    switch(in) {
    case '0': case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
    case 'a': case 'b': case 'c': case 'd': case 'e':
    case 'f': case 'g': case 'h': case 'i': case 'j':
    case 'k': case 'l': case 'm': case 'n': case 'o':
    case 'p': case 'q': case 'r': case 's': case 't':
    case 'u': case 'v': case 'w': case 'x': case 'y': case 'z':
    case 'A': case 'B': case 'C': case 'D': case 'E':
    case 'F': case 'G': case 'H': case 'I': case 'J':
    case 'K': case 'L': case 'M': case 'N': case 'O':
    case 'P': case 'Q': case 'R': case 'S': case 'T':
    case 'U': case 'V': case 'W': case 'X': case 'Y': case 'Z':
    case '-': case '.': case '_': case '~':
	return 1;
    default:
	break;
    }
    return 0;
}

/*! Percent encoding according to RFC 3896 
 * @param[out]  esc   Deallocate with free()
 */
int
percent_encode(char  *str, 
	       char **escp)
{
    int   retval = -1;
    char *esc = NULL;
    int   len;
    int   i, j;
    
    /* This is max */
    len = strlen(str)*3+1;
    if ((esc = malloc(len)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc"); 
	goto done;
    }
    memset(esc, 0, len);
    j = 0;
    for (i=0; i<strlen(str); i++){
	if (unreserved(str[i]))
	    esc[j++] = str[i];
	else{
	    snprintf(&esc[j], 4, "%%%02X", str[i]&0xff);
	    j += 3;
	}
    }
    *escp = esc;
    retval = 0;
 done:
    if (retval < 0 && esc)
	free(esc);
    return retval;
}

/*! Percent decoding according to RFC 3896 
 * @param[out]  str   Deallocate with free()
 */
int
percent_decode(char  *esc, 
	       char **strp)
{
    int   retval = -1;
    char *str = NULL;
    int   i, j;
    char  hstr[3];
    int   len;
    char *ptr;
    
    /* This is max */
    len = strlen(esc)+1;
    if ((str = malloc(len)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc"); 
	goto done;
    }
    memset(str, 0, len);
    j = 0;
    for (i=0; i<strlen(esc); i++){
	if (esc[i] == '%' && strlen(esc)-i > 2 && 
	    isxdigit(esc[i+1]) && isxdigit(esc[i+2])){
	    hstr[0] = esc[i+1];
	    hstr[1] = esc[i+2];
	    hstr[2] = 0;
	    str[j] = strtoul(hstr, &ptr, 16);
	    i += 2;
	}
	else
	    str[j] = esc[i];
	j++;
    }
    str[j++] = '\0';
    *strp = str;
    retval = 0;
 done:
    if (retval < 0 && str)
	free(str);
    return retval;
}

/*! Split a string into a cligen variable vector using 1st and 2nd delimiter 
 * Split a string first into elements delimited by delim1, then into
 * pairs delimited by delim2.
 * @param[in] string  String to split
 * @param[in] delim1  First delimiter char that delimits between elements
 * @param[in] delim2  Second delimiter char for pairs within an element
 * @param[out] cvp    Created cligen variable vector, deallocate w cvec_free
 * @retval    0       on OK
 * @retval    -1      error
 *
 * @example, 
 * Assuming delim1 = '&' and delim2 = '='
 * a=b&c=d    ->  [[a,"b"][c="d"]
 * kalle&c=d  ->  [[c="d"]]  # Discard elements with no delim2
 * XXX differentiate between error and null cvec.
 */
int
str2cvec(char  *string, 
	 char   delim1, 
	 char   delim2, 
	 cvec **cvp)
{
    int     retval = -1;
    char   *s;
    char   *s0 = NULL;;
    char   *val;     /* value */
    char   *valu;    /* unescaped value */
    char   *snext; /* next element in string */
    cvec   *cvv = NULL;
    cg_var *cv;

    if ((s0 = strdup(string)) == NULL){
	clicon_err(OE_UNIX, errno, "strdup");
	goto err;
    }
    s = s0;
    if ((cvv = cvec_new(0)) ==NULL){
	clicon_err(OE_UNIX, errno, "cvec_new");
	goto err;
    }
    while (s != NULL) {
	/*
	 * In the pointer algorithm below:
	 * name1=val1;  name2=val2;
	 * ^     ^      ^
	 * |     |      |
	 * s     val    snext
	 */
	if ((snext = index(s, delim1)) != NULL)
	    *(snext++) = '\0';
	if ((val = index(s, delim2)) != NULL){
	    *(val++) = '\0';
	    if (percent_decode(val, &valu) < 0)
		goto err;
	    if ((cv = cvec_add(cvv, CGV_STRING)) == NULL){
		clicon_err(OE_UNIX, errno, "cvec_add");
		goto err;
	    }
	    while ((strlen(s) > 0) && isblank(*s))
		s++;
	    cv_name_set(cv, s);
	    cv_string_set(cv, valu);
	    free(valu); valu = NULL;
	}
	else{
	    if (strlen(s)){
		if ((cv = cvec_add(cvv, CGV_STRING)) == NULL){
		    clicon_err(OE_UNIX, errno, "cvec_add");
		    goto err;
		}
		cv_name_set(cv, s);
		cv_string_set(cv, "");
	    }
	}
	s = snext;
    }
    retval = 0;
 done:
    *cvp = cvv;
    if (s0)
	free(s0);
    return retval;
 err:
    if (cvv){
	cvec_free(cvv);
	cvv = NULL;
    }
    goto done;
}


/*! strndup() for systems without it, such as xBSD
 */
#ifndef HAVE_STRNDUP
char *
clicon_strndup (const char *str, 
		size_t      len)
{
  char *new;
  size_t slen;

  slen  = strlen (str);
  len = (len < slen ? len : slen);

  new = malloc (len + 1);
  if (new == NULL)
    return NULL;

  new[len] = '\0';
  memcpy (new, str, len);

  return new;
}
#endif /* ! HAVE_STRNDUP */



/*
 * Turn this on for uni-test programs
 * Usage: clixon_string join
 * Example compile:
 gcc -g -o clixon_string -I. -I../clixon ./clixon_string.c -lclixon -lcligen
 * Example run:
*/
#if 0 /* Test program */

static int
usage(char *argv0)
{
    fprintf(stderr, "usage:%s <string>\n", argv0);
    exit(0);
}

int
main(int argc, char **argv)
{
    int nvec;
    char **vec;
    char *str0;
    char *str1;
    int   i;

    if (argc != 2){
	usage(argv[0]);
	return 0;
    }
    str0 = argv[1];
    if ((vec = clicon_strsep(str0, " \t", &nvec)) == NULL)
	return -1;
    fprintf(stderr, "nvec: %d\n", nvec);
    for (i=0; i<nvec+1; i++)
	fprintf(stderr, "vec[%d]: %s\n", i, vec[i]);
    if ((str1 = clicon_strjoin(nvec, vec, " ")) == NULL)
	return -1;
    fprintf(stderr, "join: %s\n", str1);
    free(vec);
    free(str1);
    return 0;
}

#endif /* Test program */

