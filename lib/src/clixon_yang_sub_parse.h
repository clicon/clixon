/*
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

 * Sub-parsers to upper-level YANG parser: everything that is "stringified"
 */
#ifndef _CLIXON_YANG_SUB_PARSE_H_
#define _CLIXON_YANG_SUB_PARSE_H_

/*
 * Types
 */
/*! Sub-parse rule to accept */
enum yang_sub_parse_accept{
    YA_IF_FEATURE,
    YA_ID_REF,
    YA_ABS_SCHEMANODEID,
    YA_DESC_SCHEMANODEID
};

/*! XML parser yacc handler struct */
struct clixon_yang_sub_parse_yacc {
    char       *if_parse_string; /* original (copy of) parse string */
    const char *if_mainfile;     /* Original main-file (this is a sib-parser) */
    int         if_linenum;      /* Number of \n in parsed buffer (in mainfile) */
    void      *if_lexbuf;       /* Internal parse buffer from lex */
    yang_stmt *if_ys;           /* Yang statement, NULL if no check */
    enum yang_sub_parse_accept if_accept; /* Which sub-parse rule to accept */ 
    int         if_enabled;      /* Result: 0: feature disabled, 1: enabled */
};
typedef struct clixon_yang_sub_parse_yacc clixon_yang_sub_parse_yacc;

/*
 * Variables
 */
extern char *clixon_yang_sub_parsetext;

/*
 * Prototypes
 */
int clixon_yang_sub_parsel_init(clixon_yang_sub_parse_yacc *ya);
int clixon_yang_sub_parsel_exit(clixon_yang_sub_parse_yacc *ya);
int clixon_yang_sub_parsel_linenr(void);
int clixon_yang_sub_parselex(void *);
int clixon_yang_sub_parseparse(void *);

int  yang_subparse(char *str, yang_stmt *ys, enum yang_sub_parse_accept accept, const char *mainfile, int linenum, int *enabled);
int  yang_schema_nodeid_subparse(char *str, enum yang_sub_parse_accept accept, const char *mainfile, int linenum);

#endif	/* _CLIXON_YANG_SUB_PARSER_H_ */
