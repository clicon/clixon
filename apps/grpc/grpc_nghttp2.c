/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2026 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * gRPC/nghttp2 connection management for clixon_grpc
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <syslog.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>

#include <nghttp2/nghttp2.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

#include "grpc_gnmi.h"
#include "grpc_nghttp2.h"

/*! Per-stream state — accumulated headers and body for one gRPC call */
typedef struct grpc_stream {
    int32_t  gs_stream_id;
    char    *gs_path;
    uint8_t *gs_body;
    size_t   gs_bodylen;
    size_t   gs_bodyalloc;
    struct grpc_stream *gs_next;
} grpc_stream_t;

/*! Per-connection state */
typedef struct grpc_conn {
    clixon_handle     gc_h;
    int               gc_s;
    nghttp2_session  *gc_session;
    grpc_stream_t    *gc_streams;
    struct grpc_conn *gc_next;      /* global connection list */
} grpc_conn_t;

/* Global linked list of all live client connections */
static grpc_conn_t *_grpc_conns = NULL;

/*! Per-response state for the data source read callback */
typedef struct {
    uint8_t          *data;         /* gRPC-framed payload (owned) */
    size_t            len;
    size_t            offset;
    nghttp2_session  *session;      /* needed to submit trailer from within callback */
    int32_t           stream_id;
    int               grpc_status;
    char             *grpc_message; /* optional error description (owned, may be NULL) */
} buf_src_t;

/*! Find or create a per-stream state struct */
static grpc_stream_t *
grpc_stream_get(grpc_conn_t *gc,
                int32_t      stream_id)
{
    grpc_stream_t *gs;

    for (gs = gc->gc_streams; gs != NULL; gs = gs->gs_next)
        if (gs->gs_stream_id == stream_id)
            return gs;
    if ((gs = calloc(1, sizeof *gs)) == NULL){
        clixon_err(OE_UNIX, errno, "calloc");
        return NULL;
    }
    gs->gs_stream_id = stream_id;
    gs->gs_next = gc->gc_streams;
    gc->gc_streams = gs;
    return gs;
}

/*! Free a per-stream state struct and remove from list */
static void
grpc_stream_free(grpc_conn_t   *gc,
                 grpc_stream_t *gs)
{
    grpc_stream_t *prev = NULL;
    grpc_stream_t *cur;

    for (cur = gc->gc_streams; cur != NULL; prev = cur, cur = cur->gs_next){
        if (cur == gs){
            if (prev)
                prev->gs_next = cur->gs_next;
            else
                gc->gc_streams = cur->gs_next;
            break;
        }
    }
    if (gs->gs_path)
        free(gs->gs_path);
    if (gs->gs_body)
        free(gs->gs_body);
    free(gs);
}

/*! Free a grpc_conn_t and remove it from the global list */
static void
grpc_conn_free(grpc_conn_t *gc)
{
    grpc_conn_t *prev = NULL;
    grpc_conn_t *cur;

    for (cur = _grpc_conns; cur != NULL; prev = cur, cur = cur->gc_next){
        if (cur == gc){
            if (prev)
                prev->gc_next = cur->gc_next;
            else
                _grpc_conns = cur->gc_next;
            break;
        }
    }
    while (gc->gc_streams)
        grpc_stream_free(gc, gc->gc_streams);
    nghttp2_session_del(gc->gc_session);
    close(gc->gc_s);
    free(gc);
}

/* -------------------------------------------------------------------------
 * nghttp2 callbacks
 * -------------------------------------------------------------------------*/

/*! nghttp2 send callback — write bytes to the socket */
static ssize_t
session_send_cb(nghttp2_session *session,
                const uint8_t   *data,
                size_t           length,
                int              flags,
                void            *user_data)
{
    grpc_conn_t *gc = user_data;
    ssize_t      n;

    n = write(gc->gc_s, data, length);
    if (n < 0){
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return NGHTTP2_ERR_WOULDBLOCK;
        return NGHTTP2_ERR_CALLBACK_FAILURE;
    }
    return n;
}

/*! nghttp2 recv callback — read bytes from the socket */
static ssize_t
session_recv_cb(nghttp2_session *session,
                uint8_t         *buf,
                size_t           length,
                int              flags,
                void            *user_data)
{
    grpc_conn_t *gc = user_data;
    ssize_t      n;

    n = read(gc->gc_s, buf, length);
    if (n == 0)
        return NGHTTP2_ERR_EOF;
    if (n < 0){
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return NGHTTP2_ERR_WOULDBLOCK;
        return NGHTTP2_ERR_CALLBACK_FAILURE;
    }
    return n;
}

/*! nghttp2 header callback — capture :path and other request headers */
static int
on_header_cb(nghttp2_session            *session,
             const nghttp2_frame        *frame,
             const uint8_t              *name,
             size_t                      namelen,
             const uint8_t              *value,
             size_t                      valuelen,
             uint8_t                     flags,
             void                       *user_data)
{
    grpc_conn_t   *gc = user_data;
    grpc_stream_t *gs;

    clixon_debug(CLIXON_DBG_DEFAULT, "header: %.*s: %.*s",
                 (int)namelen, name, (int)valuelen, value);
    if (frame->hd.type != NGHTTP2_HEADERS ||
        frame->headers.cat != NGHTTP2_HCAT_REQUEST)
        return 0;
    if ((gs = grpc_stream_get(gc, frame->hd.stream_id)) == NULL)
        return NGHTTP2_ERR_CALLBACK_FAILURE;
    if (namelen == 5 && memcmp(name, ":path", 5) == 0){
        if (gs->gs_path)
            free(gs->gs_path);
        if ((gs->gs_path = strndup((char *)value, valuelen)) == NULL){
            clixon_err(OE_UNIX, errno, "strndup");
            return NGHTTP2_ERR_CALLBACK_FAILURE;
        }
    }
    return 0;
}

/*! nghttp2 DATA chunk callback — accumulate gRPC body */
static int
on_data_chunk_cb(nghttp2_session *session,
                 uint8_t          flags,
                 int32_t          stream_id,
                 const uint8_t   *data,
                 size_t           len,
                 void            *user_data)
{
    grpc_conn_t   *gc = user_data;
    grpc_stream_t *gs;
    size_t         newlen;
    uint8_t       *nb;

    if ((gs = grpc_stream_get(gc, stream_id)) == NULL)
        return NGHTTP2_ERR_CALLBACK_FAILURE;
    newlen = gs->gs_bodylen + len;
    if (newlen > gs->gs_bodyalloc){
        if ((nb = realloc(gs->gs_body, newlen + 256)) == NULL){
            clixon_err(OE_UNIX, errno, "realloc");
            return NGHTTP2_ERR_CALLBACK_FAILURE;
        }
        gs->gs_body = nb;
        gs->gs_bodyalloc = newlen + 256;
    }
    memcpy(gs->gs_body + gs->gs_bodylen, data, len);
    gs->gs_bodylen += len;
    return 0;
}

/*! nghttp2 read_callback: serve the response body and submit trailers on EOF
 *
 * gRPC requires that trailers (grpc-status) are submitted from within the
 * data source read callback when NGHTTP2_DATA_FLAG_EOF is set.
 */
static ssize_t
buf_data_source_cb(nghttp2_session     *session,
                   int32_t              stream_id,
                   uint8_t             *buf,
                   size_t               length,
                   uint32_t            *data_flags,
                   nghttp2_data_source *source,
                   void                *user_data)
{
    buf_src_t  *s = source->ptr;
    size_t      n;
    char        status_str[16];
    nghttp2_nv  trailers[2];
    int         ntrailers = 1;

    n = s->len - s->offset;
    if (n > length)
        n = length;
    memcpy(buf, s->data + s->offset, n);
    s->offset += n;
    if (s->offset >= s->len){
        /* Signal: no more DATA bytes, but do NOT close stream with END_STREAM
         * on this DATA frame; trailers (a HEADERS+END_STREAM frame) come next. */
        *data_flags |= NGHTTP2_DATA_FLAG_EOF | NGHTTP2_DATA_FLAG_NO_END_STREAM;
        /* Submit grpc-status (and optional grpc-message) trailers */
        snprintf(status_str, sizeof status_str, "%d", s->grpc_status);
        trailers[0].name     = (uint8_t *)"grpc-status";
        trailers[0].namelen  = 11;
        trailers[0].value    = (uint8_t *)status_str;
        trailers[0].valuelen = strlen(status_str);
        trailers[0].flags    = NGHTTP2_NV_FLAG_NONE;
        if (s->grpc_message != NULL){
            trailers[1].name     = (uint8_t *)"grpc-message";
            trailers[1].namelen  = 12;
            trailers[1].value    = (uint8_t *)s->grpc_message;
            trailers[1].valuelen = strlen(s->grpc_message);
            trailers[1].flags    = NGHTTP2_NV_FLAG_NONE;
            ntrailers = 2;
        }
        nghttp2_submit_trailer(s->session, s->stream_id, trailers, ntrailers);
        free(s->data);
        free(s->grpc_message);
        free(s);
    }
    return (ssize_t)n;
}

/*! Send a gRPC response: 200 headers + framed protobuf body + grpc-status trailers
 *
 * @param[in]  gc          Connection
 * @param[in]  stream_id   HTTP/2 stream
 * @param[in]  buf         Serialized protobuf message (may be NULL for empty body)
 * @param[in]  buflen      Length of buf
 * @param[in]  grpc_status gRPC status code (0 = OK)
 * @param[in]  grpc_msg    Human-readable error message (may be NULL); copied
 * @retval     0           OK
 * @retval    -1           Error
 */
static int
grpc_send_response(grpc_conn_t    *gc,
                   int32_t         stream_id,
                   const uint8_t  *buf,
                   size_t          buflen,
                   int             grpc_status,
                   const char     *grpc_msg)
{
    int                 retval = -1;
    uint8_t            *frame = NULL;
    size_t              framelen;
    uint32_t            msglen_be;
    nghttp2_nv          resp_hdrs[2];
    nghttp2_data_provider dp;
    buf_src_t          *src = NULL;

    /* 5-byte gRPC Length-Prefixed-Message prefix + protobuf payload */
    framelen = GRPC_PREFIX_LEN + buflen;
    if ((frame = malloc(framelen)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    frame[0] = 0; /* compressed flag = 0 */
    msglen_be = htonl((uint32_t)buflen);
    memcpy(frame + 1, &msglen_be, 4);
    if (buflen > 0)
        memcpy(frame + GRPC_PREFIX_LEN, buf, buflen);

    /* Response headers */
    resp_hdrs[0].name      = (uint8_t *)":status";
    resp_hdrs[0].namelen   = 7;
    resp_hdrs[0].value     = (uint8_t *)"200";
    resp_hdrs[0].valuelen  = 3;
    resp_hdrs[0].flags     = NGHTTP2_NV_FLAG_NONE;
    resp_hdrs[1].name      = (uint8_t *)"content-type";
    resp_hdrs[1].namelen   = 12;
    resp_hdrs[1].value     = (uint8_t *)"application/grpc";
    resp_hdrs[1].valuelen  = 16;
    resp_hdrs[1].flags     = NGHTTP2_NV_FLAG_NONE;

    if ((src = malloc(sizeof *src)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    src->data        = frame;
    src->len         = framelen;
    src->offset      = 0;
    src->session     = gc->gc_session;
    src->stream_id   = stream_id;
    src->grpc_status   = grpc_status;
    src->grpc_message  = grpc_msg ? strdup(grpc_msg) : NULL;
    frame = NULL; /* src now owns frame */

    dp.source.ptr    = src;
    dp.read_callback = buf_data_source_cb;
    src = NULL; /* dp now owns src */

    if (nghttp2_submit_response(gc->gc_session, stream_id,
                                resp_hdrs, 2, &dp) != 0){
        clixon_err(OE_NGHTTP2, 0, "nghttp2_submit_response");
        goto done;
    }
    /* NOTE: nghttp2_session_send() is intentionally NOT called here.
     * The trailer is submitted from buf_data_source_cb when called during
     * nghttp2_session_send() in grpc_connection_cb, after recv returns. */
    retval = 0;
 done:
    if (frame)
        free(frame);
    if (src)
        free(src);
    return retval;
}

/*! Send a gRPC response with a pre-framed (already LPM-wrapped) buffer
 *
 * Like grpc_send_response() but the caller provides a buffer that already
 * contains N concatenated Length-Prefixed-Message frames.  Used for Subscribe
 * ONCE which must send multiple SubscribeResponse messages before trailers.
 *
 * @param[in]  gc          Connection
 * @param[in]  stream_id   HTTP/2 stream
 * @param[in]  framed_buf  Pre-built LPM-framed buffer (caller owns)
 * @param[in]  framed_len  Length of framed_buf
 * @param[in]  grpc_status gRPC status code (0 = OK)
 * @param[in]  grpc_msg    Human-readable error message (may be NULL); copied
 * @retval     0           OK
 * @retval    -1           Error
 */
int
grpc_send_framed(void           *gc_opaque,
                 int32_t         stream_id,
                 const uint8_t  *framed_buf,
                 size_t          framed_len,
                 int             grpc_status,
                 const char     *grpc_msg)
{
    grpc_conn_t        *gc = gc_opaque;
    int                 retval = -1;
    uint8_t            *frame = NULL;
    nghttp2_nv          resp_hdrs[2];
    nghttp2_data_provider dp;
    buf_src_t          *src = NULL;

    if ((frame = malloc(framed_len)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memcpy(frame, framed_buf, framed_len);

    resp_hdrs[0].name      = (uint8_t *)":status";
    resp_hdrs[0].namelen   = 7;
    resp_hdrs[0].value     = (uint8_t *)"200";
    resp_hdrs[0].valuelen  = 3;
    resp_hdrs[0].flags     = NGHTTP2_NV_FLAG_NONE;
    resp_hdrs[1].name      = (uint8_t *)"content-type";
    resp_hdrs[1].namelen   = 12;
    resp_hdrs[1].value     = (uint8_t *)"application/grpc";
    resp_hdrs[1].valuelen  = 16;
    resp_hdrs[1].flags     = NGHTTP2_NV_FLAG_NONE;

    if ((src = malloc(sizeof *src)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    src->data        = frame;
    src->len         = framed_len;
    src->offset      = 0;
    src->session     = gc->gc_session;
    src->stream_id   = stream_id;
    src->grpc_status   = grpc_status;
    src->grpc_message  = grpc_msg ? strdup(grpc_msg) : NULL;
    frame = NULL;

    dp.source.ptr    = src;
    dp.read_callback = buf_data_source_cb;
    src = NULL;

    if (nghttp2_submit_response(gc->gc_session, stream_id,
                                resp_hdrs, 2, &dp) != 0){
        clixon_err(OE_NGHTTP2, 0, "nghttp2_submit_response");
        goto done;
    }
    retval = 0;
 done:
    if (frame)
        free(frame);
    if (src)
        free(src);
    return retval;
}

/*! nghttp2 frame recv callback — dispatch complete requests */
static int
on_frame_recv_cb(nghttp2_session     *session,
                 const nghttp2_frame *frame,
                 void                *user_data)
{
    grpc_conn_t   *gc = user_data;
    grpc_stream_t *gs;
    uint8_t       *resp_buf = NULL;
    size_t         resp_len = 0;
    const uint8_t *req_proto = NULL;
    size_t         req_proto_len = 0;
    int            gst;

    clixon_debug(CLIXON_DBG_DEFAULT, "frame type:%u flags:0x%02x stream:%d",
                 frame->hd.type, frame->hd.flags, frame->hd.stream_id);
    if (frame->hd.type != NGHTTP2_DATA &&
        frame->hd.type != NGHTTP2_HEADERS)
        return 0;
    if (!(frame->hd.flags & NGHTTP2_FLAG_END_STREAM))
        return 0;

    if ((gs = grpc_stream_get(gc, frame->hd.stream_id)) == NULL){
        clixon_log(gc->gc_h, LOG_DEBUG, "on_frame_recv_cb: no stream state for id=%d", frame->hd.stream_id);
        return 0;
    }

    /* Extract protobuf payload from gRPC Length-Prefixed-Message */
    if (gs->gs_body != NULL && gs->gs_bodylen >= GRPC_PREFIX_LEN){
        req_proto     = gs->gs_body + GRPC_PREFIX_LEN;
        req_proto_len = gs->gs_bodylen - GRPC_PREFIX_LEN;
    }

    clixon_log(gc->gc_h, LOG_DEBUG, "on_frame_recv_cb: dispatch path='%s' bodylen=%zu",
               gs->gs_path ? gs->gs_path : "(null)", gs->gs_bodylen);
    /* Dispatch by path */
    if (gs->gs_path != NULL){
        if (strcmp(gs->gs_path, "/gnmi.gNMI/Capabilities") == 0){
            gst = GRPC_INTERNAL;
            if (gnmi_capabilities(gc->gc_h, req_proto, req_proto_len,
                                  &resp_buf, &resp_len, &gst) < 0){
                grpc_send_response(gc, frame->hd.stream_id, NULL, 0,
                                   gst, clixon_err_str());
            }
            else {
                grpc_send_response(gc, frame->hd.stream_id, resp_buf, resp_len,
                                   GRPC_OK, NULL);
                if (resp_buf)
                    free(resp_buf);
            }
        }
        else if (strcmp(gs->gs_path, "/gnmi.gNMI/Get") == 0){
            gst = GRPC_INTERNAL;
            if (gnmi_get(gc->gc_h, req_proto, req_proto_len,
                         &resp_buf, &resp_len, &gst) < 0){
                grpc_send_response(gc, frame->hd.stream_id, NULL, 0,
                                   gst, clixon_err_str());
            }
            else {
                grpc_send_response(gc, frame->hd.stream_id, resp_buf, resp_len,
                                   GRPC_OK, NULL);
                if (resp_buf)
                    free(resp_buf);
            }
        }
        else if (strcmp(gs->gs_path, "/gnmi.gNMI/Set") == 0){
            gst = GRPC_INTERNAL;
            if (gnmi_set(gc->gc_h, req_proto, req_proto_len,
                         &resp_buf, &resp_len, &gst) < 0){
                grpc_send_response(gc, frame->hd.stream_id, NULL, 0,
                                   gst, clixon_err_str());
            }
            else {
                grpc_send_response(gc, frame->hd.stream_id, resp_buf, resp_len,
                                   GRPC_OK, NULL);
                if (resp_buf)
                    free(resp_buf);
            }
        }
        else if (strcmp(gs->gs_path, "/gnmi.gNMI/Subscribe") == 0){
            gst = GRPC_INTERNAL;
            if (gnmi_subscribe(gc->gc_h, req_proto, req_proto_len,
                               &resp_buf, &resp_len, &gst) < 0){
                grpc_send_response(gc, frame->hd.stream_id, NULL, 0,
                                   gst, clixon_err_str());
            }
            else {
                grpc_send_framed(gc, frame->hd.stream_id, resp_buf, resp_len,
                                 GRPC_OK, NULL);
                if (resp_buf)
                    free(resp_buf);
            }
        }
        else {
            grpc_send_response(gc, frame->hd.stream_id, NULL, 0,
                               GRPC_UNIMPLEMENTED, "method not implemented");
        }
    }
    grpc_stream_free(gc, gs);
    return 0;
}

/*! nghttp2 stream close callback — clean up stream state */
static int
on_stream_close_cb(nghttp2_session *session,
                   int32_t          stream_id,
                   uint32_t         error_code,
                   void            *user_data)
{
    grpc_conn_t   *gc = user_data;
    grpc_stream_t *gs;

    for (gs = gc->gc_streams; gs != NULL; gs = gs->gs_next){
        if (gs->gs_stream_id == stream_id){
            grpc_stream_free(gc, gs);
            break;
        }
    }
    return 0;
}

/*! Clixon event callback: data available on a gRPC client connection */
static int
grpc_connection_cb(int   s,
                   void *arg)
{
    grpc_conn_t *gc = arg;
    int          rv;

    clixon_log(gc->gc_h, LOG_DEBUG, "grpc_connection_cb: recv start");
    rv = nghttp2_session_recv(gc->gc_session);
    clixon_log(gc->gc_h, LOG_DEBUG, "grpc_connection_cb: recv rv=%d", rv);
    if (rv != 0){
        if (rv != NGHTTP2_ERR_EOF)
            clixon_debug(CLIXON_DBG_DEFAULT, "nghttp2_session_recv: %s",
                         nghttp2_strerror(rv));
        /* Connection closed or error: unregister and free */
        clixon_event_unreg_fd(gc->gc_s, grpc_connection_cb);
        grpc_conn_free(gc);
        return 0;
    }
    /* Flush any pending output */
    nghttp2_session_send(gc->gc_session);
    return 0;
}

/*! Clixon event callback: new client connection on the listening socket */
static int
grpc_accept_cb(int   ss,
               void *arg)
{
    clixon_handle              h = arg;
    int                        cs = -1;
    struct sockaddr_storage    sa;
    socklen_t                  salen = sizeof sa;
    grpc_conn_t               *gc = NULL;
    nghttp2_session_callbacks *cbs = NULL;
    int                        ngerr;
    int                        fl;

    if ((cs = accept(ss, (struct sockaddr *)&sa, &salen)) < 0){
        clixon_err(OE_UNIX, errno, "accept");
        return -1;
    }
    clixon_log(h, LOG_DEBUG, "grpc_accept_cb: accepted fd=%d", cs);
    /* Non-blocking so nghttp2_session_recv returns WOULDBLOCK when no more data */
    {
        fl = fcntl(cs, F_GETFL);
        fcntl(cs, F_SETFL, fl | O_NONBLOCK);
    }
    if ((gc = calloc(1, sizeof *gc)) == NULL){
        clixon_err(OE_UNIX, errno, "calloc");
        close(cs);
        return -1;
    }
    gc->gc_h = h;
    gc->gc_s = cs;

    /* Set up nghttp2 server session */
    nghttp2_session_callbacks_new(&cbs);
    nghttp2_session_callbacks_set_send_callback(cbs, session_send_cb);
    nghttp2_session_callbacks_set_recv_callback(cbs, session_recv_cb);
    nghttp2_session_callbacks_set_on_header_callback(cbs, on_header_cb);
    nghttp2_session_callbacks_set_on_data_chunk_recv_callback(cbs, on_data_chunk_cb);
    nghttp2_session_callbacks_set_on_frame_recv_callback(cbs, on_frame_recv_cb);
    nghttp2_session_callbacks_set_on_stream_close_callback(cbs, on_stream_close_cb);

    ngerr = nghttp2_session_server_new(&gc->gc_session, cbs, gc);
    nghttp2_session_callbacks_del(cbs);
    if (ngerr != 0){
        clixon_log(h, LOG_ERR, "grpc_accept_cb: nghttp2_session_server_new failed: %s",
                   nghttp2_strerror(ngerr));
        free(gc);
        close(cs);
        return -1;
    }

    /* Send HTTP/2 server connection preface (settings frame) */
    if ((ngerr = nghttp2_submit_settings(gc->gc_session, NGHTTP2_FLAG_NONE, NULL, 0)) != 0){
        clixon_log(h, LOG_ERR, "grpc_accept_cb: nghttp2_submit_settings failed: %s",
                   nghttp2_strerror(ngerr));
        nghttp2_session_del(gc->gc_session);
        free(gc);
        close(cs);
        return -1;
    }
    if ((ngerr = nghttp2_session_send(gc->gc_session)) != 0){
        clixon_log(h, LOG_ERR, "grpc_accept_cb: nghttp2_session_send failed: %s",
                   nghttp2_strerror(ngerr));
        nghttp2_session_del(gc->gc_session);
        free(gc);
        close(cs);
        return -1;
    }
    clixon_log(h, LOG_DEBUG, "grpc_accept_cb: session ready, registering fd=%d", cs);

    if (clixon_event_reg_fd(cs, grpc_connection_cb, gc, "grpc client") < 0){
        nghttp2_session_del(gc->gc_session);
        free(gc);
        close(cs);
        return -1;
    }
    /* Add to global connection list for cleanup on exit */
    gc->gc_next = _grpc_conns;
    _grpc_conns = gc;
    return 0;
}

/*! Free all live client connections — called on daemon exit */
void
grpc_conns_free_all(void)
{
    while (_grpc_conns)
        grpc_conn_free(_grpc_conns);
}

/*! Create TCP listening socket and register accept callback
 *
 * @param[in]  h     Clixon handle
 * @param[in]  port  TCP port to listen on
 * @retval     0     OK
 * @retval    -1     Error
 */
int
grpc_listen_init(clixon_handle h,
                 uint16_t      port)
{
    int                 retval = -1;
    int                 ss = -1;
    struct sockaddr_in  sin;
    int                 on = 1;

    if ((ss = socket(AF_INET, SOCK_STREAM, 0)) < 0){
        clixon_err(OE_UNIX, errno, "socket");
        goto done;
    }
    setsockopt(ss, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
    memset(&sin, 0, sizeof sin);
    sin.sin_family      = AF_INET;
    sin.sin_addr.s_addr = INADDR_ANY;
    sin.sin_port        = htons(port);
    if (bind(ss, (struct sockaddr *)&sin, sizeof sin) < 0){
        clixon_err(OE_UNIX, errno, "bind port %u", port);
        goto done;
    }
    if (listen(ss, 16) < 0){
        clixon_err(OE_UNIX, errno, "listen");
        goto done;
    }
    if (clixon_event_reg_fd(ss, grpc_accept_cb, h, "grpc server") < 0)
        goto done;
    clixon_log(h, LOG_NOTICE, "gRPC listening on port %u", port);
    retval = 0;
 done:
    if (retval < 0 && ss >= 0)
        close(ss);
    return retval;
}
