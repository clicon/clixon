/*
 *
  ***** BEGIN LICENSE BLOCK *****

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
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****
  * Netconf input routines
  */

#ifndef _CLIXON_NETCONF_INPUT_H
#define _CLIXON_NETCONF_INPUT_H

/* What kind of framing? NETCONF_SSH_EOM or NETCONF_SSH_CHUNKED
 * Global setting used with clicon_data_int_get()
 */
#define NETCONF_FRAMING_TYPE "netconf-framing-type"

/*
 * Prototypes
 */
#ifdef __cplusplus
extern "C" {
#endif

int     detect_endtag(const char *tag, char ch, int *state);
ssize_t netconf_input_read2(int s, unsigned char *buf, ssize_t buflen, int *eof);
int     netconf_input_msg2(unsigned char **bufp, size_t *lenp, cbuf *cbmsg,
                           netconf_framing_type framing, int *frame_state, size_t *frame_size,
                           int *eom);
int     netconf_input_frame2(cbuf *cb, yang_bind yb, yang_stmt *yspec, cxobj **xrecv, cxobj **xerr);

#ifdef __cplusplus
}
#endif

#endif /* _CLIXON_NETCONF_INPUT_H */
