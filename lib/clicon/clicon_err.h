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
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * Errors may be syslogged using LOG_ERR, and printed to stderr, as controlled by 
 * clicon_log_init
 * global error variables are set:
 *  clicon_errno, clicon_suberrno, clicon_err_reason.
 */

#ifndef _CLICON_ERR_H_
#define _CLICON_ERR_H_

/*
 * Constants
 */ 
#define ERR_STRLEN 256

/*
 * Types
 * Add error here, but must also add an entry in EV variable.
 */ 
enum clicon_err{
    /* 0 means error not set) */  
    OE_DB = 1,   /* database registries */
    OE_DEMON,    /* demons: pidfiles, etc */
    OE_EVENTS,   /* events, filedescriptors, timeouts */
    OE_CFG,      /* config commit / quagga */
    OE_PROTO,    /* config/client communication */
    OE_REGEX,    /* Regexp error */
    OE_UNIX,     /* unix/linux syscall error */
    OE_SYSLOG,   /* syslog error */
    OE_ROUTING,  /* routing daemon error (eg quagga) */
    OE_XML,      /* xml parsing etc */
    OE_PLUGIN,   /* plugin loading, etc */
    OE_YANG ,    /* Yang error */
    OE_FATAL,    /* Fatal error */
    OE_UNDEF,
};

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
int clicon_err_reset(void);
int clicon_err_fn(const char *fn, const int line, int level, int err, char *format, ...);
char *clicon_strerror(int err);
void *clicon_err_save(void);
int clicon_err_restore(void *handle);

#endif  /* _CLICON_ERR_H_ */
