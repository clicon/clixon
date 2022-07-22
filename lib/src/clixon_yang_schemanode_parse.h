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

 * decendant-schema-nodeid RFC7950 14
 */
#ifndef _CLIXON_YANG_SCHEMANODE_PARSE_H_
#define _CLIXON_YANG_SCHEMANODE_PARSE_H_

/*
 * Types
 */
/*! XML parser yacc handler struct */
struct clixon_yang_schemanode_parse_yacc {
    char      *if_parse_string; /* original (copy of) parse string */
    const char *if_mainfile;     /* Original main-file (this is a sib-parser) */
    int        if_linenum;      /* Number of \n in parsed buffer */
    void      *if_lexbuf;       /* Internal parse buffer from lex */
    yang_stmt *if_ys;           /* Yang statement, NULL if no check */
    enum yang_sub_parse_accept if_accept;
};
typedef struct clixon_yang_schemanode_parse_yacc clixon_yang_schemanode_yacc;

/*
 * Variables
 */
extern char *clixon_yang_schemanode_parsetext;

/*
 * Prototypes
 */
int clixon_yang_schemanode_parsel_init(clixon_yang_schemanode_yacc *ya);
int clixon_yang_schemanode_parsel_exit(clixon_yang_schemanode_yacc *ya);
int clixon_yang_schemanode_parsel_linenr(void);
int clixon_yang_schemanode_parselex(void *);
int clixon_yang_schemanode_parseparse(void *);

#endif	/* _CLIXON_YANG_SCHEMANODE_PARSE_H_ */
