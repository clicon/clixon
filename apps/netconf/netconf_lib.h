/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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
 *  Netconf lib
 *****************************************************************************/
#ifndef _NETCONF_LIB_H_
#define _NETCONF_LIB_H_

/*
 * Types
 */ 
enum target_type{ /* netconf */
    RUNNING,
    CANDIDATE
}; 
enum transport_type{ 
    NETCONF_SSH,  /* RFC 4742 */
#ifdef NOTUSED
    NETCONF_SOAP,  /* RFC 4743 */
#endif
};

enum test_option{ /* edit-config */
    SET,
    TEST_THEN_SET,
    TEST_ONLY
};

enum error_option{ /* edit-config */
    STOP_ON_ERROR,
    CONTINUE_ON_ERROR
};

/*
 * Variables
 */ 
extern enum transport_type transport;
extern int cc_closed;

/*
 * Prototypes
 */ 
int add_preamble(cbuf *xf);
int add_postamble(cbuf *xf);
int add_error_preamble(cbuf *xf, char *reason);
int add_error_postamble(cbuf *xf);
int netconf_output(int s, cbuf *xf, char *msg);
int netconf_output_encap(clicon_handle h, int s, cbuf *cb, char *msg);

#endif  /* _NETCONF_LIB_H_ */
