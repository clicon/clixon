/*
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
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

  Custom file as boilerplate appended by clixon_config.h 
  */

#ifndef HAVE_STRNDUP 
#define strndup(s, n) clicon_strndup(s, n)
#endif

#if defined(__OpenBSD__) || defined(__FreeBSD__) ||  defined(__NetBSD__)
#define BSD
/* at least for openbsd 4.5 i cannot get a hdr file */
int strverscmp (__const char *__s1, __const char *__s2);
#endif

/* Set if you want to enable "v" cli callback functions, such as cli_setv() 
 * This was obsoleted in 3.7
 */
#undef COMPAT_CLIV

/* Set if you want to assert that all rpc messages have set username
 */
#undef RPC_USERNAME_ASSERT

/* Full xmlns validation check is made only if XML has associated YANG spec 
*/
#define XMLNS_YANG_ONLY 1

/* Set if you want to enable old xpath functions in clixon_xsl.* instead of the
 * the new xpath functions in clixon_xpath.*
 * Note that when changing from old xpath code to new, calls on the form 
 * `x[a=str]` where `str` is a  string (not a number or XML symbol), 
 * must be changed to: `x[a='str'] or x[a="str"]`
 * Enabling COMPAT_XSL may make sense if you have written a lot of user code that 
 * relieson the error above. Or if a bug appears in the newimplementation.
 * @see test/lib.sh
 */
#undef COMPAT_XSL
