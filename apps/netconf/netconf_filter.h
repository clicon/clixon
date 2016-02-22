/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 *  netconf match & selection: get and edit operations
 *****************************************************************************/
#ifndef _NETCONF_FILTER_H_
#define _NETCONF_FILTER_H_

/*
 * Prototypes
 */ 
int xml_filter(cxobj *xf, cxobj *xn);
int netconf_xpath(cxobj *xsearch,
		  cxobj *xfilter, 
		  cbuf *xf, cbuf *xf_err, 
		  cxobj *xt);

#endif  /* _NETCONF_FILTER_H_ */
