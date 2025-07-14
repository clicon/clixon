/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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
 * Errors may be syslogged using LOG_ERR, and printed to stderr, as controlled by
 * clixon_log_init
 * Details about the errors may be retreievd by access functions
 *  clixon_err_reason(), clixon_err_subnr(), etc
 */

#ifndef _CLIXON_ERR_H_
#define _CLIXON_ERR_H_

#include "clixon_xml.h"			/* for cxobj */

/*
 * Constants
 */
#define ERR_STRLEN 256

/* Special error number for clicon_suberrno
 * For catching xml parse errors as exceptions
 */
#define XMLPARSE_ERRNO 898943

/*
 * Types
 * Add error category here,
 * @see EV variable in clixon_err.c but must also add an entry there
 */
enum clixon_err{
    /* 0 means error not set) */
    OE_DB = 1,   /* database registries */
    OE_DAEMON,   /* daemons: pidfiles, etc */
    OE_EVENTS,   /* events, filedescriptors, timeouts */
    OE_CFG,      /* configuration */
    OE_NETCONF,  /* Netconf error */
    OE_PROTO,    /* config/client communication */
    OE_REGEX,    /* Regexp error */
    OE_UNIX,     /* unix/linux syscall error */
    OE_SYSLOG,   /* syslog error */
    OE_ROUTING,  /* routing daemon error (eg quagga) */
    OE_XML,      /* xml parsing */
    OE_JSON,     /* json parsing */
    OE_RESTCONF, /* RESTCONF errors */
    OE_PLUGIN,   /* plugin loading, etc */
    OE_YANG ,    /* Yang error */
    OE_FATAL,    /* Fatal error */
    OE_UNDEF,
    /*-- From here error extensions using clixon_err_cat_reg, XXX register dynamically? --*/
    OE_SSL,      /* Openssl errors, see eg ssl_get_error and clixon_openssl_log_cb */
    OE_SNMP ,    /* Netsnmp error */
    OE_NGHTTP2,  /* nghttp2 errors, see HAVE_LIBNGHTTP2 */
};

/*! Clixon error category log callback
 *
 * @param[in]    handle  Application-specific handle
 * @param[in]    suberr  Application-specific handle
 * @param[out]   cb      Read log/error string into this buffer
 */
typedef int (clixon_cat_log_cb)(void *handle, int suberr, cbuf *cb);

/*
 * Macros
 */
#define clixon_err(c,s,_fmt, args...) clixon_err_fn(NULL, __func__, __LINE__, (c), (s), NULL, _fmt , ##args)
#define clixon_err_netconf(h,c,s,x,_fmt, args...) clixon_err_fn((h), __func__, __LINE__, (c), (s), (x), _fmt , ##args)

/*
 * Prototypes
 */
int   clixon_err_init(clixon_handle h);
int   clixon_err_category(void);
int   clixon_err_subnr(void);
char *clixon_err_reason(void);
char *clixon_err_str(void);
int   clixon_err_reset(void);
int   clixon_err_fn(clixon_handle h, const char *fn, const int line, int category, int suberr, cxobj *xerr, const char *format, ...) __attribute__ ((format (printf, 7, 8)));
int   netconf_err2cb(clixon_handle h, cxobj *xerr, cbuf *cberr);

void *clixon_err_save(void);
int   clixon_err_restore(void *handle);
int   clixon_err_cat_reg(enum clixon_err category, void *handle, clixon_cat_log_cb logfn);
int   clixon_err_exit(void);

/* doesnt work if arg != NULL */
#define clixon_netconf_error(h, x, f, a) clixon_err_fn((h), __func__, __LINE__, OE_XML, 0,(x), (f))

#endif  /* _CLIXON_ERR_H_ */
