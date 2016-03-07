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
#ifndef _CLIXON_XML_DB_RPC_H_
#define _CLIXON_XML_DB_RPC_H_

/*
 * Prototypes
 */
int xmldb_get_rpc(clicon_handle h, char *db,
		  char *xpath, int vector,
		  cxobj **xtop, cxobj ***xvec, size_t *xlen);
int xmldb_put_rpc(clicon_handle h, char *db, cxobj *xt, enum operation_type op);
int xmldb_put_xkey_rpc(clicon_handle h, char *db, char *xk, char *val, 
		       enum operation_type op);
int xmldb_copy_rpc(clicon_handle h, char *from, char *to);
int xmldb_lock_rpc(clicon_handle h, char *db, int pid);
int xmldb_unlock_rpc(clicon_handle h, char *db, int pid);
int xmldb_islocked_rpc(clicon_handle h, char *db);

int xmldb_exists_rpc(clicon_handle h, char *db);
int xmldb_delete_rpc(clicon_handle h, char *db);
int xmldb_init_rpc(clicon_handle h, char *db);

#endif /* _CLIXON_XML_DB_RPC_H_ */
