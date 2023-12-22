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
 * Regular logging, syslog using levels.
 */

#ifndef _CLIXON_LOG_H_
#define _CLIXON_LOG_H_

/*
 * Constants
 */
/* Where to log (masks) */
#define CLIXON_LOG_SYSLOG 1 /* print logs on syslog */
#define CLIXON_LOG_STDERR 2 /* print logs on stderr */
#define CLIXON_LOG_STDOUT 4 /* print logs on stdout */
#define CLIXON_LOG_FILE   8 /* print logs on clicon_log_filename */

/* What kind of log (only for customizable error/logs) */
enum clixon_log_type{
    LOG_TYPE_LOG,
    LOG_TYPE_ERR,
    LOG_TYPE_DEBUG
};

/*
 * Macros
 */
#define clixon_log(h, l, _fmt, args...) clixon_log_fn((h), 1, (l), NULL, _fmt , ##args)
#define clixon_log_xml(h, l, x, _fmt, args...) clixon_log_fn((h), 1, (l), x, _fmt , ##args)

/*
 * Prototypes
 */
int clixon_log_init(clixon_handle h, char *ident, int upto, int flags);
int clixon_log_exit(void);
int clixon_log_opt(char c);
int clixon_log_file(char *filename);
int clixon_log_string_limit_set(size_t sz);
size_t clixon_log_string_limit_get(void);
int clixon_get_logflags(void);
int clixon_log_str(int level, char *msg);
int clixon_log_fn(clixon_handle h, int user, int level, cxobj *x, const char *format, ...) __attribute__ ((format (printf, 5, 6)));

#if 1 /* COMPAT_6_5 */
#define CLICON_LOG_SYSLOG CLIXON_LOG_SYSLOG
#define CLICON_LOG_STDERR CLIXON_LOG_STDERR
#define CLICON_LOG_STDOUT CLIXON_LOG_STDOUT
#define CLICON_LOG_FILE   CLIXON_LOG_FILE

#define clicon_log(l, f, args...) clixon_log(NULL, (l), (f), ##args)
#define clicon_log_exit() clixon_log_exit()
#define clicon_log_opt(c) clixon_log_opt((c))
#define clicon_log_file(f) clixon_log_file((f)) 

int clicon_log_init(char *ident, int upto, int flags);

#endif /* COMPAT_6_5 */

#endif  /* _CLIXON_LOG_H_ */
