/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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

#ifndef _CLIXON_HASH_H_
#define _CLIXON_HASH_H_

struct clicon_hash {
    qelem_t     h_qelem;
    /*
     * Key must be NULL-terminated string unless clicon_hash_add_ptr function
     * is used to add keys.
     */
    void       *h_key;
    size_t      h_vlen;
    void       *h_val;
};
typedef struct clicon_hash *clicon_hash_t;

clicon_hash_t *clicon_hash_init (void);
int            clicon_hash_free (clicon_hash_t *);
clicon_hash_t  clicon_hash_lookup (clicon_hash_t *head, const char *key);
clicon_hash_t  clicon_hash_lookup_ptr (clicon_hash_t *head, void *key);
void          *clicon_hash_value (clicon_hash_t *head, const char *key, size_t *vlen);
void          *clicon_hash_ptr_value (clicon_hash_t *head, void *key);
clicon_hash_t  clicon_hash_add (clicon_hash_t *head, const char *key, const void *val, size_t vlen);
clicon_hash_t  clicon_hash_add_ptr (clicon_hash_t *head, void *key, void *val);
int            clicon_hash_del (clicon_hash_t *head, const char *key);
int            clicon_hash_del_ptr (clicon_hash_t *head, void *key);
int            clicon_hash_dump(clicon_hash_t *head, FILE *f);
int            clicon_hash_keys(clicon_hash_t *hash, char ***vector, size_t *nkeys);

/*
 *   Macros to iterate over hash contents.
 *   XXX A bit crude. Just as easy for app to loop through the keys itself.
 *
 *  Example:
 *     char *k;
 *     clicon_hash_t *h = clicon_hash_init();
 *
 *     clicon_hash_add(h, "colour", "red", 6);
 *     clicon_hash_add(h, "name", "rudolf" 7);
 *     clicon_hash_add(h, "species", "reindeer" 9);
 *
 *     clicon_hash_each(h, k) {
 *       printf ("%s = %s\n", k, (char *)clicon_hash_value(h, k, NULL));
 *     } hash_each_end();
*/
#define clicon_hash_each(__hash__, __key__)                                     \
{                                                                       \
    int __i__;                                                          \
    size_t __n__;                                                       \
    char **__k__ = hash_keys((__hash__),&__n__);                        \
    if (__k__) {                                                        \
        for(__i__ = 0; __i__ < __n__ && ((__key__) = __k__[__i__]); __i__++)
#define clicon_hash_each_end(__hash__)   if (__k__) free(__k__);  } }

#endif /* _CLIXON_HASH_H_ */
