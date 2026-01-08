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

 * JSON support functions.
 * @see http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
 *  and RFC 7951 JSON Encoding of Data Modeled with YANG
 *  and RFC 8259 The JavaScript Object Notation (JSON) Data Interchange Format
 */
#ifndef _CLIXON_JSON_H
#define _CLIXON_JSON_H

/*
 * Prototypes
 */
int json2xml_decode(cxobj *x, cxobj **xerr);
int clixon_json2cbuf(cbuf *cb, cxobj *x, int pretty, int skiptop, int autocliext, int system_only);
int xml2json_cbuf_vec(cbuf *cb, cxobj **vec, size_t veclen, int pretty, int skiptop);
int clixon_json2file(FILE *f, cxobj *x, int pretty, clicon_output_cb *fn, int skiptop, int autocliext, int system_only);
int json_print(FILE *f, cxobj *x);
int xml2json_vec(FILE *f, cxobj **vec, size_t veclen, int pretty, clicon_output_cb *fn, int skiptop);
int clixon_json_parse_string(clixon_handle h, const char *str, int jsonenc, yang_bind yb,
                             yang_stmt *yspec, cxobj **xt, cxobj **xret);
int clixon_json_parse_file(FILE *fp, int jsonenc, yang_bind yb, yang_stmt *yspec, cxobj **xt, cxobj **xret);

#endif /* _CLIXON_JSON_H */
