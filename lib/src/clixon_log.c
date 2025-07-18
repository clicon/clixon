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
 * Regular logging and debugging. Syslog using levels.
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <syslog.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/types.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_map.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_debug.h"
#include "clixon_log.h"
#include "clixon_netconf_lib.h"
#include "clixon_xml_io.h"
#include "clixon_yang_module.h"
#include "clixon_plugin.h"

/*
 * Local Variables
 */

/* Cache handle since some error calls does not have handle access */
static clixon_handle _log_clixon_h    = NULL;

/* Bitmask whether to log to syslog or stderr: CLIXON_LOG_STDERR | CLIXON_LOG_SYSLOG */
static uint16_t _log_flags = 0x0;

/* Set to open file to write debug messages directly to file */
static FILE *_log_file = NULL;

/* Set to 1 if syslog openlog() has been called */
static int _log_openlog = 0;

/* Truncate debug strings to this length. 0 means unlimited */
static int _log_trunc = 0;

/*! Mapping between Clixon debug symbolic names <--> bitfields
 *
 * Also inclode shorthands: s|e|o|f|n
 * Mapping between specific bitfields and symbolic names, note only perfect matches
 * @see typedef log_destination_t in clixon-config.yang
 */
static const map_str2int logdstmap[] = {
    {"syslog",   CLIXON_LOG_SYSLOG},
    {"s",        CLIXON_LOG_SYSLOG},
    {"stderr",   CLIXON_LOG_STDERR},
    {"e",        CLIXON_LOG_STDERR},
    {"stdout",   CLIXON_LOG_STDOUT},
    {"o",        CLIXON_LOG_STDOUT},
    {"file",     CLIXON_LOG_FILE},
    {"f",        CLIXON_LOG_FILE},
    {"n",        0x0},
    {NULL,       -1}
};

/*! Map from clixon debug (specific) bitmask to string
 *
 * @param[in] int  Bitfield, see CLIXON_LOG_SYSLOG and others
 * @retval    str  String representation of bitfield
 */
char *
clixon_logdst_key2str(int keyword)
{
    return (char*)clicon_int2str(logdstmap, keyword);
}

/*! Map from clixon log destination symbolic string to bitfield
 *
 * @param[in] str  String representation of Clixon log destination bit
 * @retval    int  Bit representation of bitfield
 */
int
clixon_logdst_str2key(char *str)
{
    return clicon_str2int(logdstmap, str);
}

/*! Initialize system logger.
 *
 * Make syslog(3) calls with specified ident and gates calls of level upto specified level (upto).
 * May also print to stderr, if err is set.
 * Applies to clixon_err() and clixon_debug too
 *
 * @param[in]  h       Clixon handle
 * @param[in]  ident   prefix that appears on syslog (eg 'cli')
 * @param[in]  upto    log priority, eg LOG_DEBUG,LOG_INFO,...,LOG_EMERG (see syslog(3)).
 * @param[in]  flags   Log destination bitmask
 * @retval     0       OK
 * @code
 *  clixon_log_init(__PROGRAM__, LOG_INFO, CLIXON_LOG_STDERR); 
 * @endcode
 */
int
clixon_log_init(clixon_handle h,
                char         *ident,
                int           upto,
                uint16_t      flags)
{
    _log_clixon_h = h;
    _log_flags = flags;
    if (flags & CLIXON_LOG_SYSLOG){
        if (setlogmask(LOG_UPTO(upto)) < 0)
            /* Cant syslog here */
            fprintf(stderr, "%s: setlogmask: %s\n", __func__, strerror(errno));
        _log_openlog = 1;
        /* LOG_PUSER is achieved by direct stderr logs in clixon_log.
         * In musl libc, closelog() may cause "Invalid file descriptor" error
         * which is seen by valgrind unless LOG_NDELAY option is provided.
         */
        openlog(ident, LOG_PID | LOG_NDELAY, LOG_USER);
    }
    return 0;
}

/*! Exit system logger
 */
int
clixon_log_exit(void)
{
    if (_log_file)
        fclose(_log_file);
    if (_log_openlog){
        closelog();
        _log_openlog = 0;
    }
    return 0;
}

/*! Utility function to set log destination/flag using command-line option
 *
 * @param[in]  c  Log option,one of s,f,e,o
 * @retval     0  One of CLIXON_LOG_SYSLOG|STDERR|STDOUT|FILE
 * @retval    -1  No match
 */
int
clixon_log_opt(char c)
{
    int logdst = -1;

    switch (c){
    case 's':
        logdst = CLIXON_LOG_SYSLOG;
        break;
    case 'e':
        logdst = CLIXON_LOG_STDERR;
        break;
    case 'o':
        logdst = CLIXON_LOG_STDOUT;
        break;
    case 'f':
        logdst = CLIXON_LOG_FILE;
        break;
    case 'n':
        logdst = 0;
        break;
    default:
        break;
    }
    return logdst;
}

/*! If log flags include CLIXON_LOG_FILE, set the file 
 *
 * @param[in]   filename   File to log to
 * @retval      0          OK
 * @retval     -1          Error
 * @see clixon_debug_init where a strean
 */
int
clixon_log_file(char *filename)
{
    if (_log_file)
        fclose(_log_file);
    if ((_log_file = fopen(filename, "a")) == NULL){
        fprintf(stderr, "fopen: %s\n", strerror(errno)); /* dont use clixon_err here due to recursion */
        return -1;
    }
    return 0;
}

/*! Get log flags
 */
uint16_t
clixon_logflags_get(void)
{
    return _log_flags;
}

/*! Replace log flags
 */
int
clixon_logflags_set(uint16_t flags)
{
    _log_flags = flags;
    return 0;
}

/*! Truncate log/debug string length
 *
 * @see  CLICON_LOG_STRING_LIMIT option
 */
int
clixon_log_string_limit_set(size_t sz)
{
    _log_trunc = sz;
    return 0;
}

/*! Get truncate log/debug string length
 */
size_t
clixon_log_string_limit_get(void)
{
    return _log_trunc;
}

/*! Translate month number (0..11) to a three letter month name
 *
 * @param[in] md  month number, where 0 is january
 */
static char *
mon2name(int md)
{
    switch(md){
    case 0: return "Jan";
    case 1: return "Feb";
    case 2: return "Mar";
    case 3: return "Apr";
    case 4: return "May";
    case 5: return "Jun";
    case 6: return "Jul";
    case 7: return "Aug";
    case 8: return "Sep";
    case 9: return "Oct";
    case 10: return "Nov";
    case 11: return "Dec";
    default:
        break;
    }
    return NULL;
}

/*! Mimic syslog and print a time on file f
 */
static int
flogtime(FILE *f)
{
    struct timeval tv;
    struct tm tm;

    gettimeofday(&tv, NULL);
    localtime_r((time_t*)&tv.tv_sec, &tm);
    fprintf(f, "%s %2d %02d:%02d:%02d.%06ld: ",
            mon2name(tm.tm_mon), tm.tm_mday,
            tm.tm_hour, tm.tm_min, tm.tm_sec,
            tv.tv_usec);
    return 0;
}

#ifdef NOTUSED
/*
 * Mimic syslog and print a time on string s
 * String returned needs to be freed.
 */
static char *
slogtime(void)
{
    struct timeval tv;
    struct tm     *tm;
    char           *str;

    /* Example: "Apr 14 11:30:52: " len=17+1 */
    if ((str = malloc(18)) == NULL){
        fprintf(stderr, "%s: malloc: %s\n", __func__, strerror(errno));
        return NULL;
    }
    gettimeofday(&tv, NULL);
    tm = localtime((time_t*)&tv.tv_sec);
    snprintf(str, 18, "%s %2d %02d:%02d:%02d: ",
             mon2name(tm->tm_mon), tm->tm_mday,
             tm->tm_hour, tm->tm_min, tm->tm_sec);
    return str;
}
#endif

/*! Make a logging call to syslog (or stderr).
 *
 * @param[in]   level log level, eg LOG_DEBUG,LOG_INFO,...,LOG_EMERG. Thisis OR:d with facility == LOG_USER
 * @param[in]   msg   Message to print as argv.
 * This is the _only_ place the actual syslog (or stderr) logging is made in clicon,..
 * @note syslog makes its own filtering, but if log to stderr we do it here
 * @see  clixon_debug
 */
int
clixon_log_str(int   level,
               char *msg)
{
    /* Remove trailing CR if any */
    if (strlen(msg) && msg[strlen(msg)-1] == '\n')
        msg[strlen(msg)-1] = '\0';
    if (_log_flags & CLIXON_LOG_SYSLOG){
        static int _recurse = 0;
        /* avoid mutex if called recursively */
        if (_recurse++ == 0){
            syslog(LOG_MAKEPRI(LOG_USER, level), "%s", msg);
            _recurse = 0;
        }
    }
   /* syslog makes own filtering, we do it here:
    * if normal (not debug) then filter loglevels >= debug
    */
    if (clixon_debug_get() == 0 && level >= LOG_DEBUG)
        goto done;
    if (_log_flags & CLIXON_LOG_STDERR){
        flogtime(stderr);
        fprintf(stderr, "%s\n", msg);
    }
    if (_log_flags & CLIXON_LOG_STDOUT){
        flogtime(stdout);
        fprintf(stdout, "%s\n", msg);
    }
    if ((_log_flags & CLIXON_LOG_FILE) && _log_file){
        flogtime(_log_file);
        fprintf(_log_file, "%s\n", msg);
        fflush(_log_file);
    }
    /* Enable this if you want syslog in a stream. But there are problems with
     * recursion
     */
 done:
    return 0;
}

/*! Make a logging call to syslog using variable arg syntax.
 *
 * Do not use this fn directly, use the clixon_log() macro
 * @param[in]  h      Clixon handle (may be NULL)
 * @param[in]  user   If set, invoke user callback
 * @param[in]  level  Log level, eg LOG_DEBUG,LOG_INFO,...,LOG_EMERG. This 
 *                    is OR:d with facility == LOG_USER
 * @param[in]  x      XML tree that is logged without prettyprint
 * @param[in]  format Message to print as argv.
 * @retval     0      OK
 * @retval    -1      Error
 * @code
        clixon_log(h, LOG_NOTICE, "%s: dump to dtd not supported", __PROGRAM__);
 * @endcode
 * @see clixon_log_init clixon_log_str 
 * The reason the "user" parameter is present is that internal calls (eg from clixon_err) may not
 * want to invoke user callbacks a second time.
 */
int
clixon_log_fn(clixon_handle h,
              int           user,
              int           level,
              cxobj        *x,
              const char   *format, ...)
{
    int     retval = -1;
    va_list ap;
    size_t  trunc;
    cbuf   *cb = NULL;

    if (h == NULL)     /* Accept NULL, use saved clixon handle */
        h = _log_clixon_h;
    if (user){
        va_start(ap, format);
        if (clixon_plugin_errmsg_all(h, NULL, 0, LOG_TYPE_LOG,
                                     NULL, NULL, x, format, ap, &cb) < 0)
            goto done;
        va_end(ap);
        if (cb != NULL){ /* Customized: expand clixon_err_args */
            clixon_log_fn(h, 0, LOG_ERR, NULL, "%s", cbuf_get(cb));
            goto ok;
        }
    }
    if ((cb = cbuf_new()) == NULL){
        fprintf(stderr, "cbuf_new: %s\n", strerror(errno));
        goto done;
    }
    va_start(ap, format);
    vcprintf(cb, format, ap);
    va_end(ap);
    if (x){
        cprintf(cb, ": ");
        if (clixon_xml2cbuf(cb, x, 0, 0, NULL, -1, 0) < 0)
            goto done;
    }
    /* Truncate long debug strings */
    if ((trunc = clixon_log_string_limit_get()) && trunc < cbuf_len(cb))
        cbuf_trunc(cb, trunc);
    /* Actually log it */
    clixon_log_str(level, cbuf_get(cb));
 ok:
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
}
