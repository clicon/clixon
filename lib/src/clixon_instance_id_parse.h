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

 * "instance-id" is a subset of XPath and defined in RF7950 Sections 9.13 and 14. 
 */
#ifndef _CLIXON_INSTANCE_ID_PARSE_H_
#define _CLIXON_INSTANCE_ID_PARSE_H_

/*
 * Types
 */
struct clixon_instance_id_yacc {
    const char   *iy_name;         /* Name of syntax (for error string) */
    int           iy_linenum;      /* Number of \n in parsed buffer */
    char         *iy_parse_string; /* original (copy of) parse string */
    void         *iy_lexbuf;       /* internal parse buffer from lex */
    clixon_path  *iy_top;
    int           iy_lex_state;    /* lex return state */
};
typedef struct clixon_instance_id_yacc clixon_instance_id_yacc;

/*
 * Variables
 */
extern char *clixon_instance_id_parsetext;

/*
 * Prototypes
 */
int instance_id_scan_init(clixon_instance_id_yacc *);
int instance_id_scan_exit(clixon_instance_id_yacc *);

int instance_id_parse_init(clixon_instance_id_yacc *);
int instance_id_parse_exit(clixon_instance_id_yacc *);

int clixon_instance_id_parselex(void *);
int clixon_instance_id_parseparse(void *);
void clixon_instance_id_parseerror(void *, char*);

#endif  /* _CLIXON_INSTANCE_ID_PARSE_H_ */
