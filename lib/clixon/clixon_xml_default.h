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

 *
 * XML default values
 */

#ifndef _CLIXON_XML_DEFAULT_H_
#define _CLIXON_XML_DEFAULT_H_

/*
 * Types
 */
/* Declared in clixon_yang_internal */
typedef enum yang_class yang_class;

/*
 * Prototypes
 */
int xml_default_recurse(cxobj *xn, int state, int flag);
int xml_global_defaults(clixon_handle h, cxobj *xn, cvec *nsc, const char *xpath, yang_stmt *yspec, int state);
int xml_default_nopresence(cxobj *xn, int mode, int flag);
int xml_add_default_tag(cxobj *x, uint16_t flags);
int xml_flag_state_default_value(cxobj *x, uint16_t flag);
int xml_flag_default_value(cxobj *x, uint16_t flag);

#endif  /* _CLIXON_XML_DEFAULT_H_ */
