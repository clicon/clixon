/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

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
int xml2json_cbuf(cbuf *cb, cxobj *x, int level);
int xml2json(FILE *f, cxobj *x, int level);
int xml_yang_validate(cxobj *xt, yang_stmt *ys) ;
int xml2cvec(cxobj *xt, yang_stmt *ys, cvec **cvv0);
int cvec2xml_1(cvec *cvv, char *toptag, cxobj *xp, cxobj **xt0);
int xml_diff(yang_spec *yspec, cxobj *xt1, cxobj *xt2, 	 
	     cxobj ***first, size_t *firstlen, 
	     cxobj ***second, size_t *secondlen, 
	     cxobj ***changed1, cxobj ***changed2, size_t *changedlen);

#endif  /* _CLIXON_XML_MAP_H_ */
