/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2026 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 * gNMI RPC handlers for clixon_grpc
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <syslog.h>
#include <sys/time.h>

#include <protobuf-c/protobuf-c.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

/* generated protobuf — fields marked deprecated in the gNMI proto are reflected
 * in the generated header and its init macros; suppress -Wdeprecated-declarations
 * for this file since we cannot modify the official gNMI .proto file */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#include "gnmi.pb-c.h"

#include "grpc_nghttp2.h"
#include "grpc_gnmi.h"
#include "banned.h"

/*! Map from NETCONF error-tag (RFC 6241 App. A) to gRPC status code
 *
 * NETCONF error-tags carried in an rpc-error are translated to the closest
 * gRPC status (https://grpc.github.io/grpc/core/md_doc_statuscodes.html)
 * @see netconf_grpc_map (RESTCONF equivalent) in apps/restconf/restconf_lib.c
 */
static const map_str2int netconf_grpc_map[] = {
    {"invalid-value",           GRPC_INVALID_ARGUMENT},
    {"too-big",                 GRPC_INVALID_ARGUMENT},
    {"missing-attribute",       GRPC_INVALID_ARGUMENT},
    {"bad-attribute",           GRPC_INVALID_ARGUMENT},
    {"unknown-attribute",       GRPC_INVALID_ARGUMENT},
    {"missing-element",         GRPC_INVALID_ARGUMENT},
    {"bad-element",             GRPC_INVALID_ARGUMENT},
    {"unknown-element",         GRPC_INVALID_ARGUMENT},
    {"unknown-namespace",       GRPC_INVALID_ARGUMENT},
    {"malformed-message",       GRPC_INVALID_ARGUMENT},
    {"access-denied",           GRPC_PERMISSION_DENIED},
    {"data-exists",             GRPC_ALREADY_EXISTS},
    {"data-missing",            GRPC_FAILED_PRECONDITION},
    {"in-use",                  GRPC_FAILED_PRECONDITION},
    {"lock-denied",             GRPC_FAILED_PRECONDITION},
    {"resource-denied",         GRPC_FAILED_PRECONDITION},
    {"rollback-failed",         GRPC_INTERNAL},
    {"partial-operation",       GRPC_INTERNAL},
    {"operation-not-supported", GRPC_UNIMPLEMENTED},
    {"operation-failed",        GRPC_FAILED_PRECONDITION},
    {NULL,                      -1}
};

/*! Translate a NETCONF error-tag to a gRPC status code
 *
 * @param[in]  tag  NETCONF error-tag string (may be NULL)
 * @retval     grpc status code, GRPC_FAILED_PRECONDITION if tag unknown/NULL
 */
static int
gnmi_errtag2status(const char *tag)
{
    int status;

    if (tag == NULL || (status = clicon_str2int(netconf_grpc_map, tag)) < 0)
        return GRPC_FAILED_PRECONDITION;
    return status;
}

/*! Build a NETCONF RPC in a cbuf, send it, and map any rpc-error to gRPC status
 *
 * Mirrors the RESTCONF pattern (construct RPC in a cbuf, send via
 * clicon_rpc_netconf, inspect the reply for rpc-error). On a NETCONF error the
 * detailed reason is set via clixon_err_netconf() (so it reaches the
 * grpc-message trailer) and the error-tag is mapped to a gRPC status code.
 *
 * @param[in]   h            Clixon handle
 * @param[in]   rpcstr       NETCONF RPC as a string (<rpc>...</rpc>)
 * @param[in]   errprefix    Prefix for the error reason (eg "edit-config")
 * @param[out]  grpc_status  gRPC status code, set on NETCONF error
 * @retval      1            OK, no error
 * @retval      0            NETCONF error returned (reason + grpc_status set)
 * @retval     -1            Fatal error
 */
static int
gnmi_rpc_send(clixon_handle h,
              const char   *rpcstr,
              const char   *errprefix,
              int          *grpc_status)
{
    int    retval = -1;
    cxobj *xret = NULL;
    cxobj *xerr;

    if (clicon_rpc_netconf(h, rpcstr, &xret, NULL) < 0)
        goto done;
    if ((xerr = xpath_first(xret, NULL, "//rpc-error")) != NULL){
        clixon_err_netconf(h, OE_NETCONF, 0, xerr, "%s", errprefix);
        *grpc_status = gnmi_errtag2status(netconf_reply_err_tag(xret));
        retval = 0;
        goto done;
    }
    retval = 1;
 done:
    if (xret)
        xml_free(xret);
    return retval;
}

/*! Build gNMI CapabilityResponse and serialize it
 *
 * Iterates the loaded YANG spec to populate supported_models.
 * Returns JSON_IETF as the only supported encoding.
 *
 * @param[in]  h            Clixon handle
 * @param[in]  req_buf      Serialized CapabilityRequest (may be NULL/empty)
 * @param[in]  req_len      Length of req_buf
 * @param[out] resp_buf     Caller-owned serialized CapabilityResponse
 * @param[out] resp_len     Length of resp_buf
 * @param[out] grpc_status  gRPC status code on error
 * @retval     0            OK
 * @retval    -1            Error
 */
int
gnmi_capabilities(clixon_handle  h,
                  const uint8_t *req_buf,
                  size_t         req_len,
                  uint8_t      **resp_buf,
                  size_t        *resp_len,
                  int           *grpc_status)
{
    int                       retval = -1;
    yang_stmt                *yspec;
    yang_stmt                *ymod;
    yang_stmt                *yrev;
    yang_stmt                *yorg;
    int                       nmod = 0;
    int                       i;
    int                       inext;
    Gnmi__CapabilityResponse  resp = GNMI__CAPABILITY_RESPONSE__INIT;
    Gnmi__ModelData         **models = NULL;
    Gnmi__ModelData          *md;
    uint8_t                  *buf = NULL;
    size_t                    sz;
    static Gnmi__Encoding     encs[] = {
        GNMI__ENCODING__JSON_IETF,
        GNMI__ENCODING__JSON,
        GNMI__ENCODING__ASCII,
    };

    *grpc_status = GRPC_INTERNAL;

    (void)req_buf;
    (void)req_len;

    yspec = clicon_dbspec_yang(h);

    /* Count top-level modules in the yspec */
    inext = 0;
    while ((ymod = yn_iter(yspec, &inext)) != NULL){
        if (yang_keyword_get(ymod) == Y_MODULE)
            nmod++;
    }

    if (nmod > 0){
        if ((models = calloc(nmod, sizeof *models)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
        }
        i = 0;
        inext = 0;
        while ((ymod = yn_iter(yspec, &inext)) != NULL){
            if (yang_keyword_get(ymod) != Y_MODULE)
                continue;
            if ((md = calloc(1, sizeof *md)) == NULL){
                clixon_err(OE_UNIX, errno, "calloc");
                goto done;
            }
            gnmi__model_data__init(md);
            md->name = yang_argument_get(ymod);
            /* Revision — use first Y_REVISION child if present */
            yrev = yang_find(ymod, Y_REVISION, NULL);
            if (yrev != NULL)
                md->version = yang_argument_get(yrev);
            /* Organization */
            yorg = yang_find(ymod, Y_ORGANIZATION, NULL);
            if (yorg != NULL)
                md->organization = yang_argument_get(yorg);
            models[i++] = md;
        }
    }

    resp.n_supported_models   = nmod;
    resp.supported_models     = models;

    /* Report supported encodings */
    resp.n_supported_encodings = 3;
    resp.supported_encodings   = encs;
    resp.gnmi_version = "0.10.0";

    sz  = gnmi__capability_response__get_packed_size(&resp);
    if ((buf = malloc(sz)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    gnmi__capability_response__pack(&resp, buf);

    *resp_buf = buf;
    *resp_len = sz;
    buf = NULL;
    retval = 0;
 done:
    if (models){
        for (i = 0; i < nmod; i++)
            if (models[i])
                free(models[i]);
        free(models);
    }
    if (buf)
        free(buf);
    return retval;
}

/*! Find the YANG namespace for a module name
 *
 * Searches all loaded modules for a module matching the given name.
 * Returns a pointer into the YANG tree — do NOT free.
 *
 * @param[in]  h        Clixon handle
 * @param[in]  modname  YANG module name
 * @retval     ns       Namespace string (borrowed, not freed by caller)
 * @retval     NULL     Not found
 */
static const char *
gnmi_namespace_from_module(clixon_handle h,
                           const char   *modname)
{
    yang_stmt *yspec;
    yang_stmt *ymod;
    yang_stmt *yns;
    int        inext = 0;

    yspec = clicon_dbspec_yang(h);
    while ((ymod = yn_iter(yspec, &inext)) != NULL){
        if (yang_keyword_get(ymod) != Y_MODULE)
            continue;
        if (strcmp(yang_argument_get(ymod), modname) == 0){
            yns = yang_find(ymod, Y_NAMESPACE, NULL);
            if (yns != NULL)
                return yang_argument_get(yns);
        }
    }
    return NULL;
}

/*! Find the YANG namespace for a top-level node name
 *
 * Searches all loaded modules for a top-level data node matching name.
 * Returns a pointer into the YANG tree — do NOT free.
 *
 * @param[in]  h     Clixon handle
 * @param[in]  name  Top-level node name to look up
 * @retval     ns    Namespace string (borrowed, not freed by caller)
 * @retval     NULL  Not found
 */
static const char *
gnmi_find_namespace(clixon_handle h,
                    const char   *name)
{
    yang_stmt *yspec;
    yang_stmt *ymod;
    yang_stmt *yns;
    int        inext = 0;

    yspec = clicon_dbspec_yang(h);
    while ((ymod = yn_iter(yspec, &inext)) != NULL){
        if (yang_keyword_get(ymod) != Y_MODULE)
            continue;
        if (yang_find_datanode(ymod, name) != NULL){
            yns = yang_find(ymod, Y_NAMESPACE, NULL);
            if (yns != NULL)
                return yang_argument_get(yns);
        }
    }
    return NULL;
}

/*! Validate a gNMI-supplied element/key name is a safe identifier
 *
 * gNMI path element and key names become XML element/tag names and XPath node
 * names; these cannot be escaped, so reject any name containing characters
 * outside a conservative YANG-identifier set (alphanumeric, '_', '-', '.') to
 * prevent XML/XPath structure injection.
 * @param[in]  name  Candidate name
 * @retval     1     Valid
 * @retval     0     Invalid (NULL, empty, or illegal character)
 */
static int
gnmi_name_valid(const char *name)
{
    const char *p;

    if (name == NULL || *name == '\0')
        return 0;
    for (p = name; *p; p++){
        if ((*p >= 'A' && *p <= 'Z') ||
            (*p >= 'a' && *p <= 'z') ||
            (*p >= '0' && *p <= '9') ||
            *p == '_' || *p == '-' || *p == '.')
            continue;
        return 0;
    }
    return 1;
}

/*! Resolve the namespace and local name for a gNMI path element
 *
 * gNMI uses YANG module-qualified names ("module:localname") to identify
 * elements from a different module than the parent (e.g. augmented nodes).
 * Unqualified names inherit the parent namespace; if the name does not exist
 * in the parent namespace, YANG tree traversal is used as a fallback to
 * resolve augmented nodes sent without a module qualifier by lenient clients.
 *
 * @param[in]     h           Clixon handle
 * @param[in]     elem_name   Raw name from PathElem (may be "module:localname")
 * @param[in]     parent_ns   Namespace inherited from parent element, or NULL
 * @param[in,out] yparent     Current YANG schema node; updated to child on return
 * @param[out]    local_name  Points into elem_name past any "module:" prefix
 * @retval        ns          Namespace string (borrowed, not freed by caller)
 * @retval        NULL        Not found
 */
static const char *
gnmi_resolve_elem_ns(clixon_handle  h,
                     const char    *elem_name,
                     const char    *parent_ns,
                     yang_stmt    **yparent,
                     const char   **local_name)
{
    const char *colon;
    yang_stmt  *yn = NULL;
    yang_stmt  *ymod;
    yang_stmt  *yns;
    const char *ns;
    char        modname[256];
    size_t      len;

    colon = strchr(elem_name, ':');
    if (colon != NULL){
        /* Module-qualified: resolve directly from module name */
        len = (size_t)(colon - elem_name);

        if (len >= sizeof modname)
            len = sizeof modname - 1;
        memcpy(modname, elem_name, len);
        modname[len] = '\0';
        *local_name = colon + 1;
        ns = gnmi_namespace_from_module(h, modname);
        /* Advance YANG parent */
        if (yparent != NULL){
            if (*yparent != NULL)
                yn = yang_find_datanode(*yparent, *local_name);
            *yparent = yn;
        }
        return ns;
    }

    /* Unqualified: use local name as-is */
    *local_name = elem_name;

    if (yparent != NULL && *yparent != NULL){
        /* Try to find the child in the current YANG parent — covers augmented
         * nodes whose namespace differs from the parent (fallback for clients
         * that don't qualify augmented element names). */
        yn = yang_find_datanode(*yparent, elem_name);
        *yparent = yn;
        if (yn != NULL){
            ymod = ys_module(yn);
            yns  = yang_find(ymod, Y_NAMESPACE, NULL);
            if (yns != NULL)
                return yang_argument_get(yns);
        }
    }

    /* No YANG parent or child not found: inherit parent namespace */
    return parent_ns;
}

/*! Free the allocated inner value of a Gnmi__TypedValue built by gnmi_get
 *
 * Only frees the dynamically allocated string/bytes payload; does not free tv
 * itself (caller owns the struct).
 */
static void
gnmi_typed_value_free(Gnmi__TypedValue *tv)
{
    if (tv == NULL)
        return;
    switch (tv->value_case){
    case GNMI__TYPED_VALUE__VALUE_ASCII_VAL:
        free(tv->ascii_val);
        break;
    case GNMI__TYPED_VALUE__VALUE_JSON_VAL:
        free(tv->json_val.data);
        break;
    case GNMI__TYPED_VALUE__VALUE_JSON_IETF_VAL:
        free(tv->json_ietf_val.data);
        break;
    default:
        break;
    }
}

/*! Find the top-level YANG data node matching a local name
 *
 * Searches all loaded modules for a top-level data node.
 * Returns a borrowed pointer into the YANG tree — do NOT free.
 *
 * @param[in]  h      Clixon handle
 * @param[in]  local  Top-level node name
 * @retval     yn     YANG node (borrowed)
 * @retval     NULL   Not found
 */
static yang_stmt *
gnmi_find_yparent(clixon_handle h,
                  const char   *local)
{
    yang_stmt *yspec;
    yang_stmt *ymod;
    yang_stmt *yn;
    int        ix = 0;

    yspec = clicon_dbspec_yang(h);
    while ((ymod = yn_iter(yspec, &ix)) != NULL){
        if (yang_keyword_get(ymod) != Y_MODULE)
            continue;
        yn = yang_find_datanode(ymod, local);
        if (yn != NULL)
            return yn;
    }
    return NULL;
}

/*! Build XPath, query running datastore, return XML result for one gNMI path
 *
 * Constructs a namespace-qualified XPath from the gNMI path elements,
 * registers each distinct namespace with a unique prefix, then issues
 * clicon_rpc_get against the running datastore.
 *
 * @param[in]  h           Clixon handle
 * @param[in]  gpath       gNMI Path to query (may be NULL)
 * @param[in]  content     CONTENT_ALL, CONTENT_CONFIG, or CONTENT_NONCONFIG
 * @param[out] xretp       XML result tree; caller must xml_free()
 * @param[out] grpc_status gRPC status code on error
 * @retval     0           OK
 * @retval    -1           Error
 */
static int
gnmi_get_one_path(clixon_handle h,
                  Gnmi__Path   *gpath,
                  int           content,
                  cxobj       **xretp,
                  int          *grpc_status)
{
    int                       retval = -1;
    cvec                     *nsc = NULL;
    const char               *ns = NULL;
    const char               *prev_ns = NULL;
    int                       pfxnr = 0;
    char                      pfxbuf[16];
    yang_stmt                *yparent = NULL;
    const char               *local0;
    size_t                    j;
    size_t                    nk;
    cbuf                     *xpathcb = NULL;
    Gnmi__PathElem           *elem;
    Gnmi__PathElem__KeyEntry *ke;
    const char               *ens;
    const char               *local;
    char                     *pfx;

    *grpc_status = GRPC_INTERNAL;

    if ((xpathcb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }

    if (gpath != NULL && gpath->n_elem > 0){
        ns = gnmi_resolve_elem_ns(h, gpath->elem[0]->name, NULL, NULL, &local0);
        if (ns == NULL)
            ns = gnmi_find_namespace(h, gpath->elem[0]->name);
    }

    if (ns != NULL){
        if ((nsc = xml_nsctx_init(NULL, NULL)) == NULL){
            clixon_err(OE_UNIX, errno, "xml_nsctx_init");
            goto done;
        }
        /* Build xpath; each distinct namespace gets a unique prefix.
         * yparent is seeded on the first element that resolves, so that
         * subsequent unqualified augmented children are resolved via traversal. */
        for (j = 0; j < gpath->n_elem; j++){
            elem = gpath->elem[j];
            ens  = gnmi_resolve_elem_ns(h, elem->name, prev_ns, &yparent, &local);
            if (ens == NULL){
                ens   = ns;
                local = elem->name;
                if (yparent == NULL)
                    yparent = gnmi_find_yparent(h, local);
            }
            if (prev_ns == NULL || strcmp(ens, prev_ns) != 0){
                snprintf(pfxbuf, sizeof pfxbuf, "n%d", pfxnr++);
                if (xml_nsctx_add(nsc, pfxbuf, ens) < 0){
                    clixon_err(OE_UNIX, errno, "xml_nsctx_add");
                    goto done;
                }
                prev_ns = ens;
            }
            pfx = NULL;
            xml_nsctx_get_prefix(nsc, ens, &pfx);
            if (!gnmi_name_valid(local)){
                clixon_err(OE_XML, EINVAL, "Invalid gNMI element name in path");
                *grpc_status = GRPC_INVALID_ARGUMENT;
                goto done;
            }
            cprintf(xpathcb, "/%s:%s", pfx, local);
            for (nk = 0; nk < elem->n_key; nk++){
                ke = elem->key[nk];
                if (!gnmi_name_valid(ke->key)){
                    clixon_err(OE_XML, EINVAL, "Invalid gNMI key name in path");
                    *grpc_status = GRPC_INVALID_ARGUMENT;
                    goto done;
                }
                /* XPath 1.0 single-quoted literals cannot escape a quote, so
                 * reject key values containing one (prevents XPath injection) */
                if (ke->value != NULL && strchr(ke->value, '\'') != NULL){
                    clixon_err(OE_XML, EINVAL, "Invalid gNMI key value: contains quote");
                    *grpc_status = GRPC_INVALID_ARGUMENT;
                    goto done;
                }
                cprintf(xpathcb, "[%s:%s='%s']", pfx, ke->key, ke->value);
            }
        }
        if (clicon_rpc_get(h, cbuf_get(xpathcb), nsc,
                           content, -1, NULL, xretp) < 0)
            goto done;
    } else {
        if (clicon_rpc_get(h, "/", NULL, content, -1, NULL, xretp) < 0)
            goto done;
    }
    retval = 0;
 done:
    if (nsc)
        xml_nsctx_free(nsc);
    if (xpathcb)
        cbuf_free(xpathcb);
    return retval;
}

/*! Handle gNMI Get RPC
 *
 * Decodes GetRequest, queries the running datastore for each path,
 * and returns a GetResponse with one Notification per path.
 * Supported response encodings: JSON_IETF (default), JSON, ASCII.
 *
 * @param[in]  h            Clixon handle
 * @param[in]  req_buf      Serialized GetRequest
 * @param[in]  req_len      Length of req_buf
 * @param[out] resp_buf     Caller-owned serialized GetResponse
 * @param[out] resp_len     Length of resp_buf
 * @param[out] grpc_status  gRPC status code on error
 * @retval     0            OK
 * @retval    -1            Error
 */
int
gnmi_get(clixon_handle  h,
         const uint8_t *req_buf,
         size_t         req_len,
         uint8_t      **resp_buf,
         size_t        *resp_len,
         int           *grpc_status)
{
    int                    retval = -1;
    Gnmi__GetRequest      *req = NULL;
    Gnmi__GetResponse      gresp = GNMI__GET_RESPONSE__INIT;
    Gnmi__Notification   **notifs = NULL;
    Gnmi__Notification    *notif;
    Gnmi__Notification    *n;
    Gnmi__Update          *upd;
    Gnmi__Update          *u;
    char                  *jsonstr;
    size_t                 i;
    cxobj                 *xret = NULL;
    cbuf                  *jsoncb = NULL;
    uint8_t               *buf = NULL;
    size_t                 sz;
    int                    content;

    *grpc_status = GRPC_INTERNAL;

    req = gnmi__get_request__unpack(NULL, req_len, req_buf);
    if (req == NULL){
        clixon_err(OE_UNIX, 0, "gnmi__get_request__unpack");
        *grpc_status = GRPC_INVALID_ARGUMENT;
        goto done;
    }

    if (req->n_path == 0){
        /* No paths: return empty response */
        gresp.n_notification = 0;
        gresp.notification   = NULL;
        sz  = gnmi__get_response__get_packed_size(&gresp);
        if ((buf = malloc(sz)) == NULL){
            clixon_err(OE_UNIX, errno, "malloc");
            goto done;
        }
        gnmi__get_response__pack(&gresp, buf);
        *resp_buf = buf; buf = NULL;
        *resp_len = sz;
        retval = 0;
        goto done;
    }

    if ((notifs = calloc(req->n_path, sizeof *notifs)) == NULL){
        clixon_err(OE_UNIX, errno, "calloc");
        goto done;
    }

    /* Map gNMI DataType to Clixon content filter */
    switch (req->type){
    case GNMI__GET_REQUEST__DATA_TYPE__CONFIG:
        content = CONTENT_CONFIG;
        break;
    case GNMI__GET_REQUEST__DATA_TYPE__STATE:
    case GNMI__GET_REQUEST__DATA_TYPE__OPERATIONAL:
        content = CONTENT_NONCONFIG;
        break;
    case GNMI__GET_REQUEST__DATA_TYPE__ALL:
    default:
        content = CONTENT_ALL;
        break;
    }

    for (i = 0; i < req->n_path; i++){
        if (xret){
            xml_free(xret);
            xret = NULL;
        }
        if (gnmi_get_one_path(h, req->path[i], content, &xret, grpc_status) < 0)
            goto done;

        /* Build JSON from the returned XML subtree */
        if ((jsoncb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            goto done;
        }
        if (clixon_json2cbuf(jsoncb, xret, 0, 0, 0, 0) < 0)
            goto done;
        jsonstr = cbuf_get(jsoncb);

        /* Build Notification with one Update */
        if ((notif = calloc(1, sizeof *notif)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
        }
        gnmi__notification__init(notif);
        notif->timestamp = (int64_t)time(NULL) * (int64_t)1000000000;

        if ((upd = calloc(1, sizeof *upd)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            free(notif);
            goto done;
        }
        gnmi__update__init(upd);
        upd->path = req->path[i]; /* borrow reference — not freed separately */

        if ((upd->val = calloc(1, sizeof *upd->val)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            free(upd);
            free(notif);
            goto done;
        }
        gnmi__typed_value__init(upd->val);
        /* Encode response value according to requested encoding.
         * Default (JSON=0) is treated as JSON_IETF for RFC7951 compliance. */
        switch (req->encoding){
        case GNMI__ENCODING__ASCII:
            upd->val->value_case = GNMI__TYPED_VALUE__VALUE_ASCII_VAL;
            upd->val->ascii_val  = strdup(jsonstr);
            break;
        case GNMI__ENCODING__JSON:
            upd->val->value_case        = GNMI__TYPED_VALUE__VALUE_JSON_VAL;
            upd->val->json_val.data     = (uint8_t *)strdup(jsonstr);
            upd->val->json_val.len      = strlen(jsonstr);
            break;
        case GNMI__ENCODING__JSON_IETF:
        default:
            upd->val->value_case            = GNMI__TYPED_VALUE__VALUE_JSON_IETF_VAL;
            upd->val->json_ietf_val.data    = (uint8_t *)strdup(jsonstr);
            upd->val->json_ietf_val.len     = strlen(jsonstr);
            break;
        }

        notif->update = (Gnmi__Update **)malloc(sizeof(Gnmi__Update *));
        if (notif->update == NULL){
            clixon_err(OE_UNIX, errno, "malloc");
            gnmi_typed_value_free(upd->val);
            free(upd->val); free(upd); free(notif);
            goto done;
        }
        notif->update[0] = upd;
        notif->n_update  = 1;

        notifs[i] = notif;

        cbuf_free(jsoncb); jsoncb = NULL;
    }

    gresp.n_notification = req->n_path;
    gresp.notification   = notifs;

    sz = gnmi__get_response__get_packed_size(&gresp);
    if ((buf = malloc(sz)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    gnmi__get_response__pack(&gresp, buf);

    *resp_buf = buf; buf = NULL;
    *resp_len = sz;
    retval = 0;
 done:
    if (req)
        gnmi__get_request__free_unpacked(req, NULL);
    if (notifs){
        for (i = 0; i < (size_t)gresp.n_notification; i++){
            n = notifs[i];
            if (n){
                if (n->n_update && n->update){
                    u = n->update[0];
                    if (u){
                        if (u->val){
                            gnmi_typed_value_free(u->val);
                            free(u->val);
                        }
                        free(u);
                    }
                    free(n->update);
                }
                free(n);
            }
        }
        free(notifs);
    }
    if (jsoncb)
        cbuf_free(jsoncb);
    if (xret)
        xml_free(xret);
    if (buf)
        free(buf);
    return retval;
}

/*! Extract a string value from a gNMI TypedValue
 *
 * Supports JSON_IETF, JSON, and STRING typed values.
 * Strips surrounding double-quotes if present (JSON string encoding).
 * Caller owns the returned string and must free() it.
 *
 * @param[in]  tv    TypedValue to extract from
 * @retval     str   Allocated string (caller frees)
 * @retval     NULL  Unsupported value type or allocation error
 */
static char *
gnmi_extract_value_string(Gnmi__TypedValue *tv)
{
    char  *s = NULL;
    size_t len;
    char   numbuf[64];

    if (tv == NULL)
        return NULL;
    switch (tv->value_case){
    case GNMI__TYPED_VALUE__VALUE_JSON_IETF_VAL:
        s = strndup((char *)tv->json_ietf_val.data, tv->json_ietf_val.len);
        break;
    case GNMI__TYPED_VALUE__VALUE_JSON_VAL:
        s = strndup((char *)tv->json_val.data, tv->json_val.len);
        break;
    case GNMI__TYPED_VALUE__VALUE_STRING_VAL:
        s = strdup(tv->string_val);
        break;
    case GNMI__TYPED_VALUE__VALUE_ASCII_VAL:
        s = strdup(tv->ascii_val);
        break;
    case GNMI__TYPED_VALUE__VALUE_BOOL_VAL:
        s = strdup(tv->bool_val ? "true" : "false");
        break;
    case GNMI__TYPED_VALUE__VALUE_UINT_VAL:
        snprintf(numbuf, sizeof numbuf, "%" PRIu64, tv->uint_val);
        s = strdup(numbuf);
        break;
    case GNMI__TYPED_VALUE__VALUE_INT_VAL:
        snprintf(numbuf, sizeof numbuf, "%" PRId64, tv->int_val);
        s = strdup(numbuf);
        break;
    case GNMI__TYPED_VALUE__VALUE_DOUBLE_VAL:
        snprintf(numbuf, sizeof numbuf, "%g", tv->double_val);
        s = strdup(numbuf);
        break;
    /* float_val and decimal_val are deprecated in gNMI; use double_val instead */
    default:
        /* BYTES_VAL, LEAFLIST_VAL, ANY_VAL, PROTO_BYTES — not implemented */
        break;
    }
    if (s == NULL)
        return NULL;
    /* Strip surrounding double-quotes from JSON-encoded strings */
    len = strlen(s);
    if (len >= 2 && s[0] == '"' && s[len-1] == '"'){
        memmove(s, s+1, len-2);
        s[len-2] = '\0';
    }
    return s;
}

/*! Build XML edit-config body for a gNMI Path, optionally with a leaf value
 *
 * Generates the element tree corresponding to the path, placing list key
 * subelements inline.  If value is non-NULL it is placed inside the innermost
 * element (leaf case).  nc:operation="<op>" is added as an attribute on the
 * innermost element for all operations including merge, so all edits can be
 * batched into a single edit-config with default-operation=none.
 * The result is appended to cb without the outer <config> wrapper.
 *
 * @param[in]  h      Clixon handle (namespace lookup)
 * @param[in]  path   gNMI Path
 * @param[in]  value  Leaf value string, or NULL for delete/container
 * @param[in]  op     Operation (OP_MERGE, OP_REPLACE, OP_REMOVE)
 * @param[in]  cb     Output buffer to append to
 * @param[out] grpc_status  gRPC status code on error
 * @retval     0      OK
 * @retval    -1      Error
 */
static int
gnmi_path_to_xml(clixon_handle       h,
                 Gnmi__Path         *path,
                 const char         *value,
                 enum operation_type op,
                 cbuf               *cb,
                 int                *grpc_status)
{
    const char             *ns = NULL;
    const char             *opstr = NULL;
    const char             *prev_ns = NULL;
    yang_stmt              *yparent = NULL;
    size_t                  j;
    size_t                  nk;
    Gnmi__PathElem         *elem;
    Gnmi__PathElem__KeyEntry *ke;
    const char             *ens;
    const char             *local;

    if (path == NULL || path->n_elem == 0)
        return 0;
    opstr = xml_operation2str(op);

    /* Seed yparent from the top-level element for YANG traversal fallback */
    /* Open elements, emitting xmlns when namespace changes.
     * gNMI uses "module:localname" to qualify elements from a different module;
     * unqualified names use YANG tree traversal as fallback for augmented nodes.
     * yparent is seeded on the first element found via gnmi_find_namespace so
     * that subsequent unqualified augmented children can be resolved. */
    for (j = 0; j < path->n_elem; j++){
        elem = path->elem[j];
        ens = gnmi_resolve_elem_ns(h, elem->name, prev_ns, &yparent, &local);
        if (ens == NULL){
            ens = gnmi_find_namespace(h, elem->name);
            local = elem->name;
            /* Seed yparent so that subsequent elements can use YANG traversal */
            if (ens != NULL && yparent == NULL)
                yparent = gnmi_find_yparent(h, local);
        }
        if (ns == NULL)
            ns = ens;

        if (!gnmi_name_valid(local)){
            clixon_err(OE_XML, EINVAL, "Invalid gNMI element name in path");
            *grpc_status = GRPC_INVALID_ARGUMENT;
            return -1;
        }

        /* nc:operation goes on the innermost (last) element only, so that
         * intermediate containers are not themselves deleted/replaced. */
        int is_last = (j == path->n_elem - 1);

        if (j == 0){
            if (ens != NULL && opstr != NULL && is_last)
                cprintf(cb, "<%s xmlns=\"%s\" xmlns:nc=\"%s\" nc:operation=\"%s\">",
                        local, ens, NETCONF_BASE_NAMESPACE, opstr);
            else if (ens != NULL)
                cprintf(cb, "<%s xmlns=\"%s\">", local, ens);
            else if (opstr != NULL && is_last)
                cprintf(cb, "<%s xmlns:nc=\"%s\" nc:operation=\"%s\">",
                        local, NETCONF_BASE_NAMESPACE, opstr);
            else
                cprintf(cb, "<%s>", local);
            prev_ns = ens;
        } else {
            /* Emit xmlns only when namespace changes from parent */
            if (ens != NULL && (prev_ns == NULL || strcmp(ens, prev_ns) != 0)){
                if (opstr != NULL && is_last)
                    cprintf(cb, "<%s xmlns=\"%s\" xmlns:nc=\"%s\" nc:operation=\"%s\">",
                            local, ens, NETCONF_BASE_NAMESPACE, opstr);
                else
                    cprintf(cb, "<%s xmlns=\"%s\">", local, ens);
                prev_ns = ens;
            } else {
                if (opstr != NULL && is_last)
                    cprintf(cb, "<%s xmlns:nc=\"%s\" nc:operation=\"%s\">",
                            local, NETCONF_BASE_NAMESPACE, opstr);
                else
                    cprintf(cb, "<%s>", local);
            }
        }
        for (nk = 0; nk < elem->n_key; nk++){
            ke = elem->key[nk];
            if (!gnmi_name_valid(ke->key)){
                clixon_err(OE_XML, EINVAL, "Invalid gNMI key name in path");
                *grpc_status = GRPC_INVALID_ARGUMENT;
                return -1;
            }
            cprintf(cb, "<%s>", ke->key);
            if (xml_chardata_cbuf_append(cb, 0, ke->value) < 0)
                return -1;
            cprintf(cb, "</%s>", ke->key);
        }
    }
    /* Leaf value inside innermost element */
    if (value != NULL)
        if (xml_chardata_cbuf_append(cb, 0, value) < 0)
            return -1;
    /* Close all elements in reverse order */
    for (j = path->n_elem; j > 0; j--){
        gnmi_resolve_elem_ns(h, path->elem[j-1]->name, NULL, NULL, &local);
        cprintf(cb, "</%s>", local);
    }
    return 0;
}

/*! Send one edit-config RPC to the candidate datastore (no commit)
 *
 * Builds a full edit-config RPC (default-operation=none) around the given XML
 * body and sends it via clicon_rpc_netconf.  Each node in xmlbody must already
 * carry an nc:operation attribute.  On a NETCONF error the detailed reason is
 * set and the error-tag is mapped to a gRPC status code.
 *
 * @param[in]   h            Clixon handle
 * @param[in]   xmlbody      XML content to wrap in <config>...</config>
 * @param[out]  grpc_status  gRPC status code, set on NETCONF error
 * @retval      1            OK
 * @retval      0            NETCONF error (reason + grpc_status set)
 * @retval     -1            Fatal error
 */
static int
gnmi_edit_candidate(clixon_handle h,
                    cbuf         *xmlbody,
                    int          *grpc_status)
{
    int      retval = -1;
    cbuf    *cb = NULL;
    char    *username;
    char    *groupname;

    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    cprintf(cb, "<rpc xmlns=\"%s\"", NETCONF_BASE_NAMESPACE);
    cprintf(cb, " xmlns:%s=\"%s\"", NETCONF_BASE_PREFIX, NETCONF_BASE_NAMESPACE);
    if ((username = clicon_username_get(h)) != NULL)
        cprintf(cb, " %s:username=\"%s\"", CLIXON_LIB_PREFIX, username);
    if ((groupname = clixon_groupname_get(h)) != NULL)
        cprintf(cb, " %s:groupname=\"%s\"", CLIXON_LIB_PREFIX, groupname);
    if (username != NULL || groupname != NULL)
        cprintf(cb, " xmlns:%s=\"%s\"", CLIXON_LIB_PREFIX, CLIXON_LIB_NS);
    cprintf(cb, " %s", NETCONF_MESSAGE_ID_ATTR);
    cprintf(cb, "><edit-config><target><candidate/></target>");
    cprintf(cb, "<default-operation>none</default-operation>");
    cprintf(cb, "<config>%s</config>", cbuf_get(xmlbody));
    cprintf(cb, "</edit-config></rpc>");
    retval = gnmi_rpc_send(h, cbuf_get(cb), "edit-config", grpc_status);
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
}

/*! Handle gNMI Set RPC
 *
 * Processes delete, replace, and update operations from a SetRequest in order
 * per RFC gNMI section 3.4.3 (transactional semantics): each operation is
 * sent as a separate edit-config to the candidate datastore, then a single
 * commit is issued so that YANG validation (including mandatory leaves) runs
 * against the complete resulting candidate.  If the commit fails, discard-changes
 * is called to restore the candidate to the running state.
 *
 * Supported value encodings: JSON_IETF, JSON, STRING.
 *
 * @param[in]  h            Clixon handle
 * @param[in]  req_buf      Serialized SetRequest
 * @param[in]  req_len      Length of req_buf
 * @param[out] resp_buf     Caller-owned serialized SetResponse
 * @param[out] resp_len     Length of resp_buf
 * @param[out] grpc_status  gRPC status code on error
 * @retval     0            OK
 * @retval    -1            Error
 */
int
gnmi_set(clixon_handle  h,
         const uint8_t *req_buf,
         size_t         req_len,
         uint8_t      **resp_buf,
         size_t        *resp_len,
         int           *grpc_status)
{
    int                    retval = -1;
    Gnmi__SetRequest      *req = NULL;
    Gnmi__SetResponse      sresp = GNMI__SET_RESPONSE__INIT;
    Gnmi__UpdateResult   **results = NULL;
    Gnmi__UpdateResult    *ur;
    Gnmi__Path            *dpath;
    Gnmi__Update          *upd;
    char                  *val;
    size_t                 nresults;
    size_t                 ri;
    size_t                 i;
    cbuf                  *xmlcb = NULL;
    uint8_t               *buf = NULL;
    size_t                 sz;
    int                    any = 0;
    int                    ret;

    *grpc_status = GRPC_FAILED_PRECONDITION;

    req = gnmi__set_request__unpack(NULL, req_len, req_buf);
    if (req == NULL){
        clixon_err(OE_UNIX, 0, "gnmi__set_request__unpack");
        *grpc_status = GRPC_INVALID_ARGUMENT;
        goto done;
    }

    nresults = req->n_delete_ + req->n_replace + req->n_update;
    if (nresults > 0){
        if ((results = calloc(nresults, sizeof *results)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
        }
    }
    ri = 0;

    if ((xmlcb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }

    /* 1. Process deletes (OP_REMOVE — no error if path absent).
     * Each delete is sent as a separate edit-config so that the candidate
     * accumulates all changes before the final commit. */
    for (i = 0; i < req->n_delete_; i++){
        dpath = req->delete_[i];
        cbuf_reset(xmlcb);
        if (gnmi_path_to_xml(h, dpath, NULL, OP_REMOVE, xmlcb, grpc_status) < 0)
            goto discard;
        if ((ret = gnmi_edit_candidate(h, xmlcb, grpc_status)) < 0)
            goto discard;
        if (ret == 0) /* NETCONF error: reason + grpc_status set */
            goto discard;
        any = 1;
        if ((ur = calloc(1, sizeof *ur)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto discard;
        }
        gnmi__update_result__init(ur);
        ur->path = dpath;
        ur->op   = GNMI__UPDATE_RESULT__OPERATION__DELETE;
        results[ri++] = ur;
    }

    /* 2. Process replaces (OP_REPLACE) */
    for (i = 0; i < req->n_replace; i++){
        upd = req->replace[i];
        if (upd->val == NULL)
            continue;
        if ((val = gnmi_extract_value_string(upd->val)) == NULL)
            continue;
        cbuf_reset(xmlcb);
        if (gnmi_path_to_xml(h, upd->path, val, OP_REPLACE, xmlcb, grpc_status) < 0){
            free(val); goto discard;
        }
        free(val);
        if ((ret = gnmi_edit_candidate(h, xmlcb, grpc_status)) < 0)
            goto discard;
        if (ret == 0) /* NETCONF error: reason + grpc_status set */
            goto discard;
        any = 1;
        if ((ur = calloc(1, sizeof *ur)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto discard;
        }
        gnmi__update_result__init(ur);
        ur->path = upd->path;
        ur->op   = GNMI__UPDATE_RESULT__OPERATION__REPLACE;
        results[ri++] = ur;
    }

    /* 3. Process updates (OP_MERGE) */
    for (i = 0; i < req->n_update; i++){
        upd = req->update[i];
        if (upd->val == NULL)
            continue;
        if ((val = gnmi_extract_value_string(upd->val)) == NULL)
            continue;
        cbuf_reset(xmlcb);
        if (gnmi_path_to_xml(h, upd->path, val, OP_MERGE, xmlcb, grpc_status) < 0){
            free(val); goto discard;
        }
        free(val);
        if ((ret = gnmi_edit_candidate(h, xmlcb, grpc_status)) < 0)
            goto discard;
        if (ret == 0) /* NETCONF error: reason + grpc_status set */
            goto discard;
        any = 1;
        if ((ur = calloc(1, sizeof *ur)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto discard;
        }
        gnmi__update_result__init(ur);
        ur->path = upd->path;
        ur->op   = GNMI__UPDATE_RESULT__OPERATION__UPDATE;
        results[ri++] = ur;
    }

    /* Commit all edits as one transaction; discard on failure */
    if (any){
        cbuf_reset(xmlcb);
        cprintf(xmlcb, "<rpc xmlns=\"%s\" %s><commit/></rpc>",
                NETCONF_BASE_NAMESPACE, NETCONF_MESSAGE_ID_ATTR);
        if ((ret = gnmi_rpc_send(h, cbuf_get(xmlcb), "commit", grpc_status)) < 0)
            goto discard;
        if (ret == 0){
            /* NETCONF error returned — reason + grpc_status already set;
             * discard and surface the error */
            clicon_rpc_discard_changes(h);
            goto done;
        }
    }

    sresp.timestamp  = (int64_t)time(NULL) * (int64_t)1000000000;
    sresp.n_response = ri;
    sresp.response   = results;

    sz = gnmi__set_response__get_packed_size(&sresp);
    if ((buf = malloc(sz)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    gnmi__set_response__pack(&sresp, buf);

    *resp_buf = buf; buf = NULL;
    *resp_len = sz;
    retval = 0;
 done:
    if (results){
        for (i = 0; i < ri; i++)
            if (results[i])
                free(results[i]);
        free(results);
    }
    if (req)
        gnmi__set_request__free_unpacked(req, NULL);
    if (xmlcb)
        cbuf_free(xmlcb);
    if (buf)
        free(buf);
    return retval;
 discard:
    /* An edit-config or allocation failed after some edits were applied;
     * restore the candidate to its pre-request state before returning error. */
    clicon_rpc_discard_changes(h);
    goto done;
}

/*! Append one gRPC Length-Prefixed-Message frame to a cbuf
 *
 * Writes the 5-byte LPM prefix (compressed=0, big-endian length) followed
 * by the protobuf payload into cb.
 *
 * @param[in]  cb        Output buffer
 * @param[in]  proto_buf Serialized protobuf message
 * @param[in]  proto_len Length of proto_buf
 * @retval     0         OK
 * @retval    -1         Error
 */
static int
gnmi_lpm_append(cbuf          *cb,
                const uint8_t *proto_buf,
                size_t         proto_len)
{
    uint8_t  prefix[GRPC_PREFIX_LEN];
    uint32_t msglen_be;

    prefix[0] = 0; /* compressed flag */
    msglen_be = htonl((uint32_t)proto_len);
    memcpy(prefix + 1, &msglen_be, 4);
    if (cbuf_append_buf(cb, (char *)prefix, GRPC_PREFIX_LEN) < 0){
        clixon_err(OE_UNIX, errno, "cbuf_append_buf");
        return -1;
    }
    if (proto_len > 0){
        if (cbuf_append_buf(cb, (char *)proto_buf, proto_len) < 0){
            clixon_err(OE_UNIX, errno, "cbuf_append_buf");
            return -1;
        }
    }
    return 0;
}

/* Default sample interval when the client requests 0 (target-defined) */
#define GNMI_SAMPLE_INTERVAL_DEFAULT_NS (10ULL*1000000000ULL)

/* Minimum accepted sample interval (smaller values are clamped) */
#define GNMI_SAMPLE_INTERVAL_MIN_NS     (100ULL*1000000ULL)

/* Forward declaration */
typedef struct gnmi_sub gnmi_sub_t;

/*! Per-subscription-path state for a STREAM subscription */
typedef struct gnmi_sub_entry {
    gnmi_sub_t         *se_sub;         /* Backpointer to subscription */
    Gnmi__Subscription *se_s;           /* Points into se_sub->sb_req, not owned */
    uint64_t            se_interval_ns; /* Effective sample interval */
    char               *se_lastval;     /* Last sent JSON value, owned */
    struct timeval      se_lastsent;    /* Time of last sent update */
    int                 se_timer;       /* Sample timer registered */
} gnmi_sub_entry_t;

/*! State of one active gNMI STREAM subscription (one per Subscribe stream) */
struct gnmi_sub {
    clixon_handle           sb_h;
    void                   *sb_gc;        /* Transport connection, opaque */
    int32_t                 sb_stream_id; /* HTTP/2 stream */
    Gnmi__SubscribeRequest *sb_req;       /* Unpacked request, owned */
    int                     sb_poll;      /* POLL mode (no timers) */
    gnmi_sub_entry_t       *sb_entries;
    size_t                  sb_nentries;
};

/*! Append one LPM-framed SubscribeResponse(update) for a path to a cbuf
 *
 * Queries the datastore for the path, JSON-encodes the result into a
 * TypedValue(ASCII) update wrapped in a Notification/SubscribeResponse,
 * and appends the packed message as a gRPC LPM frame to framecb.
 *
 * @param[in]  h           Clixon handle
 * @param[in]  gpath       gNMI path to query
 * @param[in]  framecb     Output buffer for the LPM frame
 * @param[out] jsonp       If non-NULL, malloced copy of the JSON value
 * @param[out] grpc_status gRPC status code on error
 * @retval     0           OK
 * @retval    -1           Error
 */
static int
gnmi_sub_frame_update(clixon_handle h,
                      Gnmi__Path   *gpath,
                      cbuf         *framecb,
                      char        **jsonp,
                      int          *grpc_status)
{
    int                      retval = -1;
    Gnmi__SubscribeResponse  sresp = GNMI__SUBSCRIBE_RESPONSE__INIT;
    Gnmi__Notification       notif = GNMI__NOTIFICATION__INIT;
    Gnmi__Update             upd = GNMI__UPDATE__INIT;
    Gnmi__Update            *updp = &upd;
    Gnmi__TypedValue         tv = GNMI__TYPED_VALUE__INIT;
    cxobj                   *xret = NULL;
    cbuf                    *jsoncb = NULL;
    uint8_t                 *pbuf = NULL;
    size_t                   pbuflen;
    char                    *asciistr = NULL;

    if (gnmi_get_one_path(h, gpath, CONTENT_ALL, &xret, grpc_status) < 0)
        goto done;
    if ((jsoncb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    if (clixon_json2cbuf(jsoncb, xret, 0, 0, 0, 0) < 0)
        goto done;
    if ((asciistr = strdup(cbuf_get(jsoncb))) == NULL){
        clixon_err(OE_UNIX, errno, "strdup");
        goto done;
    }
    tv.value_case = GNMI__TYPED_VALUE__VALUE_ASCII_VAL;
    tv.ascii_val  = asciistr;

    upd.path = gpath;
    upd.val  = &tv;

    notif.timestamp = (int64_t)time(NULL) * (int64_t)1000000000;
    notif.update    = &updp;
    notif.n_update  = 1;

    sresp.response_case = GNMI__SUBSCRIBE_RESPONSE__RESPONSE_UPDATE;
    sresp.update        = &notif;

    pbuflen = gnmi__subscribe_response__get_packed_size(&sresp);
    if ((pbuf = malloc(pbuflen)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    gnmi__subscribe_response__pack(&sresp, pbuf);
    if (gnmi_lpm_append(framecb, pbuf, pbuflen) < 0)
        goto done;
    if (jsonp != NULL){
        *jsonp = asciistr;
        asciistr = NULL;
    }
    retval = 0;
 done:
    if (xret)
        xml_free(xret);
    if (jsoncb)
        cbuf_free(jsoncb);
    if (pbuf)
        free(pbuf);
    if (asciistr)
        free(asciistr);
    return retval;
}

/*! Append one LPM-framed SubscribeResponse(sync_response) to a cbuf
 *
 * @param[in]  framecb  Output buffer for the LPM frame
 * @retval     0        OK
 * @retval    -1        Error
 */
static int
gnmi_sub_frame_sync(cbuf *framecb)
{
    int                      retval = -1;
    Gnmi__SubscribeResponse  sresp = GNMI__SUBSCRIBE_RESPONSE__INIT;
    uint8_t                 *pbuf = NULL;
    size_t                   pbuflen;

    sresp.response_case = GNMI__SUBSCRIBE_RESPONSE__RESPONSE_SYNC_RESPONSE;
    sresp.sync_response = 1;
    pbuflen = gnmi__subscribe_response__get_packed_size(&sresp);
    if ((pbuf = malloc(pbuflen)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    gnmi__subscribe_response__pack(&sresp, pbuf);
    if (gnmi_lpm_append(framecb, pbuf, pbuflen) < 0)
        goto done;
    retval = 0;
 done:
    if (pbuf)
        free(pbuf);
    return retval;
}

/* Forward declaration: timer callback needed by gnmi_sub_close */
static int gnmi_sub_sample_cb(int fd, void *arg);

/*! Free a STREAM subscription: unregister timers and release all state
 *
 * Registered as transport stream close callback via grpc_stream_sub_set(),
 * invoked when the HTTP/2 stream or connection is closed.
 *
 * @param[in]  arg  gnmi_sub_t
 */
static void
gnmi_sub_close(void *arg)
{
    gnmi_sub_t *sb = (gnmi_sub_t *)arg;
    size_t      i;

    if (sb == NULL)
        return;
    for (i = 0; i < sb->sb_nentries; i++){
        if (sb->sb_entries[i].se_timer)
            clixon_event_unreg_timeout(gnmi_sub_sample_cb, &sb->sb_entries[i]);
        if (sb->sb_entries[i].se_lastval)
            free(sb->sb_entries[i].se_lastval);
    }
    if (sb->sb_entries)
        free(sb->sb_entries);
    if (sb->sb_req)
        gnmi__subscribe_request__free_unpacked(sb->sb_req, NULL);
    free(sb);
}

/*! (Re-)arm the sample timer for one subscription entry
 *
 * @param[in]  se  Subscription entry
 * @retval     0   OK
 * @retval    -1   Error
 */
static int
gnmi_sub_entry_arm(gnmi_sub_entry_t *se)
{
    struct timeval t;
    struct timeval add;

    gettimeofday(&t, NULL);
    add.tv_sec  = se->se_interval_ns / 1000000000ULL;
    add.tv_usec = (se->se_interval_ns % 1000000000ULL) / 1000;
    timeradd(&t, &add, &t);
    if (clixon_event_reg_timeout(t, gnmi_sub_sample_cb, se, "gnmi sample") < 0)
        return -1;
    se->se_timer = 1;
    return 0;
}

/*! Timer callback: sample one subscribed path and send an update
 *
 * Honors suppress_redundant (skip unchanged values) and heartbeat_interval
 * (force an update even if unchanged after the heartbeat elapses).
 * On error the response stream is finished with an error status and the
 * timer is not re-armed; state is freed when the stream closes.
 *
 * @param[in]  fd   Not used (timer)
 * @param[in]  arg  gnmi_sub_entry_t
 * @retval     0    OK (always: an error must not stop the event loop)
 */
static int
gnmi_sub_sample_cb(int   fd,
                   void *arg)
{
    gnmi_sub_entry_t *se = (gnmi_sub_entry_t *)arg;
    gnmi_sub_t       *sb = se->se_sub;
    cbuf             *framecb = NULL;
    char             *jsonstr = NULL;
    int               send = 1;
    int               gst = GRPC_INTERNAL;
    struct timeval    now;
    struct timeval    diff;
    uint64_t          elapsed_ns;

    se->se_timer = 0;
    if ((framecb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto fail;
    }
    if (gnmi_sub_frame_update(sb->sb_h, se->se_s->path, framecb,
                              &jsonstr, &gst) < 0)
        goto fail;
    if (se->se_s->suppress_redundant &&
        se->se_lastval != NULL &&
        strcmp(se->se_lastval, jsonstr) == 0){
        send = 0;
        if (se->se_s->heartbeat_interval > 0){
            gettimeofday(&now, NULL);
            timersub(&now, &se->se_lastsent, &diff);
            elapsed_ns = (uint64_t)diff.tv_sec * 1000000000ULL +
                (uint64_t)diff.tv_usec * 1000ULL;
            if (elapsed_ns >= se->se_s->heartbeat_interval)
                send = 1;
        }
    }
    if (send){
        if (grpc_stream_write(sb->sb_gc, sb->sb_stream_id,
                              (uint8_t *)cbuf_get(framecb),
                              cbuf_len(framecb)) < 0)
            goto fail;
        if (se->se_lastval)
            free(se->se_lastval);
        se->se_lastval = jsonstr;
        jsonstr = NULL;
        gettimeofday(&se->se_lastsent, NULL);
    }
    if (gnmi_sub_entry_arm(se) < 0)
        goto fail;
 out:
    if (framecb)
        cbuf_free(framecb);
    if (jsonstr)
        free(jsonstr);
    return 0;
 fail:
    clixon_log(sb->sb_h, LOG_WARNING, "gNMI sample failed, terminating subscription: %s",
               clixon_err_reason());
    grpc_stream_finish(sb->sb_gc, sb->sb_stream_id, gst, clixon_err_reason());
    goto out;
}

/*! Handle gNMI Subscribe RPC — ONCE and STREAM(SAMPLE) modes
 *
 * ONCE: queries each subscribed path once, sends a stream of
 * SubscribeResponse(update) messages followed by a final sync_response and
 * gRPC trailers.
 *
 * STREAM: sends initial updates (unless updates_only) and sync_response,
 * then keeps the HTTP/2 stream open and samples each path periodically
 * (SAMPLE and TARGET_DEFINED subscription modes; ON_CHANGE is not yet
 * implemented).  Subscription state is attached to the transport stream and
 * freed when the stream or connection closes.
 *
 * POLL: sends initial updates and sync_response, then keeps the stream open;
 * subsequent Poll requests are handled by gnmi_subscribe_poll().
 *
 * On success (retval 0) all responses have been sent, or scheduled, via the
 * transport stream API; on error (retval -1) nothing has been submitted on
 * the HTTP/2 stream and the caller should send an error response using
 * grpc_status.
 *
 * @param[in]  h            Clixon handle
 * @param[in]  gc_opaque    Transport connection (opaque)
 * @param[in]  stream_id    HTTP/2 stream id
 * @param[in]  req_buf      Serialized SubscribeRequest
 * @param[in]  req_len      Length of req_buf
 * @param[out] grpc_status  gRPC status code on error
 * @retval     0            OK
 * @retval    -1            Error (before the response stream was opened)
 */
int
gnmi_subscribe(clixon_handle  h,
               void          *gc_opaque,
               int32_t        stream_id,
               const uint8_t *req_buf,
               size_t         req_len,
               int           *grpc_status)
{
    int                     retval = -1;
    Gnmi__SubscribeRequest *req = NULL;
    Gnmi__SubscriptionList *sublist;
    Gnmi__Subscription     *sub;
    gnmi_sub_t             *sb = NULL;
    gnmi_sub_entry_t       *se;
    cbuf                   *framecb = NULL;
    size_t                  i;
    int                     stream_mode = 0;
    int                     poll_mode = 0;

    *grpc_status = GRPC_INTERNAL;

    req = gnmi__subscribe_request__unpack(NULL, req_len, req_buf);
    if (req == NULL){
        clixon_err(OE_UNIX, 0, "gnmi__subscribe_request__unpack");
        *grpc_status = GRPC_INVALID_ARGUMENT;
        goto done;
    }
    if (req->request_case != GNMI__SUBSCRIBE_REQUEST__REQUEST_SUBSCRIBE){
        clixon_err(OE_UNIX, 0, "SubscribeRequest is not a SUBSCRIBE (case=%d)",
                   req->request_case);
        *grpc_status = GRPC_INVALID_ARGUMENT;
        goto done;
    }
    sublist = req->subscribe;
    if (sublist == NULL){
        clixon_err(OE_UNIX, 0, "SubscribeRequest has no SubscriptionList");
        *grpc_status = GRPC_INVALID_ARGUMENT;
        goto done;
    }
    switch (sublist->mode){
    case GNMI__SUBSCRIPTION_LIST__MODE__ONCE:
        break;
    case GNMI__SUBSCRIPTION_LIST__MODE__STREAM:
        stream_mode = 1;
        break;
    case GNMI__SUBSCRIPTION_LIST__MODE__POLL:
        stream_mode = 1;
        poll_mode = 1;
        break;
    default:
        clixon_err(OE_UNIX, 0, "Subscribe mode %d not implemented",
                   sublist->mode);
        *grpc_status = GRPC_UNIMPLEMENTED;
        goto done;
    }
    if ((framecb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    if (stream_mode){
        /* Allocate subscription state; validate per-subscription modes */
        if ((sb = calloc(1, sizeof *sb)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
        }
        sb->sb_h = h;
        sb->sb_gc = gc_opaque;
        sb->sb_stream_id = stream_id;
        sb->sb_req = req;
        sb->sb_poll = poll_mode;
        req = NULL; /* sb now owns the unpacked request */
        sublist = sb->sb_req->subscribe;
        if (sublist->n_subscription > 0 &&
            (sb->sb_entries = calloc(sublist->n_subscription,
                                     sizeof *sb->sb_entries)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
        }
        for (i = 0; i < sublist->n_subscription; i++){
            sub = sublist->subscription[i];
            se = &sb->sb_entries[i];
            se->se_sub = sb;
            se->se_s = sub;
            if (!poll_mode){
                if (sub->mode == GNMI__SUBSCRIPTION_MODE__ON_CHANGE){
                    clixon_err(OE_UNIX, 0, "Subscription mode ON_CHANGE not implemented");
                    *grpc_status = GRPC_UNIMPLEMENTED;
                    goto done;
                }
                /* SAMPLE and TARGET_DEFINED: periodic sampling */
                se->se_interval_ns = sub->sample_interval;
                if (se->se_interval_ns == 0)
                    se->se_interval_ns = GNMI_SAMPLE_INTERVAL_DEFAULT_NS;
                else if (se->se_interval_ns < GNMI_SAMPLE_INTERVAL_MIN_NS)
                    se->se_interval_ns = GNMI_SAMPLE_INTERVAL_MIN_NS;
            }
            sb->sb_nentries++;
        }
    }
    /* Build initial updates + sync_response; updates_only sends sync only */
    if (!sublist->updates_only){
        for (i = 0; i < sublist->n_subscription; i++){
            se = stream_mode ? &sb->sb_entries[i] : NULL;
            if (gnmi_sub_frame_update(h, sublist->subscription[i]->path,
                                      framecb,
                                      se != NULL ? &se->se_lastval : NULL,
                                      grpc_status) < 0)
                goto done;
            if (se != NULL)
                gettimeofday(&se->se_lastsent, NULL);
        }
    }
    if (gnmi_sub_frame_sync(framecb) < 0)
        goto done;

    /* Open response stream and send initial frames.  From this point errors
     * are reported on the stream itself (retval 0) since headers are out. */
    if (grpc_stream_open(gc_opaque, stream_id) < 0)
        goto done;
    if (grpc_stream_write(gc_opaque, stream_id,
                          (uint8_t *)cbuf_get(framecb),
                          cbuf_len(framecb)) < 0){
        grpc_stream_finish(gc_opaque, stream_id, GRPC_INTERNAL, "write failed");
        retval = 0;
        goto done;
    }
    if (!stream_mode){
        /* ONCE: all data sent, terminate with OK trailers */
        if (grpc_stream_finish(gc_opaque, stream_id, GRPC_OK, NULL) < 0){
            retval = 0;
            goto done;
        }
    }
    else {
        /* STREAM/POLL: attach subscription to transport stream; STREAM also
         * starts sample timers, POLL waits for Poll requests */
        if (grpc_stream_sub_set(gc_opaque, stream_id, sb, gnmi_sub_close) < 0){
            grpc_stream_finish(gc_opaque, stream_id, GRPC_INTERNAL, "internal error");
            retval = 0;
            goto done;
        }
        if (!poll_mode){
            for (i = 0; i < sb->sb_nentries; i++){
                if (gnmi_sub_entry_arm(&sb->sb_entries[i]) < 0){
                    grpc_stream_finish(gc_opaque, stream_id, GRPC_INTERNAL,
                                       "timer registration failed");
                    break;
                }
            }
        }
        sb = NULL; /* owned by transport stream; freed via gnmi_sub_close */
    }
    retval = 0;
 done:
    if (sb)
        gnmi_sub_close(sb);
    if (req)
        gnmi__subscribe_request__free_unpacked(req, NULL);
    if (framecb)
        cbuf_free(framecb);
    return retval;
}

/*! Handle a subsequent SubscribeRequest on an already-active Subscribe stream
 *
 * Per gNMI spec 3.5.1.5.3 only Poll messages are valid after the initial
 * SubscribeRequest, and only for POLL-mode subscriptions.  On a valid Poll
 * the current value of every subscribed path is sent, followed by a
 * sync_response.  Protocol violations terminate the response stream with an
 * error status; retval is 0 since errors are reported on the stream itself.
 *
 * @param[in]  h            Clixon handle
 * @param[in]  gc_opaque    Transport connection (opaque)
 * @param[in]  stream_id    HTTP/2 stream id
 * @param[in]  req_buf      Serialized SubscribeRequest
 * @param[in]  req_len      Length of req_buf
 * @retval     0            OK (including errors reported on the stream)
 * @retval    -1            Fatal error
 */
int
gnmi_subscribe_poll(clixon_handle  h,
                    void          *gc_opaque,
                    int32_t        stream_id,
                    const uint8_t *req_buf,
                    size_t         req_len)
{
    int                     retval = -1;
    Gnmi__SubscribeRequest *req = NULL;
    gnmi_sub_t             *sb;
    cbuf                   *framecb = NULL;
    size_t                  i;
    int                     gst = GRPC_INTERNAL;

    sb = (gnmi_sub_t *)grpc_stream_sub_get(gc_opaque, stream_id);
    if (sb == NULL){
        grpc_stream_finish(gc_opaque, stream_id, GRPC_INVALID_ARGUMENT,
                           "no active subscription on stream");
        retval = 0;
        goto done;
    }
    req = gnmi__subscribe_request__unpack(NULL, req_len, req_buf);
    if (req == NULL){
        grpc_stream_finish(gc_opaque, stream_id, GRPC_INVALID_ARGUMENT,
                           "malformed SubscribeRequest");
        retval = 0;
        goto done;
    }
    if (req->request_case != GNMI__SUBSCRIBE_REQUEST__REQUEST_POLL){
        grpc_stream_finish(gc_opaque, stream_id, GRPC_INVALID_ARGUMENT,
                           "only Poll allowed after initial SubscribeRequest");
        retval = 0;
        goto done;
    }
    if (!sb->sb_poll){
        grpc_stream_finish(gc_opaque, stream_id, GRPC_INVALID_ARGUMENT,
                           "Poll on non-POLL subscription");
        retval = 0;
        goto done;
    }
    if ((framecb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    for (i = 0; i < sb->sb_nentries; i++){
        if (gnmi_sub_frame_update(sb->sb_h, sb->sb_entries[i].se_s->path,
                                  framecb, NULL, &gst) < 0){
            grpc_stream_finish(gc_opaque, stream_id, gst, clixon_err_reason());
            retval = 0;
            goto done;
        }
    }
    if (gnmi_sub_frame_sync(framecb) < 0)
        goto done;
    if (grpc_stream_write(gc_opaque, stream_id,
                          (uint8_t *)cbuf_get(framecb),
                          cbuf_len(framecb)) < 0){
        grpc_stream_finish(gc_opaque, stream_id, GRPC_INTERNAL, "write failed");
        retval = 0;
        goto done;
    }
    retval = 0;
 done:
    if (req)
        gnmi__subscribe_request__free_unpacked(req, NULL);
    if (framecb)
        cbuf_free(framecb);
    return retval;
}
