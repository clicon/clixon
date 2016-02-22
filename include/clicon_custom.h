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

  Custom file as boilerplate appended by clicon_config.h 
  */

#ifndef HAVE_STRNDUP 
#define strndup(s, n) clicon_strndup(s, n)
#endif

#if defined(__OpenBSD__) || defined(__FreeBSD__) ||  defined(__NetBSD__)
#define BSD
/* at least for openbsd 4.5 i cannot get a hdr file */
int strverscmp (__const char *__s1, __const char *__s2);
#endif

