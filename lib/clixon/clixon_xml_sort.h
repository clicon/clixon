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

 * XML sort and earch functions when used with YANG
 */
#ifndef _CLIXON_XML_SORT_H
#define _CLIXON_XML_SORT_H

/*
 * Prototypes
 */
int xml_child_spec(cxobj *x, cxobj *xp, yang_stmt *yspec, yang_stmt **yp);
int xml_cmp(cxobj *x1, cxobj *x2, int enm);
int xml_sort(cxobj *x0, void *arg);
int xml_insert(cxobj *xp, cxobj *xc, enum insert_type ins, char *key_val, cvec *nsckey);
int xml_sort_verify(cxobj *x, void *arg);
int match_base_child(cxobj *x0, cxobj *x1c, yang_stmt *yc, cxobj **x0cp);
cxobj *xml_binsearch(cxobj *xp, char *name, char *keyname, char *keyval);

#endif /* _CLIXON_XML_SORT_H */
