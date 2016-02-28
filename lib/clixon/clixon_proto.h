/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * Protocol to communicate with CLICON config daemon
 */

#ifndef _CLIXON_PROTO_H_
#define _CLIXON_PROTO_H_

/*
 * Types
 */
enum format_enum{
    MSG_NOTIFY_TXT, /* means filter works on strings */
    MSG_NOTIFY_XML, /* means filter works on xml */
};

/* See also map_type2str in clicon_proto.c */
enum clicon_msg_type{
    CLICON_MSG_COMMIT = 1,    /* Commit a configuration db->running_db
			    current state, set running_db. Body is:
			    1. uint32: (1)snapshot while doing commit, (0) dont
			    2. uint32: (1)save to startup-config, (0) dont
			    3. string: name of 'from' database (eg candidate)
			    4. string: name of 'to' database (eg current)
			 */
    CLICON_MSG_VALIDATE,	/* Validate settings in a database. Body is:
			   1. string: name of database
			*/
    CLICON_MSG_CHANGE,   /* Change a (single) database entry:
			  1. uint32: operation: OP_MERGE/OP_REPLACE/OP_REMOVE
			  2. uint32: length of value string
			  3. string: name of database to change (eg current)
			  4. string: key
			  5. string: value
			 */
    CLICON_MSG_XMLPUT, /* Send database entries as XML to backend daemon
			  1. uint32: operation: LV_SET/LV_DELETE
			  2. string: name of database to change (eg current)
			  3. string: XML data
			*/

    CLICON_MSG_SAVE,    /* Save config state from db to a file in backend. Body is:
			  1. uint32: make snapshot (1), dont(0)
			  2. string: name of database to save from (eg running)
			  3. string: filename to write. If snapshot=1, then this
			             is empty.
		       */
    CLICON_MSG_LOAD,    /* Load config state from file in backend to db via XML. Body is:
			  1. uint32: whether to replace/initdb before load (1) or 
			             merge (0).
			  2. string: name of database to load into (eg running)
			  3. string: filename to load from

		       */
    CLICON_MSG_COPY,    /* Copy from file to file in backend. Body is:
			  1. string: filename to copy from
			  2. string: filename to copy to
		       */
    CLICON_MSG_RM ,    /* Delete file. Body is:
			  1. string: filename to delete
		       */

    CLICON_MSG_INITDB ,  /* (Re-)Initialize a database. Body is:
			  1. string: filename of db to initialize
		       */
    CLICON_MSG_LOCK ,   /* Lock a database. Body is
			  1. name of db
			  The reply will be OK, or ERROR. If error is
			  lock-denied, the session-id of the locking
			  entity is returned (cf netconf)
		       */
    CLICON_MSG_UNLOCK , /* Unlock a database. Body is:
			  1. name of db *
		       */
    CLICON_MSG_KILL, /* Kill (other) session:
			  1. session-id
		       */
    CLICON_MSG_DEBUG, /* Debug
			  1. session-id
		       */
    CLICON_MSG_CALL ,   /* Backend plugin call request. Body is:
			  1. struct clicon_msg_call_req *
		       */
    CLICON_MSG_SUBSCRIPTION, /* Create a new notification subscription. 
			        Body is:
			        1. int: status off/on
			        1. int: format (enum format_enum)
			        2. string: name of notify stream 
			        3. string: filter, if format=xml: xpath, if text: fnmatch */
    CLICON_MSG_OK,       /* server->client reply */
    CLICON_MSG_NOTIFY,   /* Notification. Body is:
			    1. int: loglevel
			    2. event: log message. */
    CLICON_MSG_ERR       /* server->client reply. 
			    Body is:
			    1. uint32: man error category
			    2. uint32: sub-error
			    3. string: reason
			 */
};

/* Protocol message header */
struct clicon_msg {
    uint16_t    op_len;      /* length of message. */
    uint16_t    op_type;     /* message type, see enum clicon_msg_type */
    char        op_body[0];  /* rest of message, actual data */
};

/* Generic clicon message. Either generic/internal message
   or application-specific backend plugin downcall request */
struct clicon_msg_call_req {
    uint16_t	  cr_len;	/* Length of total request */
    uint16_t	  cr_op;        /* Generic application-defined operation */
    char	 *cr_plugin;	/* Name of backend plugin, NULL -> internal
				   functions */
    char	 *cr_func;	/* Function name in plugin (or internal) */
    uint16_t	  cr_arglen;	/* App specific argument length */
    char	 *cr_arg;	/* App specific argument */
    char	  cr_data[0];	/* Allocated data containng the above */
};

/*
 * Prototypes
 */ 
#ifndef LIBCLICON_API
int clicon_connect_unix(char *sockpath);

int clicon_rpc_connect_unix(struct clicon_msg *msg, 
			    char *sockpath,
			    char **data, 
			    uint16_t *datalen, 
			    int      *sock0,
			    const char *label);

int clicon_rpc_connect_inet(struct clicon_msg *msg, 
			    char *dst, 
			    uint16_t port,
			    char **data, 
			    uint16_t *datalen,
			    int      *sock0,
			    const char *label);

int clicon_rpc(int s, struct clicon_msg *msg, char **data, uint16_t *datalen,
	    const char *label);

#endif
int clicon_msg_send(int s, struct clicon_msg *msg);

int clicon_msg_rcv(int s, struct clicon_msg **msg, 
		  int *eof, const char *label);

int send_msg_notify(int s, int level, char *event);

int send_msg_reply(int s, uint16_t type, char *data, uint16_t datalen);

int send_msg_ok(int s);

int send_msg_err(int s, int err, int suberr, char *format, ...);





#endif  /* _CLIXON_PROTO_H_ */
