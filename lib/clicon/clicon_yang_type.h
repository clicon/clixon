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

 */

#ifndef _CLICON_YANG_TYPE_H_
#define _CLICON_YANG_TYPE_H_

/*
 * Constants
 */
/*! Bit-fields used in options argument in yang_type_get()
 */
#define YANG_OPTIONS_LENGTH           0x01
#define YANG_OPTIONS_RANGE            0x02
#define YANG_OPTIONS_PATTERN          0x04
#define YANG_OPTIONS_FRACTION_DIGITS  0x08

/*
 * Types
 */


/*
 * Prototypes
 */
int        yang_type_cache_set(yang_type_cache **ycache, 	    
			       yang_stmt *resolved, int options, cg_var *mincv, 
			       cg_var *maxcv, char *pattern, uint8_t fraction);
int        yang_type_cache_get(yang_type_cache *ycache, 
			       yang_stmt **resolved, int *options, cg_var **mincv, 
			       cg_var **maxcv, char **pattern, uint8_t *fraction);
int        yang_type_cache_cp(yang_type_cache **ycnew, yang_type_cache *ycold);
int        yang_type_cache_free(yang_type_cache *ycache);
int        ys_resolve_type(yang_stmt *ys, void *arg);
int        yang2cv_type(char *ytype, enum cv_type *cv_type);
char      *cv2yang_type(enum cv_type cv_type);
yang_stmt *yang_find_identity(yang_stmt *ys, char *identity);
int        ys_cv_validate(cg_var *cv, yang_stmt *ys, char **reason);
int        clicon_type2cv(char *type, char *rtype, enum cv_type *cvtype);
char      *ytype_id(yang_stmt *ys);
int        yang_type_get(yang_stmt *ys, char **otype, yang_stmt **restype, 
			 int *options, cg_var **mincv, cg_var **maxcv, char **pattern,
                         uint8_t *fraction_digits);
int        yang_type_resolve(yang_stmt   *ys, yang_stmt   *ytype, 
			     yang_stmt  **restype, int   *options, 
			     cg_var     **mincv, cg_var     **maxcv, 
			     char       **pattern,  uint8_t     *fraction);


#endif  /* _CLICON_YANG_TYPE_H_ */
