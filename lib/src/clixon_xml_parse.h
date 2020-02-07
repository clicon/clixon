/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2020 Olof Hagsand

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
struct xml_parse_yacc_arg{
    char       *ya_parse_string; /* original (copy of) parse string */
    int         ya_linenum;      /* Number of \n in parsed buffer */
    void       *ya_lexbuf;       /* internal parse buffer from lex */

    cxobj      *ya_xelement;     /* xml active element */
    cxobj      *ya_xparent;      /* xml parent element*/
    yang_stmt  *ya_yspec;        /* If set, top-level yang-spec */
    int         ya_lex_state;    /* lex return state */
};

extern char *clixon_xml_parsetext;

/*
 * Prototypes
 */
int clixon_xml_parsel_init(struct xml_parse_yacc_arg *ya);
int clixon_xml_parsel_exit(struct xml_parse_yacc_arg *ya);

int clixon_xml_parsel_linenr(void);
int clixon_xml_parselex(void *);
int clixon_xml_parseparse(void *);

#endif	/* _CLIXON_XML_PARSE_H_ */
