/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
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

 * HTTP/1.1 parser according to RFC 7230
 */
#ifndef _CLIXON_HTTP1_PARSE_H_
#define _CLIXON_HTTP1_PARSE_H_

/*
 * Types
 */
struct clixon_http1_yacc {
    const char   *hy_name;         /* Name of syntax (for error string) */
    clicon_handle hy_h;            /* Clixon handle */
    restconf_conn *hy_rc;          /* Connection handle */
    int           hy_linenum;      /* Number of \n in parsed buffer */
    char         *hy_parse_string; /* original (copy of) parse string */
    void         *hy_lexbuf;       /* internal parse buffer from lex */
};
typedef struct clixon_http1_yacc clixon_http1_yacc;

/*
 * Variables
 */
extern char *clixon_http1_parsetext;

/*
 * Prototypes
 */
int http1_scan_init(clixon_http1_yacc *);
int http1_scan_exit(clixon_http1_yacc *);

int http1_parse_init(clixon_http1_yacc *);
int http1_parse_exit(clixon_http1_yacc *);

int clixon_http1_parselex(void *);
int clixon_http1_parseparse(void *);
void clixon_http1_parseerror(void *, char*);

#endif  /* _CLIXON_HTTP1_PARSE_H_ */
