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

 * XML support functions.
 */
#ifndef _CLIXON_XML_DB_H
#define _CLIXON_XML_DB_H

/*
 * Prototypes
 */
int yang2xmlkeyfmt(yang_stmt *ys, char **xkfmt);
int xmlkeyfmt2key(char *xkfmt, cvec *cvv, char **xk);
int xmlkeyfmt2xpath(char *xkfmt, cvec *cvv, char **xk);
int xmldb_get(clicon_handle h, char *db, char *xpath, int vector, 
	      cxobj **xtop, cxobj ***xvec, size_t *xlen);
int xmldb_put(clicon_handle h, char *db, cxobj *xt, enum operation_type op);
int xmldb_put_xkey(clicon_handle h, char *db, 
		   char *xkey, char *val,
		   enum operation_type op);
int xmldb_dump(FILE *f, char *dbfilename, char *rxkey);
int xmldb_copy(clicon_handle h, char *from, char *to);
int xmldb_lock(clicon_handle h, char *db, int pid);
int xmldb_unlock(clicon_handle h, char *db, int pid);
int xmldb_islocked(clicon_handle h, char *db);
int xmldb_exists(clicon_handle h, char *db);
int xmldb_delete(clicon_handle h, char *db);
int xmldb_init(clicon_handle h, char *db);

#endif /* _CLIXON_XML_DB_H */
