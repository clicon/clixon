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
 * clicon_log_init
 * global error variables are set:
 *  clicon_errno, clicon_suberrno, clicon_err_reason.
 */

#ifndef _CLIXON_ERR_H_
#define _CLIXON_ERR_H_

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
enum clicon_err{
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
    OE_SSL,      /* Openssl errors, see eg ssl_get_error */
    OE_SNMP ,    /* Netsnmp error */    
    OE_NGHTTP2,  /* nghttp2 errors, see HAVE_LIBNGHTTP2 */
};

/* Clixon error category log callback 
 * @param[in]    handle  Application-specific handle
 * @param[in]    suberr  Application-specific handle
 * @param[out]   cb      Read log/error string into this buffer
 */
typedef int (clixon_cat_log_cb)(void *handle, int suberr, cbuf *cb);

/*
 * Variables
 * XXX: should not be global
 */
extern int  clicon_errno;    /* CLICON errors (see clicon_err) */
extern int  clicon_suberrno; /* Eg orig errno */
extern char clicon_err_reason[ERR_STRLEN];

/*
 * Macros
 */
#define clicon_err(e,s,_fmt, args...)  clicon_err_fn(__FUNCTION__, __LINE__, (e), (s), _fmt , ##args)

/*
 * Prototypes
 */
int   clicon_err_reset(void);
int   clicon_err_fn(const char *fn, const int line, int category, int err, const char *format, ...) __attribute__ ((format (printf, 5, 6)));
char *clicon_strerror(int err);
void *clicon_err_save(void);
int   clicon_err_restore(void *handle);
int   clixon_err_cat_reg(enum clicon_err category, void *handle, clixon_cat_log_cb logfn);
int   clixon_err_exit(void);

#endif  /* _CLIXON_ERR_H_ */
