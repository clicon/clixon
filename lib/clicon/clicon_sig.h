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

#ifndef _CLICON_SIG_H_
#define _CLICON_SIG_H_

/*
 * Types
 */
typedef void (*sigfn_t)(int);

/*
 * Prototypes
 */ 
int set_signal(int signo, void (*handler)(int), void (**oldhandler)(int));
void clicon_signal_block(int);
void clicon_signal_unblock(int);

int pidfile_get(char *pidfile, pid_t *pid0);
int pidfile_write(char *pidfile);
int pidfile_zapold(pid_t pid);

#endif  /* _CLICON_SIG_H_ */
