/*
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

 *
 * XML code
 */

#ifndef _CLIXON_XML_MAP_H_
#define _CLIXON_XML_MAP_H_

/*
 * Prototypes
 */
int xml2txt(FILE *f, cxobj *x, int level);
int xml2cli(FILE *f, cxobj *x, char *prepend, enum genmodel_type gt);
int xml_yang_validate_rpc(cxobj *xrpc);
int xml_yang_validate_add(cxobj *xt, void *arg);
int xml_yang_validate_all(cxobj *xt, void *arg);
int xml2cvec(cxobj *xt, yang_stmt *ys, cvec **cvv0);
int cvec2xml_1(cvec *cvv, char *toptag, cxobj *xp, cxobj **xt0);
int xml_diff(yang_spec *yspec, cxobj *xt1, cxobj *xt2, 	 
	     cxobj ***first, size_t *firstlen, 
	     cxobj ***second, size_t *secondlen, 
	     cxobj ***changed1, cxobj ***changed2, size_t *changedlen);
int yang2api_path_fmt(yang_stmt *ys, int inclkey, char **api_path_fmt);
int api_path_fmt2api_path(char *api_path_fmt, cvec *cvv, char **api_path);
int api_path_fmt2xpath(char *api_path_fmt, cvec *cvv, char **xpath);
int xml_tree_prune_flagged_sub(cxobj *xt, int flag, int test, int *upmark);
int xml_tree_prune_flagged(cxobj *xt, int flag, int test);
int xml_default(cxobj *x, void  *arg);
int xml_order(cxobj *x, void  *arg);
int xml_sanity(cxobj *x, void  *arg);
int xml_non_config_data(cxobj *xt, void *arg);
int xml_spec_populate_rpc(clicon_handle h, cxobj *x, yang_spec *yspec);
int xml_spec_populate(cxobj *x, void *arg);
int api_path2xpath_cvv(yang_spec *yspec, cvec *cvv, int offset, cbuf *xpath);
int api_path2xpath(yang_spec *yspec, char *api_path, cbuf *xpath);
int api_path2xml(char *api_path, yang_spec *yspec, cxobj *xtop, 
		 yang_class nodeclass, cxobj **xpathp, yang_node **ypathp);
int xml_merge(cxobj *x0, cxobj *x1, yang_spec *yspec, char **reason);
int yang_enum_int_value(cxobj *node, int32_t *val);

#endif  /* _CLIXON_XML_MAP_H_ */
