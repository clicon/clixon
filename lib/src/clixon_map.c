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
               const char        *str)
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
                const char        *str,
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
                const char        *str,
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
        while (i < len && clicon_strcmp(str, mptab[i].mp_str) == 0){
            mp = &mptab[i];
            i++;
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
                      const char        *str,
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
               const char        *str)
{
    const struct map_str2str *ms;

    for (ms = &mstab[0]; ms->ms_s0; ms++)
        if (strcmp(ms->ms_s0, str) == 0)
            return ms->ms_s1;
    return NULL;
}

/*! Helper function for qsort of str2ptr map
 */
static int
str2ptr_qsort(const void* arg1,
              const void* arg2)
{
    map_str2ptr *mp1 = (map_str2ptr*)arg1;
    map_str2ptr *mp2 = (map_str2ptr*)arg2;
    int          eq;
    yang_stmt   *yp;
    yang_stmt   *y;
    int          i;
    int          i1 = -1;
    int          i2 = -1;

    eq = clicon_strcmp(mp1->mp_str, mp2->mp_str);
    if (eq == 0 && mp1->mp_ptr){
        yp = yang_parent_get(mp1->mp_ptr);
        i = 0;
        while ((y = yn_iter(yp, &i)) != NULL){
            if (y == mp1->mp_ptr)
                i1 = i;
            else if (y == mp2->mp_ptr)
                i2 = i;
            if (i1 >= 0 && i2 >= 0){
                eq = i1 < i2;
                break;
            }
        }
    }
    return eq;
}

/*! Sort a str2ptr map according to alphabetic string order
 */
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
               const char  *str,
               size_t       len)
{
    map_str2ptr *mp = NULL;

    if (str2ptr_search1(mptab, str, 0, len, len, &mp))
        return mp->mp_ptr;
    return NULL; /* not found */
}

/*! Print a str2ptr map
 *
 * @param[in]  f     FILE
 * @param[in]  mptab String to ptr map
 * @retval     0     OK
 */
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

/*! Map from string to ptr using binary (alphatical) search
 *
 * Assumes sorted strings, tree search. If two are equal take first
 * @param[in]  ms    String, integer map
 * @param[in]  str   Input string
 * @param[in]  low   Lower bound index
 * @param[in]  upper Upper bound index
 * @param[in]  len   Length of array (max)
 * @param[in]  exact 0: return next lowest match, 1: return exact match only
 * @param[out] found element
 * @retval     1     Found with "found" value set.
 * @retval     0     Not found
 */
static int
ptr2ptr_search(const map_ptr2ptr *mptab,
               void              *ptr,
               size_t             low,
               size_t             upper,
               size_t             len,
               int                exact,
               map_ptr2ptr      **found)
{
    const map_ptr2ptr *mp;
    int                mid;
    int                cmp;
    size_t             i;

    if (upper < low)
        return 0; /* not found */
    mid = (low + upper) / 2;
    if (mid >= len)  /* beyond range */
        return 0; /* not found */
    mp = &mptab[mid];
    if (ptr < mp->mp_p0){
        cmp = -1;
        if (exact == 0 && mid == low){
            *found = (map_ptr2ptr *)mp;
            return 1;
        }
    }
    else if (ptr > mp->mp_p0){
        cmp = 1;
        if (exact == 0 && mid+1 >= upper){
            mp = &mptab[mid];
            for (i=mid; i<len; i++){
                if (ptr < mp->mp_p0)
                    break;
                mp = &mptab[i+1];
            }
            if (i == len)
                mp = &mptab[len];
            *found = (map_ptr2ptr *)mp;
            return 1;
        }
    }
    else
        cmp = 0;
    if (cmp == 0){
        *found = (map_ptr2ptr *)mp;
        return 1; /* found */
    }
    else if (cmp < 0)
        return ptr2ptr_search(mptab, ptr, low, mid-1, len, exact, found);
    else
        return ptr2ptr_search(mptab, ptr, mid+1, upper, len, exact, found);
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
               size_t       len,
               void        *ptr)
{
    struct map_ptr2ptr *mp;

    if (ptr2ptr_search(mptab, ptr, 0, len, len, 1, &mp))
        return mp->mp_p1;
    return NULL;
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
                   size_t       *lenp,
                   void         *ptr0,
                   void         *ptr1)
{
    int                 retval = -1;
    struct map_ptr2ptr *mp;
    struct map_ptr2ptr *mptail;
    struct map_ptr2ptr *mptab0;
    struct map_ptr2ptr *mptab1;
    size_t              len;
    size_t              sz;

    if (mptabp == NULL) {
        clixon_err(OE_YANG, EINVAL, "mptabp is NULL");
        goto done;
    }
    len = *lenp;
    sz = sizeof(*mp);
    mptab0 = *mptabp;
    if ((mptab1 = realloc(mptab0, (len+1)*sz)) == NULL){
        clixon_err(OE_UNIX, errno, "realloc");
        goto done;
    }
    memset(&mptab1[len], 0, sz);
    if (len == 0){
        mp = &mptab1[0];
    }
    else {
        if (ptr2ptr_search(mptab1, ptr0, 0, len, len, 0, &mp) == 0){
            clixon_err(OE_UNIX, 0, "No map found");
            goto done;
        }
        mptail = &mptab1[len];
        if ((void*)mptail-(void*)mp > 0)
            memmove(&mp[1], mp, (void*)mptail-(void*)mp);
    }
    mp->mp_p0 = ptr0;
    mp->mp_p1 = ptr1;
    *lenp = len+1;
    *mptabp = mptab1;
    retval = 0;
 done:
    return retval;
}
