/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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

 * Event notification streams according to RFC5277
 */
#ifndef _CLIXON_STREAM_H_
#define _CLIXON_STREAM_H_

/*
 * Constants
 */
/* Default STREAM namespace (see rfc5277 3.1)
 * From RFC8040: 
 *  The structure of the event data is based on the <notification>
 *  element definition in Section 4 of [RFC5277].  It MUST conform to the
 *  schema for the <notification> element in Section 4 of [RFC5277],
 *  using the XML namespace as defined in the XSD as follows:
 *     urn:ietf:params:xml:ns:netconf:notification:1.0
 * It is used everywhere in yangmodels, but not in openconfig
 */
#define NOTIFICATION_RFC5277_NAMESPACE "urn:ietf:params:xml:ns:netconf:notification:1.0"

/*
 * Then there is also this namespace that is only used in RFC5277 seems to be for "netconf"
 * events. The usage seems wrong here,...
 */
#define EVENT_RFC5277_NAMESPACE "urn:ietf:params:xml:ns:netmod:notification"

/*
 * Types
 */
/* Subscription callback 
 * @param[in]  h     Clicon handle
 * @param[in]  op    Operation: 0 OK, 1 Close
 * @param[in]  event Event as XML
 * @param[in]  arg   Extra argument provided in stream_ss_add
 * @see stream_ss_add
 */
typedef	int (*stream_fn_t)(clicon_handle h, int op, cxobj *event, void *arg);

struct stream_subscription{
    qelem_t                     ss_q;   /* queue header */
    char                       *ss_stream; /* Name of associated stream */
    char                       *ss_xpath;  /* Filter selector as xpath */
    struct timeval              ss_starttime; /* Replay starttime */
    struct timeval              ss_stoptime; /* Replay stoptime */
    stream_fn_t                 ss_fn;     /* Callback when event occurs */
    void                       *ss_arg;    /* Callback argument */
};

/* Replay time-series */
struct stream_replay{
    qelem_t        r_q;   /* queue header */
    struct timeval r_tv;  /* time index */
    cxobj         *r_xml; /* event in xml form */
};

/* See RFC8040 9.3, stream list, no replay support for now
 */
struct event_stream{
    qelem_t              es_q;   /* queue header */
    char                *es_name; /* name of notification event stream */
    char                *es_description;
    struct stream_subscription *es_subscription;
    int                  es_replay_enabled; /* set if replay is enables */
    struct timeval       es_retention; /* replay retention - how much to save */
    struct stream_replay *es_replay;

};
typedef struct event_stream event_stream_t;

/*
 * Prototypes
 */
event_stream_t *stream_find(clicon_handle h, const char *name);
int stream_add(clicon_handle h, const char *name, const char *description, int replay_enabled, struct timeval *retention);
int stream_delete_all(clicon_handle h, int force);
int stream_get_xml(clicon_handle h, int access, cbuf *cb);
int stream_timer_setup(int fd, void *arg);
/* Subscriptions */
struct stream_subscription *stream_ss_add(clicon_handle h, char *stream,
		  char *xpath, struct timeval *start, struct timeval *stop,
		  stream_fn_t fn, void *arg);
int stream_ss_rm(clicon_handle h, event_stream_t *es, struct stream_subscription *ss, int force);
struct stream_subscription *stream_ss_find(event_stream_t *es,
					   stream_fn_t fn, void *arg);
int stream_ss_delete_all(clicon_handle h, stream_fn_t fn, void *arg);
int stream_ss_delete(clicon_handle h, char *name, stream_fn_t fn, void *arg);

int stream_notify_xml(clicon_handle h, char *stream, cxobj *xml);
#if defined(__GNUC__) && __GNUC__ >= 3
int stream_notify(clicon_handle h, const char *stream, const char *event, ...)  __attribute__ ((format (printf, 3, 4)));
#else
int stream_notify(clicon_handle h, const char *stream, const char *event, ...);
#endif

/* Replay */
int stream_replay_add(event_stream_t *es, struct timeval *tv, cxobj *xv);
int stream_replay_trigger(clicon_handle h, char *stream, stream_fn_t fn, void *arg);

/* Experimental publish streams using SSE. CLIXON_PUBLISH_STREAMS should be set */
int stream_publish(clicon_handle h, const char *stream);
int stream_publish_init();
int stream_publish_exit();

#endif /* _CLIXON_STREAM_H_ */
