/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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

  Key-value store
 */
#ifndef _CLIXON_XMLDB_TEXT_H
#define _CLIXON_XMLDB_TEXT_H

/*
 * Prototypes
 */
int text_get(clicon_handle h, char *db, char *xpath,
	   cxobj **xtop, cxobj ***xvec, size_t *xlen);
int text_put(clicon_handle h, char *db, enum operation_type op, 
	   char *api_path,  cxobj *xt);
int text_dump(FILE *f, char *dbfilename, char *rxkey);
int text_copy(clicon_handle h, char *from, char *to);
int text_lock(clicon_handle h, char *db, int pid);
int text_unlock(clicon_handle h, char *db, int pid);
int text_unlock_all(clicon_handle h, int pid);
int text_islocked(clicon_handle h, char *db);
int text_exists(clicon_handle h, char *db);
int text_delete(clicon_handle h, char *db);
int text_init(clicon_handle h, char *db);

#endif /* _CLIXON_XMLDB_TEXT_H */
