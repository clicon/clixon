/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 * XML parser
 */
#ifndef _CLICON_XML_PARSE_H_
#define _CLICON_XML_PARSE_H_

/*
 * Types
 */
struct xml_parse_yacc_arg{
    char                 *ya_parse_string; /* original (copy of) parse string */
    int                   ya_linenum;      /* Number of \n in parsed buffer */
    void                 *ya_lexbuf;       /* internal parse buffer from lex */

    cxobj      *ya_xelement;     /* xml active element */
    cxobj      *ya_xparent;      /* xml parent element*/
};

extern char *clicon_xml_parsetext;

/*
 * Prototypes
 */
int clicon_xml_parsel_init(struct xml_parse_yacc_arg *ya);
int clicon_xml_parsel_exit(struct xml_parse_yacc_arg *ya);

int clicon_xml_parsel_linenr(void);
int clicon_xml_parselex(void *);
int clicon_xml_parseparse(void *);

#endif	/* _CLICON_XML_PARSE_H_ */
