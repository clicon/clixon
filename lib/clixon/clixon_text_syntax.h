/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * TEXT / curly-brace syntax parsing and translations
 */
#ifndef _CLIXON_TEXT_SYNTAX_H
#define _CLIXON_TEXT_SYNTAX_H

/*
 * Prototypes
 */
int clixon_text2file(FILE *f, cxobj *xn, int level, clicon_output_cb *fn, int skiptop, int autocliext);
int clixon_text2cbuf(cbuf *cb, cxobj *xn, int level, int skiptop, int autocliext);
int clixon_text_diff2cbuf(cbuf *cb, cxobj *x0, cxobj *x1);
int clixon_text_syntax_parse_string(const char *str, yang_bind yb, yang_stmt *yspec, cxobj **xt, cxobj **xerr);
int clixon_text_syntax_parse_file(FILE *fp, yang_bind yb, yang_stmt *yspec, cxobj **xt, cxobj **xerr);

#endif /* _CLIXON_TEXT_SYNTAX_H */
