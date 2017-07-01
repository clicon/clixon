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
 */
#ifndef _CLIXON_XML_DB_H
#define _CLIXON_XML_DB_H

/* The XMLDB has a handle to keep connected state. To users of the API it is 
 * a void* but it may have structure within a specific plugin.
 * The handle is independent from clicon so that (in principle) the datastore
 * can work in other contexts than clicon.
 * The connect API call sets the handle and disconnect resets it. In principle
 * there can be several handles at one time.
 */
#if 1 /* SANITY CHECK */
typedef struct {int16_t a;} *xmldb_handle;
#else
typedef void *xmldb_handle;
#endif

/* Version of clixon datastore plugin API. */
#define XMLDB_API_VERSION 1

/* Magic to ensure plugin sanity. */
#define XMLDB_API_MAGIC 0xf386f730

/* Name of plugin init function (must be called this) */
#define XMLDB_PLUGIN_INIT_FN "clixon_xmldb_plugin_init"

/* Type of plugin init function */
typedef void * (plugin_init_t)(int version);

/* Type of plugin exit function */
typedef int (plugin_exit_t)(void);

/* Type of xmldb connect function */
typedef xmldb_handle (xmldb_connect_t)(void);

/* Type of xmldb disconnect function */
typedef int (xmldb_disconnect_t)(xmldb_handle xh);

/* Type of xmldb getopt function */
typedef int (xmldb_getopt_t)(xmldb_handle xh, char *optname, void **value);

/* Type of xmldb setopt function */
typedef int (xmldb_setopt_t)(xmldb_handle xh, char *optname, void *value);

/* Type of xmldb get function */
typedef int (xmldb_get_t)(xmldb_handle xh, char *db, char *xpath, int config, cxobj **xtop);

/* Type of xmldb put function */
typedef int (xmldb_put_t)(xmldb_handle xh, char *db, enum operation_type op, cxobj *xt);

/* Type of xmldb copy function */
typedef int (xmldb_copy_t)(xmldb_handle xh, char *from, char *to);

/* Type of xmldb lock function */
typedef int (xmldb_lock_t)(xmldb_handle xh, char *db, int pid);

/* Type of xmldb unlock function */
typedef int (xmldb_unlock_t)(xmldb_handle xh, char *db);

/* Type of xmldb unlock_all function */
typedef int (xmldb_unlock_all_t)(xmldb_handle xh, int pid);

/* Type of xmldb islocked function */
typedef int (xmldb_islocked_t)(xmldb_handle xh, char *db);

/* Type of xmldb exists function */
typedef int (xmldb_exists_t)(xmldb_handle xh, char *db);

/* Type of xmldb delete function */
typedef int (xmldb_delete_t)(xmldb_handle xh, char *db);

/* Type of xmldb init function */
typedef int (xmldb_create_t)(xmldb_handle xh, char *db);

/* plugin init struct for the api */
struct xmldb_api{
    int                 xa_version;
    int                 xa_magic;
    plugin_init_t      *xa_plugin_init_fn; /* XMLDB_PLUGIN_INIT_FN */
    plugin_exit_t      *xa_plugin_exit_fn;
    xmldb_connect_t    *xa_connect_fn;
    xmldb_disconnect_t *xa_disconnect_fn;
    xmldb_getopt_t     *xa_getopt_fn;
    xmldb_setopt_t     *xa_setopt_fn;
    xmldb_get_t        *xa_get_fn;
    xmldb_put_t        *xa_put_fn;
    xmldb_copy_t       *xa_copy_fn;
    xmldb_lock_t       *xa_lock_fn;
    xmldb_unlock_t     *xa_unlock_fn;
    xmldb_unlock_all_t *xa_unlock_all_fn;
    xmldb_islocked_t   *xa_islocked_fn;
    xmldb_exists_t     *xa_exists_fn;
    xmldb_delete_t     *xa_delete_fn;
    xmldb_create_t     *xa_create_fn;
};

/*
 * Prototypes
 * API
 */
int xmldb_plugin_load(clicon_handle h, char *filename);
int xmldb_plugin_unload(clicon_handle h);

int xmldb_validate_db(char *db);
int xmldb_connect(clicon_handle h);
int xmldb_disconnect(clicon_handle h);
int xmldb_getopt(clicon_handle h, char *optname, void **value);
int xmldb_setopt(clicon_handle h, char *optname, void *value);
int xmldb_get(clicon_handle h, char *db, char *xpath, int config, cxobj **xtop);
int xmldb_put(clicon_handle h, char *db, enum operation_type op, cxobj *xt);
int xmldb_copy(clicon_handle h, char *from, char *to);
int xmldb_lock(clicon_handle h, char *db, int pid);
int xmldb_unlock(clicon_handle h, char *db);
int xmldb_unlock_all(clicon_handle h, int pid);
int xmldb_islocked(clicon_handle h, char *db);
int xmldb_exists(clicon_handle h, char *db);
int xmldb_delete(clicon_handle h, char *db);
int xmldb_create(clicon_handle h, char *db);

#endif /* _CLIXON_XML_DB_H */
