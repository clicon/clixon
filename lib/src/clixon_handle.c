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

 *
 */
#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
 
#include <cligen/cligen.h>

/* clicon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_err.h"
#include "clixon_yang.h"
#include "clixon_options.h"

#define CLICON_MAGIC 0x99aafabe

#define handle(h) (assert(clicon_handle_check(h)==0),(struct clicon_handle *)(h))

/*
 * clicon_handle
 * Internal structire of basic handle. Also header of all other handles.
 * see struct clicon_cli_handle, struct clicon_backend_handle, etc
 */
struct clicon_handle {
    int                      ch_magic;    /* magic (HDR) */
    clicon_hash_t           *ch_copt;     /* clicon option list (HDR) */
    clicon_hash_t           *ch_data;     /* internal clicon data (HDR) */
};


/*! Internal call to allocate a CLICON handle. 
 *
 * There may be different variants of handles with some common options.
 * So far the only common options is a MAGIC cookie for sanity checks and 
 * CLICON options
 */
clicon_handle 
clicon_handle_init0(int size)
{
    struct clicon_handle *ch;
    clicon_handle         h = NULL;

    if ((ch = malloc(size)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
	goto done;
    }
    memset(ch, 0, size);
    ch->ch_magic = CLICON_MAGIC;
    if ((ch->ch_copt = hash_init()) == NULL){
	clicon_handle_exit((clicon_handle)ch);
	goto done;
    }
    if ((ch->ch_data = hash_init()) == NULL){
	clicon_handle_exit((clicon_handle)ch);
	goto done;
    }
    h = (clicon_handle)ch;
  done:
    return h;
}

/*! Basic CLICON init functions returning a handle for API access.
 *
 * This is the first call to CLICON basic API which returns a handle to be 
 * used in the API functions. There are other clicon_init functions for more 
 * elaborate applications (cli/backend/netconf). This should be used by the most
 * basic applications that use CLICON lib directly.
 */
clicon_handle 
clicon_handle_init(void)
{
    return clicon_handle_init0(sizeof(struct clicon_handle));
}

/*! Deallocate clicon handle, including freeing handle data.
 * @Note: handle 'h' cannot be used in calls after this
 */
int
clicon_handle_exit(clicon_handle h)
{
    struct clicon_handle *ch = handle(h);
    clicon_hash_t        *copt;
    clicon_hash_t        *data;

    if ((copt = clicon_options(h)) != NULL)
	hash_free(copt);
    if ((data = clicon_data(h)) != NULL)
	hash_free(data);
    free(ch);
    return 0;
}

/*
 * Check struct magic number for sanity checks
 * return 0 if OK, -1 if fail.
 */
int
clicon_handle_check(clicon_handle h)
{
    /* Dont use handle macro to avoid recursion */
    struct clicon_handle *ch = (struct clicon_handle *)(h);

    return ch->ch_magic == CLICON_MAGIC ? 0 : -1;
}

/* 
 * Return clicon options (hash-array) given a handle.
 */
clicon_hash_t *
clicon_options(clicon_handle h)
{
    struct clicon_handle *ch = handle(h);

    return ch->ch_copt;
}

/* 
 * Return clicon data (hash-array) given a handle.
 */
clicon_hash_t *
clicon_data(clicon_handle h)
{
    struct clicon_handle *ch = handle(h);

    return ch->ch_data;
}
