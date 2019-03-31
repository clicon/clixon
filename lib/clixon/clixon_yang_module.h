/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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

/* Struct contataining module state differences between two modules or two 
 * revisions of same module. 
 * This is in state of flux so it needss to be conatained and easily changed.
 */
typedef struct {
    cxobj *md_del;   /* yang module state deletes */
    cxobj *md_mod;   /* yang module state modifications */
} modstate_diff_t;

/*
 * Prototypes
 */
modstate_diff_t * modstate_diff_new(void);
int modstate_diff_free(modstate_diff_t *);

int yang_modules_init(clicon_handle h);
char *yang_modules_revision(clicon_handle h);

int yang_modules_state_get(clicon_handle h, yang_spec *yspec, char *xpath,
			   int brief, cxobj **xret);

int clixon_module_upgrade(clicon_handle h, cxobj *xt, modstate_diff_t *msd, cbuf *cb);

#endif  /* _CLIXON_YANG_MODULE_H_ */
