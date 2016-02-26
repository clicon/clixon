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

#ifndef _CLI_HANDLE_H_
#define _CLI_HANDLE_H_

/*
 * Prototypes 
 * Internal prototypes. For exported functions see clicon_cli_api.h
 */
char cli_tree_add(clicon_handle h, char *tree, parse_tree pt);

int cli_parse_file(clicon_handle h,
		   FILE *f,
		   char *name, /* just for errs */
		   parse_tree *pt,
		   cvec *globals);

char *cli_tree_active(clicon_handle h);

int cli_tree_active_set(clicon_handle h, char *treename);

parse_tree *cli_tree(clicon_handle h, char *name);

int cli_susp_hook(clicon_handle h, cli_susphook_t *fn);

char *cli_nomatch(clicon_handle h);

int cli_prompt_set(clicon_handle h, char *prompt);

int cli_logsyntax_set(clicon_handle h, int status);

/* Internal functions for handling cli groups */

cli_syntax_t *cli_syntax(clicon_handle h);
int cli_syntax_set(clicon_handle h, cli_syntax_t *stx);

#endif  /* _CLI_HANDLE_H_ */
