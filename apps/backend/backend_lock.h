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

 *
 * Database logical lock functions.
 * Only one lock (candidate_db)
 * Not persistent (needs another db)
 */

#ifndef _BACKEND_LOCK_H_
#define _BACKEND_LOCK_H_

/*
 * Prototypes
 */ 
int db_lock(clicon_handle h, int id);
int db_unlock(clicon_handle h);
int db_islocked(clicon_handle h);

#endif  /* _BACKEND_LOCK_H_ */
