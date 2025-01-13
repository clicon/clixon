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

 * CALLING ORDER OF YANG PARSE FILES
 *                                      yang_spec_parse_module
 *                                     |                       | 
 *                                     v                       v   v
 * yang_spec_parse_file-> yang_parse_post->yang_parse_recurse->yang_parse_module
 *                    \   /                                         v
 * yang_spec_load_dir ------------------------------------> yang_parse_filename
 *                                                                 v  
 *                                                          yang_parse_file
 *                                                                 v  
 *                                                          yang_parse_str
 */

#ifndef _CLIXON_YANG_PARSE_LIB_H_
#define _CLIXON_YANG_PARSE_LIB_H_

/*
 * Prototypes
 */
int        ys_grouping_resolve(yang_stmt *yuses, char *prefix, char *name, yang_stmt **ygrouping0);
yang_stmt *yang_parse_file(FILE *fp, const char *name, yang_stmt *ysp);
int        yang_file_find_match(clixon_handle h, const char *module, const char *revision, const char *domain, cbuf *fbuf);
yang_stmt *yang_parse_filename(clixon_handle h, const char *filename, yang_stmt  *ysp);
yang_stmt *yang_parse_module(clixon_handle h, const char *module, const char *revision, yang_stmt *yspec, char *domain, char *origname);
int        yang_parse_post(clixon_handle h, yang_stmt *yspec, int modmin);
int        yang_spec_parse_module(clixon_handle h, const char *module,
                                  const char *revision, yang_stmt *yspec);
yang_stmt *yang_parse_str(char *str, const char *name, yang_stmt *yspec);
int        yang_spec_parse_file(clixon_handle h, char *filename, yang_stmt *yspec);
int        yang_spec_load_dir(clixon_handle h, char *dir, yang_stmt *yspec);
int        ys_parse_date_arg(char *datearg, uint32_t *dateint);
cg_var    *ys_parse(yang_stmt *ys, enum cv_type cvtype);
int        ys_parse_sub(yang_stmt *ys, const char *filename, char *extra);
#ifdef OPTIMIZE_YSPEC_NAMESPACE
int        yspec_nscache_clear(yang_stmt *yspec);
yang_stmt *yspec_nscache_get(yang_stmt *yspec, char *ns);
int        yspec_nscache_new(yang_stmt *yspec);
#endif

#endif  /* _CLIXON_YANG_LIB_H_ */
