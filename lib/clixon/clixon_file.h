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

 */

#ifndef _CLIXON_FILE_H_
#define _CLIXON_FILE_H_


char **clicon_realpath(const char *cwd, char *path, const char *label);

int clicon_file_dirent(const char *dir, struct dirent **ent, 
		    const char *regexp, mode_t type, const char *label);

char *clicon_tmpfile(const char *label);

int file_cp(char *src, char *target);

#endif /* _CLIXON_FILE_H_ */
