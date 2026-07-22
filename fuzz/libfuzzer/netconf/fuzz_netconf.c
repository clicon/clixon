/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2024 Olof Hagsand

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

 * LLVM libfuzzer for the NETCONF / XML receive path.
 *
 * Feeds arbitrary byte sequences through the full NETCONF receive pipeline:
 *   netconf_input_msg2()    — EOM (]]>]]>) or chunked (RFC 6242) framing
 *   netconf_input_frame2()  — XML parse + single-message validation
 *
 * The first byte of the fuzzer input selects the framing type:
 *   0x00  NETCONF_SSH_EOM      (legacy ]]>]]> framing)
 *   other NETCONF_SSH_CHUNKED  (RFC 6242 chunk framing)
 * The remaining bytes are the raw message body.
 *
 * No backend or YANG spec is required; YANG binding is YB_NONE so only the
 * XML parser and NETCONF framing logic are exercised.
 *
 * Build: see build.sh
 */

#include "clixon_config.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

#include <cligen/cligen.h>
#include <clixon/clixon.h>
#include <clixon/clixon_netconf_input.h>

/* Persistent handle — allocated once in LLVMFuzzerInitialize, reused per input */
static clixon_handle _fuzz_h = NULL;

int
LLVMFuzzerInitialize(int *argc, char ***argv)
{
    if ((_fuzz_h = clixon_handle_init()) == NULL)
        return 0;
    clixon_log_init(_fuzz_h, "fuzz_netconf", LOG_DEBUG, 0);
    return 0;
}

/*! libfuzzer entry point
 *
 * @param[in]  data  Fuzzer-supplied byte sequence
 * @param[in]  size  Length of data
 * @retval     0     Always (errors are expected and ignored)
 */
int
LLVMFuzzerTestOneInput(const uint8_t *data,
                       size_t         size)
{
    netconf_framing_type  framing;
    unsigned char        *buf = NULL;
    unsigned char        *p;
    size_t                plen;
    cbuf                 *cbmsg = NULL;
    cxobj                *xrecv = NULL;
    cxobj                *xerr  = NULL;
    int                   frame_state = 0;
    size_t                frame_size  = 0;
    int                   eom = 0;

    if (size < 1)
        goto done;

    /* First byte selects framing type */
    framing = (data[0] == 0x00) ? NETCONF_SSH_EOM : NETCONF_SSH_CHUNKED;
    data++;
    size--;

    if ((buf = malloc(size)) == NULL)
        goto done;
    memcpy(buf, data, size);

    if ((cbmsg = cbuf_new()) == NULL)
        goto done;

    p    = buf;
    plen = size;

    /* Drive framing state machine until EOM or all input consumed */
    while (plen > 0) {
        if (netconf_input_msg2(&p, &plen, cbmsg, framing,
                               &frame_state, &frame_size, &eom) < 0)
            goto done;
        if (!eom)
            break;
        /* Parse the framed XML; errors are expected and ignored */
        netconf_input_frame2(cbmsg, YB_NONE, NULL, &xrecv, &xerr);
        if (xrecv) {
            xml_free(xrecv);
            xrecv = NULL;
        }
        if (xerr) {
            xml_free(xerr);
            xerr = NULL;
        }
        cbuf_reset(cbmsg);
        eom = 0;
    }

 done:
    if (xrecv)
        xml_free(xrecv);
    if (xerr)
        xml_free(xerr);
    if (cbmsg)
        cbuf_free(cbmsg);
    free(buf);
    return 0;
}
