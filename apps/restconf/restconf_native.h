/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****
  *
  * Data structures:
  *                     1                                             1
  * +--------------------+   restconf_handle_get  +--------------------+
  * | rn restconf_native | <--------------------- |  h  clixon_handle  |
  * |     _handle        |                        +--------------------+
  * +--------------------+                                   ^
  *  common SSL config     \                                 |         
  *                          \                               |        n
  *                            \  rn_sockets      +--------------------+ 
  *                              +----------->    | rs restconf_socket |
  *                                               +--------------------+
  *                                               per-server socket (per config)
  *                                                     |   ^
  *                                            rs_conns v   |        n
  *                                               +--------------------+
  *                                               | rc restconf_conn   |
  *                                               +--------------------+
  *                                                per-connection (transient)
  *                     n                          
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
    cbuf                 *sd_inbuf;     /* Receive/input buf (whole message) */
    cbuf                 *sd_indata;    /* Receive/input data body */
    char                 *sd_path;      /* Uri path, uri-encoded, without args (eg ?) */
    uint16_t              sd_code;      /* If != 0 send a reply XXX: need reply flag? */
    struct restconf_conn *sd_conn;      /* Backpointer to connection this stream is part of */
    restconf_http_proto   sd_proto;     /* http protocol XXX not sure this is needed */
    cvec                 *sd_qvec;      /* Query parameters, ie ?a=b&c=d */
    void                 *sd_req;       /* Lib-specific request */
    int                   sd_upgrade2;  /* Upgrade to http/2 */
    uint8_t              *sd_settings2; /* Settings for upgrade to http/2 request */
} restconf_stream_data;

typedef struct restconf_socket restconf_socket;

/* Restconf connection handle 
 * Per connection request
 */
typedef struct restconf_conn {
    qelem_t               rc_qelem;     /* List header */
    /* XXX rc_proto and rc_proto_d1/d2 may not both be necessary.
     * remove rc_proto?
     */
    int                   rc_callhome;  /* 0: listen, 1: callhome */
    restconf_http_proto   rc_proto;     /* HTTP protocol: http/1 or http/2 */
    int                   rc_proto_d1;  /* parsed version digit 1 */
    int                   rc_proto_d2;  /* parsed version digit 2 */
    int                   rc_s;         /* Connection socket */
    clixon_handle         rc_h;         /* Clixon handle */
    SSL                  *rc_ssl;       /* Structure for SSL connection */
    restconf_stream_data *rc_streams; /* List of http/2 session streams */
    int                   rc_exit;    /* Set to close socket server-side */
    /* Decision to keep lib-specific data here, otherwise new struct necessary
     * drawback is specific includes need to go everywhere */
#ifdef HAVE_LIBNGHTTP2
    nghttp2_session      *rc_ngsession; /* XXX Not sure it is needed */
#endif
    restconf_socket      *rc_socket;    /* Backpointer to restconf_socket needed for callhome */
    struct timeval        rc_t;         /* Timestamp of last read/write activity, used by callhome
                                           idle-timeout algorithm */
} restconf_conn;

/* Restconf per socket handle
 * Two types: listen and callhome.
 * Listen: Uses socket rs_ss to listen for connections and accepts them, creates one
 *         restconf_conn for each new accept.
 * Callhome: Calls connect according to timer to setup single restconf_conn.
 *           when this is closed, new connect is made, according to connection-type.
 */
typedef struct restconf_socket{
    qelem_t       rs_qelem;     /* List header */
    clixon_handle rs_h;         /* Clixon handle */
    char         *rs_description; /* Description */
    int           rs_callhome;  /* 0: listen, 1: callhome */
    int           rs_ss;        /* Listen: Server socket, ready for accept
                                 * XXXCallhome: connect socket (same as restconf_conn->rc_s) 
                                 * Callhome: No-op, see restconf_conn->rc_s
                                 */
    int           rs_ssl;       /* 0: Not SSL socket, 1:SSL socket */
    char         *rs_addrtype;  /* Address type according to ietf-inet-types:
                                   eg inet:ipv4-address or inet:ipv6-address */
    char         *rs_addrstr;   /* Address as string, eg 127.0.0.1, ::1 */
    uint16_t      rs_port;      /* Protocol port */
    int           rs_periodic;  /* 0: persistent, 1: periodic (if callhome) */
    uint32_t      rs_period;    /* Period in s (if callhome & periodic) */
    uint8_t       rs_max_attempts;  /* max connect attempts (if callhome) */
    uint16_t      rs_idle_timeout; /* Max underlying TCP session remains idle (if callhome and periodic) (in seconds)*/
    uint64_t      rs_start;     /* First period start, next is start+periods*period */
    uint64_t      rs_period_nr; /* Dynamic succeeding or timed out periods. 
                                   Set in restconf_callhome_timer*/
    uint8_t       rs_attempts;  /* Dynamic connect attempts in this round (if callhome) 
                                 * Set in restconf_callhome_cb
                                 */
    restconf_conn *rs_conns;  /* List of transient connect sockets */
    char          *rs_from_addr; /* From IP address as seen by accept (mv to rc?) */

} restconf_socket;

/* Restconf handle 
 * Global data about ssl (not per packet/request)
 */
typedef struct {
    SSL_CTX         *rn_ctx;       /* SSL context */
    restconf_socket *rn_sockets;   /* List of restconf server (ready for accept) sockets */
    void            *rn_arg;       /* Packet specific handle */
} restconf_native_handle;

/*
 * Prototypes
 */
restconf_stream_data *restconf_stream_data_new(restconf_conn *rc, int32_t stream_id);
restconf_stream_data *restconf_stream_find(restconf_conn *rc, int32_t id);
int               restconf_stream_free(restconf_stream_data *sd);
restconf_conn    *restconf_conn_new(clixon_handle h, int s, restconf_socket *socket);
int               ssl_x509_name_oneline(SSL *ssl, char **oneline);

int               restconf_close_ssl_socket(restconf_conn *rc, const char *callfn, int sslerr0);
int               restconf_connection_sanity(clixon_handle h, restconf_conn *rc, restconf_stream_data *sd);
restconf_native_handle *restconf_native_handle_get(clixon_handle h);
int               restconf_connection(int s, void *arg);
int               restconf_ssl_accept_client(clixon_handle h, int s, restconf_socket *rsock, restconf_conn  **rcp);
int               restconf_idle_timer_unreg(restconf_conn *rc);
int               restconf_idle_timer(restconf_conn *rc);
int               restconf_callhome_timer_unreg(restconf_socket *rsock);
int               restconf_callhome_timer(restconf_socket *rsock, int status);
int               restconf_socket_extract(clixon_handle h, cxobj *xs, cvec *nsc, restconf_socket *rsock,
                                          char **namespace, char **address, char **addrtype, uint16_t *port);

#endif /* _RESTCONF_NATIVE_H_ */

#ifdef __cplusplus
} /* extern "C" */
#endif
