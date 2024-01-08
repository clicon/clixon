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

/* Limitations/deviations from RFC 8528 */
/*! Only support YANG presende containers as mount-points
 *
 * This is a limitation of othe current implementation
 */
#define YANG_SCHEMA_MOUNT_ONLY_PRESENCE_CONTAINERS

/*
 * Prototypes
 */
int yang_schema_mount_point0(yang_stmt *y);
int yang_schema_mount_point(yang_stmt *y);
int yang_mount_get(yang_stmt *yu, char *xpath, yang_stmt **yspec);
int yang_mount_set(yang_stmt *yu, char *xpath, yang_stmt *yspec);
int xml_yang_mount_get(clixon_handle h, cxobj *x, validate_level *vl, yang_stmt **yspec);
int xml_yang_mount_set(clixon_handle h, cxobj *x,  yang_stmt *yspec);
int yang_mount_get_yspec_any(yang_stmt *y, yang_stmt **yspec);
int yang_mount_freeall(cvec *cvv);
int yang_schema_mount_statedata(clixon_handle h, yang_stmt *yspec, char *xpath, cvec *nsc, cxobj **xret, cxobj **xerr);
int yang_schema_mount_statistics(clixon_handle h, cxobj *xt, int modules, cbuf *cb);
int yang_schema_yanglib_parse_mount(clixon_handle h, cxobj *xt);
int yang_schema_get_child(clixon_handle h, cxobj *x1, cxobj *x1c, yang_stmt **yc);

#endif  /* _CLIXON_YANG_SCHEMA_MOUNT_H_ */
