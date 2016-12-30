/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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
 * XML code
 */

#ifndef _CLIXON_XML_MAP_H_
#define _CLIXON_XML_MAP_H_

/*
 * lvmap_xml op codes
 */
enum {
    LVXML,       /* a.b{x=1} -> <a><b>1 */
    LVXML_VAL,       /* a.b{x=1} -> <a><b><x>1 */
    LVXML_VECVAL,   /* key: a.b.0{x=1} -> <a><b><x>1</x></b></a> och */
    LVXML_VECVAL2,  /* key: a.b.0{x=1} -> <a><x>1</x></a> och */
};


/*
 * Prototypes
 */
int xml2txt(FILE *f, cxobj *x, int level);
int xml2cli(FILE *f, cxobj *x, char *prepend, enum genmodel_type gt, const char *label);
int xml_yang_validate(cxobj *xt, yang_stmt *ys) ;
int xml2cvec(cxobj *xt, yang_stmt *ys, cvec **cvv0);
int cvec2xml_1(cvec *cvv, char *toptag, cxobj *xp, cxobj **xt0);
int xml_diff(yang_spec *yspec, cxobj *xt1, cxobj *xt2, 	 
	     cxobj ***first, size_t *firstlen, 
	     cxobj ***second, size_t *secondlen, 
	     cxobj ***changed1, cxobj ***changed2, size_t *changedlen);

#endif  /* _CLIXON_XML_MAP_H_ */
