/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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
#define CLICON_LOG_FILE   8 /* print logs on clicon_log_filename */

/*
 * Prototypes
 */
int clicon_log_init(char *ident, int upto, int flags);
int clicon_log_exit(void);
int clicon_log_opt(char c);
int clicon_log_file(char *filename);
int clicon_get_logflags(void);
int clicon_log(int level, const char *format, ...) __attribute__ ((format (printf, 2, 3)));
int clicon_debug(int dbglevel, const char *format, ...) __attribute__ ((format (printf, 2, 3)));
int clicon_debug_init(int dbglevel, FILE *f);
int clicon_debug_get(void);

char *mon2name(int md);

#endif  /* _CLIXON_LOG_H_ */
