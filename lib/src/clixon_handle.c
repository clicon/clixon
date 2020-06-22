/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
#include <sys/time.h>
 
#include <cligen/cligen.h>

/* clicon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_log.h"
#include "clixon_err.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_stream.h"
#include "clixon_data.h"
#include "clixon_options.h"

#define CLICON_MAGIC 0x99aafabe

#define handle(h) (assert(clicon_handle_check(h)==0),(struct clicon_handle *)(h))

/*! Internal structure of basic handle. Also header of all other handles.
 * @note If you change here, you must also change the structs below:
 * This is the internal definition of a "Clixon handle" which in its external
 * form is "clicon_handle" and is used in most Clixon API calls.
 * Some details:
 * 1) the internal structure contains a header (defined here) whereas higher
 *    order libs (eg cli and backend) introduce more fields appended to this 
 *    struct.
 * 2) ch_options accessed via clicon_options() are clixon config options are 
 *    string values appearing in the XML configfile accessed with -f. 
 *    Alternatively, these could be accessed via clicon_conf_xml()
 * 3) ch_data accessed via clicon_data() is more general purpose for any data.
 *    that is, not only strings. And has separate namespace from options.
 * 4) ch_db_elmnt. Only reason it is not in ch_data is its own namespace and
 *    need to dump all hashes
 * XXX: put ch_stream under ch_data
 * @see struct cli_handle
 * @see struct backend_handle
 * @see struct restconf_handle
 */
struct clicon_handle {
    int               ch_magic;    /* magic (HDR) */
    clicon_hash_t    *ch_copt;     /* clicon option list (HDR) */
    clicon_hash_t    *ch_data;     /* internal clicon data (HDR) */
    clicon_hash_t    *ch_db_elmnt; /* xml datastore element cache data */
    event_stream_t   *ch_stream;   /* notification streams, see clixon_stream.[ch] */
};

/*! Internal call to allocate a CLICON handle. 
 *
 * @param[in]  size  Size of handle (internal) struct.
 * @retval   h   Clicon handle
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
    if ((ch->ch_copt = clicon_hash_init()) == NULL){
	clicon_handle_exit((clicon_handle)ch);
	goto done;
    }
    if ((ch->ch_data = clicon_hash_init()) == NULL){
	clicon_handle_exit((clicon_handle)ch);
	goto done;
    }
    if ((ch->ch_db_elmnt = clicon_hash_init()) == NULL){
	clicon_handle_exit((clicon_handle)ch);
	goto done;
    }
    h = (clicon_handle)ch;
  done:
    return h;
}

/*! Basic CLICON init functions returning a handle for API access.
 *
 * @retval   h   Clicon handle
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
 * @param[in]  h   Clicon handle
 * @Note: handle 'h' cannot be used in calls after this
 */
int
clicon_handle_exit(clicon_handle h)
{
    int                   retval = -1;
    struct clicon_handle *ch = handle(h);
    clicon_hash_t        *ha;

    if ((ha = clicon_options(h)) != NULL)
	clicon_hash_free(ha);
    if ((ha = clicon_data(h)) != NULL)
	clicon_hash_free(ha);
    if ((ha = clicon_db_elmnt(h)) != NULL)
	clicon_hash_free(ha);
    stream_delete_all(h, 1);
    free(ch);
    retval = 0;
    return retval;
}

/*! Check struct magic number for sanity checks
 * @param[in]  h   Clicon handle
 * @retval     0   Sanity check OK
 * @retval    -1   Sanity check failed
 */
int
clicon_handle_check(clicon_handle h)
{
    /* Dont use handle macro to avoid recursion */
    struct clicon_handle *ch = (struct clicon_handle *)(h);

    return ch->ch_magic == CLICON_MAGIC ? 0 : -1;
}

/*! Return clicon options (hash-array) given a handle.
 * @param[in]  h        Clicon handle
 */
clicon_hash_t *
clicon_options(clicon_handle h)
{
    struct clicon_handle *ch = handle(h);

    return ch->ch_copt;
}

/*! Return clicon data (hash-array) given a handle.
 * @param[in]  h        Clicon handle
 */
clicon_hash_t *
clicon_data(clicon_handle h)
{
    struct clicon_handle *ch = handle(h);

    return ch->ch_data;
}

/*! Return clicon db_elmnt (hash-array) given a handle.
 * @param[in]  h        Clicon handle
 */
clicon_hash_t *
clicon_db_elmnt(clicon_handle h)
{
    struct clicon_handle *ch = handle(h);

    return ch->ch_db_elmnt;
}

/*! Return stream hash-array given a clicon handle.
 * @param[in]  h        Clicon handle
 */
event_stream_t *
clicon_stream(clicon_handle h)
{
    struct clicon_handle *ch = handle(h);

    return ch->ch_stream;
}

int
clicon_stream_set(clicon_handle   h,
		  event_stream_t *es)
{
    struct clicon_handle *ch = handle(h);

    ch->ch_stream = es;
    return 0;
}

int
clicon_stream_append(clicon_handle h,
		     event_stream_t *es)
{
    struct clicon_handle *ch = handle(h);
    
    ADDQ(es, ch->ch_stream);
    return 0;
}
