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

 * "Instance-identifier" is a subset of XML Xpaths and defined in Yang, used in NACM for example.
 *  and defined in RF7950 Sections 9.13 and 14.
 *
 * "api-path" is "URI-encoded path expression" definition in RFC8040 3.5.3
 * BNF:
 *  <api-path>       := <root> ("/" (<api-identifier> | <list-instance>))*
 *  <root>           := <string>
 *  <api-identifier> := [<module-name> ":"] <identifier>
 *  <module-name>    := <identifier>
 *  <list-instance>  := <api-identifier> "=" key-value *("," key-value)
 *  <key-value>      := <string>
 *  <string>         := <an unquoted string>
 *  <identifier>     := (<ALPHA> | "_") (<ALPHA> | <DIGIT> | "_" | "-" | ".")
 */

#ifndef _CLIXON_PATH_H_
#define _CLIXON_PATH_H_

/*
 * Types
 */
/* Internal path structure. Somewhat more general than api-path, much less than xpath
 * about the same as yang instance-identifier
 * Not that cp_cvk api-paths do not specifiy key-names, so cp_cvk is just a list of
 * (NULL:value)*, which means that names must be added using api_path_check() based on
 * yang.
 * Other formats (eg xpath) have the names given in the format.
 */
typedef struct {
    qelem_t     cp_qelem;    /* List header */
    char       *cp_prefix;   /* Prefix or module name, should be resolved + id to cp_yang */
    char       *cp_id;       /* Identifier */
    cvec       *cp_cvk;      /* Key values: list of (name:value) pairs alt (NULL:value)
                              * Can also be single uint32, if so positional eg x/y[42]
                              * This seems kludgy but follows RFC 7950 Sec 9.13
                              */
    yang_stmt  *cp_yang;     /* Corresponding yang spec (after XML match - ie resolved) */
} clixon_path;

/*! Callback given XML mount-point, return yang-spec of mount-point
 *
 * Used by api_path2xml when yang mountpoint is empty
 * @param[in]   h     Clixon handle
 * @param[in]   xmt   XML mount-point in XML tree
 * @param[out]  yspec Resulting mounted yang spec if retval = 1
 * @param[out]  xerr  Netconf error message if retval=0
 * @retval      1     OK
 * @retval      0     Invalid api_path or associated XML, netconf error in
 * @retval     -1     Fatal error
 * @see api_path2xml  Uses callback when yang mountpoint is empty
 */
typedef int (api_path_mnt_cb_t)(clixon_handle h, cxobj *xmt, yang_stmt **yspec, cxobj **xerr);

/*
 * Prototypes
 */
int clixon_path_free(clixon_path *cplist);
int xml_yang_root(cxobj *x, cxobj **xr);
int yang2api_path_fmt(yang_stmt *ys, int inclkey, char **api_path_fmt);
int api_path_fmt2api_path(const char *api_path_fmt, cvec *cvv, yang_stmt *yspec, char **api_path, int *cvvi);
int api_path_fmt2xpath(const char *api_path_fmt, cvec *cvv, char **xpath);
int api_path2xpath(const char *api_path, yang_stmt *yspec, char **xpath, cvec **nsc, cxobj **xerr);
int api_path2xml(const char *api_path, yang_stmt *yspec, cxobj *xtop,
                 yang_class nodeclass, int strict,
                 cxobj **xpathp, yang_stmt **ypathp, cxobj **xerr);
int api_path2xml_mnt(const char *api_path, yang_stmt *yspec, cxobj *xtop,
                     yang_class nodeclass, int strict,
                     api_path_mnt_cb_t mnt_cb, void *arg,
                     cxobj **xpathp, yang_stmt **ypathp, cxobj **xerr);
int xml2api_path_one(cxobj *x, cbuf *cb);
int xml2api_path(cxobj *x, uint16_t flag, cbuf *cb);
int clixon_xml_find_api_path(cxobj *xt, yang_stmt *yt, cxobj ***xvec, int *xlen, const char *format,
                     ...) __attribute__ ((format (printf, 5, 6)));
int clixon_xml_find_instance_id(cxobj *xt, yang_stmt *yt, cxobj ***xvec, int *xlen, const char *format,
                     ...) __attribute__ ((format (printf, 5, 6)));
int clixon_instance_id_bind(yang_stmt *yt, cvec *nsctx, const char *format, ...) __attribute__ ((format (printf, 3, 4)));
int clixon_instance_id_parse(yang_stmt *yt, clixon_path **cplistp, cxobj **xerr, const char *format, ...) __attribute__ ((format (printf, 4, 5)));

#endif  /* _CLIXON_PATH_H_ */
