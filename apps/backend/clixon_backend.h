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

 *
 * The exported interface to plugins. External apps (eg backend plugins) should
 * only include this file.
 * Internal code should not include this file
 */

#ifndef _CLIXON_BACKEND_H_
#define _CLIXON_BACKEND_H_

/*
 * Use this constant to disable some prototypes that should not be visible outside the lib.
 * This is an alternative to use separate internal include files.
 */

/* Common code (API and Backend daemon) */
#include <clixon/clixon_backend_handle.h>
#include <clixon/clixon_backend_transaction.h>

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
int plugin_reset(clicon_handle h, const char *db);

/*! Retreive statedata, add statedata to XML tree
 * @see plgstatedata_ t
 */
int plugin_statedata(clicon_handle h, char *xpath, cxobj *xtop);

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

#endif /* _CLIXON_BACKEND_H_ */
