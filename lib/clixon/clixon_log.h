/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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
 * Regular logging and debugging. Syslog using levels.
 */

#ifndef _CLIXON_LOG_H_
#define _CLIXON_LOG_H_

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

#endif  /* _CLIXON_LOG_H_ */
