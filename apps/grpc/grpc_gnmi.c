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

#include <protobuf-c/protobuf-c.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

/* generated protobuf */
#include "gnmi.pb-c.h"

#include "grpc_nghttp2.h"
#include "grpc_gnmi.h"

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
 * @param[in]  h        Clixon handle
 * @param[in]  gpath    gNMI Path to query (may be NULL)
 * @param[in]  content  CONTENT_ALL, CONTENT_CONFIG, or CONTENT_NONCONFIG
 * @param[out] xretp    XML result tree; caller must xml_free()
 * @retval     0        OK
 * @retval    -1        Error
 */
static int
gnmi_get_one_path(clixon_handle h,
                  Gnmi__Path   *gpath,
                  int           content,
                  cxobj       **xretp)
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
            cprintf(xpathcb, "/%s:%s", pfx, local);
            for (nk = 0; nk < elem->n_key; nk++){
                ke = elem->key[nk];
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
        if (gnmi_get_one_path(h, req->path[i], content, &xret) < 0)
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
 * element (leaf case).  If op is not OP_MERGE, nc:operation="<op>" is added as
 * an attribute on the outermost element so delete/replace apply per-node.
 * The result is appended to cb without the outer <config> wrapper.
 *
 * @param[in]  h      Clixon handle (namespace lookup)
 * @param[in]  path   gNMI Path
 * @param[in]  value  Leaf value string, or NULL for delete/container
 * @param[in]  op     Operation (OP_MERGE, OP_REPLACE, OP_REMOVE)
 * @param[in]  cb     Output buffer to append to
 * @retval     0      OK
 * @retval    -1      Error
 */
static int
gnmi_path_to_xml(clixon_handle       h,
                 Gnmi__Path         *path,
                 const char         *value,
                 enum operation_type op,
                 cbuf               *cb)
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
    if (op != OP_MERGE)
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

        if (j == 0){
            if (ens != NULL && opstr != NULL)
                cprintf(cb, "<%s xmlns=\"%s\" xmlns:nc=\"%s\" nc:operation=\"%s\">",
                        local, ens, NETCONF_BASE_NAMESPACE, opstr);
            else if (ens != NULL)
                cprintf(cb, "<%s xmlns=\"%s\">", local, ens);
            else if (opstr != NULL)
                cprintf(cb, "<%s xmlns:nc=\"%s\" nc:operation=\"%s\">",
                        local, NETCONF_BASE_NAMESPACE, opstr);
            else
                cprintf(cb, "<%s>", local);
            prev_ns = ens;
        } else {
            /* Emit xmlns only when namespace changes from parent */
            if (ens != NULL && (prev_ns == NULL || strcmp(ens, prev_ns) != 0)){
                cprintf(cb, "<%s xmlns=\"%s\">", local, ens);
                prev_ns = ens;
            } else {
                cprintf(cb, "<%s>", local);
            }
        }
        for (nk = 0; nk < elem->n_key; nk++){
            ke = elem->key[nk];
            cprintf(cb, "<%s>%s</%s>", ke->key, ke->value, ke->key);
        }
    }
    /* Leaf value inside innermost element */
    if (value != NULL)
        cprintf(cb, "%s", value);
    /* Close all elements in reverse order */
    for (j = path->n_elem; j > 0; j--){
        gnmi_resolve_elem_ns(h, path->elem[j-1]->name, NULL, NULL, &local);
        cprintf(cb, "</%s>", local);
    }
    return 0;
}

/*! Handle gNMI Set RPC
 *
 * Processes delete, replace, and update operations from a SetRequest in order,
 * applies all edits to the candidate datastore, then commits.
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

    /* 1. Process deletes (OP_REMOVE — no error if path absent) */
    for (i = 0; i < req->n_delete_; i++){
        dpath = req->delete_[i];

        if ((xmlcb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            goto done;
        }
        cprintf(xmlcb, "<config>");
        if (gnmi_path_to_xml(h, dpath, NULL, OP_REMOVE, xmlcb) < 0)
            goto done;
        cprintf(xmlcb, "</config>");
        if (clicon_rpc_edit_config(h, "candidate", OP_NONE,
                                   cbuf_get(xmlcb)) < 0)
            goto done;
        cbuf_free(xmlcb); xmlcb = NULL;
        any = 1;

        if ((ur = calloc(1, sizeof *ur)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
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
        if ((xmlcb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            free(val);
            goto done;
        }
        cprintf(xmlcb, "<config>");
        if (gnmi_path_to_xml(h, upd->path, val, OP_REPLACE, xmlcb) < 0){
            free(val); goto done;
        }
        cprintf(xmlcb, "</config>");
        free(val);
        if (clicon_rpc_edit_config(h, "candidate", OP_NONE,
                                   cbuf_get(xmlcb)) < 0)
            goto done;
        cbuf_free(xmlcb); xmlcb = NULL;
        any = 1;

        if ((ur = calloc(1, sizeof *ur)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
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
        if ((xmlcb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            free(val);
            goto done;
        }
        cprintf(xmlcb, "<config>");
        if (gnmi_path_to_xml(h, upd->path, val, OP_MERGE, xmlcb) < 0){
            free(val); goto done;
        }
        cprintf(xmlcb, "</config>");
        free(val);
        if (clicon_rpc_edit_config(h, "candidate", OP_MERGE,
                                   cbuf_get(xmlcb)) < 0)
            goto done;
        cbuf_free(xmlcb); xmlcb = NULL;
        any = 1;

        if ((ur = calloc(1, sizeof *ur)) == NULL){
            clixon_err(OE_UNIX, errno, "calloc");
            goto done;
        }
        gnmi__update_result__init(ur);
        ur->path = upd->path;
        ur->op   = GNMI__UPDATE_RESULT__OPERATION__UPDATE;
        results[ri++] = ur;
    }

    /* Commit all changes at once */
    if (any){
        if (clicon_rpc_commit(h, 0, 0, 0, NULL, NULL) < 0)
            goto done;
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

/*! Handle gNMI Subscribe RPC — ONCE mode only
 *
 * For ONCE mode: queries each subscribed path once, returns a stream of
 * SubscribeResponse(update) messages followed by a final sync_response.
 * STREAM and POLL modes are not yet implemented.
 *
 * @param[in]  h            Clixon handle
 * @param[in]  req_buf      Serialized SubscribeRequest
 * @param[in]  req_len      Length of req_buf
 * @param[out] resp_buf     Caller-owned pre-framed LPM buffer (multiple responses)
 * @param[out] resp_len     Length of resp_buf
 * @param[out] grpc_status  gRPC status code on error
 * @retval     0            OK
 * @retval    -1            Error
 */
int
gnmi_subscribe(clixon_handle  h,
               const uint8_t *req_buf,
               size_t         req_len,
               uint8_t      **resp_buf,
               size_t        *resp_len,
               int           *grpc_status)
{
    int                          retval = -1;
    Gnmi__SubscribeRequest      *req = NULL;
    Gnmi__SubscriptionList      *sublist;
    Gnmi__SubscribeResponse      sresp = GNMI__SUBSCRIBE_RESPONSE__INIT;
    Gnmi__Notification           notif = GNMI__NOTIFICATION__INIT;
    Gnmi__Update                 upd = GNMI__UPDATE__INIT;
    Gnmi__Update                *updp = NULL;
    Gnmi__TypedValue             tv = GNMI__TYPED_VALUE__INIT;
    Gnmi__SubscribeResponse      sync_sresp = GNMI__SUBSCRIBE_RESPONSE__INIT;
    cbuf                        *framecb = NULL;
    cbuf                        *jsoncb = NULL;
    uint8_t                     *pbuf = NULL;
    size_t                       pbuflen;
    size_t                       i;
    cxobj                       *xret = NULL;
    char                        *jsonstr;
    char                        *asciistr = NULL;

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

    if (sublist->mode != GNMI__SUBSCRIPTION_LIST__MODE__ONCE){
        clixon_err(OE_UNIX, 0, "Subscribe mode %d not implemented (only ONCE supported)",
                   sublist->mode);
        *grpc_status = GRPC_UNIMPLEMENTED;
        goto done;
    }

    if ((framecb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }

    for (i = 0; i < sublist->n_subscription; i++){
        if (xret){
            xml_free(xret);
            xret = NULL;
        }
        if (gnmi_get_one_path(h, sublist->subscription[i]->path,
                              CONTENT_ALL, &xret) < 0)
            goto done;

        if ((jsoncb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            goto done;
        }
        if (clixon_json2cbuf(jsoncb, xret, 0, 0, 0, 0) < 0)
            goto done;
        jsonstr = cbuf_get(jsoncb);

        /* Build TypedValue with ASCII encoding */
        if ((asciistr = strdup(jsonstr)) == NULL){
            clixon_err(OE_UNIX, errno, "strdup");
            goto done;
        }
        tv.value_case  = GNMI__TYPED_VALUE__VALUE_ASCII_VAL;
        tv.ascii_val   = asciistr;

        /* Build Update */
        gnmi__update__init(&upd);
        upd.path  = sublist->subscription[i]->path;
        upd.val   = &tv;
        updp = &upd;

        /* Build Notification */
        gnmi__notification__init(&notif);
        notif.timestamp = (int64_t)time(NULL) * (int64_t)1000000000;
        notif.update    = &updp;
        notif.n_update  = 1;

        /* Build SubscribeResponse with update */
        gnmi__subscribe_response__init(&sresp);
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
        free(pbuf); pbuf = NULL;

        free(asciistr); asciistr = NULL;
        cbuf_free(jsoncb); jsoncb = NULL;
    }

    /* Final sync_response message */
    gnmi__subscribe_response__init(&sync_sresp);
    sync_sresp.response_case = GNMI__SUBSCRIBE_RESPONSE__RESPONSE_SYNC_RESPONSE;
    sync_sresp.sync_response = 1;

    pbuflen = gnmi__subscribe_response__get_packed_size(&sync_sresp);
    if ((pbuf = malloc(pbuflen)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    gnmi__subscribe_response__pack(&sync_sresp, pbuf);
    if (gnmi_lpm_append(framecb, pbuf, pbuflen) < 0)
        goto done;
    free(pbuf); pbuf = NULL;

    *resp_len = cbuf_len(framecb);
    if ((*resp_buf = malloc(*resp_len)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memcpy(*resp_buf, cbuf_get(framecb), *resp_len);
    retval = 0;
 done:
    if (req)
        gnmi__subscribe_request__free_unpacked(req, NULL);
    if (xret)
        xml_free(xret);
    if (jsoncb)
        cbuf_free(jsoncb);
    if (framecb)
        cbuf_free(framecb);
    if (pbuf)
        free(pbuf);
    if (asciistr)
        free(asciistr);
    return retval;
}
