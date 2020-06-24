/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand

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

 * XML support functions.
 * @see     https://www.w3.org/TR/2009/REC-xml-names-20091208/
 */
#ifndef _CLIXON_XML_NSCTX_H
#define _CLIXON_XML_NSCTX_H

/*
 * An xml namespace context is a cligen variable vector containing a list of
 * <prefix,namespace> pairs.
 * It is encoded in a cvv as a list of string values, where the c name is the 
 * prefix and the string values are the namespace URI.
 * The default namespace is decoded as having the name NULL
 */

/*
 * Prototypes
 */
cvec   *xml_nsctx_init(const char *prefix, const char *_namespace);
int     xml_nsctx_free(cvec *nsc);
char   *xml_nsctx_get(cvec *nsc, char *prefix);
int     xml_nsctx_get_prefix(cvec *cvv,	const char *_namespace, char **prefix);
int     xml_nsctx_add(cvec *nsc, const char *prefix, const char *_namespace);
int     xml_nsctx_node(cxobj *x, cvec **ncp);
int     xml_nsctx_yang(yang_stmt *yn, cvec **ncp);
int     xml_nsctx_yangspec(yang_stmt *yspec, cvec **ncp);

int     xml2ns(cxobj *x, char *localname, char **_namespace);
int     xml2ns_recurse(cxobj *x);
int     xml2prefix(cxobj *xn, char *_namespace, char **prefixp);

#endif /* _CLIXON_XML_NSCTX_H */
