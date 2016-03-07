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


#ifndef _BACKEND_COMMIT_H_
#define _BACKEND_COMMIT_H_

/*
 * Prototypes
 */ 
int from_client_validate(clicon_handle h, int s, struct clicon_msg *msg, const char *label);
int from_client_commit(clicon_handle h, int s, struct clicon_msg *msg, const char *label);
int candidate_commit(clicon_handle h, char *candidate);

#endif  /* _BACKEND_COMMIT_H_ */
