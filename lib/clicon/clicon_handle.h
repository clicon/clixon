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

 */


#ifndef _CLICON_HANDLE_H_
#define _CLICON_HANDLE_H_

/*
 * Types
 */
/* Common handle used in most clicon calls that you get from clicon_init(). 
   Note that its contents is different dependending on if invoked from a 
   cli/backend/netconf or other plugin. But this is hidden under-the-hood.
*/
#if 1 /* SANITY CHECK */
typedef struct {float a;} *clicon_handle;
#else
typedef void *clicon_handle;
#endif

/*
 * Prototypes
 */
/* Basic CLICON init functions returning a handle for API access. */
clicon_handle clicon_handle_init(void);

/* Internal call to allocate a CLICON handle. */
clicon_handle clicon_handle_init0(int size);

/* Deallocate handle */
int clicon_handle_exit(clicon_handle h);

/* Check struct magic number for sanity checks */
int clicon_handle_check(clicon_handle h);

/* Return clicon options (hash-array) given a handle.*/
clicon_hash_t *clicon_options(clicon_handle h);

/* Return internal clicon data (hash-array) given a handle.*/
clicon_hash_t *clicon_data(clicon_handle h);

#endif  /* _CLICON_HANDLE_H_ */
