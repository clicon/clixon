/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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

#ifndef _CLIXON_QDB_H_
#define _CLIXON_QDB_H_


/*
 * Low level API
 */

struct db_pair {    
    char *dp_key;  /* database key */
    char *dp_matched; /* Matched component of key */
    char *dp_val;  /* pointer to vector of lvalues */
    int   dp_vlen; /* length of vector of lvalues */
};

/*
 * Prototypes
 */ 
int db_init(char *file);

int db_delete(char *file);

int db_set(char *file, char *key, void *data, size_t datalen);

int db_get(char *file, char *key, void *data, size_t *datalen);

int db_get_alloc(char *file, char *key, void **data, size_t *datalen);

int db_del(char *file, char *key);

int db_exists(char *file, char *key);

int db_regexp(char *file, char *regexp, const char *label, 
	      struct db_pair **pairs, int noval);

char *db_sanitize(char *rx, const char *label);

#endif  /* _CLIXON_QDB_H_ */
