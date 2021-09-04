/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
 * Access functions for clixon data. 
 * Free-typed values for runtime getting and setting.
 *            Accessed with clicon_data(h).
 * @see clixon_option.[ch] for clixon options
 */

#ifndef _CLIXON_DATA_H_
#define _CLIXON_DATA_H_

/*
 * Types
 */
/* Struct per database in hash 
 * Semantics of de_modified is to implement this from RFC 6241 Sec 7.5:
 *       The target configuration is <candidate>, it has already been
 *       modified, and these changes have not been committed or rolled back.
 */
typedef struct {
    uint32_t  de_id;       /* session id keeps lock */
    cxobj    *de_xml;      /* cache */
    int       de_modified; /* Dirty since loaded/copied/committed/etc XXX:nocache? */
    int       de_empty;    /* Empty on read from file, xmldb_readfile and xmldb_put sets it */
} db_elmnt;

/*
 * Prototypes
 */
int clicon_data_get(clicon_handle h, const char *name, char **val);
int clicon_data_set(clicon_handle h, const char *name, char *val);
int clicon_data_del(clicon_handle h, const char *name);

cvec *clicon_data_cvec_get(clicon_handle h, const char *name);
int   clicon_data_cvec_set(clicon_handle h, const char *name, cvec *cvv);
int   clicon_data_cvec_del(clicon_handle h, const char *name);

yang_stmt * clicon_dbspec_yang(clicon_handle h);
int clicon_dbspec_yang_set(clicon_handle h, yang_stmt *ys);

yang_stmt * clicon_config_yang(clicon_handle h);
int clicon_config_yang_set(clicon_handle h, yang_stmt *ys);

yang_stmt * clicon_nacm_ext_yang(clicon_handle h);
int clicon_nacm_ext_yang_set(clicon_handle h, yang_stmt *ys);

cvec *clicon_nsctx_global_get(clicon_handle h);
int clicon_nsctx_global_set(clicon_handle h, cvec *nsctx);

cxobj * clicon_nacm_ext(clicon_handle h);
int clicon_nacm_ext_set(clicon_handle h, cxobj *xn);

cxobj *clicon_nacm_cache(clicon_handle h);
int clicon_nacm_cache_set(clicon_handle h, cxobj *xn);

cxobj *clicon_conf_xml(clicon_handle h);
int clicon_conf_xml_set(clicon_handle h, cxobj *x);

cxobj *clicon_conf_restconf(clicon_handle h);

db_elmnt *clicon_db_elmnt_get(clicon_handle h, const char *db);
int clicon_db_elmnt_set(clicon_handle h, const char *db, db_elmnt *xc);

/**/
/* Set and get authorized user name */
char *clicon_username_get(clicon_handle h);
int clicon_username_set(clicon_handle h, void *username);

/* Set and get startup status */
enum startup_status clicon_startup_status_get(clicon_handle h);
int clicon_startup_status_set(clicon_handle h, enum startup_status status);

/* Set and get server socket fd (ie backend server socket / restconf fcgi socket */
int clicon_socket_get(clicon_handle h);
int clicon_socket_set(clicon_handle h, int s);

/* Set and get client socket fd (ie client cli / netconf / restconf / client-api socket */
int clicon_client_socket_get(clicon_handle h);
int clicon_client_socket_set(clicon_handle h, int s);

/*! Set and get module state full and brief cached tree */
cxobj *clicon_modst_cache_get(clicon_handle h, int brief);
int clicon_modst_cache_set(clicon_handle h, int brief, cxobj *xms);

/*! Set and get yang/xml module revision changelog */
cxobj *clicon_xml_changelog_get(clicon_handle h);
int clicon_xml_changelog_set(clicon_handle h, cxobj *xchlog);

/*! Set and get user command-line options (after --) */
int clicon_argv_get(clicon_handle h, int *argc, char ***argv);
int clicon_argv_set(clicon_handle h, char *argv0, int argc, char **argv);

/*! Set and get (client/backend) session id */
int clicon_session_id_set(clicon_handle h, uint32_t id);
int clicon_session_id_get(clicon_handle h, uint32_t *id);

/* If set, quit startup directly after upgrade */
int clicon_quit_upgrade_get(clicon_handle h);
int clicon_quit_upgrade_set(clicon_handle h, int val);

#endif  /* _CLIXON_DATA_H_ */
