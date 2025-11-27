/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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

 * XML sort and earch functions when used with YANG
 */
#ifndef _CLIXON_XML_SORT_H
#define _CLIXON_XML_SORT_H

/*
 * Prototypes
 */
int xml_cmp(cxobj *x1, cxobj *x2, int same, int skip1, const char *expl);
int xml_sort(cxobj *x);
int xml_sort_by(cxobj *x, char *indexvar);
int xml_sort_recurse(cxobj *xn);
int xml_insert(cxobj *xp, cxobj *xc, enum insert_type ins, const char *key_val, cvec *nsckey);
int xml_sort_verify(cxobj *x, void *arg);
#ifdef XML_EXPLICIT_INDEX
int xml_search_indexvar_binary_pos(cxobj *xp, const char *indexvar, clixon_xvec *xvec,
                                   int low, int upper, int max, int *eq);
#endif
int match_base_child(cxobj *x0, cxobj *x1c, yang_stmt *yc, cxobj **x0cp);
int clixon_xml_find_index(cxobj *xp, yang_stmt *yp, const char *ns, const char *name,
                          cvec *cvk, clixon_xvec *xvec);
int clixon_xml_find_pos(cxobj *xp, yang_stmt *yc, uint32_t pos, clixon_xvec *xvec);

#endif /* _CLIXON_XML_SORT_H */
