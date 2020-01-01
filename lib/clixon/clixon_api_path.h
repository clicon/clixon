/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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
 * "api-path" is "URI-encoded path expression" definition in RFC8040 3.5.3
 * BNF:
 *  <api-path>       := <root> ("/" (<api-identifier> | <list-instance>))*
 *  <root>           := <string>
 *  <api-identifier> := [<module-name> ":"] <identifier>
 *  <module-name>    := <identifier>
 *  <list-instance>  := <api-identifier> "=" key-value *("," key-value)
 *  <key-value>      := <string>
 *  <string>         := <an unquoted string>
 *  <identifier>     := (<ALPHA> | "_") (<ALPHA> | <DIGIT> | "_" | "-" | ".")
 */

#ifndef _CLIXON_API_PATH_H_
#define _CLIXON_API_PATH_H_

/*
 * Prototypes
 */
int xml_yang_root(cxobj *x, cxobj **xr);
int yang2api_path_fmt(yang_stmt *ys, int inclkey, char **api_path_fmt);
int api_path_fmt2api_path(char *api_path_fmt, cvec *cvv, char **api_path);
int api_path_fmt2xpath(char *api_path_fmt, cvec *cvv, char **xpath);
int api_path2xpath_cvv(cvec *api_path, int offset, yang_stmt *yspec, cbuf *xpath, cvec **nsc, cxobj **xerr);
int api_path2xpath(char *api_path, yang_stmt *yspec, char **xpath, cvec **nsc);
int api_path2xml(char *api_path, yang_stmt *yspec, cxobj *xtop, 
		 yang_class nodeclass, int strict,
		 cxobj **xpathp, yang_stmt **ypathp, cxobj **xerr);
int xml2api_path_1(cxobj *x, cbuf *cb);

#endif  /* _CLIXON_API_PATH_H_ */
