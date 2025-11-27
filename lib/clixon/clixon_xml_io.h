/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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

 * Clixon XML object parse and print functions
 * @see https://www.w3.org/TR/2008/REC-xml-20081126
 *      https://www.w3.org/TR/2009/REC-xml-names-20091208
 */
#ifndef _CLIXON_XML_IO_H_
#define _CLIXON_XML_IO_H_

/*
 * Prototypes
 */
int   clixon_xml2file1(FILE *f, cxobj *xn, int level, int pretty, const char *prefix,
                       clicon_output_cb *fn, int skiptop, int autocliext, withdefaults_type wdef,
                       int multi, int system_only);
int   clixon_xml2file(FILE *f, cxobj *xn, int level, int pretty, const char *prefix, clicon_output_cb *fn, int skiptop, int autocliext);
int   xml_print(FILE *f, cxobj *xn);
int   xml_print1(FILE *f, cxobj *xn);
int   xml_dump(FILE  *f, cxobj *x);
int   clixon_xml2cbuf1(cbuf *cb, cxobj *x, int level, int prettyprint, const char *prefix,
                       int32_t depth, int skiptop, withdefaults_type wdef);
int   xmltree2cbuf(cbuf *cb, cxobj *x, int level);
int   clixon_xml_parse_file(FILE *f, yang_bind yb, yang_stmt *yspec, cxobj **xt, cxobj **xerr);
int   clixon_xml_parse_string1(clixon_handle h, const char *str, yang_bind yb, yang_stmt *yspec, cxobj **xt, cxobj **xerr);
int   clixon_xml_parse_va(yang_bind yb, yang_stmt *yspec, cxobj **xt, cxobj **xerr,
                        const char *format, ...)  __attribute__ ((format (printf, 5, 6)));
int   clixon_xml_attr_copy(cxobj *xin, cxobj *xout, const char *name);
int   clixon_xml_diff2cbuf(cbuf *cb, cxobj *x0, cxobj *x1);

static inline int
clixon_xml2cbuf(cbuf       *cb,
                cxobj      *xn,
                int         level,
                int         pretty,
                const char *prefix,
                int32_t     depth,
                int         skiptop)
{
    return clixon_xml2cbuf1(cb, xn, level, pretty, prefix, depth, skiptop, WITHDEFAULTS_REPORT_ALL);
}

/* 7.4 backward compatible */
static inline int
clixon_xml_parse_string(const char *str, yang_bind yb, yang_stmt *yspec, cxobj **xt, cxobj **xerr)
{
    return clixon_xml_parse_string1(NULL, str, yb, yspec, xt, xerr);
}

#endif  /* _CLIXON_XML_IO_H_ */
