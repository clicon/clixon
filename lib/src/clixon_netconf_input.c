/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2023 Olof Hagsand

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

  ***** END LICENSE BLOCK *****
  * Unified netconf input routines
  *
  * Usage:
  
    if ((len = netconf_input_read2(s, buf, buflen, &eof)) < 0)
       goto done;
    p = buf; plen = len;
    while (!eof){
       if (netconf_input_msg2(&p, &plen, cbmsg, framing_type, &frame_state, &frame_size, &eom) < 0)
          goto done;
       if (!eom)
          break;
       if ((ret = netconf_input_frame2(cbmsg, YB_RPC, yspec, &cbret, &xtop)) < 0)
          goto done;
       // process incoming packet xtop
    }

    if (eom == 0)
        // frame not complete
    if ((ret = netconf_input_frame(cb, yspec, &xtop)) < 0)
        goto done;
    if (ret == 0)
        // invalid
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <syslog.h>
#include <fcntl.h>
#include <fnmatch.h>
#include <sys/stat.h>
#include <sys/time.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_string.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_netconf_lib.h"
#include "clixon_xml_io.h"
#include "clixon_proto.h"
#include "clixon_netconf_input.h"

/*! Look for a text pattern in an input string, one char at a time
 *
 * @param[in]     tag     What to look for
 * @param[in]     ch      New input character
 * @param[in,out] state   A state integer holding how far we have parsed.
 * @retval        1       Yes, we have detected end tag!
 * @retval        0       No, we havent detected end tag
 * @code
 *   int state = 0;
 *   char ch;
 *   while (1) {
 *     // read ch
 *     if (detect_endtag("mypattern", ch, &state)) {
 *       // mypattern is matched
 *     }
 *   }
 * @endcode
 */
int
detect_endtag(const char *tag,
              char        ch,
              int        *state)
{
    int retval = 0;

    if (tag[*state] == ch){
        (*state)++;
        if (*state == strlen(tag)){
            *state = 0;
            retval = 1;
        }
    }
    else
        *state = 0;
    return retval;
}

/*! Read from socket and append to cbuf
 *
 * @param[in]   s       Socket where input arrives. Read from this.
 * @param[out]  buf     Packet buffer
 * @param[in]   buflen  Length of packet buffer
 * @param[out]  eof     Socket closed / eof?
 * @retval      n       length
 * @retval     -1       Error
 */
ssize_t
netconf_input_read2(int            s,
                    unsigned char *buf,
                    ssize_t        buflen,
                    int           *eof)
{
    int     retval = -1;
    ssize_t len;
    int     restarts = 0;
    int     maxrestarts = 5;

    memset(buf, 0, buflen);
    while ((len = read(s, buf, buflen)) < 0) {
        switch (errno){
        case EINTR:
        case EAGAIN:
            if (restarts++ >= maxrestarts){
                clixon_log(NULL, LOG_ERR, "%s: read: %s", __func__, strerror(errno));
                goto done;
            }
            break;       /* Try again */
        case ECONNRESET: /* Connection reset by peer */
        case EPIPE:      /* Client shutdown */
        case EBADF:      /* Client shutdown - freebsd */
            len = 0;     /* Emulate EOF */
            break;
        default:
            clixon_log(NULL, LOG_ERR, "%s: read: %s", __func__, strerror(errno));
            goto done;
        }
        if (len == 0)
            break;
    } /* read */
    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "len:%ld", len);
    if (len == 0){  /* EOF */
        clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "len==0, closing");
        *eof = 1;
    }
    retval = len;
 done:
    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "retval:%d", retval);
    return retval;
}

/*! Get netconf message using NETCONF framing
 *
 * @param[in,out] bufp         Input data, incremented as read
 * @param[in,out] lenp         Data len, decremented as read
 * @param[in,out] cbmsg        Completed frame (if eom), may contain data on entry
 * @param[in]     framing_type EOM or chunked framing
 * @param[in,out] frame_state  Framing state depending on type
 * @param[in,out] frame_size   Chunked framing size parameter
 * @param[out]    eom          If frame found in cb?
 * @retval        0            OK
 * @retval       -1            Error (from chunked framing)
 * The routine should be called continuously with more data from input socket in buf
 * State of previous reads is saved in:
 * - bufp/lenp
 * - cbmsg
 * - frame_state/frame_size
 */
int
netconf_input_msg2(unsigned char      **bufp,
                   size_t              *lenp,
                   cbuf                *cbmsg,
                   netconf_framing_type framing_type,
                   int                 *frame_state,
                   size_t              *frame_size,
                   int                 *eom)
{
    int       retval = -1;
    int       i;
    int       found = 0;
    size_t    len;
    char      ch;
    int       ret;

    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "");
    len = *lenp;
    for (i=0; i<len; i++){
        if ((ch = (*bufp)[i]) == 0)
            continue; /* Skip NULL chars (eg from terminals) */
        if (framing_type == NETCONF_SSH_CHUNKED){
            /* Track chunked framing defined in RFC6242 */
            if ((ret = netconf_input_chunked_framing(ch, frame_state, frame_size)) < 0)
                goto done;
            switch (ret){
            case 1: /* chunk-data */
                cbuf_append(cbmsg, ch);
                break;
            case 2: /* end-of-data */
                /* Somewhat complex error-handling:
                 * Ignore packet errors, UNLESS an explicit termination request (eof)
                 */
                found++;
                break;
            default:
                break;
            }
        }
        else{
            cbuf_append(cbmsg, ch);
            if (detect_endtag("]]>]]>", ch, frame_state)){
                *frame_state = 0;
                /* OK, we have an xml string from a client */
                /* Remove trailer */
                *(((char*)cbuf_get(cbmsg)) + cbuf_len(cbmsg) - strlen("]]>]]>")) = '\0';
                found++;
            }
        }
        if (found){
            i++;
            break;
        }
    } /* for */
    *bufp += i;
    *lenp -= i;
    *eom = found;
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "retval:%d", retval);
    return retval;
}

/*! Parse incoming frame (independent of framing)
 *
 * Parse string to xml, check only one netconf message within a frame
 * A relatively high-level function.
 * @param[in]   cb    Packet buffer
 * @param[in]   yb    Yang binding: Y_RPC for server-side, Y_NONE for client-side (for now)
 * @param[in]   yspec Yang spec
 * @param[out]  xrecv XML packet
 * @param[out]  xerr  XML error, (if ret = 0)
 * @retval      1     OK
 * @retval      0     Invalid, parse error, etc, xerr points to netconf error message
 * @retval     -1     Fatal error
 */
int
netconf_input_frame2(cbuf      *cb,
                     yang_bind  yb,
                     yang_stmt *yspec,
                     cxobj    **xrecv,
                     cxobj    **xerr)
{
    int     retval = -1;
    char   *str = NULL;
    cxobj  *xtop = NULL; /* Request (in) */
    int     ret;

    clixon_debug(CLIXON_DBG_DEFAULT | CLIXON_DBG_DETAIL, "");
    if (xrecv == NULL){
        clixon_err(OE_PLUGIN, EINVAL, "xrecv is NULL");
        goto done;
    }
    str = cbuf_get(cb);
    /* Special case: empty XML */
    if (strlen(str) == 0){
        if (netconf_operation_failed_xml(xerr, "rpc", "Empty XML")< 0)
            goto done;
        goto failed;
    }
    /* Fix to distinguish RPC and REPLIES */
    if ((ret = clixon_xml_parse_string(str, yb, yspec, &xtop, xerr)) < 0){
        /* XXX possibly should quit on -1? */
        if (netconf_operation_failed_xml(xerr, "rpc", clixon_err_reason())< 0)
            goto done;
        goto failed;
    }
    if (ret == 0){
        /* Note: xtop can be "hello" in which case one (maybe) should drop the session and log
         * However, its not until netconf_input_packet that rpc vs hello vs other identification is 
         * actually made.
         * Actually, there are no error replies to hello messages according to any RFC, so
         * rpc error reply here is non-standard, but may be useful.
         */
        goto failed;
    }
    /* Check for empty frame (no messages), return empty message, not clear from RFC what to do */
    if (xml_child_nr_type(xtop, CX_ELMNT) == 0){
        if (netconf_operation_failed_xml(xerr, "rpc", "Truncated XML")< 0)
            goto done;
        goto failed;
    }
    if (xml_child_nr_type(xtop, CX_ELMNT) != 1){
        if (netconf_malformed_message_xml(xerr, "More than one message in netconf rpc frame")< 0)
            goto done;
        goto failed;
    }
    *xrecv = xtop;
    xtop = NULL;
    retval = 1;
 done:
    if (xtop)
        xml_free(xtop);
    return retval;
 failed:
    retval = 0;
    goto done;
}
