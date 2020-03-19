/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren
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

 *
 * Translation / mapping code between formats
 */

#ifndef _CLIXON_XML_MAP_H_
#define _CLIXON_XML_MAP_H_

/* declared in clixon_yang_internal */
typedef enum yang_class yang_class;

/*
 * Prototypes
 */
int isxmlns(cxobj *x);
int xml2txt(FILE *f, cxobj *x, int level);
int xml2cli(FILE *f, cxobj *x, char *prepend, enum genmodel_type gt);
int xmlns_assign(cxobj *x);
int xml2cvec(cxobj *xt, yang_stmt *ys, cvec **cvv0);
int cvec2xml_1(cvec *cvv, char *toptag, cxobj *xp, cxobj **xt0);
int xml_diff(yang_stmt *yspec, cxobj *x0, cxobj *x1, 	 
	     cxobj ***first, size_t *firstlen, 
	     cxobj ***second, size_t *secondlen, 
	     cxobj ***changed_x0, cxobj ***changed_x1, size_t *changedlen);
int xml_tree_prune_flagged_sub(cxobj *xt, int flag, int test, int *upmark);
int xml_tree_prune_flagged(cxobj *xt, int flag, int test);
int xml_namespace_change(cxobj *x, char *namespace, char *prefix);
int xml_default(cxobj *x, void  *arg);
int xml_sanity(cxobj *x, void  *arg);
int xml_non_config_data(cxobj *xt, void *arg);
int xml_bind_yang_rpc(cxobj *xrpc, yang_stmt *yspec, cxobj **xerr);
int xml_bind_yang_rpc_reply(cxobj *xrpc, char *name, yang_stmt *yspec, cxobj **xerr);
int xml_bind_yang0(cxobj *xt, yang_bind yb, yang_stmt *yspec, cxobj **xerr);
int xml_bind_yang(cxobj *xt, yang_bind yb, yang_stmt *yspec, cxobj **xerr);

int xml2xpath(cxobj *x, char **xpath);
int assign_namespaces(cxobj *x0, cxobj *x1, cxobj *x1p);
int xml_merge(cxobj *x0, cxobj *x1, yang_stmt *yspec, char **reason);
int yang_enum_int_value(cxobj *node, int32_t *val);

#endif  /* _CLIXON_XML_MAP_H_ */
