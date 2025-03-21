/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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
  
  * @see https://nginx.org/en/docs/http/ngx_http_core_module.html#var_https
  * @note The response payload for errors uses text_html. RFC7231 is vague
  * on the response payload (and its media). Maybe it should be omitted 
  * altogether?
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h" /* generated by config & autoconf */
#endif

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>
#include <ctype.h>
#include <time.h>
#include <signal.h>
#include <dlfcn.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <arpa/inet.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

#include "restconf_api.h"
#include "restconf_lib.h"
#include "restconf_err.h"
#include "restconf_handle.h"

/*
   +----------------------------+--------------------------------------+
   | 100 Continue               | POST accepted, 201 should follow     |
   | 200 OK                     | Success with response message-body   |
   | 201 Created                | POST to create a resource success    |
   | 204 No Content             | Success without response message-    |
   |                            | body                                 |
   | 304 Not Modified           | Conditional operation not done       |
   | 400 Bad Request            | Invalid request message              |
   | 401 Unauthorized           | Client cannot be authenticated       |
   | 403 Forbidden              | Access to resource denied            |
   | 404 Not Found              | Resource target or resource node not |
   |                            | found                                |
   | 405 Method Not Allowed     | Method not allowed for target        |
   |                            | resource                             |
   | 409 Conflict               | Resource or lock in use              |
   | 412 Precondition Failed    | Conditional method is false          |
   | 413 Request Entity Too     | too-big error                        |
   | Large                      |                                      |
   | 414 Request-URI Too Large  | too-big error                        |
   | 415 Unsupported Media Type | non RESTCONF media type              |
   | 500 Internal Server Error  | operation-failed                     |
   | 501 Not Implemented        | unknown-operation                    |
   | 503 Service Unavailable    | Recoverable server error             |
   +----------------------------+--------------------------------------+
Mapping netconf error-tag -> status code
                 +-------------------------+-------------+
                 | <error&#8209;tag>       | status code |
                 +-------------------------+-------------+
                 | in-use                  | 409         |
                 | invalid-value           | 400         |
                 | too-big                 | 413         |
                 | missing-attribute       | 400         |
                 | bad-attribute           | 400         |
                 | unknown-attribute       | 400         |
                 | bad-element             | 400         |
                 | unknown-element         | 400         |
                 | unknown-namespace       | 400         |
                 | access-denied           | 403         |
                 | lock-denied             | 409         |
                 | resource-denied         | 409         |
                 | rollback-failed         | 500         |
                 | data-exists             | 409         |
                 | data-missing            | 409         |
                 | operation-not-supported | 405 or 501  |
                 | operation-failed        | 500         |
                 | partial-operation       | 500         |
                 | malformed-message       | 400         |
                 +-------------------------+-------------+

 * See RFC 8040 Section 7:  Mapping from NETCONF<error-tag> to Status Code
 * and RFC 6241 Appendix A. NETCONF Error list
 */
static const map_str2int netconf_restconf_map[] = {
    {"in-use",                 409},
    {"invalid-value",          400}, /* or 404 special case if msg is: "Invalid HTTP data method" handled in api_return_err */
    {"invalid-value",          404},
    {"invalid-value",          406},
    {"too-big",                413}, /* request */
    {"too-big",                400}, /* response */
    {"missing-attribute",      400},
    {"bad-attribute",          400},
    {"unknown-attribute",      400},
    {"missing-element",        400},
    {"bad-element",            400},
    {"unknown-element",        400},
    {"unknown-namespace",      400},
    {"access-denied",          403}, /* or 401 special case if msg is: "The requested URL was unauthorized" handled in api_return_err */
    {"access-denied",          401},
    {"lock-denied",            409},
    {"resource-denied",        409},
    {"rollback-failed",        500},
    {"data-exists",            409},
    {"data-missing",           409},
    {"operation-not-supported",405},
    {"operation-not-supported",501},
    {"operation-failed",       412},
    {"operation-failed",       500},
    {"partial-operation",      500},
    {"malformed-message",      400},
    {NULL,                     -1}
};

/* See 7231 Section 6.1
 */
static const map_str2int http_reason_phrase_map[] = {
    {"Continue",                      100},
    {"Switching Protocols",           101},
    {"OK",                            200},
    {"Created",                       201},
    {"Accepted",                      202},
    {"Non-Authoritative Information", 203},
    {"No Content",                    204},
    {"Reset Content",                 205},
    {"Partial Content",               206},
    {"Multiple Choices",              300},
    {"Moved Permanently",             301},
    {"Found",                         302},
    {"See Other",                     303},
    {"Not Modified",                  304},
    {"Use Proxy",                     305},
    {"Temporary Redirect",            307},
    {"Bad Request",                   400},
    {"Unauthorized",                  401},
    {"Payment Required",              402},
    {"Forbidden",                     403},
    {"Not Found",                     404},
    {"Method Not Allowed",            405},
    {"Not Acceptable",                406},
    {"Proxy Authentication Required", 407},
    {"Request Timeout",               408},
    {"Conflict",                      409},
    {"Gone",                          410},
    {"Length Required",               411},
    {"Precondition Failed",           412},
    {"Payload Too Large",             413},
    {"URI Too Long",                  414},
    {"Unsupported Media Type",        415},
    {"Range Not Satisfiable",         416},
    {"Expectation Failed",            417},
    {"Upgrade Required",              426},
    {"Internal Server Error",         500},
    {"Not Implemented",               501},
    {"Bad Gateway",                   502},
    {"Service Unavailable",           503},
    {"Gateway Timeout",               504},
    {"HTTP Version Not Supported",    505},
    {NULL,                            -1}
};

/* See RFC 8040
 * @see restconf_media_str2int
 */
static const map_str2int http_media_map[] = {
    {"application/yang-data+xml",        YANG_DATA_XML},
    {"application/yang-data+json",       YANG_DATA_JSON},
    {"application/yang-patch+xml",       YANG_PATCH_XML},
    {"application/yang-patch+json",      YANG_PATCH_JSON},
    {"application/yang-data+xml-list",   YANG_PAGINATION_XML},  /* sdraft-netconf-list-pagination-04.txt */
    {"text/html",                        HTTP_DATA_TEXT_HTML}, /* for http_data */
    {NULL,                              -1}
};

/* Mapping to http proto types */
static const map_str2int http_proto_map[] = {
    {"http/1.0",  HTTP_10},
    {"http/1.1",  HTTP_11},
    {"http/2",    HTTP_2},
    {NULL,        -1}
};

int
restconf_err2code(char *tag)
{
    return clicon_str2int(netconf_restconf_map, tag);
}

const char *
restconf_code2reason(int code)
{
    return clicon_int2str(http_reason_phrase_map, code);
}

/*! One media to integer representation
 */
const restconf_media
restconf_media_str2int(char *media)
{
    return clicon_str2int(http_media_map, media);
}

/*! Select first registered media in media list to integer
 *
 * Example: list="imag/avif,application/yang-data+xml,**"
 * returns: YANG_DATA_XML
 * Note that if no registered medias are found, then return -1
 * Filters any "; q=.."
 * @param[in]  list
 * @retval    -1     No registered media found
 */
const restconf_media
restconf_media_list_str2int(char *list)
{
    int     reti = -1;
    cg_var *cv;
    cvec   *cvv = NULL;
    char   *str;

    if (uri_str2cvec(list, ',', ';', 0, &cvv) < 0)
        return -1;
    cv = NULL;
    while ((cv = cvec_each(cvv, cv)) != NULL){
        str = cv_name_get(cv);
        if ((reti = clicon_str2int(http_media_map, str)) != -1)
            break;
    }
    if (cvv)
        cvec_free(cvv);
    return reti;
}

/*! Check if media exists in media string
 *
 * Example: media="text/html";
 *          list="img/avif,text/html,application/yang-data+xml,**"
 * Returns: 1
 * @param[in]  media  Single media string
 * @param[in]  list   Comma-separated list of medias
 * @retval     1      Found
 * @retval     0      Not found
 * @retval    -1      Error
 */
int
restconf_media_in_list(char *media,
                       char *list)
{
    int     retval = -1;
    cg_var *cv;
    cvec   *cvv = NULL;
    char   *str;

    if (uri_str2cvec(list, ',', ';', 0, &cvv) < 0)
        goto done;
    cv = NULL;
    while ((cv = cvec_each(cvv, cv)) != NULL){
        str = cv_name_get(cv);
        if (strcmp(str, media) == 0)
            break;
    }
    if (cv != NULL)
        retval = 1;
    else
        retval = 0;
 done:
    if (cvv)
        cvec_free(cvv);
    return retval;
}

const char *
restconf_media_int2str(restconf_media media)
{
    return clicon_int2str(http_media_map, media);
}

int
restconf_str2proto(char *str)
{
    return clicon_str2int(http_proto_map, str);
}

const char *
restconf_proto2str(int proto)
{
    return clicon_int2str(http_proto_map, proto);
}

/*! Return media_in from Content-Type, -1 if not found or unrecognized
 *
 * @note media-type syntax does not support parameters
 * @see RFC7231 Sec 3.1.1.1 for media-type syntax type:
 *    media-type = type "/" subtype *( OWS ";" OWS parameter )
 *     type       = token
 *    subtype    = token
 *
 */
restconf_media
restconf_content_type(clixon_handle h)
{
    char          *str = NULL;
    restconf_media m;

    if ((str = restconf_param_get(h, "HTTP_CONTENT_TYPE")) == NULL)
        return -1;
    if ((int)(m = restconf_media_str2int(str)) == -1)
        return -1;
    return m;
}

/*! Translate http header by capitalizing, prepend w HTTP_ and - -> _
 *
 * Example: Host -> HTTP_HOST 
 */
int
restconf_convert_hdr(clixon_handle h,
                     char         *name,
                     char         *val)
{
    int           retval = -1;
    cbuf         *cb = NULL;
    int           i;
    char          c;
    size_t       len;

    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    /* convert key name */
    cprintf(cb, "HTTP_");
    len = strlen(name);
    for (i=0; i<len; i++){
        c = name[i] & 0xff;
        if (islower(c))
            cprintf(cb, "%c", toupper(c));
        else if (c == '-')
            cprintf(cb, "_");
        else
            cprintf(cb, "%c", c);
    }
    if (restconf_param_set(h, cbuf_get(cb), val) < 0)
        goto done;
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
}

/*! Parse a cookie string and return value of cookie attribute
 *
 * @param[in]  cookiestr  cookie string according to rfc6265 (modified)
 * @param[in]  attribute  cookie attribute
 * @param[out] val        malloced cookie value, free with free()
 * @retval     0          OK
 * @retval    -1          Error
 */
int
get_user_cookie(char  *cookiestr,
                char  *attribute,
                char **val)
{
    int    retval = -1;
    cvec  *cvv = NULL;
    char  *c;

    if (uri_str2cvec(cookiestr, ';', '=', 1, &cvv) < 0)
        goto done;
    if ((c = cvec_find_str(cvv, attribute)) != NULL){
        if ((*val = strdup(c)) == NULL)
            goto done;
    }
    retval = 0;
 done:
    if (cvv)
        cvec_free(cvv);
    return retval;
}

/*! Clean and close all state of restconf process (but dont exit).
 *
 * Cannot use h after this 
 * @param[in]  h  Clixon handle
 */
int
restconf_terminate(clixon_handle h)
{
    cvec      *nsctx;
    cxobj     *x;
    int        fs; /* fgcx socket */

    clixon_debug(CLIXON_DBG_RESTCONF, "");
    if ((fs = clicon_socket_get(h)) != -1)
        close(fs);
    /* Delete all plugins, and RPC callbacks */
    clixon_plugin_module_exit(h);
    clicon_rpc_close_session(h);
    yang_exit(h);
    if ((nsctx = clicon_nsctx_global_get(h)) != NULL)
        cvec_free(nsctx);
    if ((x = clicon_conf_xml(h)) != NULL)
        xml_free(x);
    xpath_optimize_exit();
    clixon_err_exit();
    clixon_debug(CLIXON_DBG_RESTCONF, "pid:%u done", getpid());
    restconf_handle_exit(h);
    clixon_log_exit(); /* Must be after last clixon_debug */
    return 0;
}

/*! If RESTCONF insert/point attributes are present, translate to NETCONF 
 *
 * @param[in] xdata  URI->XML to translate
 * @param[in] qvec   Query parameters (eg where insert/point should be)
 * @retval    0      OK 
 * @retval   -1      Error
 * A difficulty is that RESTCONF 'point' is a complete identity-identifier encoded
 * as an uri-path
 * wheras NETCONF key and value are:
 * The value of the "key" attribute is the key predicates of the full instance identifier
 * the "value" attribute MUST also be used to specify an existing entry in the
 * leaf-list.
 * This means that api-path is first translated to xpath, and then strip everything
 * except the key values (or leaf-list values).
 * Example:
 * RESTCONF URI: point=%2Fexample-jukebox%3Ajukebox%2Fplaylist%3DFoo-One%2Fsong%3D1
 * Leaf example:
 *   instance-id: /ex:system/ex:service[ex:name='foo'][ex:enabled='']
 *   NETCONF: yang:key="[ex:name='foo'][ex:enabled='']
 * Leaf-list example:
 *   instance-id: /ex:system/ex:service[.='foo']
 *   NETCONF: yang:value="foo"
 */
int
restconf_insert_attributes(cxobj *xdata,
                           cvec  *qvec)
{
    int        retval = -1;
    char      *instr;
    char      *pstr;
    yang_stmt *y;
    char      *attrname;
    int        ret;
    char      *xpath = NULL;
    cvec      *nsc = NULL;
    cbuf      *cb = NULL;
    char      *p;
    cg_var    *cv = NULL;

    y = xml_spec(xdata);
    if ((instr = cvec_find_str(qvec, "insert")) != NULL){
        /* First add xmlns:yang attribute */
        if (xmlns_set(xdata, "yang", YANG_XML_NAMESPACE) < 0)
            goto done;
        if (xml_add_attr(xdata, "insert", instr, "yang", NULL) == NULL)
            goto done;
    }
    if ((pstr = cvec_find_str(qvec, "point")) != NULL){
        if (y == NULL){
            clixon_err(OE_YANG, 0, "Cannot yang resolve %s", xml_name(xdata));
            goto done;
        }
        if (yang_keyword_get(y) == Y_LIST)
            attrname="key";
        else
            attrname="value";

        if ((ret = api_path2xpath(pstr, ys_spec(y), &xpath, &nsc, NULL)) < 0)
            goto done;
        if ((cb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            goto done;
        }
        if (yang_keyword_get(y) == Y_LIST){
            /* translate /../x[] --> []*/
            if ((p = rindex(xpath,'/')) == NULL)
                p = xpath;
            p = index(p, '[');
            cprintf(cb, "%s", p);
        }
        else{ /* LEAF_LIST */
            /* translate /../x[.='x'] --> x */
            if ((p = rindex(xpath,'\'')) == NULL){
                clixon_err(OE_YANG, 0, "Translated api->xpath %s->%s not on leaf-list canonical form: ../[.='x']", pstr, xpath);
                goto done;
            }
            *p = '\0';
            if ((p = rindex(xpath,'\'')) == NULL){
                clixon_err(OE_YANG, 0, "Translated api->xpath %s->%s not on leaf-list canonical form: ../[.='x']", pstr, xpath);
                goto done;
            }
            p++;
            cprintf(cb, "%s", p);
        }
        if (xml_add_attr(xdata, attrname, cbuf_get(cb), "yang", NULL) == NULL)
            goto done;
    }
    /* Add prefix/namespaces used in attributes */
    cv = NULL;
    while ((cv = cvec_each(nsc, cv)) != NULL){
        char *ns = cv_string_get(cv);
        if (xmlns_set(xdata, cv_name_get(cv), ns) < 0)
            goto done;
    }
    if (nsc)
        xml_sort(xdata); /* Ensure attr is first */
    cprintf(cb, "/>");
    retval = 0;
 done:
    if (xpath)
        free(xpath);
    if (nsc)
        xml_nsctx_free(nsc);
    if (cb)
        cbuf_free(cb);
    return retval;
}

/*! Callback for yang extensions ietf-restconf:yang-data
 *
 * @param[in] h    Clixon handle
 * @param[in] yext Yang node of extension
 * @param[in] ys   Yang node of (unknown) statement belonging to extension
 * @retval    0    OK, all callbacks executed OK
 * @retval   -1    Error in one callback
 * @note This extension adds semantics to YANG according to RFC8040 as follows:
 *   - The list-stmt is not required to have a key-stmt defined.(NB!!)
 *   - The if-feature-stmt is ignored if present.
 *   - The config-stmt is ignored if present.
 *   - The available identity values for any 'identityref'
 *       leaf or leaf-list nodes are limited to the module containing this extension statement and
 *       the modules imported into that module.
 * @see ietf-restconf.yang
 */
int
restconf_main_extension_cb(clixon_handle h,
                           yang_stmt    *yext,
                           yang_stmt    *ys)
{
    int        retval = -1;
    char      *extname;
    char      *modname;
    yang_stmt *ymod;
    yang_stmt *yc;
    yang_stmt *yn = NULL;

    ymod = ys_module(yext);
    modname = yang_argument_get(ymod);
    extname = yang_argument_get(yext);
    if (strcmp(modname, "ietf-restconf") != 0 || strcmp(extname, "yang-data") != 0)
        goto ok;
    clixon_debug(CLIXON_DBG_RESTCONF, "Enabled extension:%s:%s", modname, extname);
    if ((yc = yang_find(ys, 0, NULL)) == NULL)
        goto ok;
    if ((yn = ys_dup(yc)) == NULL)
        goto done;
    /* yang-data extension: The list-stmt is not required to have a key-stmt defined.
     */
    yang_flag_set(yn, YANG_FLAG_NOKEY);
    if (yn_insert(yang_parent_get(ys), yn) < 0)
        goto done;
 ok:
    retval = 0;
 done:
    return retval;
}

/*! Extract uri-encoded uri-path without arguments
 *
 * Use REQUEST_URI parameter and strip ?args
 *   eg /interface=eth%2f0%2f0?insert=first -> /interface=eth%2f0%2f0
 * @retval path malloced, need free
 */
char *
restconf_uripath(clixon_handle h)
{
    char *path = NULL;
    char *path2 = NULL;
    char *q;

    if ((path = restconf_param_get(h, "REQUEST_URI")) == NULL){
        clixon_err(OE_RESTCONF, 0, "No REQUEST_URI");
        return NULL;
    }
    if ((path2 = strdup(path)) == NULL){
        clixon_err(OE_UNIX, errno, "strdup");
        return NULL;
    }
    if ((q = index(path2, '?')) != NULL)
        *q = '\0';
    return path2;
}

/*! Drop privileges from root to user (or already at user)
 *
 * @param[in]  h    Clixon handle
 * @retval     0    OK
 * @retval    -1    Error
 * Group set to CLICON_SOCK_GROUP to communicate with backend
 */
int
restconf_drop_privileges(clixon_handle h)
{
    int   retval = -1;
    uid_t newuid = -1;
    uid_t uid;
    char *group;
    gid_t gid = -1;
    char *user;
    enum priv_mode_t priv_mode = PM_NONE;

    clixon_debug(CLIXON_DBG_RESTCONF, "");
    /* Sanity check: backend group exists */
    if ((group = clicon_sock_group(h)) == NULL){
        clixon_err(OE_FATAL, 0, "clicon_sock_group option not set");
        return -1;
    }
    if (group_name2gid(group, &gid) < 0){
        clixon_log(h, LOG_ERR, "'%s' does not seem to be a valid user group." /* \n required here due to multi-line log */
                   "The config daemon requires a valid group to create a server UNIX socket\n"
                   "Define a valid CLICON_SOCK_GROUP in %s or via the -g option\n"
                   "or create the group and add the user to it. Check documentation for how to do this on your platform",
                   group,
                   clicon_configfile(h));
        goto done;
    }

    /* Get privileges mode (for dropping privileges) */
    if ((priv_mode = clicon_restconf_privileges_mode(h)) == PM_NONE)
        goto ok;
    if ((user = clicon_option_str(h, "CLICON_RESTCONF_USER")) == NULL)
        goto ok;

    /* Get (wanted) new www user id */
    if (name2uid(user, &newuid) < 0){
        clixon_err(OE_DAEMON, errno, "'%s' is not a valid user .\n", user);
        goto done;
    }
    /* get current userid, if already at this level OK */
    if ((uid = getuid()) == newuid)
        goto ok;
    if (uid != 0){
        clixon_err(OE_DAEMON, EPERM, "Privileges can only be dropped from root user (uid is %u)\n", uid);
        goto done;
    }
    if (setgid(gid) == -1) {
        clixon_err(OE_DAEMON, errno, "setgid %d", gid);
        goto done;
    }
    switch (priv_mode){
    case PM_DROP_PERM:
        if (drop_priv_perm(newuid) < 0)
            goto done;
        /* Verify you cannot regain root privileges */
        if (setuid(0) != -1){
            clixon_err(OE_DAEMON, EPERM, "Could regain root privilieges");
            goto done;
        }
        break;
    case PM_DROP_TEMP:
        if (drop_priv_temp(newuid) < 0)
            goto done;
        break;
    case PM_NONE:
        break; /* catched above */
    }
    clixon_debug(CLIXON_DBG_RESTCONF, "dropped privileges from root to %s(%d)",
                 user, newuid);
 ok:
    retval = 0;
 done:
    return retval;
}

/*! restconf auth cb
 *
 * @param[in]  h         Clixon handle
 * @param[in]  req       Generic Www handle (can be part of clixon handle)
 * @param[in]  pretty    Pretty-print
 * @param[in]  media_out Restconf output media
 * @retval     1         Authenticated
 * @retval     0         Not authenticated
 * @retval    -1         Error
 */
int
restconf_authentication_cb(clixon_handle  h,
                           void          *req,
                           int            pretty,
                           restconf_media media_out)
{
    int                retval = -1;
    clixon_auth_type_t auth_type;
    int                authenticated;
    int                ret;
    char              *username = NULL; /* Assume malloced if set */
    cxobj             *xret = NULL;
    cxobj             *xerr;
    char              *anonymous = NULL;

    auth_type = restconf_auth_type_get(h);
    clixon_debug(CLIXON_DBG_RESTCONF, "auth-type:%s", clixon_auth_type_int2str(auth_type));
    ret = 0;
    authenticated = 0;
    /* ret: -1 Error, 0: Ignore/not handled, 1: OK see authenticated parameter */
    if ((ret = clixon_plugin_auth_all(h, req,
                                      auth_type,
                                      &username)) < 0)
        goto done;
    if (ret == 1){ /* OK, tag username to handle */
        if (username != NULL){
            authenticated = 1;
            clicon_username_set(h, username);
        }
    }
    else {         /* Default behaviour */
        switch (auth_type){
        case CLIXON_AUTH_NONE:
            /* if not handled by callback, use anonymous user */
            if ((anonymous = clicon_option_str(h, "CLICON_ANONYMOUS_USER")) == NULL){
                break; /* not authenticated */
            }
            clicon_username_set(h, anonymous);
            authenticated = 1;
            break;
        case CLIXON_AUTH_CLIENT_CERTIFICATE: {
            char *cn;
            /* Check for cert subject common name (CN) */
            if ((cn = restconf_param_get(h, "SSL_CN")) != NULL){
                clicon_username_set(h, cn);
                authenticated = 1;
            }
            break;
        }
        case CLIXON_AUTH_USER:
            authenticated = 0;
            break;
        }
    }
    if (authenticated == 0){ /* Message is not authenticated (401 returned) */
        if (netconf_access_denied_xml(&xret, "protocol", "The requested URL was unauthorized") < 0)
            goto done;
        if ((xerr = xpath_first(xret, NULL, "//rpc-error")) != NULL){
            if (api_return_err(h, req, xerr, pretty, media_out, 0) < 0)
                goto done;
            goto notauth;
        }
        retval = 0;
        goto notauth;
    }
    /* If set but no user, set a dummy user */
    retval = 1;
 done:
    clixon_debug(CLIXON_DBG_RESTCONF, "retval:%d authenticated:%d user:%s",
                 retval, authenticated, clicon_username_get(h));
    if (username)
        free(username);
    if (xret)
        xml_free(xret);
    return retval;
 notauth:
    retval = 0;
    goto done;
}

/*! Basic config init, set auth-type, pretty, etc
 *
 * @param[in]  h         Clixon handle
 * @param[in]  xrestconf XML config containing clixon-restconf top-level
 * @retval     1         OK
 * @retval     0         Restconf is disable
 * @retval    -1         Error
 */
int
restconf_config_init(clixon_handle h,
                     cxobj        *xrestconf)
{
    int        retval = -1;
    char      *enable;
    cxobj     *x;
    char      *bstr;
    cvec      *nsc = NULL;
    int        auth_type;
    yang_stmt *yspec;
    yang_stmt *y;

    if ((yspec = clicon_dbspec_yang(h)) == NULL){
        clixon_err(OE_FATAL, 0, "No DB_SPEC");
        goto done;
    }
    /* Apply default values (removed in clear function) */
    if (xml_default_recurse(xrestconf, 0, 0) < 0)
        goto done;
    if ((x = xpath_first(xrestconf, nsc, "enable")) != NULL &&
        (enable = xml_body(x)) != NULL){
        if (strcmp(enable, "false") == 0){
            clixon_debug(CLIXON_DBG_RESTCONF, "restconf disabled");
            goto disable;
        }
    }
    /* get common fields */
    if ((x = xpath_first(xrestconf, nsc, "auth-type")) != NULL &&
        (bstr = xml_body(x)) != NULL){
        if ((auth_type = clixon_auth_type_str2int(bstr)) < 0){
            clixon_err(OE_CFG, EFAULT, "Invalid restconf auth-type: %s", bstr);
            goto done;
        }
        restconf_auth_type_set(h, auth_type);
    }
    if ((x = xpath_first(xrestconf, nsc, "pretty")) != NULL &&
        (bstr = xml_body(x)) != NULL){
        if (strcmp(bstr, "true") == 0)
            restconf_pretty_set(h, 1);
        else if (strcmp(bstr, "false") == 0)
            restconf_pretty_set(h, 0);
    }
    /* Check if enable-http-data is true and that feature is enabled
     * It is protected by if-feature http-data, which means if the feature is not enabled, its
     * YANG spec will exist but by ANYDATA
     */
    if ((x = xpath_first(xrestconf, nsc, "enable-http-data")) != NULL &&
        (y = xml_spec(x)) != NULL &&
        yang_keyword_get(y) != Y_ANYDATA &&
        (bstr = xml_body(x)) != NULL &&
        strcmp(bstr, "true") == 0) {
        restconf_http_data_set(h, 1);
    }
    else
        restconf_http_data_set(h, 0);

    /* Check if fcgi-socket is true and that feature is enabled
     * It is protected by if-feature fcgi, which means if the feature is not enabled, then 
     * YANG spec will exist but by ANYDATA
     */
    if ((x = xpath_first(xrestconf, nsc, "fcgi-socket")) != NULL &&
        (y = xml_spec(x)) != NULL &&
        yang_keyword_get(y) != Y_ANYDATA &&
        (bstr = xml_body(x)) != NULL){
        if (restconf_fcgi_socket_set(h, bstr) < 0)
            goto done;
    }
    retval = 1;
 done:
    return retval;
 disable:
    retval = 0;
    goto done;
}

/*! Create and bind restconf socket
 *
 * @param[in]  netns0    Network namespace, special value "default" is same as NULL
 * @param[in]  addrstr   Address as string, eg "0.0.0.0", "::"
 * @param[in]  addrtype  One of inet:ipv4-address or inet:ipv6-address
 * @param[in]  port      TCP port
 * @param[in]  backlog   Listen backlog, queie of pending connections
 * @param[in]  flags     Socket flags OR:ed in with the socket(2) type parameter
 * @param[out] ss        Server socket (bound for accept)
 * @retval     0         OK
 * @retval    -1         Error
 */
int
restconf_socket_init(const char   *netns0,
                     const char   *addrstr,
                     const char   *addrtype,
                     uint16_t      port,
                     int           backlog,
                     int           flags,
                     int          *ss)
{
    int                 retval = -1;
    struct sockaddr_in6 sin6 = {0,}; // because its larger than sin and sa
    struct sockaddr    *sa = (struct sockaddr *)&sin6;
    size_t              sa_len;
    const char         *netns;

    clixon_debug(CLIXON_DBG_RESTCONF, "%s %s %s %hu", netns0, addrtype, addrstr, port);
    /* netns default -> NULL */
    if (netns0 != NULL && strcmp(netns0, RESTCONF_NETNS_DEFAULT)==0)
        netns = NULL;
    else
        netns = netns0;
    if (clixon_inet2sin(addrtype, addrstr, port, sa, &sa_len) < 0)
        goto done;
    if (clixon_netns_socket(netns, sa, sa_len, backlog, flags, addrstr, ss) < 0)
        goto done;
    clixon_debug(CLIXON_DBG_RESTCONF, "ss=%d", *ss);
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_RESTCONF, "retval:%d", retval);
    return retval;
}

/*! Callback used by api_path2xml when yang mountpoint is empty
 *
 * @param[in]  h   Clixon handle
 * @param[in]  x   XML node
 * @param[out] yp  YANG
 */
int
restconf_apipath_mount_cb(clixon_handle h,
                          cxobj        *x,
                          yang_stmt   **yp)
{
    int    retval = -1;
    cxobj *xyanglib = NULL;
    int    ret;

    if (clixon_plugin_yang_mount_all(h, x, NULL, NULL, &xyanglib) < 0)
        goto done;
    if (xyanglib != NULL){
        if ((ret = yang_schema_yanglib_mount_parse(h, x, xyanglib, yp)) < 0)
            goto done;
    }
    retval = 0;
 done:
    if (xyanglib)
        xml_free(xyanglib);
    return retval;
}
