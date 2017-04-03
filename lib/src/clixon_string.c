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

/* clicon */
#include "clixon_queue.h"
#include "clixon_chunk.h"
#include "clixon_string.h"
#include "clixon_err.h"

/*! Split string into a vector based on character delimiters
 *
 * The given string is split into a vector where the delimiter can be
 * any of the characters in the specified delimiter string. 
 *
 * The vector returned is one single memory chunk that must be unchunked 
 * by the caller
 *
 * @param[in]   string     String to be split
 * @param[in]   delim      String of delimiter characters
 * @param[out]  nvec       Number of entries in returned vector
 * @param[in]   label      Chunk label for returned vector
 * @retval      vec        Vector of strings. Free with unchunk
 * @retval      NULL       Error
 * @see clicon_strsplit    Operates on full string delimiters rather than
 *                         individual character delimiters.
 * @see clicon_strsep      Use malloc instead of chunk
 */
char **
clicon_sepsplit (char       *string, 
		 char       *delim, 
		 int        *nvec, 
		 const char *label)
{
    int idx;
    size_t siz;
    char *s, *s0;
    char **vec, *vecp;

    *nvec = 0;
    s0 = s = chunkdup (string, strlen(string)+1, __FUNCTION__);
    while (strsep(&s, delim))
	(*nvec)++;
    unchunk (s0);

    siz = ((*nvec +1) * sizeof (char *)) + strlen(string) + 1;
    vec = (char **) chunk (siz, label);
    if (!vec) {
	return NULL;
    }
    bzero (vec, siz);

    vecp = (char *)&vec[*nvec +1];
    bcopy (string, vecp, strlen (string));

    for (idx = 0; idx < *nvec; idx++) {
	vec[idx] = vecp;
	strsep (&vecp, delim);
    }

    return vec;
}

/*! Split string into a vector based on a string delimiter
 *
 * The given string is split into a vector where the delimited by the
 * the full delimiter string. The matched delimiters are not part of the
 * resulting vector.
 *
 * The vector returned is one single memory chunk that must be unchunked 
 * by the caller
 *
 * @param[in]   string     String to be split
 * @param[in]   delim      String of delimiter characters
 * @param[out]  nvec       Number of entries in returned vector
 * @param[in]   label      Chunk label for returned vector
 * @retval      vec        Vector of strings. Free with unchunk
 * @retval      NULL       Error
 * @see clicon_sepsplit    Operates on individual character delimiters rather 
 *                         than full string delimiter.
 * @see clicon_strsep      Use malloc instead of chunk
 */
char **
clicon_strsplit (char       *string, 
		 char       *delim, 
		 int        *nvec, 
		 const char *label)
{
    int idx;
    size_t siz;
    char *s;
    char **vec, *vecp;

    *nvec = 1;
    s = string;
    while ((s = strstr(s, delim))) {
	s += strlen(delim);
	(*nvec)++;
    }

    siz = ((*nvec +1) * sizeof (char *)) + strlen(string) + 1;
    vec = (char **) chunk (siz, label);
    if (!vec) {
	return NULL;
    }
    bzero (vec, siz);

    vecp = (char *)&vec[*nvec +1];
    bcopy (string, vecp, strlen (string));

    s = vecp;
    for (idx = 0; idx < *nvec; idx++) {
	vec[idx] = s;
	if ((s = strstr(s, delim)) != NULL) {
	    *s = '\0';
	    s += strlen(delim);
	}
    }

    return vec;
}

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
 * @retval      vec        Vector of strings. Free after use
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

    for (i=0; i<strlen(string); i++)
	if (index(delim, string[i]))
	    nvec++;
    /* alloc vector and append copy of string */
    if ((vec = (char**)malloc(nvec* sizeof(char*) + strlen(string)+1)) == NULL){
	clicon_err(OE_YANG, errno, "malloc"); 
	goto err;
    } 
    ptr = (char*)vec + nvec* sizeof(char*); /* this is where ptr starts */
    strncpy(ptr, string, strlen(string)+1);
    i = 0;
    while ((p = strsep(&ptr, delim)) != NULL)
	vec[i++] = p;
    *nvec0 = nvec;
 err:
    return vec;
}


/*! Concatenate elements of a string array into a string. 
 * An optional delimiter string can be specified which will be inserted betwen 
 * each element. 
 * @param[in]   label      Chunk label for returned vector
 * @retval  str   Joined string. Free with unchunk()
 * @retval  NULL  Failure
 */
char *
clicon_strjoin (int         argc, 
		char      **argv, 
		char       *delim, 
		const char *label)
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
  
  if ((str = chunk (len, label)) == NULL)
    return NULL;
  memset (str, '\0', len);

  for (i = 0; i < argc; i++) {
    if (i != 0)
      strncat (str, delim, len - strlen(str));
    strncat (str, argv[i], len - strlen(str));
  }
  
  return str;
}

/*! Trim whitespace in beginning and end of string.
 *
 * @param[in]   label      Chunk label for returned vector
 * @retval  str   Trimmed string. Free with unchunk()
 * @retval  NULL  Failure
 */
char *
clicon_strtrim(char       *str, 
	       const char *label)
{
    char *start, *end, *new;
    
    start = str;
    while (*start != '\0' && isspace(*start))
	start++;
    if (!strlen(start))
	return (char *)chunkdup("\0", 1, label);
    
    end = str + strlen(str)  ;
    while (end > str && isspace(*(end-1)))
	end--;
    if((new = chunkdup (start, end-start+1, label)))
	new[end-start] = '\0';

    return new;
}

/*! Given a string s, on format: a[b], separate it into two parts: a and b
 * [] are separators.
 * alterative use:
 * a/b -> a and b (where sep = "/")
 * @param[in]   label      Chunk label for returned vector
 */
int
clicon_sep(char       *s, 
	   const char  sep[2], 
	   const char *label, 
	   char      **a0, 
	   char      **b0)
{
    char *a = NULL;
    char *b = NULL;    
    char *ptr;
    int len;
    int retval = -1;

    ptr = s;
    /* move forward to last char of element name */
    while (*ptr && *ptr != sep[0] && *ptr != sep[1] )
	ptr++;    
    /* Copy first element name */
    len = ptr-s;
    if ((a = chunkdup(s, len+1, label)) == NULL)
	goto catch;
    a[len] = '\0';	
    /* Do we have an extended format? */
    if (*ptr == sep[0]) {
	b = ++ptr;
	/* move forward to end extension */
	while (*ptr && *ptr != sep[1])
	    ptr++;
	/* Copy extension */
	len = ptr-b;
	if ((b = chunkdup(b, len+1, label)) == NULL)
	    goto catch;
	b[len] = '\0';	
    }

    *a0 = a;
    *b0 = b;
    retval = 0;
  catch:
    return retval;
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

/*! Match string against regexp. 
 *
 * If a match pointer is given, the matching substring 
 * will be allocated 'match' will be pointing to it. The match string must
 * be free:ed by the application.
 * @retval  -1   Failure
 * @retval   0   No match
 * @retval  >0   Match: Length of matching substring
 */
int
clicon_strmatch(const char *str, 
		const char *regexp, 
		char      **match)
{
    size_t len;
    int status;
    regex_t re;
    char rxerr[128];
    size_t nmatch = 1;
    regmatch_t pmatch[1];

    if (match)
	*match = NULL;

    if ((status = regcomp(&re, regexp, REG_EXTENDED)) != 0) {
	regerror(status, &re, rxerr, sizeof(rxerr));
	clicon_err(OE_REGEX, errno, "%s", rxerr);
	return -1;
    }

    status = regexec(&re, str, nmatch, pmatch, 0);
    regfree(&re); 
    if (status != 0) 
	return 0;   /* No match */

    len = pmatch[0].rm_eo - pmatch[0].rm_so;
/* If we've specified a match pointer, allocate and populate it. */
    if (match) {
	if ((*match = malloc(len + 1)) == NULL) {
	    clicon_err(OE_UNIX, errno, "Failed to allocate string");
	    return -1;
	}
	memset(*match, '\0', len + 1);
	strncpy(*match, str + pmatch[0].rm_so, len);
    }

    return len;
}

/*! Substitute pattern in string.
 * @retval  str  Malloc:ed string on success, use free to deallocate
 * @retval  NULL Failure.
 */
char *
clicon_strsub(char *str, 
	      char *from, 
	      char *to)
{
    char **vec;
    int nvec;
    char *new;
    char *retval = NULL;

    if ((vec = clicon_strsplit(str, from, &nvec, __FUNCTION__)) == NULL) {
        clicon_err(OE_UNIX, errno, "Failed to split string");
	goto done;
    }

    if ((new = clicon_strjoin (nvec, vec, to, __FUNCTION__)) == NULL) {
        clicon_err(OE_UNIX, errno, "Failed to split string");
	goto done;
    }
    
    retval = strdup(new);

 done:
    unchunk_group(__FUNCTION__);
    return retval;
}
