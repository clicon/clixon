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

 *
 * Configuration file and Options.
 */

#ifndef _CLIXON_OPTIONS_H_
#define _CLIXON_OPTIONS_H_

/*
 * Constants
 */
/* default group membership to access config unix socket */
#define CLICON_SOCK_GROUP "clicon"

/*
 * Types
 */

/*! Controls how keywords a generated in CLI syntax / prints from object model
 * Example YANG: 
 *  list a {
 *    key x;
 *    leaf x;   
 *    leaf y;   
 *  }
 * NONE: a <x> <y>;
 * VARS: a <x> y <y>;
 * ALL:  a x <x> y <y>;
 */
enum genmodel_type{
    GT_ERR =-1, /* Error  */
    GT_NONE=0,  /* No extra keywords */
    GT_VARS,    /* Keywords on non-key variables */
    GT_ALL,     /* Keywords on all variables */
};

/*! See clixon-config.yang type startup_mode */
enum startup_mode_t{
    SM_NONE=0,
    SM_STARTUP,
    SM_RUNNING,
    SM_INIT
};

/*
 * Prototypes
 */

/* Print registry on file. For debugging. */
void clicon_option_dump(clicon_handle h, int dblevel);

/* Add a clicon options overriding file setting */
int clicon_option_add(clicon_handle h,	char *name, char *value);

/* Initialize options: set defaults, read config-file, etc */
int clicon_options_main(clicon_handle h, yang_spec *yspec);

/*! Check if a clicon option has a value */
int clicon_option_exists(clicon_handle h, const char *name);

/* String options, default NULL */
char *clicon_option_str(clicon_handle h, const char *name);
int clicon_option_str_set(clicon_handle h, const char *name, char *val);

/* Option values gixen as int, default -1 */
int clicon_option_int(clicon_handle h, const char *name);
int clicon_option_int_set(clicon_handle h, const char *name, int val);

/* Option values gixen as bool, default false */
int clicon_option_bool(clicon_handle h, const char   *name);
int clicon_option_bool_set(clicon_handle h, const char *name, int val);

/* Delete a single option via handle */
int clicon_option_del(clicon_handle h, const char *name);

/*-- Standard option access functions for YANG options --*/
static inline char *clicon_configfile(clicon_handle h){
    return clicon_option_str(h, "CLICON_CONFIGFILE");
}
static inline char *clicon_yang_main_file(clicon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MAIN_FILE");
}
static inline char *clicon_yang_main_dir(clicon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MAIN_DIR");
}
static inline char *clicon_yang_module_main(clicon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MODULE_MAIN");
}
static inline char *clicon_yang_module_revision(clicon_handle h){
    return clicon_option_str(h, "CLICON_YANG_MODULE_REVISION");
}
static inline char *clicon_backend_dir(clicon_handle h){
    return clicon_option_str(h, "CLICON_BACKEND_DIR");
}
static inline char *clicon_netconf_dir(clicon_handle h){
    return clicon_option_str(h, "CLICON_NETCONF_DIR");
}
static inline char *clicon_restconf_dir(clicon_handle h){
    return clicon_option_str(h, "CLICON_RESTCONF_DIR");
}
static inline char *clicon_cli_dir(clicon_handle h){
    return clicon_option_str(h, "CLICON_CLI_DIR");
}
static inline char *clicon_clispec_dir(clicon_handle h){
    return clicon_option_str(h, "CLICON_CLISPEC_DIR");
}
static inline char *clicon_cli_mode(clicon_handle h){
    return clicon_option_str(h, "CLICON_CLI_MODE");
}
static inline char *clicon_cli_model_treename(clicon_handle h){
    return clicon_option_str(h, "CLICON_CLI_MODEL_TREENAME");
}
static inline char *clicon_sock(clicon_handle h){
    return clicon_option_str(h, "CLICON_SOCK");
}
static inline char *clicon_sock_group(clicon_handle h){
    return clicon_option_str(h, "CLICON_SOCK_GROUP");
}
static inline char *clicon_backend_pidfile(clicon_handle h){
    return clicon_option_str(h, "CLICON_BACKEND_PIDFILE");
}
static inline char *clicon_xmldb_dir(clicon_handle h){
    return clicon_option_str(h, "CLICON_XMLDB_DIR");
}
static inline char *clicon_xmldb_plugin(clicon_handle h){
    return clicon_option_str(h, "CLICON_XMLDB_PLUGIN");
}

/*-- Specific option access functions for YANG options w type conversion--*/
int   clicon_cli_genmodel(clicon_handle h);
int   clicon_cli_genmodel_completion(clicon_handle h);
enum genmodel_type clicon_cli_genmodel_type(clicon_handle h);
int   clicon_cli_varonly(clicon_handle h);
int   clicon_sock_family(clicon_handle h);
int   clicon_sock_port(clicon_handle h);
int   clicon_autocommit(clicon_handle h);
int   clicon_startup_mode(clicon_handle h);

/*-- Specific option access functions for non-yang options --*/
int clicon_quiet_mode(clicon_handle h);
int clicon_quiet_mode_set(clicon_handle h, int val);

yang_spec * clicon_dbspec_yang(clicon_handle h);
int clicon_dbspec_yang_set(clicon_handle h, struct yang_spec *ys);

cxobj * clicon_nacm_ext(clicon_handle h);
int clicon_nacm_ext_set(clicon_handle h, cxobj *xn);

yang_spec * clicon_config_yang(clicon_handle h);
int clicon_config_yang_set(clicon_handle h, struct yang_spec *ys);

cxobj *clicon_conf_xml(clicon_handle h);
int clicon_conf_xml_set(clicon_handle h, cxobj *x);

plghndl_t clicon_xmldb_plugin_get(clicon_handle h);
int clicon_xmldb_plugin_set(clicon_handle h, plghndl_t handle);

void *clicon_xmldb_api_get(clicon_handle h);
int clicon_xmldb_api_set(clicon_handle h, void *xa_api);

void *clicon_xmldb_handle_get(clicon_handle h);
int clicon_xmldb_handle_set(clicon_handle h, void *xh);

/**/
/* Set and get authorized user name */
char *clicon_username_get(clicon_handle h);
int clicon_username_set(clicon_handle h, void *username);

/* Set and get socket fd (ie backend server socket / restconf fcgx socket */
int clicon_socket_get(clicon_handle h);
int clicon_socket_set(clicon_handle h, int s);

#endif  /* _CLIXON_OPTIONS_H_ */
