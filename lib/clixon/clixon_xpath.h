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

 * Clixon XML XPATH 1.0 according to https://www.w3.org/TR/xpath-10
 */
#ifndef _CLIXON_XPATH_H
#define _CLIXON_XPATH_H

/*
 * Types
 */
enum xp_op{
    XO_AND,
    XO_OR,
    XO_DIV,
    XO_MOD,
    XO_ADD,
    XO_MULT,
    XO_SUB,
    XO_EQ,
    XO_NE,
    XO_GE,
    XO_LE,
    XO_LT,
    XO_GT,
    XO_UNION,
};

/* Axis specifiers according to https://www.w3.org/TR/xpath-10/#NT-AxisName */
enum axis_type{
    A_NAN = 0, /* Not set */
    A_ANCESTOR,
    A_ANCESTOR_OR_SELF,
    A_ATTRIBUTE,
    A_CHILD,
    A_DESCENDANT, 
    A_DESCENDANT_OR_SELF,
    A_FOLLOWING,
    A_FOLLOWING_SIBLING, 
    A_NAMESPACE,
    A_PARENT,
    A_PRECEEDING,
    A_PRECEEDING_SIBLING,
    A_SELF,
    A_ROOT /* XXX Not in https://www.w3.org/TR/xpath-10 */
};

/*
 * Variables
 */
extern const map_str2int xpopmap[];

/*
 * Prototypes
 */
#if defined(__GNUC__) && __GNUC__ >= 3
int xpath_vec(cxobj *xcur, char *format, cxobj  ***vec, size_t *veclen, ...) __attribute__ ((format (printf, 2, 5)));
int xpath_vec_flag(cxobj *xcur, char *format, uint16_t flags, 
		   cxobj ***vec, size_t *veclen, ...) __attribute__ ((format (printf, 2, 6)));
cxobj *xpath_first(cxobj *xcur, char *format, ...) __attribute__ ((format (printf, 2, 3)));
int xpath_vec_bool(cxobj *xcur, char *format, ...) __attribute__ ((format (printf, 2, 3)));

#else
int xpath_vec(cxobj *xcur, char *format, cxobj  ***vec, size_t *veclen, ...);
int xpath_vec_flag(cxobj *xcur, char *format, uint16_t flags, 
		   cxobj ***vec, size_t *veclen, ...);
cxobj *xpath_first(cxobj *xcur, char *format, ...);
int xpath_vec_bool(cxobj *xcur, char *format, ...);

#endif
int xpath_vec_ctx(cxobj *xcur, char *xpath, xp_ctx  **xrp);

#endif /* _CLIXON_XPATH_H */
