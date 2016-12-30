/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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

#endif  /* _CLIXON_ERR_H_ */
