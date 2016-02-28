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

#ifndef _BACKEND_PLUGIN_H_
#define _BACKEND_PLUGIN_H_

/*
 * Types
 */


/*! Transaction data
 * Clicon internal, presented as void* to app's callback in the 'transaction_data'
 * type in clicon_backend_api.h
 * XXX: move to .c file?
 */
typedef struct {
    uint64_t   td_id;       /* Transaction id */
    void      *td_arg;      /* Callback argument */
    cxobj     *td_src;      /* Source database xml tree */
    cxobj     *td_target;   /* Target database xml tree */
    cxobj    **td_dvec;     /* Delete xml vector */
    size_t     td_dlen;     /* Delete xml vector length */
    cxobj    **td_avec;     /* Add xml vector */
    size_t     td_alen;     /* Add xml vector length */
    cxobj    **td_scvec;    /* Source changed xml vector */
    cxobj    **td_tcvec;    /* Target changed xml vector */
    size_t     td_clen;     /* Changed xml vector length */
} transaction_data_t;

/*
 * Prototypes
 */
int  config_plugin_init(clicon_handle h);
int  plugin_initiate(clicon_handle h); 
int  plugin_finish(clicon_handle h);

int  plugin_reset_state(clicon_handle h, char *dbname);
int  plugin_start_hooks(clicon_handle h, int argc, char **argv);
int  plugin_downcall(clicon_handle h, struct clicon_msg_call_req *req,
		    uint16_t *retlen,  void **retarg);

transaction_data_t * transaction_new(void);
int transaction_free(transaction_data_t *);

int  plugin_transaction_begin(clicon_handle h, transaction_data_t *td);
int  plugin_transaction_validate(clicon_handle h, transaction_data_t *td);
int  plugin_transaction_complete(clicon_handle h, transaction_data_t *td);
int  plugin_transaction_commit(clicon_handle h, transaction_data_t *td);
int  plugin_transaction_end(clicon_handle h, transaction_data_t *td);
int  plugin_transaction_abort(clicon_handle h, transaction_data_t *td);

#endif  /* _BACKEND_PLUGIN_H_ */
