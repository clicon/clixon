/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 */
#ifndef _CLIXON_JSON_PARSE_H_
#define _CLIXON_JSON_PARSE_H_

/*
 * Types
 */

struct clicon_json_yacc_arg{ /* XXX: mostly unrelevant */
    const char           *jy_name;         /* Name of syntax (for error string) */
    int                   jy_linenum;      /* Number of \n in parsed buffer */
    char                 *jy_parse_string; /* original (copy of) parse string */
    void                 *jy_lexbuf;       /* internal parse buffer from lex */
    cxobj                *jy_current;
};

/*
 * Variables
 */
extern char *clixon_json_parsetext;

/*
 * Prototypes
 */
int json_scan_init(struct clicon_json_yacc_arg *jy);
int json_scan_exit(struct clicon_json_yacc_arg *jy);

int json_parse_init(struct clicon_json_yacc_arg *jy);
int json_parse_exit(struct clicon_json_yacc_arg *jy);

int clixon_json_parselex(void *);
int clixon_json_parseparse(void *);
void clixon_json_parseerror(void *, char*);

#endif	/* _CLIXON_JSON_PARSE_H_ */
