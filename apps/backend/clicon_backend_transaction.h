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
  along with CLICON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * Part of the external API to plugins. Applications should not include
 * this file directly (only via clicon_backend.h).
 * Internal code should include this
 */

#ifndef _CLICON_BACKEND_TRANSACTION_H_
#define _CLICON_BACKEND_TRANSACTION_H_

/*
 * Types
 */

/*! Generic downcall registration. 
 * Enables any function to be called from (cli) frontend
 * to backend. Like an RPC on application-level.
 */
typedef int (*downcall_cb)(clicon_handle h, uint16_t op, uint16_t len, 
			   void *arg, uint16_t *retlen, void **retarg);

/* Transaction callback data accessors for client plugins
 * (defined in config_dbdep.c)
 * @see transaction_data_t  internal structure
 */
typedef void *transaction_data;
uint64_t transaction_id(transaction_data td);
void   *transaction_arg(transaction_data td);
cxobj  *transaction_src(transaction_data td);
cxobj  *transaction_target(transaction_data td);
cxobj **transaction_dvec(transaction_data td);
size_t  transaction_dlen(transaction_data td);
cxobj **transaction_avec(transaction_data td);
size_t  transaction_alen(transaction_data td);
cxobj **transaction_scvec(transaction_data td);
cxobj **transaction_tcvec(transaction_data td);
size_t  transaction_clen(transaction_data td);

int transaction_print(FILE *f, transaction_data th);

#endif /* _CLICON_BACKEND_TRANSACTION_H_ */
