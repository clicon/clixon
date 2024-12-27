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

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>

#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_map.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_string.h"

/*! Map from int to string using str2int map
 *
 * @param[in] ms   String, integer map
 * @param[in] i    Input integer
 * @retval    str  String value
 * @retval    NULL Error, not found
 * @note linear search
 */
const char *
clicon_int2str(const map_str2int *mstab,
               int                i)
{
    const struct map_str2int *ms;

    for (ms = &mstab[0]; ms->ms_str; ms++)
        if (ms->ms_int == i)
            return ms->ms_str;
    return NULL;
}

/*! Map from string to int using str2int map
 *
 * @param[in] ms   String, integer map
 * @param[in] str  Input string
 * @retval    int  Value
 * @retval   -1    Error, not found
 * @see clicon_str2int_search for optimized lookup, but strings must be sorted
 */
int
clicon_str2int(const map_str2int *mstab,
               char              *str)
{
    const struct map_str2int *ms;

    for (ms = &mstab[0]; ms->ms_str; ms++)
        if (strcmp(ms->ms_str, str) == 0)
            return ms->ms_int;
    return -1;
}

/*! Map from string to int using binary (alphatical) search
 *
 * @param[in]  ms    String, integer map
 * @param[in]  str   Input string
 * @param[in]  low   Lower bound index
 * @param[in]  upper Upper bound index
 * @param[in]  len   Length of array (max)
 * @param[out] found Integer found (can also be negative)
 * @retval     1     Found with "found" value set.
 * @retval     0     Not found
 * @note Assumes sorted strings, tree search
 */
static int
str2int_search1(const map_str2int *mstab,
                char              *str,
                int                low,
                int                upper,
                int                len,
                int               *found)
{
    const map_str2int *ms;
    int                mid;
    int                cmp;

    if (upper < low)
        return 0; /* not found */
    mid = (low + upper) / 2;
    if (mid >= len)  /* beyond range */
        return 0; /* not found */
    ms = &mstab[mid];
    if ((cmp = strcmp(str, ms->ms_str)) == 0){
        *found = ms->ms_int;
        return 1; /* found */
    }
    else if (cmp < 0)
        return str2int_search1(mstab, str, low, mid-1, len, found);
    else
        return str2int_search1(mstab, str, mid+1, upper, len, found);
}

/*! Map from string to ptr using binary (alphatical) search
 *
 * Assumes sorted strings, tree search. If two are equal take first
 * @param[in]  ms    String, integer map
 * @param[in]  str   Input string
 * @param[in]  low   Lower bound index
 * @param[in]  upper Upper bound index
 * @param[in]  len   Length of array (max)
 * @param[out] found element
 * @retval     1     Found with "found" value set.
 * @retval     0     Not found

 */
static int
str2ptr_search1(const map_str2ptr *mptab,
                char              *str,
                size_t             low,
                size_t             upper,
                size_t             len,
                map_str2ptr      **found)
{
    const map_str2ptr *mp;
    int                mid;
    int                cmp;
    int                i;

    if (upper < low)
        return 0; /* not found */
    mid = (low + upper) / 2;
    if (mid >= len)  /* beyond range */
        return 0; /* not found */
    mp = &mptab[mid];
    if ((cmp = clicon_strcmp(str, mp->mp_str)) == 0){
        i = mid;
        while (i >= 0 && clicon_strcmp(str, mptab[i].mp_str) == 0){
            mp = &mptab[i];
            i--;
        }
        *found = (map_str2ptr *)mp;
        return 1; /* found */
    }
    else if (cmp < 0)
        return str2ptr_search1(mptab, str, low, mid-1, len, found);
    else
        return str2ptr_search1(mptab, str, mid+1, upper, len, found);
}

/*! Map from string to int using str2int map
 *
 * @param[in] ms   String, integer map
 * @param[in] str  Input string
 * @param[in] len
 * @retval    int  Value
 * @retval   -1    Error, not found
 * @note Assumes sorted strings, tree search
 * @note -1 can not be value
 */
int
clicon_str2int_search(const map_str2int *mstab,
                      char              *str,
                      int                len)
{
    int found;

    if (str2int_search1(mstab, str, 0, len, len, &found))
        return found;
    return -1; /* not found */
}

/*! Map from string to string using str2str map
 *
 * @param[in] mstab String, string map
 * @param[in] str   Input string
 * @retval    str   Output string
 * @retval    NULL  Error, not found
 */
char*
clicon_str2str(const map_str2str *mstab,
               char              *str)
{
    const struct map_str2str *ms;

    for (ms = &mstab[0]; ms->ms_s0; ms++)
        if (strcmp(ms->ms_s0, str) == 0)
            return ms->ms_s1;
    return NULL;
}

static int
str2ptr_qsort(const void* arg1,
              const void* arg2)
{
    map_str2ptr *mp1 = (map_str2ptr*)arg1;
    map_str2ptr *mp2 = (map_str2ptr*)arg2;
    int          eq;
    yang_stmt   *yrev;
    char        *rev1 = NULL;
    char        *rev2 = NULL;

    eq = clicon_strcmp(mp1->mp_str, mp2->mp_str);
    if (0 && eq == 0){
        if ((yrev = yang_find(mp1->mp_ptr, Y_REVISION, NULL)) != NULL)
            rev1 = yang_argument_get(yrev);
        if ((yrev = yang_find(mp2->mp_ptr, Y_REVISION, NULL)) != NULL)
            rev2 = yang_argument_get(yrev);
        eq = clicon_strcmp(rev1, rev2);
    }
    return eq;
}

void
clixon_str2ptr_sort(map_str2ptr *mptab,
                    size_t       len)
{
    qsort(mptab, len, sizeof(*mptab), str2ptr_qsort);
}

/*! Map from string to string using str2str map
 *
 * @param[in] mptab String to ptr map
 * @param[in] str   Input string
 * @retval    ptr   Output pointer
 * @retval    NULL  Error, not found
 */
void*
clixon_str2ptr(map_str2ptr *mptab,
               char         *str,
               size_t        len)
{
    map_str2ptr *mp = NULL;

    if (str2ptr_search1(mptab, str, 0, len, len, &mp))
        return mp->mp_ptr;
    return NULL; /* not found */
}

int
clixon_str2ptr_print(FILE        *f,
                     map_str2ptr *mptab)
{
    map_str2ptr *mp = NULL;
    int          i;

    i = 0;
    for (mp = &mptab[0]; mp->mp_str; mp++)
        fprintf(f, "%d %s %p\n", i++, mp->mp_str, mp->mp_ptr);
    return 0;
}

/*! Map from pointer to pointer using mptab map
 *
 * @param[in] mptab Ptr to ptr map
 * @param[in] ptr   Input pointer
 * @retval    ptr   Output pointer
 * @retval    NULL  Error, not found
 */
void*
clixon_ptr2ptr(map_ptr2ptr *mptab,
               void        *ptr)
{
    struct map_ptr2ptr *mp;

    for (mp = &mptab[0]; mp->mp_p0; mp++)
        if (mp->mp_p0 == ptr)
            return mp->mp_p1;
    return 0;
}

/*! Add pointer pair to mptab map
 *
 * @param[in]  mptab  Ptr to ptr map
 * @param[in]  ptr0   Input pointer
 * @param[in]  ptr1   Output pointer
 * @retval     0      OK
 * @retval    -1      Error
 */
int
clixon_ptr2ptr_add(map_ptr2ptr **mptabp,
                   void         *ptr0,
                   void         *ptr1)
{
    int                 retval = -1;
    struct map_ptr2ptr *mp;
    struct map_ptr2ptr *mptab0;
    struct map_ptr2ptr *mptab1;
    int                 i;

    if (mptabp == NULL) {
        clixon_err(OE_YANG, EINVAL, "mptabp is NULL");
        goto done;
    }
    mptab0 = *mptabp;
    for (i=0, mp = &mptab0[0]; mp->mp_p0; mp++, i++);
    if ((mptab1 = realloc(mptab0, (i+2)*sizeof(*mp))) == NULL){
        clixon_err(OE_UNIX, errno, "realloc");
        goto done;
    }
    mptab1[i].mp_p0 = ptr0;
    mptab1[i++].mp_p1 = ptr1;
    mptab1[i].mp_p0 = NULL;
    mptab1[i].mp_p1 = NULL;
    *mptabp = mptab1;
    retval = 0;
 done:
    return retval;
}
