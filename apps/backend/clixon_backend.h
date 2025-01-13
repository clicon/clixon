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
 * The exported interface to plugins. External apps (eg backend plugins) should
 * only include this file.
 * Internal code should not include this file
 */
#ifdef __cplusplus
extern "C" {
#endif
#ifndef _CLIXON_BACKEND_H_
#define _CLIXON_BACKEND_H_

/*
 * Use this constant to disable some prototypes that should not be visible outside the lib.
 * This is an alternative to use separate internal include files.
 */

/* Common code (API and Backend daemon) */
#include <clixon/clixon_backend_client.h>
#include <clixon/clixon_backend_transaction.h>
#include <clixon/clixon_backend_commit.h>
#include <clixon/clixon_backend_plugin.h>

#endif /* _CLIXON_BACKEND_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif
