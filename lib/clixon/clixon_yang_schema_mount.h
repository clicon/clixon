/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2023 Olof Hagsand

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

 */

#ifndef _CLIXON_YANG_SCHEMA_MOUNT_H_
#define _CLIXON_YANG_SCHEMA_MOUNT_H_

/*
 * Constants
 */

/* RFC 8528 YANG Schema Mount
 */
#define YANG_SCHEMA_MOUNT_NAMESPACE "urn:ietf:params:xml:ns:yang:ietf-yang-schema-mount"

/*
 * Prototypes
 */
int yang_schema_mount_point(yang_stmt *y);

int schema_mounts_state_get(clicon_handle h, yang_stmt *yspec, char *xpath, cvec *nsc, cxobj **xret, cxobj **xerr);
int yang_schema_unknown(clicon_handle h, yang_stmt *yext, yang_stmt *ys);

#endif  /* _CLIXON_YANG_SCHEMA_MOUNT_H_ */
