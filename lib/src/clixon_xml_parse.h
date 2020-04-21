/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC

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

 * XML parser
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208
 */
#ifndef _CLIXON_XML_PARSE_H_
#define _CLIXON_XML_PARSE_H_

/*
 * Types
 */
/*! XML parser yacc handler struct */
struct clixon_xml_parse_yacc {
    char       *xy_parse_string; /* original (copy of) parse string */
    int         xy_linenum;      /* Number of \n in parsed buffer */
    void       *xy_lexbuf;       /* internal parse buffer from lex */
    cxobj      *xy_xtop;         /* cxobj top element (fixed) */
    cxobj      *xy_xelement;     /* cxobj active element (changes with parse context) */
    cxobj      *xy_xparent;      /* cxobj parent element (changes with parse context) */
    yang_stmt  *xy_yspec;        /* If set, top-level yang-spec */
    int         xy_lex_state;    /* lex return state */
    cxobj     **xy_xvec;         /* Vector of created top-level nodes (to know which are created) */
    int         xy_xlen;         /* Length of xy_xvec */
};
typedef struct clixon_xml_parse_yacc clixon_xml_yacc;

extern char *clixon_xml_parsetext;

/*
 * Prototypes
 */
int clixon_xml_parsel_init(clixon_xml_yacc *ya);
int clixon_xml_parsel_exit(clixon_xml_yacc *ya);

int clixon_xml_parsel_linenr(void);
int clixon_xml_parselex(void *);
int clixon_xml_parseparse(void *);

#endif	/* _CLIXON_XML_PARSE_H_ */
