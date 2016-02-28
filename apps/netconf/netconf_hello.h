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
 *  Code for handling netconf hello messages
 *****************************************************************************/
#ifndef _NETCONF_HELLO_H_
#define _NETCONF_HELLO_H_

/*
 * Prototypes
 */ 
int netconf_create_hello(cbuf *xf, int session_id);

int netconf_hello_dispatch(cxobj *xn);

#endif  /* _NETCONF_HELLO_H_ */
