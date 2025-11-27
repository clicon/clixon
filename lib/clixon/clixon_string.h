/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

/* Required for the inline to compile */
#include <stdlib.h>
#include <string.h>

/*! A strdup version that aligns on 4 bytes. To avoid warning from valgrind */
static inline char * strdup4(char *str)
{
    char *dup;
    size_t len;
    len = align4(strlen(str)+1);
    if ((dup = (char*) malloc(len)) == NULL)
        return NULL;
    memcpy(dup, str, strlen(str)+1);
    return dup;
}

/*
 * Prototypes
 */
char **clixon_strsep1(const char *string, const char *delim, int  *nvec0);
int    clixon_strsep2(char *str, const char *delim1, const char *delim2, char ***vcp, int *nvec);
char **clixon_strsep3(const char *string, const char *delim, int  *nvec0);
char  *clicon_strjoin(int argc, char *const argv[], const char *delim);
char  *clixon_string_del_join(char *str1, const char *del, const char *str2);
int    clixon_strsplit(const char *nodeid, const int delim, char **prefix, char **id);
int    uri_str2cvec(const char *string, const char delim1, const char delim2, int decode, cvec **cvp);
int    uri_percent_encode(char **encp, const char *fmt, ...) __attribute__ ((format (printf, 2, 3)));
int    xml_chardata_encode(char **escp, int quote, const char *fmt, ... ) __attribute__ ((format (printf, 3, 4)));
int    xml_chardata_cbuf_append(cbuf *cb, int quote, const char *str);
int    xml_chardata_decode(char **escp, const char *fmt,...);
int    uri_percent_decode(const char *enc, char **str);
int    nodeid_split(const char *nodeid, char **prefix, char **id);
char  *clixon_trim(char *str);
char  *clixon_trim2(char *str, const char *trims);
int    clicon_strcmp(const char *s1, const char *s2);
int    clixon_unicode2utf8(const char *ucstr, char *utfstr, size_t utflen);
int    clixon_str_subst(char *str, cvec *cvv, cbuf *cb);

#ifndef HAVE_STRNDUP
char *clicon_strndup (const char *, size_t);
#endif /* ! HAVE_STRNDUP */

/* Backward compatible 7.5 */
#define clicon_strsep(x, d, n) clixon_strsep1((x), (d), (n))

#endif  /* _CLIXON_STRING_H_ */
