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
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 */

#ifndef _CLI_COMMON_H_
#define _CLI_COMMON_H_

void cli_signal_block(clicon_handle h);
void cli_signal_unblock(clicon_handle h);

/* If you do not find a function here it may be in clicon_cli_api.h which is 
   the external API */

#endif /* _CLI_COMMON_H_ */
