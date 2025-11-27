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

 * This file contains access functions for options, one type of clixon variables
 * ie string based variables from Clixon configuration files.
 *            Accessed with clicon_options(h).
 * @see clixon_data.[ch] for the other type: free-type runtime get/set *
 */

#ifndef _CLIXON_OPTIONS_H_
#define _CLIXON_OPTIONS_H_

/*
 * Constants
 */
/*! Clixon configuration namespace
 *
 * Probably should be defined somewhere else or extracted from yang
 * @see clixon-config.yang
 * @see clixon-lib.yang
 */
#define CLIXON_CONF_NS     "http://clicon.org/config"
#define CLIXON_CONF_PREFIX "cc"
#define CLIXON_LIB_NS      "http://clicon.org/lib"
#define CLIXON_LIB_PREFIX  "cl"
#define CLIXON_AUTOCLI_NS  "http://clicon.org/autocli"
#define CLIXON_RESTCONF_NS "http://clicon.org/restconf"

/*
 * Types
 */

/*! See clixon-config.yang type startup_mode */
enum startup_mode_t{
    SM_NONE=0,         /* Do not touch running state */
    SM_INIT,           /* Initialize running state */
    SM_RUNNING,        /* Commit running db configuration into running state */
    SM_STARTUP,        /* Commit startup configuration into running state */
    SM_RUNNING_STARTUP, /* First try running db, if it is empty try startup db */
};

/*! See clixon-config.yang type priv_mode (privileges mode) */
enum priv_mode_t{
    PM_NONE=0,        /* Make no drop/change in privileges */
    PM_DROP_PERM,     /* Drop privileges permanently */
    PM_DROP_TEMP      /* Drop privileges temporary */
};

/*! See clixon-config.yang type nacm_cred_mode (user credentials) */
enum nacm_credentials_t{
    NC_NONE=0,   /* Dont match NACM user to any user credentials.  */
    NC_EXACT,    /* Exact match between NACM user and unix socket peer user. */
    NC_EXCEPT    /* Exact match except for root and www user  */
};

/*! yang clixon regexp engine
 *
 * @see regexp_mode in clixon-config.yang
 */
enum regexp_mode{
    REGEXP_POSIX,
    REGEXP_LIBXML2
};

/*
 * Prototypes
 */
const char *format_int2str(enum format_enum showas);
int format_str2int(const char *str);

/* Debug dump config options */
int clicon_option_dump(clixon_handle h, int dblevel);

/*! Dump config options on stdio using output format */
int clicon_option_dump1(clixon_handle h, FILE *f, int format, int pretty);

/* Add a clicon options overriding file setting */
int clicon_option_add(clixon_handle h, const char *name, const char *value);

/* Initialize options: set defaults, read config-file, etc */
int clicon_options_main(clixon_handle h);

/* Options debug and log helper function */
int clixon_options_main_helper(clixon_handle h, uint32_t dbg, uint32_t logdst, const char *ident);

/*! Check if a clicon option has a value */
int clicon_option_exists(clixon_handle h, const char *name);

/* String options, default NULL */
char *clicon_option_str(clixon_handle h, const char *name);
int clicon_option_str_set(clixon_handle h, const char *name, const char *val);

/* Option values gixen as int, default -1 */
int clicon_option_int(clixon_handle h, const char *name);
int clicon_option_int_set(clixon_handle h, const char *name, int val);

/* Option values gixen as bool, default false */
int clicon_option_bool(clixon_handle h, const char *name);
int clicon_option_bool_set(clixon_handle h, const char *name, int val);

/* Delete a single option via handle */
int clicon_option_del(clixon_handle h, const char *name);

/*-- Standard option access functions for YANG options --*/
static inline char *clicon_configfile(clixon_handle h){
    return clicon_option_str(h, "CLICON_CONFIGFILE");
}
static inline char *clicon_yang_main_file(clixon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MAIN_FILE");
}
static inline char *clicon_yang_main_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MAIN_DIR");
}
static inline char *clicon_yang_domain_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_YANG_DOMAIN_DIR");
}
static inline char *clicon_yang_module_main(clixon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MODULE_MAIN");
}
static inline char *clicon_yang_module_revision(clixon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MODULE_REVISION");
}
static inline char *clicon_backend_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_BACKEND_DIR");
}
static inline char *clicon_netconf_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_NETCONF_DIR");
}
static inline char *clicon_restconf_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_RESTCONF_DIR");
}
static inline char *clicon_cli_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_CLI_DIR");
}
static inline char *clicon_clispec_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_CLISPEC_DIR");
}
static inline char *clicon_cli_mode(clixon_handle h){
    return clicon_option_str(h, "CLICON_CLI_MODE");
}
static inline int clicon_cli_tab_mode(clixon_handle h){
    return clicon_option_int(h, "CLICON_CLI_TAB_MODE");
}
static inline char *clicon_sock_str(clixon_handle h){
    return clicon_option_str(h, "CLICON_SOCK");
}
static inline char *clicon_sock_group(clixon_handle h){
    return clicon_option_str(h, "CLICON_SOCK_GROUP");
}
static inline char *clicon_backend_user(clixon_handle h){
    return clicon_option_str(h, "CLICON_BACKEND_USER");
}
static inline char *clicon_backend_pidfile(clixon_handle h){
    return clicon_option_str(h, "CLICON_BACKEND_PIDFILE");
}
static inline char *clicon_xmldb_dir(clixon_handle h){
    return clicon_option_str(h, "CLICON_XMLDB_DIR");
}
static inline char *clicon_nacm_recovery_user(clixon_handle h){
    return clicon_option_str(h, "CLICON_NACM_RECOVERY_USER");
}

/*-- Specific option access functions for YANG options w type conversion--*/
int   clicon_cli_varonly(clixon_handle h);
int   clicon_sock_family(clixon_handle h);
int   clicon_sock_port(clixon_handle h);
int   clicon_autocommit(clixon_handle h);
int   clicon_startup_mode(clixon_handle h);
enum priv_mode_t clicon_backend_privileges_mode(clixon_handle h);
enum priv_mode_t clicon_restconf_privileges_mode(clixon_handle h);
enum nacm_credentials_t clicon_nacm_credentials(clixon_handle h);

enum regexp_mode clicon_yang_regexp(clixon_handle h);
/*-- Specific option access functions for non-yang options --*/
int clicon_quiet_mode(clixon_handle h);
int clicon_quiet_mode_set(clixon_handle h, int val);

#endif  /* _CLIXON_OPTIONS_H_ */
