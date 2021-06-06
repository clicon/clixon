/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdarg.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <time.h>
#include <syslog.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pwd.h>
#include <netinet/in.h>
#include <libgen.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include "clixon_netconf.h"
#include "netconf_lib.h"
#include "netconf_rpc.h"
#include "netconf_capabilities.h"

/* Command line options to be passed to getopt(3) */
#define NETCONF_OPTS "hD:f:E:l:qa:u:d:p:y:U:t:eo:"

#define NETCONF_LOGFILE "/tmp/clixon_netconf.log"

/* clixon-data value to save buffer between invocations.
 * Saving data may be necessary if socket buffer contains partial netconf messages, such as:
 * <foo/> ..wait 1min  ]]>]]>
 */
#define NETCONF_HASH_BUF "netconf_input_cbuf"

/*! Ignore errors on packet errors: continue */
static int ignore_packet_errors = 1;

/* Hello request received */
static int _netconf_hello_nr = 0;

/*! Copy attributes from incoming request to reply. Skip already present (dont overwrite)
 *
 * RFC 6241:
 * If additional attributes are present in an <rpc> element, a NETCONF
 * peer MUST return them unmodified in the <rpc-reply> element.  This
 * includes any "xmlns" attributes.
 * @param[in]     xrpc  Incoming message on the form <rpc>...
 * @param[in,out] xrep  Reply message on the form <rpc-reply>...
 */
static int
netconf_add_request_attr(cxobj *xrpc,
			 cxobj *xrep)
{
    int    retval = -1;
    cxobj *xa;
    cxobj *xa2 = NULL;

    xa = NULL;
    while ((xa = xml_child_each(xrpc, xa, CX_ATTR)) != NULL){
	/* If attribute already exists, dont copy it */
	if (xml_find_type(xrep, NULL, xml_name(xa), CX_ATTR) != NULL)
	    continue; /* Skip already present (dont overwrite) */
	if ((xa2 = xml_dup(xa)) ==NULL)
	    goto done;
	if (xml_addsub(xrep, xa2) < 0)
	    goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*
 * A server receiving a <hello> message with a <session-id> element MUST
 * terminate the NETCONF session. 
 */
static int
netconf_hello_msg(clicon_handle h,
		  cxobj        *xn)
{
    int     retval = -1;
    cvec   *nsc = NULL; // namespace context
    cxobj **vec = NULL;
    size_t  veclen;
    cxobj  *x;
    cxobj  *xcap;
    int     foundbase;
    char   *body;

    _netconf_hello_nr++;
    if (xml_find_type(xn, NULL, "session-id", CX_ELMNT) != NULL) {
	clicon_err(OE_XML, errno, "Server received hello with session-id from client, terminating (see RFC 6241 Sec 8.1)");
	cc_closed++;
	goto done;
    }
    if (xpath_vec(xn, nsc, "capabilities/capability", &vec, &veclen) < 0)
	goto done;
    /* Each peer MUST send at least the base NETCONF capability, "urn:ietf:params:netconf:base:1.1"*/
    foundbase=0;
    if ((xcap = xml_find_type(xn, NULL, "capabilities", CX_ELMNT)) != NULL) {
	x = NULL;
	while ((x = xml_child_each(xcap, x, CX_ELMNT)) != NULL) {
	    if (strcmp(xml_name(x), "capability") != 0)
		continue;
	    if ((body = xml_body(x)) == NULL)
		continue;

            netconf_capabilities_put(h, body);

	    /* When comparing protocol version capability URIs, only the base part is used, in the 
	     * event any parameters are encoded at the end of the URI string. */
	    if (strncmp(body, NETCONF_BASE_CAPABILITY_1_0, strlen(NETCONF_BASE_CAPABILITY_1_0)) == 0) /* RFC 4741 */
		foundbase++;

	    else if (strncmp(body, NETCONF_BASE_CAPABILITY_1_1, strlen(NETCONF_BASE_CAPABILITY_1_1)) == 0) /* RFC 6241 */
		foundbase++;
	}
    }

    netconf_capabilities_lock(h);

    if (foundbase == 0){
	clicon_err(OE_XML, errno, "Server received hello without netconf base capability %s, terminating (see RFC 6241 Sec 8.1",
		   NETCONF_BASE_CAPABILITY_1_1);
	cc_closed++;
	goto done;
    }

    retval = 0;
 done:
    if (vec)
	free(vec);
    return retval;
}

/*! Process incoming Netconf RPC netconf message 
 * @param[in]   h     Clicon handle
 * @param[in]   xreq  XML tree containing netconf RPC message
 * @param[in]   yspec YANG spec
 * @retval      0     OK
 * @retval     -1     Error
 */
int
netconf_rpc_message(clicon_handle h,
		    cxobj        *xrpc,
		    yang_stmt    *yspec)
{
    int    retval = -1;
    cxobj *xret = NULL; /* Return (out) */
    int    ret;
    cbuf  *cbret = NULL;
    cxobj *xc;

    if (_netconf_hello_nr == 0 &&
	clicon_option_bool(h, "CLICON_NETCONF_HELLO_OPTIONAL") == 0){
	if (netconf_operation_failed_xml(&xret, "rpc", "Client must send an hello element before any RPC")< 0)
	    goto done;
	/* Copy attributes from incoming request to reply. Skip already present (dont overwrite) */
	if (netconf_add_request_attr(xrpc, xret) < 0)
	    goto done;
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	clicon_xml2cbuf(cbret, xret, 0, 0, -1);
	netconf_output_encap(1, cbret, "rpc-error");
	cc_closed++;
	goto ok;
    }
    if ((ret = xml_bind_yang_rpc(xrpc, yspec, &xret)) < 0)
	goto done;
    if (ret > 0 &&
	(ret = xml_yang_validate_rpc(h, xrpc, &xret)) < 0) 
	goto done;
    if (ret == 0){
	if (netconf_add_request_attr(xrpc, xret) < 0)
	    goto done;
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	clicon_xml2cbuf(cbret, xret, 0, 0, -1);
	if (netconf_output_encap(1, cbret, "rpc-error") < 0)
	    goto done;
	goto ok;
    }
    if (netconf_rpc_dispatch(h, xrpc, &xret) < 0){
	goto done;
    }
    /* Is there a return message in xret? */
    if (xret == NULL){
	if (netconf_operation_failed_xml(&xret, "rpc", "Internal error: no xml return")< 0)
	    goto done;
	if (netconf_add_request_attr(xrpc, xret) < 0)
	    goto done;
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	clicon_xml2cbuf(cbret, xret, 0, 0, -1);
	if (netconf_output_encap(1, cbret, "rpc-error") < 0)
	    goto done;
	goto ok;
    }
    if ((xc = xml_child_i(xret, 0))!=NULL){
	/* Copy attributes from incoming request to reply. Skip already present (dont overwrite) */
	if (netconf_add_request_attr(xrpc, xc) < 0)
	    goto done;
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	clicon_xml2cbuf(cbret, xml_child_i(xret,0), 0, 0, -1);
	if (netconf_output_encap(1, cbret, "rpc-reply") < 0)
	    goto done;
    }
 ok:
    retval = 0;
 done:
    if (cbret)
	cbuf_free(cbret);
    if (xret)
	xml_free(xret);
    return retval;
}

/*! Process incoming a single netconf message parsed as XML
 * Identify what netconf message it is
 * @param[in]   h     Clicon handle
 * @param[in]   xreq  XML tree containing netconf
 * @param[in]   yspec YANG spec
 * @retval      0     OK
 * @retval     -1     Error
 */
static int
netconf_input_packet(clicon_handle h,
		     cxobj        *xreq,
		     yang_stmt    *yspec)
{
    int     retval = -1;
    cbuf   *cbret = NULL;
    char   *rpcname;
    char   *rpcprefix;
    char   *namespace = NULL;
    cxobj  *xret = NULL;
    
    clicon_debug(1, "%s", __FUNCTION__);
    rpcname = xml_name(xreq);
    rpcprefix = xml_prefix(xreq);
    if (xml2ns(xreq, rpcprefix, &namespace) < 0)
	goto done;
    if (strcmp(rpcname, "rpc") == 0){
	/* Only accept resolved NETCONF base namespace */
	if (namespace == NULL || strcmp(namespace, NETCONF_BASE_NAMESPACE) != 0){
	    if (netconf_unknown_namespace_xml(&xret, "protocol", rpcprefix, "No appropriate namespace associated with prefix")< 0)
		goto done;
	    if (netconf_add_request_attr(xreq, xret) < 0)
		goto done;
	    if ((cbret = cbuf_new()) == NULL){ 
		clicon_err(OE_XML, errno, "cbuf_new");
		goto done;
	    }
	    clicon_xml2cbuf(cbret, xret, 0, 0, -1);
	    netconf_output_encap(1, cbret, "rpc-error");
	    goto ok;
	}
	if (netconf_rpc_message(h, xreq, yspec) < 0)
	    goto done;
    }
    else if (strcmp(rpcname, "hello") == 0){
    /* Only accept resolved NETCONF base namespace */
	if (namespace == NULL || strcmp(namespace, NETCONF_BASE_NAMESPACE) != 0){
	    clicon_err(OE_XML, EFAULT, "No appropriate namespace associated with prefix:%s", rpcprefix);
	    goto done;
	}
	if (netconf_hello_msg(h, xreq) < 0)
	    goto done;
    }
    else{
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	if (netconf_unknown_element(cbret, "protocol", rpcname, "Unrecognized netconf operation")< 0)
	    goto done;
	netconf_output_encap(1, cbret, "rpc-error");
    }
 ok:
    retval = 0;
 done:
    if (cbret)
	cbuf_free(cbret);
    return retval;
}

/*! Process incoming frame, ie a char message framed by ]]>]]>
 * Parse string to xml, check only one netconf message within a frame
 * @param[in]   h    Clicon handle
 * @param[in]   cb   Packet buffer
 * @retval      0    OK
 * @retval     -1    Fatal error
 * @note there are errors detected here prior to whether you know what kind if message it is, and
 * these errors are returned as "rpc-error".
 * This is problematic since RFC6241 only says to return rpc-error on errors to <rpc>.
 * Not at this early stage, the incoming message can be something else such as <hello> or
 * something else.
 * In section 8.1 regarding handling of <hello> it says just to "terminate" the session which I
 * interpret as not sending anything back, just closing the session.
 * Anyway, clixon therefore does the following on error:
 * - Before we know what it is: send rpc-error
 * - Hello messages: terminate
 * - RPC messages: send rpc-error
 */
static int
netconf_input_frame(clicon_handle h, 
		    cbuf         *cb)
{
    int        retval = -1;
    char      *str = NULL;
    cxobj     *xtop = NULL; /* Request (in) */
    cxobj     *xreq = NULL;
    cxobj     *xret = NULL; /* Return (out) */
    cbuf      *cbret = NULL;
    yang_stmt *yspec;
    int        ret;

    clicon_debug(1, "%s", __FUNCTION__);
    clicon_debug(2, "%s: \"%s\"", __FUNCTION__, cbuf_get(cb));
    yspec = clicon_dbspec_yang(h);
    if ((str = strdup(cbuf_get(cb))) == NULL){
	clicon_err(OE_UNIX, errno, "strdup");
	goto done;
    }
    /* Special case:  */
    if (strlen(str) == 0){
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_UNIX, errno, "cbuf_new");
	    goto done;
	}
	if (netconf_operation_failed(cbret, "rpc", "Empty XML")< 0)
	    goto done;
	netconf_output_encap(1, cbret, "rpc-error"); 
	goto ok;
    }
    /* Parse incoming XML message */
    if ((ret = clixon_xml_parse_string(str, YB_RPC, yspec, &xtop, &xret)) < 0){ 
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_UNIX, errno, "cbuf_new");
	    goto done;
	}
	if (netconf_operation_failed(cbret, "rpc", clicon_err_reason)< 0)
	    goto done;
	netconf_output_encap(1, cbret, "rpc-error");
	goto ok;
    }
    if (ret == 0){
	/* Note: xtop can be "hello" in which case one (maybe) should drop the session and log
	 * However, its not until netconf_input_packet that rpc vs hello vs other identification is 
	 * actually made
	 */
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_XML, errno, "cbuf_new");
	    goto done;
	}
	clicon_xml2cbuf(cbret, xret, 0, 0, -1);
	netconf_output_encap(1, cbret, "rpc-error");
	goto ok;
    }

    /* Check for empty frame (no mesaages), return empty message, not clear from RFC what to do */
    if (xml_child_nr_type(xtop, CX_ELMNT) == 0){
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_UNIX, errno, "cbuf_new");
	    goto done;
	}
	netconf_output_encap(1, cbret, "rpc-error");
	goto ok;
    }

    /* Check for multi-messages in frame */
    if (xml_child_nr_type(xtop, CX_ELMNT) != 1){
	if ((cbret = cbuf_new()) == NULL){ 
	    clicon_err(OE_UNIX, errno, "cbuf_new");
	    goto done;
	}
	if (netconf_malformed_message(cbret, "More than one message in netconf rpc frame")< 0)
	    goto done;
	netconf_output_encap(1, cbret, "rpc-error"); 
	goto ok;
    }
    if ((xreq = xml_child_i_type(xtop, 0, CX_ELMNT)) == NULL){ /* Shouldnt happen */
	clicon_err(OE_XML, EFAULT, "No xml req (shouldnt happen)");
	goto done;
    }
    if (netconf_input_packet(h, xreq, yspec) < 0)
	goto done;

ok:
    retval = 0;

done:
    if (str)
	free(str);
    if (xtop)
	xml_free(xtop);
    if (xret)
	xml_free(xret);
    if (cbret)
	cbuf_free(cbret);
    return retval;
}

/*! Detect a given character sequence at the end of a \b cbuf
 *
 *  This function matches the last characters of a \b cbuf against a given string sequence and
 *  returns whether a match has been found.
 *
 *  @param[in]      cb          The \b cbuf containing some text
 *  @param[in]      endTag      The sequence of characters that are matched
 *  @retval         0           The string in \b cb does not end with \b endTag
 *  @retval         1           The string in \b cb ends with the expected \b endTag
 */
static int cbuf_ends_with(cbuf * cb, char * endTag) {
    int currentBufferLength = cbuf_len(cb);
    char * buffer = cbuf_get(cb);
    int endTagLength = (int) strlen(endTag);

    if(currentBufferLength < endTagLength)
        return 0;

    int expectedStartIndex = currentBufferLength - endTagLength;

    for(int i = 0; i < endTagLength; i++) {
        char currentChar = buffer[expectedStartIndex + i];
        if(currentChar != endTag[i])
            return 0;
    }

    return 1;
}

/*! Looking for a chunk header as defined in RFC6242 section 4.2
 *
 *  This function detects a chunk header by looking at a stream of characters and returns the expected
 *  length on a successful match. It uses the \b state parameter to persist the matching progress
 *  between invocations.
 *
 *  @param[in]       ch              The current character that should be processed.
 *  @param[in,out]   state           A state variable saving the current matching progress.
 *  @param[out]      chunkLength     The length of the matched chunk. Only if the return value is positive.
 *  @retval          1               Found a chunk header. Length is returned in \b chunkLength.
 *  @retval          0               No chunk header found.
 */
static int detect_netconf_chunk_header(char ch, int * state, int * chunkLength) {
    switch(*state) {
        case 0: // Looking for \n
            if(ch == '\n') { *state = 1; *chunkLength = 0; }
            break;
        case 1: // Looking for #
            if(ch == '#') *state = 2;
            else { *state = 0; return detect_netconf_chunk_header(ch, state, chunkLength); }
            break;
        case 2: // Looking for 1-9
            if(ch >= '1' && ch <= '9') {
                *chunkLength = ch - '0';
                *state = 3;
            }
            else { *state = 0; return detect_netconf_chunk_header(ch, state, chunkLength); }
            break;
        case 3: // Looking for 0-9 or \n
            if(ch == '\n') *state = 4;
            else if(ch >= '0' && ch <= '9') *chunkLength = ((*chunkLength) * 10) + (ch - '0');
            else { *state = 0; return detect_netconf_chunk_header(ch, state, chunkLength); }
            break;
    }

    return *state == 4;
}

/*! Parses a netconf chunk as defined in RFC6242 section 4.2
 *
 *  This function parses a complete chunk of a netconf message transmitted over SSH and returns
 *  the body of the message in a new \b cbuf.
 *
 *  @param[in]      cb              The \b cbuf holding the received chunk
 *  @param[out]     bodyBuffer      The netconf message without the chunk information. Only if return value is positive.
 *  @retval         0               No chunk has been detected
 *  @retval         1               Chunk has been detected. Body is returned in \b bodyBuffer.
 */
static int detect_netconf_chunk(cbuf * cb, cbuf ** bodyBuffer) {
    int bufferLength = cbuf_len(cb);
    char currentChar;
    char * buffer = cbuf_get(cb);
    *bodyBuffer = cbuf_new();
    int currentPos = -1;
    int chunkLength = 0;
    int chunkHeaderState = 0;
    int chunkEndState = 0;
    int chunkState = 0;
    int chunkRemainingLength = 0;

    while(currentPos++ < bufferLength) {
        currentChar = buffer[currentPos];

        switch (chunkState) {
            case 0: // Detect Header
                if(detect_netconf_chunk_header(currentChar, &chunkHeaderState, &chunkLength)) {
                    chunkState = 1;
                    chunkHeaderState = 0;

                    chunkRemainingLength = chunkLength;
                }
                break;

            case 1: // Read Body
                cprintf(*bodyBuffer, "%c", currentChar);
                chunkRemainingLength--;
                if(chunkRemainingLength <= 0) {
                    chunkEndState = 0;
                    chunkHeaderState = 0;
                    chunkState = 2;
                }
                break;

            case 2: // Looking for next chunk or end
                if(detect_netconf_chunk_header(currentChar, &chunkHeaderState, &chunkLength)) {
                    chunkState = 1;
                    chunkHeaderState = 0;

                    chunkRemainingLength = chunkLength;
                }
                if(detect_endtag("\n##\n", currentChar, &chunkEndState))  {
                    return 1;
                }
        }
    }

    if(*bodyBuffer)
        cbuf_free(*bodyBuffer);

    return 0;
}

/*! Gets or creates the input buffer for incoming netconf messages
 *
 *  @param[in]      cacheTable      The cache table on which to look for existing input buffers
 *  @param[out]     cb              The input buffer
 *  @retval         -1              Unable to create input buffer
 *  @retval         0               Input buffer returned in \b cb
 */
static int netconf_input_get_msg_buf(clicon_hash_t *cacheTable, cbuf **cb) {
    void *hashValue;
    size_t cdatlen = 0;
    int returnValue = -1;

    if ((hashValue = clicon_hash_value(cacheTable, NETCONF_HASH_BUF, &cdatlen)) != NULL) {
        if (cdatlen != sizeof(cb)) {
            clicon_err(OE_XML, errno, "size mismatch %lu %lu",
                       (unsigned long) cdatlen, (unsigned long) sizeof(cb));
            goto done;
        }
        *cb = *(cbuf **) hashValue;
        clicon_hash_del(cacheTable, NETCONF_HASH_BUF);
    } else {
        if ((*cb = cbuf_new()) == NULL) {
            clicon_err(OE_XML, errno, "cbuf_new");
            goto done;
        }
    }

    returnValue = 0;

    done:
    return returnValue;
}

/*! This function processes a set of new bytes that are expected to contain a netconf message
 *
 *  Given a message buffer \b msgBuffer that might already contain parts of a message and
 *  a set of new bytes that were received, this function appends the bytes to the \b msgBuffer
 *  and meanwhile detects and directly processes the first found netconf message.
 *
 * @param[in]       h               The clicon handle associated with this netconf channel
 * @param[in,out]   msgBuffer       A message buffer that might already contain parts of a netconf message
 * @param[in]       newBytes        A char array containing the new received bytes
 * @param[in]       newByteCount    The number of received bytes that are present in \b newBytes
 * @retval          -1              Unable to process bytes
 * @retval          0               Successfully processed the new bytes
 */
static int netconf_input_process_msg_bytes(clicon_handle h, cbuf *msgBuffer, unsigned char *newBytes, int newByteCount) {
    int i;
    int returnValue = -1;
    cbuf * chunkBuffer;

    for (i = 0; i < newByteCount; i++) {
        if (newBytes[i] == 0)
            continue; /* Skip NULL chars (eg from terminals) */

        cprintf(msgBuffer, "%c", newBytes[i]);

        if (cbuf_ends_with(msgBuffer, "]]>]]>")) {
            // Received netconf message with old end-of-message-based formatting
            // Remove the trailing char sequence "]]>]]>"
            *(((char *) cbuf_get(msgBuffer)) + cbuf_len(msgBuffer) - strlen("]]>]]>")) = '\0';

            if (netconf_input_frame(h, msgBuffer) < 0 && !ignore_packet_errors) // default is to ignore errors
                goto done;

            if (cc_closed)
                break;

            cbuf_reset(msgBuffer);
        }

        if (cbuf_ends_with(msgBuffer, "\n##\n")) {
            // Detected an end-of-chunks tag. Trying to parse the chunk and extract the body.
            if (detect_netconf_chunk(msgBuffer, &chunkBuffer)) {
                if (netconf_input_frame(h, chunkBuffer) < 0 && !ignore_packet_errors) // default is to ignore errors
                    goto done;

                if (cc_closed)
                    break;

                cbuf_reset(msgBuffer);
            }
        }
    }

    returnValue = 0;

    done:
    return returnValue;
}

/*! Get netconf message: detect end-of-msg 
 * @param[in]   s    Socket where input arrived. read from this.
 * @param[in]   arg  Clicon handle.
 * This routine continuously reads until no more data on s. There could
 * be risk of starvation, but the netconf client does little else than
 * read data so I do not see a danger of true starvation here.
 * @note data is saved in clicon-handle at NETCONF_HASH_BUF since there is a potential issue if data
 * is not completely present on the s, ie if eg:
 *   <a>foo ..pause.. </a>]]>]]>
 * then only "</a>" would be delivered to netconf_input_frame().
 */
static int
netconf_input_cb(int   s, 
		 void *arg)
{
    int           retval = -1;
    clicon_handle h = arg;
    unsigned char buf[BUFSIZ];  /* from stdio.h, typically 8K */
    int           len;
    cbuf         *cb=NULL;
    int           poll;
    clicon_hash_t *cdat = clicon_data(h); /* Save cbuf between calls if not done */

    if(netconf_input_get_msg_buf(cdat, &cb) < 0)
        goto done;

    memset(buf, 0, sizeof(buf));
    while (1){
	if ((len = read(s, buf, sizeof(buf))) < 0){
	    if (errno == ECONNRESET)
		len = 0; /* emulate EOF */
	    else{
		clicon_log(LOG_ERR, "%s: read: %s", __FUNCTION__, strerror(errno));
		goto done;
	    }
	} /* read */

	if (len == 0){ 	/* EOF */
	    cc_closed++;
	    close(s);
	    retval = 0;
	    goto done;
	}

        if(netconf_input_process_msg_bytes(h, cb, buf, len) < 0)
            goto done;

	/* poll==1 if more, poll==0 if none */
	if ((poll = clixon_event_poll(s)) < 0)
	    goto done;

	if (poll == 0){
	    /* No data to read, save data and continue on next round */
	    if (cbuf_len(cb) != 0){
		if (clicon_hash_add(cdat, NETCONF_HASH_BUF, &cb, sizeof(cb)) == NULL)
		    return -1;
		cb = NULL;
	    }
	    break; 
	}
    } /* while */
    retval = 0;
  done:
    if (cb)
	cbuf_free(cb);
    if (cc_closed) 
	retval = -1;
    return retval;
}

/*! Send netconf hello message
 * @param[in]   h   Clicon handle
 * @param[in]   s   File descriptor to write on (eg 1 - stdout)
 */
static int
send_hello(clicon_handle h,
	   int           s,
	   uint32_t      id)
{
    int   retval = -1;
    cbuf *cb;
    
    if ((cb = cbuf_new()) == NULL){
	clicon_log(LOG_ERR, "%s: cbuf_new", __FUNCTION__);
	goto done;
    }
    if (netconf_hello_server(h, cb, id) < 0)
	goto done;
    if (netconf_output(s, cb, "hello") < 0)
	goto done;
    retval = 0;
  done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Clean and close all state of netconf process (but dont exit). 
 * Cannot use h after this 
 * @param[in]  h  Clixon handle
 */
static int
netconf_terminate(clicon_handle h)
{
    yang_stmt  *yspec;
    cvec       *nsctx;
    cxobj      *x;
    
    /* Delete all plugins, and RPC callbacks */
    clixon_plugin_module_exit(h);
    clicon_rpc_close_session(h);

    if ((yspec = clicon_dbspec_yang(h)) != NULL)
	ys_free(yspec);
    if ((yspec = clicon_config_yang(h)) != NULL)
	ys_free(yspec);
    if ((nsctx = clicon_nsctx_global_get(h)) != NULL)
	cvec_free(nsctx);
    if ((x = clicon_conf_xml(h)) != NULL)
	xml_free(x);

    xpath_optimize_exit();
    clixon_event_exit();
    clicon_handle_exit(h);
    clixon_err_exit();
    clicon_log_exit();
    return 0;
}

static int
timeout_fn(int s,
	   void *arg)
{
    clicon_err(OE_EVENTS, ETIMEDOUT, "User request timeout");
    return -1; 
}

/*! Usage help routine
 * @param[in]  h      Clicon handle
 * @param[in]  argv0  command line
 */
static void
usage(clicon_handle h,
      char         *argv0)
{
    fprintf(stderr, "usage:%s\n"
	    "where options are\n"
            "\t-h\t\tHelp\n"
	    "\t-D <level>\tDebug level\n"
    	    "\t-f <file>\tConfiguration file (mandatory)\n"
	    "\t-E <dir> \tExtra configuration file directory\n"
	    "\t-l (e|o|s|f<file>) Log on std(e)rr, std(o)ut, (s)yslog(default), (f)ile\n"
            "\t-q\t\tQuiet: dont send hello prompt\n"
    	    "\t-a UNIX|IPv4|IPv6 Internal backend socket family\n"
    	    "\t-u <path|addr>\tInternal socket domain path or IP addr (see -a)\n"
	    "\t-d <dir>\tSpecify netconf plugin directory dir (default: %s)\n"
	    "\t-p <dir>\tYang directory path (see CLICON_YANG_DIR)\n"
	    "\t-y <file>\tLoad yang spec file (override yang main module)\n"
	    "\t-U <user>\tOver-ride unix user with a pseudo user for NACM.\n"
	    "\t-t <sec>\tTimeout in seconds. Quit after this time.\n"
	    "\t-e \t\tDont ignore errors on packet input.\n"
	    "\t-o \"<option>=<value>\"\tGive configuration option overriding config file (see clixon-config.yang)\n",
	    argv0,
	    clicon_netconf_dir(h)
	    );
    exit(0);
}

int
main(int    argc,
     char **argv)
{
    int              retval = -1;
    int              c;
    char            *argv0 = argv[0];
    int              quiet = 0;
    clicon_handle    h;
    char            *dir;
    int              logdst = CLICON_LOG_STDERR;
    struct passwd   *pw;
    struct timeval   tv = {0,}; /* timeout */
    yang_stmt       *yspec = NULL;
    char            *str;
    uint32_t         id;
    cvec            *nsctx_global = NULL; /* Global namespace context */
    size_t           cligen_buflen;
    size_t           cligen_bufthreshold;
    int              dbg = 0;
    
    /* Create handle */
    if ((h = clicon_handle_init()) == NULL)
	return -1;
    /* In the startup, logs to stderr & debug flag set later */
    clicon_log_init(__PROGRAM__, LOG_INFO, logdst); 

    /* Set username to clicon handle. Use in all communication to backend */
    if ((pw = getpwuid(getuid())) == NULL){
	clicon_err(OE_UNIX, errno, "getpwuid");
	goto done;
    }
    if (clicon_username_set(h, pw->pw_name) < 0)
	goto done;
    while ((c = getopt(argc, argv, NETCONF_OPTS)) != -1)
	switch (c) {
	case 'h' : /* help */
	    usage(h, argv[0]);
	    break;
	case 'D' : /* debug */
	    if (sscanf(optarg, "%d", &dbg) != 1)
		usage(h, argv[0]);
	    break;
	 case 'f': /* override config file */
	    if (!strlen(optarg))
		usage(h, argv[0]);
	    clicon_option_str_set(h, "CLICON_CONFIGFILE", optarg);
	    break;
	case 'E': /* extra config directory */
	    if (!strlen(optarg))
		usage(h, argv[0]);
	    clicon_option_str_set(h, "CLICON_CONFIGDIR", optarg);
	    break;
	 case 'l': /* Log destination: s|e|o */
	    if ((logdst = clicon_log_opt(optarg[0])) < 0)
		usage(h, argv[0]);
	    if (logdst == CLICON_LOG_FILE &&
		strlen(optarg)>1 &&
		clicon_log_file(optarg+1) < 0)
		goto done;
	     break;
	}

    /* 
     * Logs, error and debug to stderr or syslog, set debug level
     */
    clicon_log_init(__PROGRAM__, dbg?LOG_DEBUG:LOG_INFO, logdst); 
    clicon_debug_init(dbg, NULL); 

    /* Find, read and parse configfile */
    if (clicon_options_main(h) < 0)
	goto done;
    
    /* Now rest of options */
    optind = 1;
    opterr = 0;
    while ((c = getopt(argc, argv, NETCONF_OPTS)) != -1)
	switch (c) {
	case 'h' : /* help */
	case 'D' : /* debug */
	case 'f':  /* config file */
	case 'E': /* extra config dir */
	case 'l':  /* log  */
	    break; /* see above */
	case 'q':  /* quiet: dont write hello */
	    quiet++;
	    break;
	case 'a': /* internal backend socket address family */
	    clicon_option_str_set(h, "CLICON_SOCK_FAMILY", optarg);
	    break;
	case 'u': /* internal backend socket unix domain path or ip host */
	    if (!strlen(optarg))
		usage(h, argv[0]);
	    clicon_option_str_set(h, "CLICON_SOCK", optarg);
	    break;
	case 'd':  /* Plugin directory */
	    if (!strlen(optarg))
		usage(h, argv[0]);
	    if (clicon_option_add(h, "CLICON_NETCONF_DIR", optarg) < 0)
		goto done;
	    break;
	case 'p' : /* yang dir path */
	    if (clicon_option_add(h, "CLICON_YANG_DIR", optarg) < 0)
		goto done;
	    break;
	case 'y' : /* Load yang spec file (override yang main module) */
	    if (clicon_option_add(h, "CLICON_YANG_MAIN_FILE", optarg) < 0)
		goto done;
	    break;
	case 'U': /* Clixon 'pseudo' user */
	    if (!strlen(optarg))
		usage(h, argv[0]);
	    if (clicon_username_set(h, optarg) < 0)
		goto done;
	    break;
	case 't': /* timeout in seconds */
	    tv.tv_sec = atoi(optarg);
	    break;
	case 'e': /* dont ignore packet errors */
	    ignore_packet_errors = 0;
	    break;
	case 'o':{ /* Configuration option */
	    char          *val;
	    if ((val = index(optarg, '=')) == NULL)
		usage(h, argv0);
	    *val++ = '\0';
	    if (clicon_option_add(h, optarg, val) < 0)
		goto done;
	    break;
	}
	default:
	    usage(h, argv[0]);
	    break;
	}
    argc -= optind;
    argv += optind;

    /* Access the remaining argv/argc options (after --) w clicon-argv_get() */
    clicon_argv_set(h, argv0, argc, argv);

    /* Init cligen buffers */
    cligen_buflen = clicon_option_int(h, "CLICON_CLI_BUF_START");
    cligen_bufthreshold = clicon_option_int(h, "CLICON_CLI_BUF_THRESHOLD");
    cbuf_alloc_set(cligen_buflen, cligen_bufthreshold);

    /* Set default namespace according to CLICON_NAMESPACE_NETCONF_DEFAULT */
    xml_nsctx_namespace_netconf_default(h);

    /* Add (hardcoded) netconf features in case ietf-netconf loaded here
     * Otherwise it is loaded in netconf_module_load below
     */
    if (netconf_module_features(h) < 0)
	goto done;
    
    /* Initialize plugin module by creating a handle holding plugin and callback lists */
    if (clixon_plugin_module_init(h) < 0)
	goto done;
    
    /* Create top-level yang spec and store as option */
    if ((yspec = yspec_new()) == NULL)
	goto done;
    clicon_dbspec_yang_set(h, yspec);	

    /* Load netconf plugins before yangs are loaded (eg extension callbacks) */
    if ((dir = clicon_netconf_dir(h)) != NULL &&
	clixon_plugins_load(h, CLIXON_PLUGIN_INIT, dir, NULL) < 0)
	goto done;
    
    /* Load Yang modules
     * 1. Load a yang module as a specific absolute filename */
    if ((str = clicon_yang_main_file(h)) != NULL){
	if (yang_spec_parse_file(h, str, yspec) < 0)
	    goto done;
    }
    /* 2. Load a (single) main module */
    if ((str = clicon_yang_module_main(h)) != NULL){
	if (yang_spec_parse_module(h, str, clicon_yang_module_revision(h),
				   yspec) < 0)
	    goto done;
    }
    /* 3. Load all modules in a directory */
    if ((str = clicon_yang_main_dir(h)) != NULL){
	if (yang_spec_load_dir(h, str, yspec) < 0)
	    goto done;
    }
    /* Load clixon lib yang module */
    if (yang_spec_parse_module(h, "clixon-lib", NULL, yspec) < 0)
	goto done;
     /* Load yang module library, RFC7895 */
    if (yang_modules_init(h) < 0)
	goto done;
    /* Add netconf yang spec, used by netconf client and as internal protocol */
    if (netconf_module_load(h) < 0)
	goto done;
    /* Here all modules are loaded 
     * Compute and set canonical namespace context
     */
    if (xml_nsctx_yangspec(yspec, &nsctx_global) < 0)
	goto done;
    if (clicon_nsctx_global_set(h, nsctx_global) < 0)
	goto done;

    /* Call start function is all plugins before we go interactive */
    if (clixon_plugin_start_all(h) < 0)
	goto done;
#if 1
    /* XXX get session id from backend hello */
    clicon_session_id_set(h, getpid()); 
#endif

    /* Initialize the capabilities hashtable */
    if(netconf_capabilities_init(h) < 0)
        goto done;

    /* Send hello request to backend to get session-id back
     * This is done once at the beginning of the session and then this is
     * used by the client, even though new TCP sessions are created for
     * each message sent to the backend.
     */
    if (clicon_hello_req(h, &id) < 0)
	goto done;
    clicon_session_id_set(h, id);
    
    /* Send hello to northbound client 
     * Note that this is a violation of RDFC 6241 Sec 8.1:
     * When the NETCONF session is opened, each peer(both client and server) MUST send a <hello..
     */
    if (!quiet){
	if (send_hello(h, 1, id) < 0)
	    goto done;
    }
    if (clixon_event_reg_fd(0, netconf_input_cb, h, "netconf socket") < 0)
	goto done;
    if (dbg)
	clicon_option_dump(h, dbg);
    if (tv.tv_sec || tv.tv_usec){
	struct timeval t;
	gettimeofday(&t, NULL);
	timeradd(&t, &tv, &t);
	if (clixon_event_reg_timeout(t, timeout_fn, NULL, "timeout") < 0)
	    goto done;
    }
    if (clixon_event_loop(h) < 0)
	goto done;
    retval = 0;
  done:
    if (ignore_packet_errors)
	retval = 0;
    netconf_terminate(h);
    clicon_log_init(__PROGRAM__, LOG_INFO, 0); /* Log on syslog no stderr */
    clicon_log(LOG_NOTICE, "%s: %u Terminated", __PROGRAM__, getpid());
    return retval;
}
