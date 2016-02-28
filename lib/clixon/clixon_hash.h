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

#ifndef _CLIXON_HASH_H_
#define _CLIXON_HASH_H_

struct clicon_hash {
    qelem_t	h_qelem;
    char       *h_key;
    size_t	h_vlen;
    void       *h_val;
};
typedef struct clicon_hash *clicon_hash_t;

clicon_hash_t *hash_init (void);
void hash_free (clicon_hash_t *);
clicon_hash_t hash_lookup (clicon_hash_t *head, const char *key);
void *hash_value (clicon_hash_t *head, const char *key, size_t *vlen);
clicon_hash_t hash_add (clicon_hash_t *head, const char *key, void *val, size_t vlen);
int hash_del (clicon_hash_t *head, const char *key);
void hash_dump(clicon_hash_t *head, FILE *f);
char **hash_keys(clicon_hash_t *hash, size_t *nkeys);


/*
 *   Macros to iterate over hash contents.
 *   XXX A bit crude. Just as easy for app to loop through the keys itself.
 *
 *  Example:
 *     char *k;
 *     clicon_hash_t *h = hash_init();
 *
 *     hash_add(h, "colour", "red", 6);
 *     hash_add(h, "name", "rudolf" 7);
 *     hash_add(h, "species", "reindeer" 9);
 * 
 *     hash_each(h, k) {
 *       printf ("%s = %s\n", k, (char *)hash_value(h, k, NULL));
 *     } hash_each_end();
*/
#define hash_each(__hash__, __key__) 					\
{									\
    int __i__;								\
    size_t __n__;							\
    char **__k__ = hash_keys((__hash__),&__n__);			\
    if (__k__) {							\
        for(__i__ = 0; __i__ < __n__ && ((__key__) = __k__[__i__]); __i__++)
#define hash_each_end(__hash__)	 if (__k__) free(__k__);  } }


#endif /* _CLIXON_HASH_H_ */
