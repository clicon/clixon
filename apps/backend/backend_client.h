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
 */

#ifndef _BACKEND_CLIENT_H_
#define _BACKEND_CLIENT_H_

/*
 * Types
 */ 
/*
 * Client entry.
 * Keep state about every connected client.
 */
struct client_entry{
    struct client_entry   *ce_next;  /* The clients linked list */
    struct sockaddr        ce_addr;  /* The clients (UNIX domain) address */
    int                    ce_s;     /* stream socket to client */
    int                    ce_nr;    /* Client number (for dbg/tracing) */
    int                    ce_stat_in; /* Nr of received msgs from client */
    int                    ce_stat_out;/* Nr of sent msgs to client */
    int                    ce_pid;   /* Process id */
    int                    ce_uid;   /* User id of calling process */
    clicon_handle          ce_handle; /* clicon config handle (all clients have same?) */
    struct client_subscription   *ce_subscription; /* notification subscriptions */
};

/* Notification subscription info 
 * @see subscription in config_handle.c
 */
struct client_subscription{
    struct client_subscription *su_next;
    int                  su_s; /* stream socket */
    enum format_enum     su_format; /* format of notification stream */
    char                *su_stream;
    char                *su_filter;
};

/*
 * Prototypes
 */ 
int backend_client_rm(clicon_handle h, struct client_entry *ce);
int config_snapshot(clicon_handle h, char *dbname, char *dir);

int from_client(int fd, void *arg);

#endif  /* _BACKEND_CLIENT_H_ */
