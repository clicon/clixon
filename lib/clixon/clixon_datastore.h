/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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
 
 * Clixon Datastore (XMLDB)
 * Saves Clixon data as clear-text XML (or JSON)
 */
#ifndef _CLIXON_DATASTORE_H
#define _CLIXON_DATASTORE_H

/*
 * Prototypes
 * API
 */
/* Internal functions */
int xmldb_db2file(clicon_handle h, const char *db, char **filename);

/* API */
int xmldb_validate_db(const char *db);
int xmldb_connect(clicon_handle h);
int xmldb_disconnect(clicon_handle h);
 /* in clixon_datastore_read.[ch] */
int xmldb_get(clicon_handle h, const char *db, cvec *nsc, char *xpath, cxobj **xtop);
int xmldb_get0(clicon_handle h, const char *db,
	       cvec *nsc, const char *xpath,
	       int copy, cxobj **xtop, modstate_diff_t *msd); 
int xmldb_get0_clear(clicon_handle h, cxobj *x);
int xmldb_get0_free(clicon_handle h, cxobj **xp);
int xmldb_put(clicon_handle h, const char *db, enum operation_type op, cxobj *xt, char *username, cbuf *cbret); /* in clixon_datastore_write.[ch] */
int xmldb_copy(clicon_handle h, const char *from, const char *to);
int xmldb_lock(clicon_handle h, const char *db, uint32_t id);
int xmldb_unlock(clicon_handle h, const char *db);
int xmldb_unlock_all(clicon_handle h, uint32_t id);
uint32_t xmldb_islocked(clicon_handle h, const char *db);
int xmldb_exists(clicon_handle h, const char *db);
int xmldb_clear(clicon_handle h, const char *db);
int xmldb_delete(clicon_handle h, const char *db);
int xmldb_create(clicon_handle h, const char *db);
/* utility functions */
int xmldb_db_reset(clicon_handle h, char *db);

#endif /* _CLIXON_DATASTORE_H */
