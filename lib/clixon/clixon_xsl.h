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

 * XML XPATH and XSLT functions.
 */
#ifndef _CLIXON_XSL_H
#define _CLIXON_XSL_H

/*
 * Prototypes
 */
cxobj *xpath_first(cxobj *xn_top, char *xpath);
cxobj *xpath_each(cxobj *xn_top, char *xpath, cxobj *prev);
int xpath_vec(cxobj *xn_top, char *xpath, cxobj ***vec, size_t *xv_len);
int xpath_vec_flag(cxobj *cxtop, char *xpath, uint16_t flags, 
		   cxobj ***vec, size_t *veclen);

#endif /* _CLIXON_XSL_H */
