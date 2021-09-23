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
  */

#ifdef __cplusplus
extern "C" {
#endif
    
#ifndef _RESTCONF_NATIVE_H_
#define _RESTCONF_NATIVE_H_

/*
 * Types
 */
    
/* Forward */
struct restconf_conn;

/* session stream struct, mainly for http/2 but http/1 has a single pseudo-stream with id=0
 */
typedef struct  {
    qelem_t               sd_qelem;     /* List header */
    int32_t               sd_stream_id;
    int                   sd_fd;        /* XXX Is this used? */
    cvec                 *sd_outp_hdrs; /* List of output headers */
    cbuf                 *sd_outp_buf;  /* Output buffer */
    cbuf                 *sd_body;      /* http output body as cbuf terminated with \r\n */
    size_t                sd_body_len;  /* Content-Length, note for HEAD body body can be NULL and this non-zero */
    size_t                sd_body_offset; /* Offset into body */
    cbuf                 *sd_indata;    /* Receive/input data */
    char                 *sd_path;      /* Uri path, uri-encoded, without args (eg ?) */
    uint16_t              sd_code;      /* If != 0 send a reply XXX: need reply flag? */
    struct restconf_conn *sd_conn;      /* Backpointer to connection this stream is part of */
    restconf_http_proto   sd_proto;     /* http protocol XXX not sure this is needed */
    cvec                 *sd_qvec;      /* Query parameters, ie ?a=b&c=d */
    void                 *sd_req;       /* Lib-specific request, eg evhtp_request_t * */
    int                   sd_upgrade2;  /* Upgrade to http/2 */
    uint8_t              *sd_settings2; /* Settings for upgrade to http/2 request */
} restconf_stream_data;

/* Restconf connection handle 
 * Per connection request
 */
typedef struct restconf_conn {
    //    qelem_t       rs_qelem; /* List header */
    size_t              rc_bufferevent_output_offset; /* Kludge to drain libevent output buffer */
    restconf_http_proto rc_proto; /* HTTP protocol: http/1 or http/2 */
    int                 rc_s;         /* Connection socket */
    clicon_handle       rc_h;         /* Clixon handle */
    SSL                *rc_ssl;       /* Structure for SSL connection */
    restconf_stream_data *rc_streams; /* List of http/2 session streams */
    int                   rc_exit;    /* Set to close socket server-side (NYI) */
    /* Decision to keep lib-specific data here, otherwise new struct necessary
     * drawback is specific includes need to go everywhere */
#ifdef HAVE_LIBEVHTP
    evhtp_connection_t *rc_evconn;
#endif
#ifdef HAVE_LIBNGHTTP2
    nghttp2_session    *rc_ngsession; /* XXX Not sure it is needed */
#endif
} restconf_conn;

/* Restconf per socket handle
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
restconf_stream_data *restconf_stream_data_new(restconf_conn *rc, int32_t stream_id);
restconf_stream_data *restconf_stream_find(restconf_conn *rc, int32_t id);
int               restconf_stream_free(restconf_stream_data *sd);
restconf_conn    *restconf_conn_new(clicon_handle h, int s);
int               restconf_conn_free(restconf_conn *rc);
int               ssl_x509_name_oneline(SSL *ssl, char **oneline);

int               restconf_close_ssl_socket(restconf_conn *rc, int shutdown); /* XXX in restconf_main_native.c */
int               restconf_connection_sanity(clicon_handle h, restconf_conn *rc, restconf_stream_data *sd);

    
#endif /* _RESTCONF_NATIVE_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif
