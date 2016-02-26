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
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 */

#ifndef _CLICON_PROC_H_
#define _CLICON_PROC_H_

/*
 * Prototypes
 */ 
int clicon_proc_run (char *, void (outcb)(char *), int doerr);
int clicon_proc_daemon (char *);
int group_name2gid(char *name, gid_t *gid);

#endif  /* _CLICON_PROC_H_ */
