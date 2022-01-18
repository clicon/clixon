/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand

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
  * C-code corresponding to clixon-autocli.yang
 */

#ifndef _CLI_AUTOCLI_H_
#define _CLI_AUTOCLI_H_

/*
 * Types
 */
/*! Autocli operation, see clixon-autocli.yang autocli-op type
 */
enum autocli_op{
    AUTOCLI_OP_ENABLE,
    AUTOCLI_OP_COMPRESS,
};

/*
 * Prototypes
 */
int autocli_module(clicon_handle h, char *modname, int *enable);
int autocli_completion(clicon_handle h, int *completion);
int autocli_list_keyword(clicon_handle h, autocli_listkw_t *listkw);
int autocli_compress(clicon_handle h, yang_stmt *ys, int *compress);
int autocli_treeref_state(clicon_handle h, int *treeref_state);
int autocli_edit_mode(clicon_handle h, char *keyw, int *flag);

#endif  /* _CLI_AUTOCLI_H_ */
