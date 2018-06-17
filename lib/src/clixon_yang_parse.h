/*
 * Yang 1.0 parser according to RFC6020.
 * It is hopefully useful but not complete
 * RFC7950 defines Yang version 1.1
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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

 * Yang parser. Hopefully useful but not complete
 * @see https://tools.ietf.org/html/rfc6020 YANG 1.0
 * @see https://tools.ietf.org/html/rfc7950 YANG 1.1
 */
#ifndef _CLIXON_YANG_PARSE_H_
#define _CLIXON_YANG_PARSE_H_

/*
 * Types
 */

struct ys_stack{
    struct ys_stack    *ys_next;
    struct yang_node   *ys_node;
};

struct clicon_yang_yacc_arg{ /* XXX: mostly unrelevant */
    char                 *yy_name;         /* Name of syntax (for error string) */
    int                   yy_linenum;      /* Number of \n in parsed buffer */
    char                 *yy_parse_string; /* original (copy of) parse string */
    void                 *yy_lexbuf;       /* internal parse buffer from lex */
    struct ys_stack      *yy_stack;     /* Stack of levels: push/pop on () and [] */
    int                   yy_lex_state;  /* lex start condition (ESCAPE/COMMENT) */
    int                   yy_lex_string_state; /* lex start condition (STRING) */
    yang_stmt            *yy_module;       /* top-level (sub)module - return value of 
					      parser */
};

/* This is a malloced piece of code we attach to cligen objects used as db-specs.
 * So if(when) we translate cg_obj to yang_obj (or something). These are the fields
 * we should add.
 */
struct yang_userdata{
    char             *du_indexvar;  /* (clicon) This command is a list and
				       this string is the key/index of the list 
				    */
    char             *du_yang;    /* (clicon) Save yang key for cli 
				       generation */
    int               du_optional; /* (clicon) Optional element in list */
    struct cg_var    *du_default;   /* default value(clicon) */
    char              du_vector;    /* (clicon) Possibly more than one element */
};

/*
 * Variables
 */
extern char *clixon_yang_parsetext;

/*
 * Prototypes
 */
int yang_scan_init(struct clicon_yang_yacc_arg *ya);
int yang_scan_exit(struct clicon_yang_yacc_arg *ya);

int yang_parse_init(struct clicon_yang_yacc_arg *ya, yang_spec *ysp);
int yang_parse_exit(struct clicon_yang_yacc_arg *ya);

int clixon_yang_parselex(void *_ya);
int clixon_yang_parseparse(void *);
void clixon_yang_parseerror(void *_ya, char*);

int ystack_pop(struct clicon_yang_yacc_arg *ya);
struct ys_stack *ystack_push(struct clicon_yang_yacc_arg *ya, yang_node *yn);

#endif	/* _CLIXON_YANG_PARSE_H_ */
