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

#ifndef _CLIXON_AUTOCLI_H_
#define _CLIXON_AUTOCLI_H_

/*
 * Types
 */
/*! Autocli list keyword type, see clixon-autocli.yang list-keyword-type
 *
 * Assume a YANG LIST: 
 *    list a {
 *       key x;
 *       leaf x;
 *       leaf y;
 *    }
 * Maybe this type should be in cli_autocli.h
 */
enum autocli_listkw{
    AUTOCLI_LISTKW_NONE,  /* No extra keywords, only <vars>: a <x> <y> */
    AUTOCLI_LISTKW_NOKEY, /* Keywords on non-key variables: a <x> y <y> */
    AUTOCLI_LISTKW_ALL,   /* Keywords on all variables: a x <x> y <y> */
};
typedef enum autocli_listkw autocli_listkw_t;

/*! Autocli operation, see clixon-autocli.yang autocli-op type
 */
enum autocli_op{
    AUTOCLI_OP_ENABLE,
    AUTOCLI_OP_DISABLE,
    AUTOCLI_OP_COMPRESS,
};

/* See clixon-autocli.yang cache-type */
enum autocli_cache{
    AUTOCLI_CACHE_DISABLED, /* Do not use cache  */
    AUTOCLI_CACHE_READ,     /* If clispec file exists read from cache, if not found generate */
};
typedef enum autocli_cache autocli_cache_t;

/*
 * Prototypes
 */
int autocli_module(clixon_handle h, const char *modname, int *enable);
int autocli_completion(clixon_handle h, int *completion);
int autocli_grouping_treeref(clixon_handle h, int *grouping_treeref);
int autocli_list_keyword(clixon_handle h, autocli_listkw_t *listkw);
int autocli_compress(clixon_handle h, yang_stmt *ys, int *compress);
int autocli_treeref_state(clixon_handle h, int *treeref_state);
int autocli_edit_mode(clixon_handle h, const char *keyw, int *flag);
int autocli_cache(clixon_handle h, autocli_cache_t *type, char **dir);


#endif  /* _CLIXON_AUTOCLI_H_ */
