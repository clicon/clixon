/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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
  *
  *                     1                                             1
  * +--------------------+   restconf_handle_get  +--------------------+
  * | rh restconf_handle | <--------------------- |  h  clicon_handle  |
  * +--------------------+                        +--------------------+
  *  common SSL config     \                                  ^         
  *                          \                                |       n
  *                            \  rh_sockets      +--------------------+
  *                              +----------->    | rs restconf_socket | 
  *                                               +--------------------+
  *                     n                          per-socket SSL config
  * +--------------------+
  * | rr restconf_request| per-packet
  * +--------------------+
  *
  * Parse functions 
  */

#ifdef __cplusplus
extern "C" {
#endif
    
#ifndef _RESTCONF_NATIVE_H_
#define _RESTCONF_NATIVE_H_

/*
 * Types
 */
/* http/2 session stream struct
 */
typedef struct  {
    qelem_t   sd_qelem;     /* List header */
    int32_t   sd_stream_id;
    int       sd_fd;
} restconf_stream_data;

/* Restconf connection handle 
 * Per connection request
 */
typedef struct {
    //    qelem_t       rs_qelem; /* List header */
    cvec               *rc_outp_hdrs; /* List of output headers */
    cbuf               *rc_outp_buf;  /* Output buffer */
    size_t              rc_bufferevent_output_offset; /* Kludge to drain libevent output buffer */
    restconf_http_proto rc_proto; /* HTTP protocol: http/1 or http/2 */
    int                 rc_s;         /* Connection socket */
    clicon_handle       rc_h;         /* Clixon handle */
    SSL                *rc_ssl;       /* Structure for SSL connection */
    restconf_stream_data *rc_streams;   /* List of http/2 session streams */
    /* Decision to keep lib-specific data here, otherwise new struct necessary
     * drawback is specific includes need to go everywhere */
#ifdef HAVE_LIBEVHTP
    evhtp_connection_t *rc_evconn;
#endif
#ifdef HAVE_LIBNGHTTP2

    nghttp2_session    *rc_ngsession;
#endif
} restconf_conn_h;
    
/* Restconf request handle 
 * Per socket request
 */
typedef struct {
    qelem_t       rs_qelem;     /* List header */
    clicon_handle rs_h;         /* Clixon handle */
    int           rs_ss;        /* Server socket (ready for accept) */
    int           rs_ssl;       /* 0: Not SSL socket, 1:SSL socket */
    char         *rs_addrtype;  /* Address type according to ietf-inet-types:
                                   eg inet:ipv4-address or inet:ipv6-address */
    char         *rs_addrstr;   /* Address as string, eg 127.0.0.1, ::1 */
    uint16_t      rs_port;      /* Protocol port */
} restconf_socket;

/* Restconf handle 
 * Global data about ssl (not per packet/request)
 */
typedef struct {
    SSL_CTX         *rh_ctx;       /* SSL context */
    restconf_socket *rh_sockets;   /* List of restconf server (ready for accept) sockets */
    void            *rh_arg;       /* Packet specific handle (eg evhtp) */
} restconf_native_handle;

/*
 * Prototypes
 */
int restconf_parse(void *req, const char *buf, size_t buflen);

#endif /* _RESTCONF_NATIVE_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif
