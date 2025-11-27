/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren
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
 */
/*
 * Internal prototypes, not accessed by plugin client code
 */

#ifndef _CLIXON_PLUGIN_H_
#define _CLIXON_PLUGIN_H_

/*
 * Constants
 */
/*! Hardcoded plugin symbol. Must exist in all plugins to kickstart
 *
 * @see clixon_plugin_init
 */
#define CLIXON_PLUGIN_INIT     "clixon_plugin_init"

/*
 * Types
 */

/*! Registered RPC callback function
 *
 * @param[in]  h       Clixon handle
 * @param[in]  xn      Request: <rpc><xn></rpc>
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..
 * @param[in]  arg     Domain specific arg, ec client-entry or FCGX_Request
 * @param[in]  regarg  User argument given at rpc_callback_register()
 * @retval     0       OK
 * @retval    -1       Error
 */
typedef int (*clicon_rpc_cb)(
    clixon_handle h,
    cxobj        *xn,
    cbuf         *cbret,
    void         *arg,
    void         *regarg
);

/*! Registered Upgrade callback function
 *
 * @param[in]  h       Clixon handle
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module
 * @param[in]  op      One of XML_FLAG_ADD, _DEL, _CHANGE
 * @param[in]  from    From revision on the form YYYYMMDD (if DEL or CHANGE)
 * @param[in]  to      To revision on the form YYYYMMDD (if ADD or CHANGE)
 * @param[in]  arg     User argument given at rpc_callback_register()
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..  (if retval = 0)
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 */
typedef int (*clicon_upgrade_cb)(
    clixon_handle h,
    cxobj        *xn,
    char         *ns,
    uint16_t      op,
    uint32_t      from,
    uint32_t      to,
    void         *arg,
    cbuf         *cbret
);

/* Clixon authentication type
 * @see http-auth-type in clixon-restconf.yang
 * For now only used by restconf frontend
 */
enum clixon_auth_type {
    CLIXON_AUTH_NONE = 0,           /* Message is authenticated automatically to
                                       anonymous user, maye be changed by ca-auth callback
                                       FEATURE clixon-restconf:allow-auth-none must be enabled */
    CLIXON_AUTH_CLIENT_CERTIFICATE, /* TLS Client certification authentication */
    CLIXON_AUTH_USER,               /* User-defined authentication according to ca-auth callback.
                                       Such as "password" authentication */
};
typedef enum clixon_auth_type clixon_auth_type_t;

/*! Common plugin function names, function types and signatures.
 *
 * This plugin code is extended by backend, cli, netconf, restconf plugins
 *   Cli     see cli_plugin.c
 *   Backend see config_plugin.c
 */

/*! Called when application is "started", (almost) all initialization is complete
 *
 * Backend: daemon is in the background. If daemon privileges are dropped
 *          this callback is called *before* privileges are dropped.
 * @param[in] h    Clixon handle
 */
typedef int (plgstart_t)(clixon_handle); /* Plugin start */

/*! Called just before or after a server has "daemonized", ie put in background.
 *
 * Backend: If daemon privileges are dropped this callback is called *before* privileges are dropped.
 * If daemon is started in foreground (-F): pre-daemon is not called, but daemon called
 * @param[in] h    Clixon handle
 */
typedef int (plgdaemon_t)(clixon_handle);              /* Plugin pre/post daemonized */

/*! Called just before plugin unloaded. 
 *
 * @param[in] h    Clixon handle
 */
typedef int (plgexit_t)(clixon_handle);                /* Plugin exit */

/*! For yang extension/unknown handling. 
 *
 * Called at parsing of yang module containing an unknown statement of an extension.
 * A plugin may identify the extension by its name, and perform actions
 * on the yang statement, such as transforming the yang.
 * A callback is made for every statement, which means that several calls per
 * extension can be made.
 * @param[in] h    Clixon handle
 * @param[in] yext Yang node of extension 
 * @param[in] ys   Yang node of (unknown) statement belonging to extension
 * @retval    0    OK, all callbacks executed OK
 * @retval   -1    Error in one callback
 */
typedef int (plgextension_t)(clixon_handle h, yang_stmt *yext, yang_stmt *ys);

/*! Plugin callback for authenticating messages (for restconf)
 *
 * Called by restconf on each incoming request to check credentials and return username
 * Given a message (its headers) and authentication type, determine if the message
 * passes authentication.
 *
 * If the message is not authenticated, an error message is returned with tag: "access denied" and
 * HTTP error code 401 Unauthorized  - Client is not authenticated
 *
 * If the message is authenticated, a user is associated with the message. This user can be derived
 * from the headers or mapped in an application-dependent way. This user is used internally in Clixon and
 * sent via the IPC protocol to the backend where it may be used for NACM authorization.
 *
 * The auth-type parameter specifies how the authentication is made and what default value is:
 *  none:        Message is authenticated. No callback is called, authenticated user is set to special user
 *               "none". Typically assumes NACM is not enabled.
 *  client-cert: Default: Set to authenticated and extract the username from the SSL_CN parameter
 *               A callback can revise this behavior
 *  user:        Default: Message is not authenticated (401 returned)
 *               Typically done by basic auth, eg HTTP_AUTHORIZATION header, and verify password
 *
 * If there are multiple callbacks, the first result which is not "ignore" is returned. This is to allow for
 * different callbacks registering different classes, or grouping of authentication.
 *
 * @param[in]  h         Clixon handle
 * @param[in]  req       Per-message request www handle to use with restconf_api.h
 * @param[in]  auth_type Authentication type: none, user-defined, or client-cert
 * @param[out] authp     NULL: Credentials failed, no user set (401 returned).
 *                       String: Credentials OK, the associated user, must be mallloc:ed
 *                       Parameter signtificant only if retval is 1/OK
 * @retval     1         OK, see authp parameter for result.
 * @retval     0         Ignore, undecided, not handled, same as no callback
 * @retval    -1         Fatal error
 * @note If authp returns string, it should be malloced
 *
 * @note user should be freed by caller
 */
typedef int (plgauth_t)(clixon_handle h, void *req, clixon_auth_type_t auth_type, char **authp);

/*! Reset system status
 *
 * Add xml or set state in backend system.
 * plugin_reset in each backend plugin after all plugins have been initialized.
 * This gives the application a chance to reset system state back to a base state.
 * This is generally done when a system boots up to make sure the initial system state
 * is well defined.
 * This involves creating default configuration files for various daemons, set interface
 * flags etc.
 * @param[in]  h   Clixon handle
 * @param[in]  db  Database name (eg "running")
 * @retval     0   OK
 * @retval    -1   Fatal error
*/
typedef int (plgreset_t)(clixon_handle h, const char *db);

/* Provide state data from plugin
 *
 * A complete valid XML tree is created by the plugin and sent back via xtop, which is merged
 * into a complete state tree by the system.
 * The plugin should ensure that xpath is matched (using namspace context nsc)
 * XXX: This callback may be replaced with a "dispatcher" type API in the future where the
 *      XPath binding is stricter, similar to the pagination API.
 *
 * @param[in]  h      Clixon handle
 * @param[in]  xpath  Part of state requested
 * @param[in]  nsc    XPath namespace context.
 * @param[out] xconfig XML tree where data is added
 * @retval     0      OK
 * @retval    -1      Fatal error
 *
 * @note The system will make an xpath check and filter out non-matching trees
 * @note The system does not validate the xml, unless CLICON_VALIDATE_STATE_XML is set
 * @see clixon_pagination_cb_register for special paginated state data callback
 */
typedef int (plgstatedata_t)(clixon_handle h, cvec *nsc, char *xpath, cxobj *xconfig);

/*! Pagination-data type
 *
 * @see pagination_data_t in for full pagination data structure
 * @see pagination_offset() and other accessor functions
 */
typedef void *pagination_data;

/*! Lock database status has changed status
 *
 * @param[in]  h    Clixon handle
 * @param[in]  db   Database name (eg "running")
 * @param[in]  lock Lock status: 0: unlocked, 1: locked
 * @param[in]  id   Session id (of locker/unlocker)
 * @retval     0    OK
 * @retval    -1    Fatal error
*/
typedef int (plglockdb_t)(clixon_handle h, char *db, int lock, int id);

/*! Transaction-data type
 *
 * @see transaction_data_t and clixon_backend_transaction.h for full transaction API
 */
typedef void *transaction_data;

/* Transaction callback
 *
 * @param[in]  h   Clixon handle
 * @param[in]  td  Transaction data
 * @retval     0    OK
 * @retval    -1    Error
 */
typedef int (trans_cb_t)(clixon_handle h, transaction_data td);

/*! Hook to override default prompt with explicit function
 *
 * Format prompt before each getline
 * @param[in] h      Clixon handle
 * @param[in] mode   Cligen syntax mode
 * @retval    prompt Prompt to prepend all CLigen command lines
 */
typedef char *(cli_prompthook_t)(clixon_handle, char *mode);

/*! General-purpose datastore upgrade callback called once on startupo
 *
 * Gets called on startup after initial XML parsing, but before module-specific upgrades
 * and before validation.
 * @param[in] h    Clixon handle
 * @param[in] db   Name of datastore, eg "running", "startup" or "tmp"
 * @param[in] xt   XML tree. Upgrade this "in place"
 * @param[in] msd  Info on datastore module-state, if any
 * @retval    0    OK
 * @retval   -1    Error
 */
typedef int (datastore_upgrade_t)(clixon_handle h, const char *db, cxobj *xt, modstate_diff_t *msd);

/*! YANG schema mount
 *
 * Given an XML mount-point xt, return XML yang-lib modules-set
 * Return yanglib as XML tree on the RFC8528 form:
 *   <yang-library>
 *      <module-set>
 *         <module>...</module>
 *         ...
 *      </module-set>
 *   </yang-library>
 * No need to YANG bind.
 * @param[in]  h       Clixon handle
 * @param[in]  xt      XML mount-point in XML tree
 * @param[out] config  If '0' all data nodes in the mounted schema are read-only
 * @param[out] vallevel Do or dont do full RFC 7950 validation
 * @param[out] yanglib XML yang-lib module-set tree. Freed by caller.
 * @retval     0       OK
 * @retval    -1       Error
 * @note For optional fields, such as revision, the callback may omit it, but will be resolved
 * at proper parse-time, but this is not visible in the yanglib return
 * @see RFC 8528 (schema-mount) and RFC 8525 (yang-lib)
 */
typedef int (yang_mount_t)(clixon_handle h, cxobj *xt, int *config,
                           validate_level *vl, cxobj **yanglib);

/*! YANG module patch
 *
 * Given a parsed YANG module, provide a method to patch it before import recursion,
 * grouping/uses checks, augments, etc
 * Can be useful if YANG in some way needs modification.
 * Deviations could be used as alternative (probably better)
 * @param[in]  h       Clixon handle
 * @param[in]  ymod    YANG module
 * @retval     0       OK
 * @retval    -1       Error
 */
typedef int (yang_patch_t)(clixon_handle h, yang_stmt *ymod);

/*! Callback to customize log, error, or debug message
 *
 * @param[in]     h        Clixon handle
 * @param[in]     fn       Inline function name (when called from clixon_err() macro)
 * @param[in]     line     Inline file line number (when called from clixon_err() macro)
 * @param[in]     type     Log message type
 * @param[in,out] category Clixon error category, See enum clixon_err
 * @param[in,out] suberr   Error number, typically errno
 * @param[in]     xerr     Netconf error xml tree on the form: <rpc-error>
 * @param[in]     format   Format string
 * @param[in]     ap       Variable argument list
 * @param[out]    cbmsg    Log string as cbuf, if set bypass ordinary logging
 * @retval        0        OK
 * @retval       -1        Error
 * When cbmsg is set by a plugin, no other plugins are called. category and suberr
 * can be rewritten by any plugin.
 */
typedef int (errmsg_t)(clixon_handle h, const char *fn, const int line,
                       enum clixon_log_type type,
                       int *category, int *suberr, cxobj *xerr,
                       const char *format, va_list ap, cbuf **cbmsg);

/*! Callback for printing version output and exit
 *
 * A plugin can customize a version (or banner) output on stdout.
 * Several version strings can be printed if there are multiple callbacks.
 * If no registered plugins exist, clixon prints CLIXON_VERSION
 * Typically invoked by command-line option -V
 * @param[in]  h   Clixon handle
 * @param[in]  f   Output file
 * @retval     0   OK
 * @retval    -1   Error
 */
typedef int (plgversion_t)(clixon_handle, FILE*);

/* For 7.3 compatibility */
#define CLIXON_PLUGIN_USERDEF

/*! Callback for generic user-defined semantics
 *
 * An application may define a user-defined callback which is called from _within_
 * an application callback. That is, not from within the Clixon base code.
 * This means that the application needs to define semantics based on where and when the
 * callback is called, and also the semantics of the arguments to the callback.
 * @param[in]  h    Clixon handle
 * @param[in]  type User-defined type
 * @param[in]  x    XML tree
 * @param[in]  arg  User-defined argument
 * @retval     0    OK
 * @retval    -1    Error
 */
typedef int (plguserdef_t)(clixon_handle, int type, cxobj *xn, void *arg);

/*! Startup status for use in startup-callback
 *
 * Note that for STARTUP_ERR and STARTUP_INVALID, running runs in failsafe mode
 * and startup contains the erroneous or invalid database.
 * The user should repair the startup and
 * (1) restart the backend
 * (2) copy startup to candidate and commit.
 */
enum startup_status{
    STARTUP_ERR,         /* XML/JSON syntax error */
    STARTUP_INVALID,     /* XML/JSON OK, but (yang) validation fails */
    STARTUP_OK           /* Everything OK (may still be modules-mismatch) */
};

/*! Plugin init struct for the api
 *
 * @note Implicit init function
 */
struct clixon_plugin_api;
typedef struct clixon_plugin_api* (plginit_t)(clixon_handle);    /* Clixon plugin Init */

struct clixon_plugin_api{
    /*--- Common fields.  ---*/
    char              ca_name[MAXPATHLEN]; /* Name of plugin (given by plugin) */
    plginit_t        *ca_init;             /* Clixon plugin Init (implicit) */
    plgstart_t       *ca_start;            /* Plugin start */
    plgexit_t        *ca_exit;             /* Plugin exit */
    plgextension_t   *ca_extension;        /* Yang extension/unknown handler */
    yang_mount_t     *ca_yang_mount;       /* RFC 8528 schema mount */
    yang_patch_t     *ca_yang_patch;       /* Patch yang after parse */
    errmsg_t         *ca_errmsg;           /* Customize log/error/debug callback */
    plgversion_t     *ca_version;          /* Output a customized version message */
    plguserdef_t     *ca_userdef;          /* User-defined plugin */
    union {
        struct { /* cli-specific */
            cli_prompthook_t *ci_prompt;         /* Prompt hook */
            cligen_susp_cb_t *ci_suspend;        /* Ctrl-Z hook, see cligen getline */
            cligen_interrupt_cb_t *ci_interrupt; /* Ctrl-C, see cligen getline */
        } cau_cli;
        struct { /* restconf-specific */
            plgauth_t        *cr_auth;           /* Auth credentials */
        } cau_restconf;
        struct { /* netconf-specific */
        } cau_netconf;
        struct { /* backend-specific */
            plgdaemon_t      *cb_pre_daemon;     /* Plugin just before daemonization (only daemon) */
            plgdaemon_t      *cb_daemon;         /* Plugin daemonized (always called) */
            plgreset_t       *cb_reset;          /* Reset system status */
            plgstatedata_t   *cb_statedata;      /* Provide state data XML from plugin */
            plgstatedata_t   *cb_system_only;    /* Provide system-only config XML from plugin */
            plglockdb_t      *cb_lockdb;         /* Database lock changed state */
            trans_cb_t       *cb_trans_begin;    /* Transaction start */
            trans_cb_t       *cb_trans_validate; /* Transaction validation */
            trans_cb_t       *cb_trans_complete; /* Transaction validation complete */
            trans_cb_t       *cb_trans_commit;   /* Transaction commit */
            trans_cb_t       *cb_trans_commit_done; /* Transaction when commit done */
            trans_cb_t       *cb_trans_commit_failed;   /* Transaction commit failed*/
            trans_cb_t       *cb_trans_revert;   /* Transaction revert */
            trans_cb_t       *cb_trans_end;      /* Transaction completed  */
            trans_cb_t       *cb_trans_abort;    /* Transaction aborted */
            datastore_upgrade_t *cb_datastore_upgrade; /* General-purpose datastore upgrade */
        } cau_backend;
    } u;
};
/* Access fields */
#define ca_prompt         u.cau_cli.ci_prompt
#define ca_suspend        u.cau_cli.ci_suspend
#define ca_interrupt      u.cau_cli.ci_interrupt
#define ca_auth           u.cau_restconf.cr_auth
#define ca_pre_daemon     u.cau_backend.cb_pre_daemon
#define ca_daemon         u.cau_backend.cb_daemon
#define ca_reset          u.cau_backend.cb_reset
#define ca_statedata      u.cau_backend.cb_statedata
#define ca_system_only    u.cau_backend.cb_system_only
#define ca_lockdb         u.cau_backend.cb_lockdb
#define ca_trans_begin    u.cau_backend.cb_trans_begin
#define ca_trans_validate u.cau_backend.cb_trans_validate
#define ca_trans_complete u.cau_backend.cb_trans_complete
#define ca_trans_commit   u.cau_backend.cb_trans_commit
#define ca_trans_commit_done u.cau_backend.cb_trans_commit_done
#define ca_trans_commit_failed   u.cau_backend.cb_trans_commit_failed
#define ca_trans_revert   u.cau_backend.cb_trans_revert
#define ca_trans_end      u.cau_backend.cb_trans_end
#define ca_trans_abort    u.cau_backend.cb_trans_abort
#define ca_datastore_upgrade  u.cau_backend.cb_datastore_upgrade

/*
 * Macros
 */
#define upgrade_callback_register(h, cb, ns, arg) upgrade_callback_reg_fn((h), (cb), #cb, (ns), (arg))

typedef struct clixon_plugin_api clixon_plugin_api;

/* This is the external handle type exposed in the API.
 * The internal struct is defined in clixon_plugin.c */
typedef struct clixon_plugin clixon_plugin_t;

/*! Structure for checking status before and after a plugin call
 *
 * The internal struct is defined in clixon_plugin.c */
typedef struct plugin_context plugin_context_t;

/*! RPC callbacks for both client/frontend and backend plugins.
 *
 * RPC callbacks are explicitly registered in the plugin_init() function
 * with a tag and a function
 * When the the tag is encountered, the callback is called.
 * Primarily backend, but also netconf and restconf frontend plugins.
 * CLI frontend so far have direct callbacks, ie functions in the cligen
 * specification are directly dlsym:ed to the CLI plugin.
 * It would be possible to use this rpc registering API for CLI plugins as well.
 *
 * When namespace and name match, the callback is made
 * Also for hellos in backend (but hello is not an RPC)
 */
typedef struct {
    qelem_t       rc_qelem;     /* List header */
    clicon_rpc_cb rc_callback;  /* RPC Callback */
    void         *rc_arg;       /* Application specific argument to cb */
    char         *rc_namespace;/* Namespace to combine with name tag */
    char         *rc_name;      /* Xml/json tag/name */
} rpc_callback_t;

/*
 * Prototypes
 */

/*! Plugin initialization function. Must appear in all plugins, not a clixon system function
 *
 * @param[in]  h    Clixon handle
 * @retval     api  Pointer to API struct
 * @retval     NULL Failure (if clixon_err() called), module disabled otherwise.
 * @see CLIXON_PLUGIN_INIT  default symbol
 */
clixon_plugin_api *clixon_plugin_init(clixon_handle h);

clixon_plugin_api *clixon_plugin_api_get(clixon_plugin_t *cp);
char            *clixon_plugin_name_get(clixon_plugin_t *cp);
plghndl_t        clixon_plugin_handle_get(clixon_plugin_t *cp);

clixon_plugin_t *clixon_plugin_each(clixon_handle h, clixon_plugin_t *cpprev);

clixon_plugin_t *clixon_plugin_each_revert(clixon_handle h, clixon_plugin_t *cpprev, int nr);

clixon_plugin_t *clixon_plugin_find(clixon_handle h, const char *name);

int clixon_plugins_load(clixon_handle h, const char *function, const char *dir, const char *regexp);

int clixon_pseudo_plugin(clixon_handle h, const char *name, clixon_plugin_t **cpp);

int clixon_plugin_start_one(clixon_plugin_t *cp, clixon_handle h);
int clixon_plugin_start_all(clixon_handle h);

int clixon_plugin_auth_all(clixon_handle h, void *req, clixon_auth_type_t auth_type, char **authp);

int clixon_plugin_extension_one(clixon_plugin_t *cp, clixon_handle h, yang_stmt *yext, yang_stmt *ys);
int clixon_plugin_extension_all(clixon_handle h, yang_stmt *yext, yang_stmt *ys);

int clixon_plugin_datastore_upgrade_one(clixon_plugin_t *cp, clixon_handle h, const char *db, cxobj *xt, modstate_diff_t *msd);
int clixon_plugin_datastore_upgrade_all(clixon_handle h, const char *db, cxobj *xt, modstate_diff_t *msd);

int clixon_plugin_yang_mount_one(clixon_plugin_t *cp, clixon_handle h, cxobj *xt, int *config, validate_level *vl, cxobj **yanglib);
int clixon_plugin_yang_mount_all(clixon_handle h, cxobj *xt, int *config, validate_level *vl, cxobj **yanglib);

int clixon_plugin_system_only_all(clixon_handle h, yang_stmt *yspec, cvec *nsc, char *xpath, cxobj **xtop);

int clixon_plugin_yang_patch_one(clixon_plugin_t *cp, clixon_handle h, yang_stmt *ymod);
int clixon_plugin_yang_patch_all(clixon_handle h, yang_stmt *ymod);

int clixon_plugin_errmsg_one(clixon_plugin_t *cp, clixon_handle h,
                             const char *fn, const int line,
                             enum clixon_log_type type,
                             int *category, int *suberr, cxobj *xerr,
                             const char *format, va_list ap, cbuf **cbmsg);
int clixon_plugin_errmsg_all(clixon_handle h,
                             const char *fn, const int line,
                             enum clixon_log_type type,
                             int *category, int *suberr, cxobj *xerr,
                             const char *format, va_list ap, cbuf **cbmsg);

int clixon_plugin_version_one(clixon_plugin_t *cp, clixon_handle h, FILE *f);
int clixon_plugin_version_all(clixon_handle h, FILE *f);

int clixon_plugin_userdef_one(clixon_plugin_t *cp, clixon_handle h, int type, cxobj *xn, void *arg);
int clixon_plugin_userdef_all(clixon_handle h, int type, cxobj* xn, void *arg);

/* rpc callback API */
int rpc_callback_register(clixon_handle h, clicon_rpc_cb cb, void *arg, const char *ns, const char *name);
int rpc_callback_call(clixon_handle h, cxobj *xe, void *arg, int *nrp, cbuf *cbret);

/* action callback API */
int action_callback_register(clixon_handle h, yang_stmt *ya, clicon_rpc_cb cb, void *arg);
int action_callback_call(clixon_handle h, cxobj *xe, cbuf *cbret, void *arg, void *regarg);

/* upgrade callback API */
int upgrade_callback_reg_fn(clixon_handle h, clicon_upgrade_cb cb, const char *strfn, const char *ns, void *arg);
int upgrade_callback_call(clixon_handle h, cxobj *xt, char *ns, uint16_t op, uint32_t from, uint32_t to, cbuf *cbret);

const int clixon_auth_type_str2int(const char *auth_type);
const char *clixon_auth_type_int2str(clixon_auth_type_t auth_type);
int              clixon_plugin_module_init(clixon_handle h);
int              clixon_plugin_module_exit(clixon_handle h);

int clixon_plugin_rpc_err(clixon_handle h, const char *ns,
                          const char *type, const char *tag, const char *info,
                          const char *severity, const char *fmt, ...);
int clixon_plugin_rpc_err_set(clixon_handle h);
int clixon_plugin_report_err(clixon_handle h, cbuf *cbret);
int clixon_plugin_report_err_xml(clixon_handle h, cxobj **xreg, const char *err, ...);

#endif  /* _CLIXON_PLUGIN_H_ */
