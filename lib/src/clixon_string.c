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

