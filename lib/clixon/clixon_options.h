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
 * Configuration file and Options.
 */

#ifndef _CLIXON_OPTIONS_H_
#define _CLIXON_OPTIONS_H_

/*
 * Constants
 */
/* default group membership to access config unix socket */
#define CLICON_SOCK_GROUP "clicon"
/* Default name of master plugin */
#define CLICON_MASTER_PLUGIN "master"

/*
 * Types
 */

/*
 * enum gensyntx
 * Controls how keywords a generated in CLI syntax / prints from obhect model
 * Example syntax a.b[] $!x $y:
 * NONE: a b <x> <y>;
 * VARS: a b <x> y <y>;
 * ALL:  a b x <x> y <y>;
 */
enum genmodel_type{
    GT_ERR =-1, /* Error  */
    GT_NONE=0,  /* No extra keywords */
    GT_VARS,    /* Keywords on non-index variables */
    GT_ALL,     /* Keywords on all variables */
};


/*
 * Prototypes
 */
/* Initialize options: set defaults, read config-file, etc */
int clicon_options_main(clicon_handle h);

void clicon_option_dump(clicon_handle h, int dblevel);

int clicon_option_exists(clicon_handle h, const char *name);

/* Get a single option via handle */
char *clicon_option_str(clicon_handle h, const char *name);
int clicon_option_int(clicon_handle h, const char *name);
/* Set a single option via handle */
int clicon_option_str_set(clicon_handle h, const char *name, char *val);
int clicon_option_int_set(clicon_handle h, const char *name, int val);
/* Delete a single option via handle */
int clicon_option_del(clicon_handle h, const char *name);

char *clicon_configfile(clicon_handle h);
char *clicon_yang_dir(clicon_handle h);
char *clicon_yang_module_main(clicon_handle h);
char *clicon_yang_module_revision(clicon_handle h);
char *clicon_running_db(clicon_handle h);
char *clicon_candidate_db(clicon_handle h);
char *clicon_backend_dir(clicon_handle h);
char *clicon_cli_dir(clicon_handle h);
char *clicon_clispec_dir(clicon_handle h);
char *clicon_netconf_dir(clicon_handle h);
char *clicon_archive_dir(clicon_handle h);
char *clicon_startup_config(clicon_handle h);
int   clicon_sock_family(clicon_handle h);
char *clicon_sock(clicon_handle h);
int   clicon_sock_port(clicon_handle h);
char *clicon_backend_pidfile(clicon_handle h);
char *clicon_sock_group(clicon_handle h);

char *clicon_master_plugin(clicon_handle h);
char *clicon_cli_mode(clicon_handle h);
int   clicon_cli_genmodel(clicon_handle h);
int   clicon_cli_varonly(clicon_handle h);
int   clicon_cli_varonly_set(clicon_handle h, int val);
int   clicon_cli_genmodel_completion(clicon_handle h);

char *clicon_quiet_mode(clicon_handle h);
enum genmodel_type clicon_cli_genmodel_type(clicon_handle h);

int clicon_autocommit(clicon_handle h);
int clicon_autocommit_set(clicon_handle h, int val);

yang_spec * clicon_dbspec_yang(clicon_handle h);
int clicon_dbspec_yang_set(clicon_handle h, struct yang_spec *ys);

char *clicon_dbspec_name(clicon_handle h);
int clicon_dbspec_name_set(clicon_handle h, char *name);

#endif  /* _CLIXON_OPTIONS_H_ */
