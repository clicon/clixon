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
