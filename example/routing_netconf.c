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
  along with CLIXON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <unistd.h>
#include <assert.h>
#include <sys/stat.h>
#include <sys/param.h>

#include <cligen/cligen.h>
#include <clicon/clicon.h>
#include <clicon/clicon_netconf.h>


/*
 * Plugin initialization
 */
int
plugin_init(clicon_handle h)
{
    return 0;
}

/*
 * Plugin start
 * Called once everything has been initialized, right before
 * the main event loop is entered.
 */
int
plugin_start(clicon_handle h, int argc, char **argv)
{
    return 0;
}

int
plugin_exit(clicon_handle h)
{
    return 0;
}

