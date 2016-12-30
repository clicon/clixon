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

#ifndef _CLIXON_STRING_H_
#define _CLIXON_STRING_H_

/*! A malloc version that aligns on 4 bytes. To avoid warning from valgrind */
#define align4(s) (((s)/4)*4 + 4)

/*! A strdup version that aligns on 4 bytes. To avoid warning from valgrind */
static inline char * strdup4(char *str) 
{
    char *dup;
    int len;
    len = align4(strlen(str)+1);
    if ((dup = malloc(len)) == NULL)
	return NULL;
    strncpy(dup, str, len);
    return dup;
}

/*
 * Prototypes
 */ 
char **clicon_sepsplit (char *string, char *delim, int *nvec, const char *label);
char **clicon_strsplit (char *string, char *delim, int *nvec, const char *label);
char *clicon_strjoin (int argc, char **argv, char *delim, const char *label);
char *clicon_strtrim(char *str, const char *label);
int clicon_sep(char *s, const char sep[2], const char *label, char**a0, char **b0);
#ifndef HAVE_STRNDUP
char *clicon_strndup (const char *, size_t);
#endif /* ! HAVE_STRNDUP */
int clicon_strmatch(const char *str, const char *regexp, char **match);
char *clicon_strsub(char *str, char *from, char *to);


#endif  /* _CLIXON_STRING_H_ */
