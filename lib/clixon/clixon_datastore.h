/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2019 Olof Hagsand
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

 * Clixon Datastore (XMLDB)
 * Saves Clixon data as clear-text XML (or JSON)
 * Backend-specific
 */
#ifndef _CLIXON_DATASTORE_H
#define _CLIXON_DATASTORE_H

/*
 * Types
 */
/* This is the external handle type exposed in the API.
 * The internal struct is defined in clixon_yang_internal.h */
typedef struct db_elmnt db_elmnt;

/*
 * Prototypes
 */
/* Backward compatible */
#define clicon_db_elmnt_get(h, db) xmldb_find((h), (db))

/* Access functions */
char    *xmldb_name_get(db_elmnt *de);
uint32_t xmldb_id_get(db_elmnt *de);
int      xmldb_id_set(db_elmnt *de, uint32_t id);
cxobj   *xmldb_cache_get(db_elmnt *de);
int      xmldb_cache_set(db_elmnt *de, cxobj *xml);
int      xmldb_modified_get(db_elmnt *de);
int      xmldb_modified_set(db_elmnt *de, int value);
int      xmldb_empty_get(db_elmnt *de);
int      xmldb_empty_set(db_elmnt *de, int value);
int      xmldb_candidate_get(db_elmnt *de);
int      xmldb_candidate_set(db_elmnt *de, int value);
int      xmldb_volatile_get(db_elmnt *de);
int      xmldb_volatile_set(db_elmnt *de, int value);

/* Creator */
db_elmnt *xmldb_new(clixon_handle h, const char *db);
db_elmnt *xmldb_find(clixon_handle h, const char *db);
int xmldb_db2file(clixon_handle h, const char *db, char **filename);
int xmldb_db2subdir(clixon_handle h, const char *db, char **dir);
int xmldb_connect(clixon_handle h);
int xmldb_disconnect(clixon_handle h);

/* in clixon_datastore_read.[ch]: */
int xmldb_get(clixon_handle h, const char *db, cvec *nsc, const char *xpath, cxobj **xret);
int xmldb_get0(clixon_handle h, const char *db, int yb,
               cvec *nsc, const char *xpath, int copy, withdefaults_type wdef,
               cxobj **xret, void *md, cxobj **xerr);
int xmldb_get_cache(clixon_handle h, const char *db, cxobj **xtp, cxobj **xerr);
int xmldb_get_cache_from_file(clixon_handle h, db_elmnt *de, cxobj **xtp, cxobj **xerr);

/* in clixon_datastore_write.[ch]: */
int xmldb_put(clixon_handle h, const char *db, enum operation_type op, cxobj *xt, const char *username, cbuf *cbret);
int xmldb_dump(clixon_handle h, FILE *f, cxobj *xt, enum format_enum format, int pretty, withdefaults_type wdef, int multi, const char *multidb);
int xmldb_write_cache2file(clixon_handle h, const char *db);

int xmldb_copy_file(clixon_handle h, const char *from, const char *to);
int xmldb_copy(clixon_handle h, const char *from, const char *to);
int xmldb_lock(clixon_handle h, const char *db, uint32_t id);
int xmldb_unlock(clixon_handle h, const char *db);
int xmldb_unlock_all(clixon_handle h, uint32_t id);
uint32_t xmldb_islocked(clixon_handle h, const char *db);
int xmldb_lock_timestamp(clixon_handle h, const char *db, struct timeval *tv);
int xmldb_exists(clixon_handle h, const char *db);
int xmldb_clear(clixon_handle h, const char *db);
int xmldb_delete(clixon_handle h, const char *db);
int xmldb_delete_candidates(clixon_handle h);
int xmldb_create(clixon_handle h, const char *db);
/* utility functions */
int xmldb_db_reset(clixon_handle h, const char *db);

int xmldb_print(clixon_handle h, FILE *f);
int xmldb_rename(clixon_handle h, const char *db, const char *newdb, const char *suffix);
int xmldb_populate(clixon_handle h, const char *db);
int xmldb_multi_upgrade(clixon_handle h, const char *db);
int xmldb_drop_priv(clixon_handle h, const char *db, uid_t uid, gid_t gid);
int xmldb_system_only_config(clixon_handle h, const char *xpath, cvec *nsc, cxobj **xret);
int xmldb_candidate_find(clixon_handle h, const char *name, uint32_t ceid, db_elmnt **dep, char **db);
int xmldb_post_commit(clixon_handle h, uint32_t ceid);

#endif /* _CLIXON_DATASTORE_H */
