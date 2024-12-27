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

  Map between strings and ints
 */

#ifndef _CLIXON_MAP_H_
#define _CLIXON_MAP_H_

/*! Struct used to map between int and strings. Typically used to map between
 *
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
    char *ms_str;
    int   ms_int;
};
typedef struct map_str2int map_str2int;

/*! Struct used to map between two strings.
 */
struct map_str2str{
    char *ms_s0;
    char *ms_s1;
};
typedef struct map_str2str map_str2str;

/*! Struct used to map from string to pointer
 */
struct map_str2ptr{
    char *mp_str;
    void *mp_ptr;
};
typedef struct map_str2ptr map_str2ptr;

/*! Map from ptr to ptr
 */
struct map_ptr2ptr{
    void *mp_p0;
    void *mp_p1;
};
typedef struct map_ptr2ptr map_ptr2ptr;

/*
 * Prototypes
 */
const char *clicon_int2str(const map_str2int *mstab, int i);
int         clicon_str2int(const map_str2int *mstab, char *str);
int         clicon_str2int_search(const map_str2int *mstab, char *str, int upper);
char       *clicon_str2str(const map_str2str *mstab, char *str);
void        clixon_str2ptr_sort(map_str2ptr *mptab, size_t len);
void       *clixon_str2ptr(map_str2ptr *mptab, char *str, size_t len);
int         clixon_str2ptr_print(FILE *f, map_str2ptr *mptab);
void       *clixon_ptr2ptr(map_ptr2ptr *mptab, void *ptr);
int         clixon_ptr2ptr_add(map_ptr2ptr **mptab, void *ptr0, void *ptr1);

#endif  /* _CLIXON_MAP_H_ */
