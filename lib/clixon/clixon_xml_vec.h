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

 * Clixon XML object vectors
 */
#ifndef _CLIXON_XML_VEC_H
#define _CLIXON_XML_VEC_H

/*
 * Types
 */
typedef struct clixon_xml_vec clixon_xvec; /* struct defined in clicon_xml_vec.c */

/*
 * Prototypes
 */
clixon_xvec *clixon_xvec_new(void);
clixon_xvec *clixon_xvec_dup(clixon_xvec *xv0);
int          clixon_xvec_free(clixon_xvec *xv);
int          clixon_xvec_len(clixon_xvec *xv);
cxobj       *clixon_xvec_i(clixon_xvec *xv, int i);
int          clixon_xvec_extract(clixon_xvec *xv, cxobj ***xvcec, int *xlen, int *xmax);
int          clixon_xvec_append(clixon_xvec *xv, cxobj *x);
int          clixon_xvec_prepend(clixon_xvec *xv, cxobj *x);
int          clixon_xvec_merge(clixon_xvec *xv0, clixon_xvec *xv1);
int          clixon_xvec_insert_pos(clixon_xvec *xv, cxobj *x, int i);
int          clixon_xvec_rm_pos(clixon_xvec *xv, int i);
int          clixon_xvec_print(FILE *f, clixon_xvec *xv);

#endif /* _CLIXON_XML_VEC_H */
