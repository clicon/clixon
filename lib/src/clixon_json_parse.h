/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 */
#ifndef _CLIXON_JSON_PARSE_H_
#define _CLIXON_JSON_PARSE_H_

/*
 * Types
 */

#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void *yyscan_t;
#endif

struct clixon_json_yacc {
    int         jy_linenum;      /* Number of \n in parsed buffer */
    const char *jy_parse_string; /* original (copy of) parse string */
    void       *jy_lexbuf;       /* internal parse buffer from lex */
    yyscan_t    jy_scanner;      /* reentrant flex scanner handle */
    cxobj      *jy_xtop;         /* cxobj top element (fixed) */
    cxobj      *jy_current;      /* cxobj active element (changes with parse context) */
    cxobj     **jy_xvec;         /* Vector of created top-level nodes (to know which are created) */
    size_t      jy_xlen;         /* Length of jy_xvec */
    cbuf       *jy_cbuf_str;     /* cbuf used for strings, if error needs to be deallocated */
};
typedef struct clixon_json_yacc clixon_json_yacc;

/*
 * Variables
 */

/*
 * Prototypes
 */
union YYSTYPE;
int   json_scan_init(clixon_json_yacc *jy);
int   json_scan_exit(clixon_json_yacc *jy);
int   json_parse_init(clixon_json_yacc *jy);
int   json_parse_exit(clixon_json_yacc *jy);
char *clixon_json_parseget_text(yyscan_t yyscanner);
char *clixon_json_parseget_text(yyscan_t yyscanner);
int   clixon_json_parselex(union YYSTYPE *yylval, yyscan_t yyscanner);
int   clixon_json_parseparse(void *, yyscan_t);
void  clixon_json_parseerror(void *, yyscan_t, char*);

#endif  /* _CLIXON_JSON_PARSE_H_ */
