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
 * The exported interface to plugins. External apps (eg backend plugins) should
 * only include this file.
 * Internal code should not include this file
 */

#ifndef _CLICON_BACKEND_H_
#define _CLICON_BACKEND_H_

/*
 * Use this constant to disable some prototypes that should not be visible outside the lib.
 * This is an alternative to use separate internal include files.
 */

/* Common code (API and Backend daemon) */
#include <clicon/clicon_backend_handle.h>
#include <clicon/clicon_backend_transaction.h>

/*! Clicon Backend plugin callbacks: use these in your backend plugin code 
 */

/*! Called when plugin loaded. Only mandadory callback. All others optional 
 * @see plginit_t
 */
int plugin_init(clicon_handle h);

/* Called when backend started with cmd-line arguments from daemon call. 
 * @see plgstart_t
 */
int plugin_start(clicon_handle h, int argc, char **argv);

/* Called just before plugin unloaded. 
 * @see plgexit_t
 */
int plugin_exit(clicon_handle h);

/*! Reset system state to original state. Eg at reboot before running thru config. 
 * @see plgreset_t 
 */
int plugin_reset(clicon_handle h, char *dbname);

/*! Called before a commit/validate sequence begins. Eg setup state before commit 
 * @see trans_cb_t
 */
int transaction_begin(clicon_handle h, transaction_data td);

/*! Validate. 
 * @see trans_cb_t
 */
int transaction_validate(clicon_handle h, transaction_data td);

/* Called after a validation completed succesfully (but before commit). 
 * @see trans_cb_t
 */
int transaction_complete(clicon_handle h, transaction_data td);

/* Commit. 
 * @see trans_cb_t
 */
int transaction_commit(clicon_handle h, transaction_data td);

/* Called after a commit sequence completed succesfully. 
 * @see trans_cb_t
 */
int transaction_end(clicon_handle h, transaction_data td);

/* Called if commit or validate sequence fails. After eventual rollback. 
 * @see trans_cb_t
 */
int transaction_abort(clicon_handle h, transaction_data td);

#endif /* _CLICON_BACKEND_H_ */
