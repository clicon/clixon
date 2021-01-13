/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * "api-path" is "URI-encoded path expression" definition in RFC8040 3.5.3
 */
#ifndef _CLIXON_API_PATH_PARSE_H_
#define _CLIXON_API_PATH_PARSE_H_

/*
 * Types
 */
struct clixon_api_path_yacc { 
    const char   *ay_name;         /* Name of syntax (for error string) */
    int           ay_linenum;      /* Number of \n in parsed buffer */
    char         *ay_parse_string; /* original (copy of) parse string */
    void         *ay_lexbuf;       /* internal parse buffer from lex */
    clixon_path  *ay_top;
};
typedef struct clixon_api_path_yacc clixon_api_path_yacc;

/*
 * Variables
 */
extern char *clixon_api_path_parsetext;

/*
 * Prototypes
 */
int api_path_scan_init(clixon_api_path_yacc *);
int api_path_scan_exit(clixon_api_path_yacc *);

int api_path_parse_init(clixon_api_path_yacc *);
int api_path_parse_exit(clixon_api_path_yacc *);

int clixon_api_path_parselex(void *);
int clixon_api_path_parseparse(void *);
void clixon_api_path_parseerror(void *, char*);

#endif	/* _CLIXON_API_PATH_PARSE_H_ */
