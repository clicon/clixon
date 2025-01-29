/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>
#include <errno.h>
#include <unistd.h>
#include <assert.h>
#include <sys/types.h>
#include <sys/time.h>
#include <regex.h>
#include <syslog.h>
#include <signal.h>
#include <netinet/in.h>
#include <limits.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

#include "clixon_backend_client.h"
#include "backend_client.h"
#include "backend_handle.h"

/* header part is copied from struct clixon_handle in lib/src/clixon_handle.c */

#define CLICON_MAGIC 0x99aafabe

#define handle(h) (assert(clixon_handle_check(h)==0),(struct backend_handle *)(h))

/* Clixon_handle for backends.
 * First part of this is header, same for clixon_handle and cli_handle.
 * Access functions for common fields are found in clicon lib: clicon_options.[ch]
 * This file should only contain access functions for the _specific_
 * entries in the struct below.
 */
/*! Backend specific handle added to header CLICON handle
 *
 * This file should only contain access functions for the _specific_
 * entries in the struct below.
 * @note The top part must be equivalent to struct clixon_handle in clixon_handle.c
 * @see struct clixon_handle, struct cli_handle
 */
struct backend_handle {
    int                      bh_magic;     /* magic (HDR)*/
    clicon_hash_t           *bh_copt;      /* clicon option list (HDR) */
    clicon_hash_t           *bh_data;      /* internal clicon data (HDR) */
    clicon_hash_t           *ch_db_elmnt;  /* xml datastore element cache data */
    event_stream_t          *bh_stream;    /* notification streams, see clixon_stream.[ch] */

    /* ------ end of common handle ------ */
    struct client_entry     *bh_ce_list;   /* The client list */
    int                      bh_ce_nr;     /* Number of clients, just increment */
};

/*! Creates and returns a clicon config handle for other CLICON API calls
 */
clixon_handle
backend_handle_init(void)
{
    struct backend_handle *bh;

    bh = (struct backend_handle *)clixon_handle_init0(sizeof(struct backend_handle));
    bh->bh_ce_nr = 1; /* To align with session-id */
    return (clixon_handle)bh;
}

/*! Deallocates a backend handle, including all client structs
 *
 * @note: handle 'h' cannot be used in calls after this
 * @see backend_client_rm
 */
int
backend_handle_exit(clixon_handle h)
{
    struct client_entry   *ce;

    stream_delete_all(h, 1);
    /* only delete client structs, not close sockets, etc, see backend_client_rm WHY NOT? */
    while ((ce = backend_client_list(h)) != NULL){
        if (ce->ce_s){
            close(ce->ce_s);
            ce->ce_s = 0;
        }
        backend_client_delete(h, ce);
    }
    clixon_handle_exit(h); /* frees h and options (and streams) */
    return 0;
}

/*! Add new client, typically frontend such as cli, netconf, restconf
 *
 * @param[in]  h        Clixon handle
 * @param[in]  addr     Address of client
 * @retval     ce       Client entry
 * @retval     NULL     Error
 */
struct client_entry *
backend_client_add(clixon_handle    h,
                   struct sockaddr *addr)
{
    struct backend_handle *bh = handle(h);
    struct client_entry   *ce = NULL;

    if ((ce = (struct client_entry *)malloc(sizeof(*ce))) == NULL){
        clixon_err(OE_PLUGIN, errno, "malloc");
        return NULL;
    }
    memset(ce, 0, sizeof(*ce));
    ce->ce_nr = bh->bh_ce_nr++; /* Session-id ? */
    memcpy(&ce->ce_addr, addr, sizeof(*addr));
    ce->ce_handle = h;
    if (clicon_session_id_get(h, &ce->ce_id) < 0){
        clixon_err(OE_NETCONF, ENOENT, "session_id not set");
        free(ce);
        return NULL;
    }
    clicon_session_id_set(h, ce->ce_id + 1);
    gettimeofday(&ce->ce_time, NULL);
    netconf_monitoring_counter_inc(h, "in-sessions");
    ce->ce_next = bh->bh_ce_list;
    bh->bh_ce_list = ce;
    return ce;
}

/*! Return client list
 *
 * @param[in]  h        Clixon handle
 * @retval     ce_list  Client entry list (all sessions)
 */
struct client_entry *
backend_client_list(clixon_handle h)
{
    struct backend_handle *bh = handle(h);

    return bh->bh_ce_list;
}

/*! Actually remove client from client list
 *
 * @param[in]  h   Clixon handle
 * @param[in]  ce  Client handle
 * @see backend_client_rm which is more high-level
 */
int
backend_client_delete(clixon_handle        h,
                      struct client_entry *ce)
{
    struct client_entry   *c;
    struct client_entry  **ce_prev;
    struct backend_handle *bh = handle(h);

    ce_prev = &bh->bh_ce_list;
    for (c = *ce_prev; c; c = c->ce_next){
        if (c == ce){
            *ce_prev = c->ce_next;
            if (ce->ce_username)
                free(ce->ce_username);
            if (ce->ce_transport)
                free(ce->ce_transport);
            if (ce->ce_source_host)
                free(ce->ce_source_host);
            ce->ce_next = NULL;
            free(ce);
            break;
        }
        ce_prev = &c->ce_next;
    }
    return 0;
}

/*! Debug print backend clients
 *
 * @param[in]  h   Clixon handle
 * @param[in]  f   UNIX output stream
 */
int
backend_client_print(clixon_handle h,
                     FILE         *f)
{
    struct backend_handle *bh = handle(h);
    struct client_entry   *ce;

    for (ce = bh->bh_ce_list; ce; ce = ce->ce_next){
        fprintf(f, "Client:     %d\n", ce->ce_nr);
        fprintf(f, "  Session:  %d\n", ce->ce_id);
        fprintf(f, "  Socket:   %d\n", ce->ce_s);
        fprintf(f, "  RPCs in:  %u\n", ce->ce_in_rpcs);
        fprintf(f, "  Bad RPCs in:  %u\n", ce->ce_in_bad_rpcs);
        fprintf(f, "  Err RPCs out:  %u\n", ce->ce_out_rpc_errors);
        fprintf(f, "  Username: %s\n", ce->ce_username);
    }
    return 0;
}
