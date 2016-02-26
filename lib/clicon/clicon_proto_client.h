/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * Client-side functions for clicon_proto protocol
 * Historically this code was part of the clicon_cli application. But
 * it should (is?) be general enough to be used by other applications.
 */

#ifndef _CLICON_PROTO_CLIENT_H_
#define _CLICON_PROTO_CLIENT_H_

int clicon_rpc_commit(clicon_handle h, char *running_db, char *db, 
		     int snapshot, int startup);
int clicon_rpc_validate(clicon_handle h, char *db);
int clicon_rpc_change(clicon_handle h, char *db, 
		      enum operation_type op, char *key, char *val);

int clicon_rpc_xmlput(clicon_handle h, char *db, enum operation_type op, char *xml);
int clicon_rpc_dbitems(clicon_handle h, char *db, char *rx, 
		       char *attr, char *val, 
		       cvec ***cvv, size_t *cvvlen);
int clicon_rpc_save(clicon_handle h, char *dbname, int snapshot, char *filename);
int clicon_rpc_load(clicon_handle h, int replace, char *db, char *filename);
int clicon_rpc_copy(clicon_handle h, char *filename1, char *filename2);
int clicon_rpc_rm(clicon_handle h, char *filename);
int clicon_rpc_initdb(clicon_handle h, char *filename);
int clicon_rpc_lock(clicon_handle h, char *dbname);
int clicon_rpc_unlock(clicon_handle h, char *dbname);
int clicon_rpc_kill(clicon_handle h, int session_id);
int clicon_rpc_debug(clicon_handle h, int level);
int clicon_rpc_call(clicon_handle h, uint16_t op, char *plugin, char *func,
		    void *param, uint16_t paramlen, 
		    char **ret, uint16_t *retlen,
		    const void *label);
int clicon_rpc_subscription(clicon_handle h, int status, char *stream, 
			    enum format_enum format, char *filter, int *s);


#endif  /* _CLICON_PROTO_CLIENT_H_ */
