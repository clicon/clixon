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

#include "clixon_xml.h"			/* for cxobj */

/*
 * Constants
 */
/*! Log destination as bitfields (masks)
 *
 * @see logdstmap Symbolic mapping (if you change here you may need to change logdstmap)
 * @see also log_desination_t in clixon-config.yang
 */
#define CLIXON_LOG_SYSLOG 0x01 /* print logs on syslog */
#define CLIXON_LOG_STDERR 0x02 /* print logs on stderr */
#define CLIXON_LOG_STDOUT 0x04 /* print logs on stdout */
#define CLIXON_LOG_FILE   0x08 /* print logs on clixon_log_file() */

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

// COMPAT_7_1
#define clixon_get_logflags() clixon_logflags_get()

/*
 * Prototypes
 */
const char *clixon_logdst_key2str(int keyword);
int      clixon_logdst_str2key(const char *str);
int      clixon_log_init(clixon_handle h, const char *ident, int upto, uint16_t flags);
int      clixon_log_exit(void);
int      clixon_log_opt(char c);
int      clixon_log_file(const char *filename);
int      clixon_log_string_limit_set(size_t sz);
size_t   clixon_log_string_limit_get(void);
uint16_t clixon_logflags_get(void);
int      clixon_logflags_set(uint16_t flags);
int      clixon_log_str(int level, char *msg);
int      clixon_log_fn(clixon_handle h, int user, int level, cxobj *x, const char *format, ...) __attribute__ ((format (printf, 5, 6)));

#endif  /* _CLIXON_LOG_H_ */
