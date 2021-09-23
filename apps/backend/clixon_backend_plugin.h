/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

  */

#ifndef _CLIXON_BACKEND_PLUGIN_H_
#define _CLIXON_BACKEND_PLUGIN_H_

/*
 * Types
 */

/*! Transaction data describing a system transition from a src to target state
 * Clicon internal, presented as void* to app's callback in the 'transaction_data'
 * type in clicon_backend_api.h
 * The struct contains source and target XML tree (e.g. candidate/running)
 * But primarily a set of XML tree vectors (dvec, avec, cvec) and associated lengths
 * These contain the difference between src and target XML, ie "what has changed".
 * It is up to the validate callbacks to ensure that these changes are OK
 * It is up to the commit callbacks to enforce these changes in the "state" of 
 *the system.
 */
typedef struct {
    uint64_t   td_id;       /* Transaction id */
    void      *td_arg;      /* Callback argument */
    cxobj     *td_src;      /* Source database xml tree */
    cxobj     *td_target;   /* Target database xml tree */
    cxobj    **td_dvec;     /* Delete xml vector */
    int        td_dlen;     /* Delete xml vector length */
    cxobj    **td_avec;     /* Add xml vector */
    int        td_alen;     /* Add xml vector length */
    cxobj    **td_scvec;    /* Source changed xml vector */
    cxobj    **td_tcvec;    /* Target changed xml vector */
    int        td_clen;     /* Changed xml vector length */
} transaction_data_t;

/*
 * Prototypes
 */
int clixon_plugin_reset_one(clixon_plugin_t *cp, clicon_handle h, char *db);
int clixon_plugin_reset_all(clicon_handle h, char *db);

int clixon_plugin_pre_daemon_all(clicon_handle h);
int clixon_plugin_daemon_all(clicon_handle h);

int clixon_plugin_statedata_all(clicon_handle h, yang_stmt *yspec, cvec *nsc, char *xpath,
				pagination_mode_t pagmode,
				uint32_t offset, uint32_t limit, uint32_t *remaining,
				cxobj **xtop);
int clixon_plugin_lockdb_all(clicon_handle h, char *db, int lock, int id);

transaction_data_t * transaction_new(void);
int transaction_free(transaction_data_t *);

int plugin_transaction_begin_one(clixon_plugin_t *cp, clicon_handle h, transaction_data_t *td);
int plugin_transaction_begin_all(clicon_handle h, transaction_data_t *td);

int plugin_transaction_validate_one(clixon_plugin_t *cp, clicon_handle h, transaction_data_t *td);
int plugin_transaction_validate_all(clicon_handle h, transaction_data_t *td);

int plugin_transaction_complete_one(clixon_plugin_t *cp, clicon_handle h, transaction_data_t *td);
int plugin_transaction_complete_all(clicon_handle h, transaction_data_t *td);

int plugin_transaction_commit_one(clixon_plugin_t *cp, clicon_handle h, transaction_data_t *td);
int plugin_transaction_commit_all(clicon_handle h, transaction_data_t *td);

int plugin_transaction_commit_done_one(clixon_plugin_t *cp, clicon_handle h, transaction_data_t *td);
int plugin_transaction_commit_done_all(clicon_handle h, transaction_data_t *td);

int plugin_transaction_end_one(clixon_plugin_t *cp, clicon_handle h, transaction_data_t *td);
int plugin_transaction_end_all(clicon_handle h, transaction_data_t *td);

int plugin_transaction_abort_one(clixon_plugin_t *cp, clicon_handle h, transaction_data_t *td);
int plugin_transaction_abort_all(clicon_handle h, transaction_data_t *td);

#endif  /* _CLIXON_BACKEND_PLUGIN_H_ */
