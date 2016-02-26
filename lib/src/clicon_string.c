/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 */
/* Error handling: dont use clicon_err, treat as unix system calls. That is,
   ensure errno is set and return -1/NULL */

#ifdef HAVE_CONFIG_H
#include "clicon_config.h"
#endif

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <regex.h>
#include <ctype.h>

/* clicon */
#include "clicon_queue.h"
#include "clicon_chunk.h"
#include "clicon_string.h"
#include "clicon_err.h"

/*! Split string into a vector based on character delimiters
 *
 * The given string is split into a vector where the delimiter can be
 * any of the characters in the specified delimiter string. 
 *
 * See also clicon_strsplit() which is similar by operates on a full string
 * delimiter rather than individual character delimiters.
 *
 * The vector returned is one single memory chunk that must be unchunked 
 * by the caller
 *
 * @param   string     String to be split
 * @param   delim      String of delimiter characters
 * @param   nvec       Number of entries in returned vector
 * @param   label      Chunk label for returned vector
 */
char **
clicon_sepsplit (char *string, char *delim, int *nvec, const char *label)
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
 * See also clicon_sepsplit() which is similar by operates on individual
 * character delimiters rather then a full string delimiter.
 *
 * The vector returned is one single memory chunk that must be unchunked 
 * by the caller
 *
 * @param   string     String to be split
 * @param   delim      String of delimiter characters
 * @param   nvec       Number of entries in returned vector
 * @param   label      Chunk label for returned vector
 */
char **
clicon_strsplit (char *string, char *delim, int *nvec, const char *label)
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


/*
 * Concatenate elements of a string array into a string. An optiona delimiter
 * string can be specified which will be inserted betwen each element. 
 * Resulting string is chunk:ed using the specified group label and need to be 
 * unchunked by the caller
 */
char *
clicon_strjoin (int argc, char **argv, char *delim, const char *label)
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

/*
 * Trim of whitespace in beginning and end of string.
 * A new string is returned, chunked with specified label
 */
char *
clicon_strtrim(char *str, const char *label)
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

/*
 * clicon_sep
 * given a string s, on format: a[b], separate it into two parts: a and b
 * [] are separators.
 * alterative use:
 * a/b -> a and b (where sep = "/")
 */
int
clicon_sep(char *s, const char sep[2], const char *label, char**a0, char **b0)
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


/*
 * strndup() for systems without it, such as xBSD
 */
#ifndef HAVE_STRNDUP
char *
clicon_strndup (const char *str, size_t len)
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
 * clicon_strmatch - Match string against regexp. 
 *
 * Returns -1 on failure, 0 on no matach or >0 (length of matching substring)
 * in case of a match. If a match pointer is given, the matching substring 
 * will be allocated 'match' will be pointing to it. The match string must
 * be free:ed by the application.
 */
int
clicon_strmatch(const char *str, const char *regexp, char **match)
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

/*
 * clicon_strsub - substitute pattern in string.
 * Returns new malloc:ed string on success or NULL on failure.
 */
char *
clicon_strsub(char *str, char *from, char *to)
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
