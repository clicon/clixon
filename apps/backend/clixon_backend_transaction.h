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

 *
 * Part of the external API to plugins. Applications should not include
 * this file directly (only via clicon_backend.h).
 * Internal code should include this
 */

#ifndef _CLIXON_BACKEND_TRANSACTION_H_
#define _CLIXON_BACKEND_TRANSACTION_H_

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

#endif /* _CLIXON_BACKEND_TRANSACTION_H_ */
