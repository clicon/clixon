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
  
 */

#ifndef _RESTCONF_LIB_H_
#define _RESTCONF_LIB_H_

/*
 * Constants
 */

/*
 * Prototypes
 */
int restconf_err2code(char *tag);
const char *restconf_code2reason(int code);
int notfound(FCGX_Request *r);
int badrequest(FCGX_Request *r);
int notimplemented(FCGX_Request *r);
int conflict(FCGX_Request *r);
int clicon_debug_xml(int dbglevel, char *str, cxobj *cx);
int test(FCGX_Request *r, int dbg);
cbuf *readdata(FCGX_Request *r);

int restconf_plugin_load(clicon_handle h);
int restconf_plugin_start(clicon_handle h, int argc, char **argv);
int restconf_plugin_unload(clicon_handle h);
int restconf_credentials(clicon_handle h, FCGX_Request *r, char **user);
int get_user_cookie(char *cookiestr, char  *attribute, char **val);


#endif /* _RESTCONF_LIB_H_ */
