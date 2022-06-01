/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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

  * Note, this is a CLICON API file, only exprorted function prototypes should appear here
 */

#ifndef _CLIXON_CLI_API_H_
#define _CLIXON_CLI_API_H_

/*
 * Types
 */
/*! Autocli list keyword type, see clixon-autocli.yang list-keyword-type
 * Assume a YANG LIST: 
 *    list a { 
 *       key x; 
 *       leaf x; 
 *       leaf y;
 *    }
 * Maybe this type should be in cli_autocli.h
 */
enum autocli_listkw{
    AUTOCLI_LISTKW_NONE,  /* No extra keywords, only <vars>: a <x> <y> */
    AUTOCLI_LISTKW_NOKEY, /* Keywords on non-key variables: a <x> y <y> */
    AUTOCLI_LISTKW_ALL,   /* Keywords on all variables: a x <x> y <y> */
};
typedef enum autocli_listkw autocli_listkw_t;

/* 
 * Function Declarations 
 */
/* cli_plugin.c */
int cli_set_syntax_mode(clicon_handle h, const char *mode);
char *cli_syntax_mode(clicon_handle h);
int cli_syntax_load(clicon_handle h);
int cli_handler_err(FILE *fd);
int cli_set_prompt(clicon_handle h, const char *mode, const char *prompt);
int cli_ptpush(clicon_handle h, char *mode, char *string, char *op);
int cli_ptpop(clicon_handle h, char *mode, char *op);

/* cli_handle.c */
clicon_handle cli_handle_init(void);
int cli_handle_exit(clicon_handle h);
cligen_handle cli_cligen(clicon_handle h);

/* cli_common.c */
int cli_notification_register(clicon_handle h, char *stream, enum format_enum format,
			      char *filter, int status, 
			      int (*fn)(int, void*), void *arg);

/* cli_common.c: CLIgen new vector callbacks */

int cli_dbxml(clicon_handle h, cvec *vars, cvec *argv, enum operation_type op, cvec *nsctx);

int cli_dbxml(clicon_handle h, cvec *vars, cvec *argv, enum operation_type op, cvec *nsctx);

int cli_set(clicon_handle h, cvec *vars, cvec *argv);

int cli_merge(clicon_handle h, cvec *vars, cvec *argv);

int cli_create(clicon_handle h, cvec *vars, cvec *argv);

int cli_remove(clicon_handle h, cvec *vars, cvec *argv);

int cli_del(clicon_handle h, cvec *vars, cvec *argv);

int cli_debug_cli(clicon_handle h, cvec *vars, cvec *argv);

int cli_debug_backend(clicon_handle h, cvec *vars, cvec *argv);

int cli_debug_restconf(clicon_handle h, cvec *vars, cvec *argv);

int cli_set_mode(clicon_handle h, cvec *vars, cvec *argv);

int cli_start_shell(clicon_handle h, cvec *vars, cvec *argv);

int cli_quit(clicon_handle h, cvec *vars, cvec *argv);

int cli_commit(clicon_handle h, cvec *vars, cvec *argv);

int cli_validate(clicon_handle h, cvec *vars, cvec *argv);

int compare_dbs(clicon_handle h, cvec *vars, cvec *argv);

int load_config_file(clicon_handle h, cvec *vars, cvec *argv);

int save_config_file(clicon_handle h, cvec *vars, cvec *argv);

int delete_all(clicon_handle h, cvec *vars, cvec *argv);

int discard_changes(clicon_handle h, cvec *vars, cvec *argv);

int cli_notify(clicon_handle h, cvec *cvv, cvec *argv);

int db_copy(clicon_handle h, cvec *cvv, cvec *argv);

int cli_lock(clicon_handle h, cvec *cvv, cvec *argv);
int cli_unlock(clicon_handle h, cvec *cvv, cvec *argv);
int cli_copy_config(clicon_handle h, cvec *cvv, cvec *argv);

int cli_help(clicon_handle h, cvec *vars, cvec *argv);

/* In cli_show.c */
int expand_dbvar(void *h, char *name, cvec *cvv, cvec *argv, 
		  cvec *commands, cvec *helptexts);
int clixon_cli2file(clicon_handle h, FILE *f, cxobj *xn, char *prepend, clicon_output_cb *fn, int skiptop);

/* cli_show.c: CLIgen new vector arg callbacks */
int show_yang(clicon_handle h, cvec *vars, cvec *argv);

int show_conf_xpath(clicon_handle h, cvec *cvv, cvec *argv);

int cli_show_config(clicon_handle h, cvec *cvv, cvec *argv);

int cli_show_config_state(clicon_handle h, cvec *cvv, cvec *argv);

int cli_show_auto(clicon_handle h, cvec *cvv, cvec *argv);

int cli_show_auto_state(clicon_handle h, cvec *cvv, cvec *argv);

int cli_show_options(clicon_handle h, cvec *cvv, cvec *argv);

/* cli_auto.c: Autocli mode support */

int cli_auto_edit(clicon_handle h, cvec *cvv1, cvec *argv);
int cli_auto_up(clicon_handle h, cvec *cvv, cvec *argv);
int cli_auto_top(clicon_handle h, cvec *cvv, cvec *argv);
int cli_auto_show(clicon_handle h, cvec *cvv, cvec *argv);
int cli_auto_set(clicon_handle h, cvec *cvv, cvec *argv);
int cli_auto_merge(clicon_handle h, cvec *cvv, cvec *argv);
int cli_auto_create(clicon_handle h, cvec *cvv,	cvec *argv);
int cli_auto_del(clicon_handle h, cvec *cvv, cvec *argv);
int cli_auto_sub_enter(clicon_handle h, cvec *cvv, cvec *argv);

int cli_pagination(clicon_handle h, cvec *cvv, cvec *argv);

#endif /* _CLIXON_CLI_API_H_ */
