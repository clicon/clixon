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
 * Clixon debugging
 */

#ifndef _CLIXON_DEBUG_H_
#define _CLIXON_DEBUG_H_

#include "clixon_xml.h"			/* for cxobj */

/*
 * Constants
 */

/* Debug-level masks */
#define CLIXON_DBG_DEFAULT 1 /* Default logs */
#define CLIXON_DBG_MSG     2 /* In/out messages and datastore reads */
#define CLIXON_DBG_DETAIL  4 /* Details: traces, parse trees, etc */
#define CLIXON_DBG_EXTRA   8 /* Extra Detailed logs */

/*
 * Macros
 */
#define clixon_debug(l, _fmt, args...) clixon_debug_fn(NULL, (l), NULL, _fmt , ##args)
#define clixon_debug_xml(l, x, _fmt, args...) clixon_debug_fn(NULL, (l), (x), _fmt , ##args)

/*
 * Prototypes
 */
int clixon_debug_init(clixon_handle h, int dbglevel);
int clixon_debug_get(void);
int clixon_debug_fn(clixon_handle h, int dbglevel, cxobj *x, const char *format, ...) __attribute__ ((format (printf, 4, 5)));

#endif  /* _CLIXON_DEBUG_H_ */
