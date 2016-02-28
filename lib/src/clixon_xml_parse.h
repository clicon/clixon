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

 * XML parser
 */
#ifndef _CLIXON_XML_PARSE_H_
#define _CLIXON_XML_PARSE_H_

/*
 * Types
 */
struct xml_parse_yacc_arg{
    char       *ya_parse_string; /* original (copy of) parse string */
    int         ya_linenum;      /* Number of \n in parsed buffer */
    void       *ya_lexbuf;       /* internal parse buffer from lex */

    cxobj      *ya_xelement;     /* xml active element */
    cxobj      *ya_xparent;      /* xml parent element*/
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
