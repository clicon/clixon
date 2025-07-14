/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

#ifndef _CLIXON_HANDLE_H_
#define _CLIXON_HANDLE_H_

/*
 * Types
 */
/*! Common handle used in most clicon calls that you get from clicon_init().
 *
 * Note that its contents is different dependending on if invoked from a
 * cli/backend/netconf or other plugin. But this is hidden under-the-hood.
 */
typedef void *clixon_handle;

/*! The dynamicically loadable plugin object handle (should be in clixon_plugin.h) */
typedef void *plghndl_t;

/*! Indirect output functions to print with something else than fprintf
 *
 * @see man fprintf
 * @retval     0       OK
 * @retval    -1       Error
 */
typedef int (clicon_output_cb)(
   FILE *f,
   const char *templ, ...
) __attribute__ ((format (printf, 2, 3)));

/*
 * Prototypes
 */
/* Basic CLICON init functions returning a handle for API access. */
clixon_handle clixon_handle_init(void);

/* Internal call to allocate a CLICON handle. */
clixon_handle clixon_handle_init0(int size);

/* Deallocate handle */
int clixon_handle_exit(clixon_handle h);

/* Check struct magic number for sanity checks */
int clixon_handle_check(clixon_handle h);

/* Return clicon options (hash-array) given a handle.*/
clicon_hash_t *clicon_options(clixon_handle h);

/* Return internal clicon data (hash-array) given a handle.*/
clicon_hash_t *clicon_data(clixon_handle h);

/* Return internal clicon db_elmnt (hash-array) given a handle.*/
clicon_hash_t *clicon_db_elmnt(clixon_handle h);

/* Return internal stream hash-array given a handle.*/
struct event_stream *clicon_stream(clixon_handle h);
struct event_stream;
int clicon_stream_set(clixon_handle h, struct event_stream *es);
int clicon_stream_append(clixon_handle h, struct event_stream *es);

#endif  /* _CLIXON_HANDLE_H_ */
