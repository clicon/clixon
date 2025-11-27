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

 */

#ifndef _CLIXON_YANG_TYPE_H_
#define _CLIXON_YANG_TYPE_H_

/*
 * Constants
 */
/*! Bit-fields used in options argument in yang_type_get()
 */
#define YANG_OPTIONS_LENGTH           0x01
#define YANG_OPTIONS_RANGE            0x02
#define YANG_OPTIONS_FRACTION_DIGITS  0x04
#define YANG_OPTIONS_PATTERN          0x08

/*
 * Types
 */
/* declared in clixon_yang_internal */
typedef struct yang_type_cache yang_type_cache;

/*
 * Prototypes
 */
int        ys_resolve_type(yang_stmt *ys, void *arg);
int        yang2cv_type(const char *ytype, enum cv_type *cv_type);
char      *cv2yang_type(enum cv_type cv_type);
yang_stmt *yang_find_identity(yang_stmt *ys, const char *identity);
yang_stmt *yang_find_identity_nsc(yang_stmt *yspec, const char *identity, cvec *nsc);
int        ys_cv_validate(clixon_handle h, cg_var *cv, yang_stmt *ys, yang_stmt **ysub, char **reason);
int        clicon_type2cv(const char *type, const char *rtype, yang_stmt *ys, enum cv_type *cvtype);
int        yang_type_get(yang_stmt *ys, char **otype, yang_stmt **restype,
                         int *options, cvec **cvv,
                         cvec *patterns, cvec *regexps,
                         uint8_t *fraction_digits);
int        yang_type_resolve(yang_stmt *yorig, yang_stmt *ys,
                             yang_stmt *ytype,
                             yang_stmt **restype, int *options,
                             cvec **cvv, cvec *patterns, cvec *regexps,
                             uint8_t *fraction);
enum cv_type yang_type2cv(yang_stmt *ys);

#endif  /* _CLIXON_YANG_TYPE_H_ */
