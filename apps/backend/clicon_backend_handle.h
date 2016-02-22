/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * Part of the external API to plugins. Applications should not include
 * this file directly (only via clicon_backend.h).
 * Internal code should include this
 */

#ifndef _CLICON_BACKEND_HANDLE_H_
#define _CLICON_BACKEND_HANDLE_H_

/*
 * Types
 */

/*! Generic downcall registration. 
 * Enables any function to be called from (cli) frontend
 * to backend. Like an RPC on application-level.
 */
typedef int (*downcall_cb)(clicon_handle h, uint16_t op, uint16_t len, 
			   void *arg, uint16_t *retlen, void **retarg);

/*
 * Log for netconf notify function (config_client.c)
 */
int backend_notify(clicon_handle h, char *stream, int level, char *txt);
int backend_notify_xml(clicon_handle h, char *stream, int level, cxobj *x);

/* subscription callback */
typedef	int (*subscription_fn_t)(clicon_handle, void *filter, void *arg);

/* Notification subscription info 
 * @see client_subscription in config_client.h
 */
struct handle_subscription{
    struct handle_subscription *hs_next;
    enum format_enum     hs_format; /*  format (enum format_enum) XXX not needed? */
    char                *hs_stream; /* name of notify stream */
    char                *hs_filter; /* filter, if format=xml: xpath, if text: fnmatch */
    subscription_fn_t    hs_fn;     /* Callback when event occurs */
    void                *hs_arg;    /* Callback argument */
};

struct handle_subscription *subscription_add(clicon_handle h, char *stream, 
					     enum format_enum format, char *filter, 
					     subscription_fn_t fn, void *arg);

int subscription_delete(clicon_handle h, char *stream, 
			subscription_fn_t fn, void *arg);

struct handle_subscription *subscription_each(clicon_handle h,
					      struct handle_subscription *hprev);
#endif /* _CLICON_BACKEND_HANDLE_H_ */
