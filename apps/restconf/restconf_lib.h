/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _RESTCONF_LIB_H_
#define _RESTCONF_LIB_H_

/*
 * Types
 */
/*! RESTCONF media types 
 * @see http_media_map
 * (also in clixon_restconf.h)
 */
enum restconf_media{
    YANG_DATA_JSON,  /* "application/yang-data+json" */
    YANG_DATA_XML,   /* "application/yang-data+xml" */
    YANG_PATCH_JSON, /* "application/yang-patch+json" */
    YANG_PATCH_XML   /* "application/yang-patch+xml" */
};
typedef enum restconf_media restconf_media;

/*
 * Prototypes
 */
int restconf_err2code(char *tag);
const char *restconf_code2reason(int code);
const restconf_media restconf_media_str2int(char *media);
const char *restconf_media_int2str(restconf_media media);
restconf_media restconf_content_type(clicon_handle h);
int   get_user_cookie(char *cookiestr, char  *attribute, char **val);
int   restconf_terminate(clicon_handle h);
int   restconf_insert_attributes(cxobj *xdata, cvec *qvec);
int   restconf_main_extension_cb(clicon_handle h, yang_stmt *yext, yang_stmt *ys);
char *restconf_uripath(clicon_handle h);
int   restconf_drop_privileges(clicon_handle h, char *user);

#endif /* _RESTCONF_LIB_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif

