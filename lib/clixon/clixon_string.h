/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

/*! Struct used to map between int and strings. Typically used to map between
 * values and their names. Note NULL terminated
 * Example:
 * @code
static const map_str2int atmap[] = {
    {"One",               1}, 
    {"Two",               2}, 
    {NULL,               -1}
};
 * @endcode
 * @see clicon_int2str
 * @see clicon_str2int
 */
struct map_str2int{
    char         *ms_str;
    int           ms_int;
};
typedef struct map_str2int map_str2int;

/*! Struct used to map between two strings.
 */
struct map_str2str{
    char         *ms_s0;
    char         *ms_s1;
};
typedef struct map_str2str map_str2str;

/*! A malloc version that aligns on 4 bytes. To avoid warning from valgrind */
#define align4(s) (((s)/4)*4 + 4)

/* Required for the inline to compile */
#include <stdlib.h>
#include <string.h>

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
char **clicon_strsep(char *string, char *delim, int  *nvec0);
char *clicon_strjoin (int argc, char **argv, char *delim);
int str2cvec(char *string, char delim1, char delim2, cvec **cvp);
#if defined(__GNUC__) && __GNUC__ >= 3
int uri_percent_encode(char **encp, char *fmt, ...) __attribute__ ((format (printf, 2, 3)));
int xml_chardata_encode(char **escp, char *fmt, ... ) __attribute__ ((format (printf, 2, 3)));
#else
int uri_percent_encode(char **encp, char *str, ...);
int xml_chardata_encode(char **escp, char *fmt, ...);
#endif
int xml_chardata_cbuf_append(cbuf *cb, char *str);
int uri_percent_decode(char *enc, char **str);
const char *clicon_int2str(const map_str2int *mstab, int i);
int clicon_str2int(const map_str2int *mstab, char *str);
int clicon_str2int_search(const map_str2int *mstab, char *str, int upper);
int nodeid_split(char *nodeid,	char **prefix, char **id);
char *clixon_trim(char *str);
char *clixon_trim2(char *str, char *trims);
int clicon_strcmp(char *s1, char *s2);

#ifdef USE_CLIGEN44
int cbuf_append_str(cbuf *cb, char *str);
#endif
#ifndef HAVE_STRNDUP
char *clicon_strndup (const char *, size_t);
#endif /* ! HAVE_STRNDUP */

#endif  /* _CLIXON_STRING_H_ */
