/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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
 */

#ifndef _CLI_HANDLE_H_
#define _CLI_HANDLE_H_

/*
 * Prototypes 
 * Internal prototypes. For exported functions see clixon_cli_api.h
 */
int cli_parse_file(clicon_handle h,
		   FILE *f,
		   char *name, /* just for errs */
		   parse_tree *pt,
		   cvec *globals);

int cli_susp_hook(clicon_handle h, cligen_susp_cb_t *fn);

int cli_interrupt_hook(clicon_handle h, cligen_interrupt_cb_t *fn);

char *cli_nomatch(clicon_handle h);

int cli_prompt_set(clicon_handle h, char *prompt);

int cli_logsyntax_set(clicon_handle h, int status);

/* Internal functions for handling cli groups */
cli_syntax_t *cli_syntax(clicon_handle h);

int cli_syntax_set(clicon_handle h, cli_syntax_t *stx);

#endif  /* _CLI_HANDLE_H_ */
