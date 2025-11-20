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

  * Note, this is a CLICON API file, only exported function prototypes should appear here
 */

#ifndef _CLIXON_CLI_API_H_
#define _CLIXON_CLI_API_H_

/* 
 * Function Declarations 
 */
/* cli_plugin.c */
int cli_set_syntax_mode(clixon_handle h, char *mode);
char *cli_syntax_mode(clixon_handle h);
int clispec_load(clixon_handle h);
int cli_handler_err(FILE *fd);
int cli_set_prompt(clixon_handle h, char *mode, char *prompt);
int cli_ptpush(clixon_handle h, char *mode, char *string, char *op);
int cli_ptpop(clixon_handle h, char *mode, char *op);

/* cli_handle.c */
clixon_handle cli_handle_init(void);
int cli_handle_exit(clixon_handle h);
cligen_handle cli_cligen(clixon_handle h);

/* cli_common.c */
int cli_notification_register(clixon_handle h, char *stream, enum format_enum format,
                              char *filter, int status,
                              int (*fn)(int, void*), void *arg);
void cli_signal_block(clixon_handle h);
void cli_signal_unblock(clixon_handle h);
void cli_signal_flush(clixon_handle h);
int mtpoint_paths(clixon_handle h, yang_stmt *yspec0, const char *domain, const char *spec,
                  const char *api_path_fmt1, char **api_path_fmt01);
int dbxml_body(cxobj *xbot, cvec *cvv);
int identityref_add_ns(cxobj *x, void *arg);
int cli_dbxml(clixon_handle h, cvec *vars, cvec *argv, enum operation_type op, cvec *nsctx);
int cli_set(clixon_handle h, cvec *vars, cvec *argv);
int cli_merge(clixon_handle h, cvec *vars, cvec *argv);
int cli_create(clixon_handle h, cvec *vars, cvec *argv);
int cli_remove(clixon_handle h, cvec *vars, cvec *argv);
int cli_del(clixon_handle h, cvec *vars, cvec *argv);
int cli_debug_show(clixon_handle h, cvec *cvv, cvec *argv);
int cli_debug_cli(clixon_handle h, cvec *vars, cvec *argv);
int cli_debug_backend(clixon_handle h, cvec *vars, cvec *argv);
int cli_debug_restconf(clixon_handle h, cvec *vars, cvec *argv);
int cli_set_mode(clixon_handle h, cvec *vars, cvec *argv);
int cli_start_program(clixon_handle h, cvec *vars, cvec *argv);
int cli_start_shell(clixon_handle h, cvec *vars, cvec *argv);
int cli_quit(clixon_handle h, cvec *vars, cvec *argv);
int cli_commit(clixon_handle h, cvec *vars, cvec *argv);
int cli_validate(clixon_handle h, cvec *vars, cvec *argv);
int cli_update(clixon_handle h, cvec *vars, cvec *argv);
int compare_db_names(clixon_handle h, enum format_enum format, char *db1, char *db2);
int compare_dbs(clixon_handle h, cvec *vars, cvec *argv);
int load_config_file(clixon_handle h, cvec *vars, cvec *argv);
int save_config_file(clixon_handle h, cvec *vars, cvec *argv);
int delete_all(clixon_handle h, cvec *vars, cvec *argv);
int discard_changes(clixon_handle h, cvec *vars, cvec *argv);
int cli_notify(clixon_handle h, cvec *cvv, cvec *argv);
int db_copy(clixon_handle h, cvec *cvv, cvec *argv);
int cli_lock(clixon_handle h, cvec *cvv, cvec *argv);
int cli_unlock(clixon_handle h, cvec *cvv, cvec *argv);
int cli_kill_session(clixon_handle h, cvec *cvv, cvec *argv);
int cli_copy_config(clixon_handle h, cvec *cvv, cvec *argv);
int cli_help(clixon_handle h, cvec *vars, cvec *argv);
cvec *cvec_append(cvec *cvv0, cvec *cvv1);
int   cvec_concat_cb(cvec *cvv, cbuf *cb);
int cli_process_control(clixon_handle h, cvec *vars, cvec *argv);
int cli_alias_cb(clixon_handle h, cvec *cvv, cvec *argv);
int cli_cache_clear(clixon_handle h, cvec *cvv, cvec *argv);

/* In cli_show.c */
int expand_dbvar(void *h, char *name, cvec *cvv, cvec *argv,
                  cvec *commands, cvec *helptexts);
int expand_yang_list(void *h, char *name, cvec *cvv, cvec *argv,
                     cvec *commands, cvec *helptexts);
int clixon_cli2file(clixon_handle h, FILE *f, cxobj *xn, char *prepend, clicon_output_cb *fn, int skiptop);
int clixon_cli2cbuf(clixon_handle h, cbuf *cb, cxobj *xn, char *prepend, int skiptop);
/* cli_show.c: CLIgen new vector arg callbacks */
int cli_show_common(clixon_handle h, char *db, enum format_enum format, int pretty, int state, char *withdefault, char *extdefault, char *prepend, char *xpath, int fromroot, cvec *nsc, int skiptop);

int show_yang(clixon_handle h, cvec *vars, cvec *argv);
int show_conf_xpath(clixon_handle h, cvec *cvv, cvec *argv);
int cli_show_option_format(clixon_handle h, cvec *argv, int argc, enum format_enum *format);
int cli_show_option_bool(cvec *argv, int argc, int *result);
int cli_show_option_withdefault(cvec *argv, int argc, char **withdefault, char **extdefault);
int cli_show_config(clixon_handle h, cvec *cvv, cvec *argv);

int cli_show_config_state(clixon_handle h, cvec *cvv, cvec *argv);

int cli_show_auto(clixon_handle h, cvec *cvv, cvec *argv);

int cli_show_options(clixon_handle h, cvec *cvv, cvec *argv);
int cli_show_version(clixon_handle h, cvec *vars, cvec *argv);
int cli_show_sessions(clixon_handle h, cvec *cvv, cvec *argv);

/* cli_auto.c: Autocli mode support */

int cli_auto_edit(clixon_handle h, cvec *cvv1, cvec *argv);
int cli_auto_up(clixon_handle h, cvec *cvv, cvec *argv);
int cli_auto_top(clixon_handle h, cvec *cvv, cvec *argv);
int cli_show_auto_mode(clixon_handle h, cvec *cvv, cvec *argv);
int cli_auto_set(clixon_handle h, cvec *cvv, cvec *argv);
int cli_auto_merge(clixon_handle h, cvec *cvv, cvec *argv);
int cli_auto_create(clixon_handle h, cvec *cvv, cvec *argv);
int cli_auto_del(clixon_handle h, cvec *cvv, cvec *argv);
int cli_auto_sub_enter(clixon_handle h, cvec *cvv, cvec *argv);

int cli_pagination(clixon_handle h, cvec *cvv, cvec *argv);

#endif /* _CLIXON_CLI_API_H_ */
