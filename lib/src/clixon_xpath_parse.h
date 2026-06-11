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

 * Clixon XML XPath 1.0 according to https://www.w3.org/TR/xpath-10
 */
#ifndef _CLIXON_XPATH_PARSE_H_
#define _CLIXON_XPATH_PARSE_H_

/*
 * Types
 */
#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void *yyscan_t;
#endif

struct clixon_xpath_yacc{
    const char *xpy_name;             /* Name of syntax (for error string) */
    int         xpy_linenum;          /* Number of \n in parsed buffer */
    const char *xpy_parse_string;     /* Original (copy of) parse string */
    int         xpy_lex_string_state; /* Lex start condition (STRING) */
    void       *xpy_lexbuf;           /* Internal parse buffer from lex */
    yyscan_t    xpy_scanner;          /* Reentrant flex scanner handle */
    xpath_tree *xpy_top;
};
typedef struct clixon_xpath_yacc clixon_xpath_yacc;

/*
 * Variables
 */

/*
 * Prototypes
 */
union YYSTYPE;
int   xpath_scan_init(clixon_xpath_yacc *xy);
int   xpath_scan_exit(clixon_xpath_yacc *xy);
int   xpath_parse_init(clixon_xpath_yacc *xy);
int   xpath_parse_exit(clixon_xpath_yacc *xy);
char *clixon_xpath_parseget_text(yyscan_t yyscanner);
int   clixon_xpath_parselex(union YYSTYPE *yylval, yyscan_t yyscanner);
int   clixon_xpath_parseparse(void *, yyscan_t);
void  clixon_xpath_parseerror(void *, yyscan_t, char*);

#endif  /* _CLIXON_XPATH_PARSE_H_ */
