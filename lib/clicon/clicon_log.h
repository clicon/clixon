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

 *
 * Regular logging and debugging. Syslog using levels.
 */

#ifndef _CLICON_LOG_H_
#define _CLICON_LOG_H_

/*
 * Constants
 */
#define CLICON_LOG_SYSLOG 1 /* print logs on syslog */
#define CLICON_LOG_STDERR 2 /* print logs on stderr */
#define CLICON_LOG_STDOUT 4 /* print logs on stdout */

/*
 * Types
 */
typedef int (clicon_log_notify_t)(int level, char *msg, void *arg);

/*
 * Variables
 */
extern int debug;  


/*
 * Prototypes
 */
int clicon_log_init(char *ident, int upto, int flags);
int clicon_log_str(int level, char *msg);
int clicon_log(int level, char *format, ...);
clicon_log_notify_t *clicon_log_register_callback(clicon_log_notify_t *cb, void *arg);
int clicon_debug_init(int dbglevel, FILE *f);
int clicon_debug(int dbglevel, char *format, ...);
char *mon2name(int md);

#endif  /* _CLICON_LOG_H_ */
