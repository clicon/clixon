/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * Yang module and feature handling
 * @see https://tools.ietf.org/html/rfc7895
 */

#ifndef _CLIXON_YANG_MODULE_H_
#define _CLIXON_YANG_MODULE_H_

/*
 * Constants
 */

/*
 * Types
 */

/*! Struct containing module state differences between two modules or two
 *
 * revisions of same module.
 * The most significant usecase is one module-state is a loaded datastore and the other
 * is the one loaded by the server by its YANG files.
 */
typedef struct {
    int    md_status;     /* 0 if no module-state in a datastore, 1 if there is */
    char  *md_content_id; /* server-specific identifier (previously md_set_id) */
    cxobj *md_diff;       /* yang module state containing revisions and XML_FLAG_ADD|DEL|CHANGE */
    cxobj *md_xmodfile;   /* XXX probably unneccesary */
} modstate_diff_t;

/*
 * Prototypes
 */
modstate_diff_t * modstate_diff_new(void);
int modstate_diff_free(modstate_diff_t *);

int yang_modules_init(clixon_handle h);
char *yang_modules_revision(clixon_handle h);
int yang_modules_state_build(clixon_handle h, yang_stmt *yspec, const char *msid, int brief, cbuf *cb);
int yang_modules_state_get(clixon_handle h, yang_stmt *yspec, const char *xpath,
                           cvec *nsc, int brief, cxobj **xret);
int clixon_module_upgrade(clixon_handle h, cxobj *xt, modstate_diff_t *msd, cbuf *cb);
yang_stmt *yang_find_module_by_prefix(yang_stmt *ys, const char *prefix);
yang_stmt *yang_find_module_by_prefix_yspec(yang_stmt *yspec, const char *prefix);
yang_stmt *yang_find_module_by_namespace(yang_stmt *yspec, const char *ns);
yang_stmt *yang_find_module_by_namespace_revision(yang_stmt *yspec, const char *ns, const char *revision);
yang_stmt *yang_find_module_by_name_revision(yang_stmt *yspec, const char *name, const char *revision);
yang_stmt *yang_find_module_by_name(yang_stmt *yspec, const char *name);
int        yang_metadata_annotation_check(cxobj *x, yang_stmt *ymod, int *ismeta);
int        yang_metadata_init(clixon_handle h);
int        yang_lib2yspec(clixon_handle h, cxobj *yanglib, const char *mntpnt, const char *domain, yang_stmt *yspec);
int        yang_imports_foreach_scope(yang_stmt *ys, yang_stmt *yspec,
                                      int (*cb)(yang_stmt *yimport, void *arg),
                                      void *arg);

#endif  /* _CLIXON_YANG_MODULE_H_ */
