/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2025 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
 * XML diff/compare functions
 */

#ifndef _CLIXON_XML_DIFF_H_
#define _CLIXON_XML_DIFF_H_

/*
 * Types
 */
/*! Rebase struct, pointers to existing objects */
struct diff_rebase{
    cxobj  **dr_addparent;  /* Parent to addsub copy of child object */
    cxobj  **dr_addchild;   /* Object to copy */
    size_t   dr_addlen;
    cxobj  **dr_remove;     /* Object to purge */
    size_t   dr_removelen;
    cxobj  **dr_changefrom; /* Object source body (value has changed) */
    cxobj  **dr_changeto;   /* Object destination body */
    size_t   dr_changelen;
};
typedef struct diff_rebase diff_rebase_t;

/*
 * Prototypes
 */
diff_rebase_t *diff_rebase_new(void);
int            diff_rebase_free(diff_rebase_t *dr);
int            diff_rebase_exec(diff_rebase_t *dr);
int            xml_rebase(clixon_handle h, cxobj *x0, cxobj *x1, cxobj *x2,
                          int *conflict, diff_rebase_t *dr);
// XXX Backward compatible for branch privcand
#define xml_rebase_check(h, x0, x1, x2, c) xml_rebase((h), (x0), (x1), (x2), (c), NULL)

#endif  /* _CLIXON_XML_DIFF_H_ */
