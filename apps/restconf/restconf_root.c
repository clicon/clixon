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
  * Generic restconf root handlers eg for /restconf /.well-known, etc
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
#include <time.h>
#include <limits.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <libgen.h>
#include <sys/stat.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>

/* restconf */
#include "restconf_lib.h"
#include "restconf_handle.h"
#include "restconf_api.h"
#include "restconf_err.h"
#include "restconf_root.h"
#include "restconf_methods.h"
#include "restconf_methods_get.h"
#include "restconf_methods_post.h"

/*! Check if uri path denotes a restconf path
 *
 * @retval     0    No, not a restconf path
 * @retval     1    Yes, a restconf path
 */
int
api_path_is_restconf(clixon_handle h)
{
    int    retval = 0;
    char  *path = NULL;
    char  *restconf_api_path;

    if ((path = restconf_uripath(h)) == NULL)
        goto done;
    if ((restconf_api_path = clicon_option_str(h, "CLICON_RESTCONF_API_ROOT")) == NULL)
        goto done;
    if (strlen(path) < strlen(restconf_api_path)) /* "/" + restconf */
        goto done;
    if (strncmp(path, restconf_api_path, strlen(restconf_api_path)) != 0)
        goto done;
    retval = 1;
 done:
    if (path)
        free(path);
    return retval;
}

/*! Determine the root of the RESTCONF API by accessing /.well-known
 *
 * @param[in]  h    Clixon handle
 * @param[in]  req  Generic Www handle (can be part of clixon handle)
 * @retval     0    OK
 * @retval    -1    Error
 * @see RFC8040 3.1 and RFC7320
 * In line with the best practices defined by [RFC7320], RESTCONF
 * enables deployments to specify where the RESTCONF API is located.
 */
int
api_well_known(clixon_handle h,
               void         *req)
{
    int       retval = -1;
    char     *request_method;
    cbuf     *cb = NULL;
    int       head;

    clixon_debug(CLIXON_DBG_RESTCONF, "");
    if (req == NULL){
        errno = EINVAL;
        goto done;
    }
    request_method = restconf_param_get(h, "REQUEST_METHOD");
    head = strcmp(request_method, "HEAD") == 0;
    if (!head && strcmp(request_method, "GET") != 0){
        if (restconf_method_notallowed(h, req, "GET,HEAD", restconf_pretty_get(h), YANG_DATA_JSON) < 0)
            goto done;
        goto ok;
    }
    if (restconf_reply_header(req, "Content-Type", "application/xrd+xml") < 0)
        goto done;
    if (restconf_reply_header(req, "Cache-Control", "no-cache") < 0)
        goto done;
    /* Create body */
    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    cprintf(cb, "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>\n");
    cprintf(cb, "   <Link rel='restconf' href='/restconf'/>\n");
    cprintf(cb, "</XRD>\r\n");

    if (restconf_reply_send(req, 200, cb, head) < 0)
        goto done;
    cb = NULL;
 ok:
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
}

/*! Retrieve the Top-Level API Resource /restconf/ (exact)
 *
 * @param[in]  h         Clixon handle
 * @param[in]  req       Generic request handle
 * @param[in]  method    Http method
 * @param[in]  pretty    Pretty print
 * @param[in]  media_out Restconf output media
 * @retval     0         OK
 * @retval    -1         Error
 * @note Only returns null for operations and data,...
 * See RFC8040 3.3
 * @see api_root_restconf for accessing /restconf/ *
 */
static int
api_root_restconf_exact(clixon_handle  h,
                        void          *req,
                        char          *request_method,
                        int            pretty,
                        restconf_media media_out)
{
    int        retval = -1;
    yang_stmt *yspec;
    cxobj     *xt = NULL;
    cbuf      *cb = NULL;
    int        head;

    clixon_debug(CLIXON_DBG_RESTCONF, "");
    head = strcmp(request_method, "HEAD") == 0;
    if (!head && strcmp(request_method, "GET") != 0){
        if (restconf_method_notallowed(h, req, "GET", pretty, media_out) < 0)
            goto done;
        goto ok;
    }
    if ((yspec = clicon_dbspec_yang(h)) == NULL){
        clixon_err(OE_FATAL, 0, "No DB_SPEC");
        goto done;
    }
    if (restconf_reply_header(req, "Content-Type", "%s", restconf_media_int2str(media_out)) < 0)
        goto done;
    if (restconf_reply_header(req, "Cache-Control", "no-cache") < 0)
        goto done;
    if (clixon_xml_parse_string("<restconf xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf\"><data/>"
                                "<operations/><yang-library-version>" IETF_YANG_LIBRARY_REVISION
                                "</yang-library-version></restconf>",
                                YB_MODULE, yspec, &xt, NULL) < 0)
        goto done;

    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_XML, errno, "cbuf_new");
        goto done;
    }
    if (xml_rootchild(xt, 0, &xt) < 0)
        goto done;
    switch (media_out){
    case YANG_DATA_XML:
    case YANG_PATCH_XML:
        if (clixon_xml2cbuf1(cb, xt, 0, pretty, NULL, -1, 0, 0) < 0)
            goto done;
        break;
    case YANG_DATA_JSON:
    case YANG_PATCH_JSON:
        if (clixon_json2cbuf(cb, xt, pretty, 0, 0, 0) < 0)
            goto done;
        break;
    default:
        break;
    }
    if (restconf_reply_send(req, 200, cb, head) < 0)
        goto done;
    cb = NULL;
 ok:
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    if (xt)
        xml_free(xt);
    return retval;
}

/** A stub implementation of the operational state datastore. The full
 * implementation is required by https://tools.ietf.org/html/rfc8527#section-3.1
 * @param[in]  h         Clixon handle
 * @param[in]  req       Generic http handle
 * @param[in]  pretty    Pretty-print
 * @param[in]  media_out Restconf output media
 */
static int
api_operational_state(clixon_handle  h,
                        void          *req,
                        char          *request_method,
                        int            pretty,
                        restconf_media media_out)

{
    clixon_debug(CLIXON_DBG_RESTCONF, "request method:%s", request_method);

    /* We are not implementing this method at this time, 20201105 despite it
     * being mandatory https://tools.ietf.org/html/rfc8527#section-3.1 */
    return restconf_notimplemented(h, req, pretty, media_out);
}

/*! get yang lib version
 *
 * See https://tools.ietf.org/html/rfc7895
 * @param[in]  pretty    Pretty-print
 * @param[in]  media_out Restconf output media
 * @retval     0         OK
 * @retval    -1         Error
 */
static int
api_yang_library_version(clixon_handle h,
                         void         *req,
                         int           pretty,
                         restconf_media media_out)
{
    int        retval = -1;
    cxobj     *xt = NULL;
    cbuf      *cb = NULL;
    yang_stmt *yspec;

    clixon_debug(CLIXON_DBG_RESTCONF, "");
    if (restconf_reply_header(req, "Content-Type", "%s", restconf_media_int2str(media_out)) < 0)
        goto done;
    if (restconf_reply_header(req, "Cache-Control", "no-cache") < 0)
        goto done;
    if (clixon_xml_parse_va(YB_NONE, NULL, &xt, NULL,
                            "<yang-library-version>%s</yang-library-version>",
                            IETF_YANG_LIBRARY_REVISION) < 0)
        goto done;
    if (xml_rootchild(xt, 0, &xt) < 0)
        goto done;
    yspec = clicon_dbspec_yang(h);
    if (xml_bind_special(xt, yspec, "/rc:restconf/yang-library-version") < 0)
        goto done;
    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    switch (media_out){
    case YANG_DATA_XML:
    case YANG_PATCH_XML:
        if (clixon_xml2cbuf1(cb, xt, 0, pretty, NULL, -1, 0, 0) < 0)
            goto done;
        break;
    case YANG_DATA_JSON:
    case YANG_PATCH_JSON:
        if (clixon_json2cbuf(cb, xt, pretty, 0, 0, 0) < 0)
            goto done;
        break;
    default:
        break;
    }
    if (restconf_reply_send(req, 200, cb, 0) < 0)
        goto done;
    cb = NULL;
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    if (xt)
        xml_free(xt);
    return retval;
}

/*! Generic REST method, GET, PUT, DELETE, etc
 *
 * @param[in]  h         CLIXON handle
 * @param[in]  r         Fastcgi request handle
 * @param[in]  api_path  According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec     Vector of path ie DOCUMENT_URI element
 * @param[in]  pi        Offset, where to start pcvec
 * @param[in]  qvec      Vector of query string (QUERY_STRING)
 * @param[in]  pretty    Set to 1 for pretty-printed xml/json output
 * @param[in]  media_out Restconf output media
 * @param[in]  ds        0 if "data" resource, 1 if rfc8527 "ds" resource
 * @retval     0         OK
 * @retval    -1         Error
 */
static int
api_data(clixon_handle h,
         void         *req,
         char         *api_path,
         cvec         *pcvec,
         int           pi,
         cvec         *qvec,
         char         *data,
         int           pretty,
         restconf_media media_out,
         ietf_ds_t     ds)
{
    int     retval = -1;
    int     read_only = 0, dynamic = 0;
    char   *request_method;
    cxobj  *xerr = NULL;

    request_method = restconf_param_get(h, "REQUEST_METHOD");
    clixon_debug(CLIXON_DBG_RESTCONF, "method:%s", request_method);

    /* https://tools.ietf.org/html/rfc8527#section-3.2 */
    /* We assume that dynamic datastores are read only at this time 20201105 */
    if (IETF_DS_DYNAMIC == ds)
        dynamic = 1;
    if ((IETF_DS_INTENDED == ds) || (IETF_DS_RUNNING == ds)
        || (IETF_DS_DYNAMIC == ds) || (IETF_DS_OPERATIONAL == ds)) {
        read_only = 1;
    }

    if (strcmp(request_method, "OPTIONS")==0)
        retval = api_data_options(h, req);
    else if (strcmp(request_method, "HEAD")==0) {
        if (dynamic)
            retval = restconf_method_notallowed(h, req, "GET,POST", pretty, media_out);
        else
            retval = api_data_head(h, req, api_path, pi, qvec, pretty, media_out, ds);
    }
    else if (strcmp(request_method, "GET")==0) {
        retval = api_data_get(h, req, api_path, pi, qvec, pretty, media_out, ds);
    }
    else if (strcmp(request_method, "POST")==0) {
        retval = api_data_post(h, req, api_path, pi, qvec, data, pretty, restconf_content_type(h), media_out, ds);
    }
    else if (strcmp(request_method, "PUT")==0) {
        if (read_only)
            retval = restconf_method_notallowed(h, req, "GET,POST", pretty, media_out);
        else
            retval = api_data_put(h, req, api_path, pi, qvec, data, pretty, media_out, ds);
    }
    else if (strcmp(request_method, "PATCH")==0) {
        if (read_only) {
            retval = restconf_method_notallowed(h, req, "GET,POST", pretty, media_out);
        }
        retval = api_data_patch(h, req, api_path, pi, qvec, data, pretty, media_out, ds);
    }
    else if (strcmp(request_method, "DELETE")==0) {
        if (read_only)
            retval = restconf_method_notallowed(h, req, "GET,POST", pretty, media_out);
        else
            retval = api_data_delete(h, req, api_path, pi, pretty, media_out, ds);
    }
    else{
        if (netconf_invalid_value_xml(&xerr, "protocol", "Invalid HTTP data method") < 0)
            goto done;
        retval = api_return_err0(h, req, xerr, pretty, media_out, 0);
    }
 done:
    clixon_debug(CLIXON_DBG_RESTCONF, "retval:%d", retval);
    if (xerr)
        xml_free(xerr);
    return retval;
}

/*! Operations REST method, POST
 *
 * @param[in]  h      CLIXON handle
 * @param[in]  req   Generic Www handle (can be part of clixon handle)
 * @param[in]  request_method  eg GET,...
 * @param[in]  path   According to restconf (Sec 3.5.1.1 in [draft])
 * @param[in]  pcvec  Vector of path ie DOCUMENT_URI element
 * @param[in]  pi     Offset, where to start pcvec
 * @param[in]  qvec   Vector of query string (QUERY_STRING)
 * @param[in]  data   Stream input data
 * @param[in]  media_out Output media
 * @retval     0         OK
 * @retval    -1         Error
 */
static int
api_operations(clixon_handle h,
               void         *req,
               char         *request_method,
               char         *path,
               cvec         *pcvec,
               int           pi,
               cvec         *qvec,
               char         *data,
               int           pretty,
               restconf_media media_out)
{
    int    retval = -1;
    cxobj *xerr = NULL;

    clixon_debug(CLIXON_DBG_RESTCONF, "");
    if (strcmp(request_method, "GET")==0)
        retval = api_operations_get(h, req, path, pi, qvec, data, pretty, media_out);
    else if (strcmp(request_method, "POST")==0)
        retval = api_operations_post(h, req, path, pi, qvec, data,
                                     pretty, media_out);
    else{
        if (netconf_invalid_value_xml(&xerr, "protocol", "Invalid HTTP operations method") < 0)
            goto done;
        retval = api_return_err0(h, req, xerr, pretty, media_out, 0);
    }
 done:
    if (xerr)
        xml_free(xerr);
    return retval;
}

/*! Process a /restconf root input, this is the root of the restconf processing
 *
 * @param[in]  h     Clixon handle
 * @param[in]  req   Generic Www handle (can be part of clixon handle)
 * @param[in]  qvec  Query parameters, ie the ?<id>=<val>&<id>=<val> stuff
 * @retval     0     OK
 * @retval    -1     Error
 * @see api_root_restconf_exact for accessing /restconf/ exact
 */
int
api_root_restconf(clixon_handle        h,
                  void                *req,
                  cvec                *qvec)
{
    int            retval = -1;
    char          *request_method = NULL; /* GET,.. */
    char          *api_resource = NULL;   /* RFC8040 3.3: eg data/operations */
    char          *path = NULL;
    char         **pvec = NULL;
    cvec          *pcvec = NULL; /* for rest api */
    int            pn;
    int            pretty;
    cbuf          *cb = NULL;
    char          *media_list = NULL;
    restconf_media media_out = YANG_DATA_JSON;
    char          *indata = NULL;
    char          *username = NULL;
    int            ret;
    cxobj         *xerr = NULL;

    clixon_debug(CLIXON_DBG_RESTCONF, "");
    if (req == NULL){
        errno = EINVAL;
        goto done;
    }
    request_method = restconf_param_get(h, "REQUEST_METHOD");
    if ((path = restconf_uripath(h)) == NULL)
        goto done;
    pretty = restconf_pretty_get(h);
    /* Get media for output (proactive negotiation) RFC7231 by using
     * Accept:. This is for methods that have output, such as GET,
     * operation POST, etc
     * If accept is * default is yang-json
     */
    if ((media_list = restconf_param_get(h, "HTTP_ACCEPT")) != NULL){
        if ((int)(media_out = restconf_media_list_str2int(media_list)) == -1) {
            if (restconf_media_in_list("*/*", media_list) == 1)
                media_out = YANG_DATA_JSON;
            else{
                /* If the server does not support any of the requested
                 * output encodings for a request, then it MUST return an error response
                 * with a "406 Not Acceptable" status-line. */
                if (restconf_not_acceptable(h, req, pretty, YANG_DATA_JSON) < 0)
                    goto done;
                goto ok;
            }
        }
    }
    clixon_debug(CLIXON_DBG_RESTCONF, "ACCEPT: %s %s", media_list, restconf_media_int2str(media_out));

    if ((pvec = clicon_strsep(path, "/", &pn)) == NULL)
        goto done;

    /* Sanity check of path. Should be /restconf/ */
    if (pn < 2){
        if (netconf_invalid_value_xml(&xerr, "protocol", "Invalid path, /restconf/ expected") < 0)
            goto done;
        if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
            goto done;
        goto ok;
    }
    if (strlen(pvec[0]) != 0){
        if (netconf_invalid_value_xml(&xerr, "protocol", "Invalid path, restconf api root expected") < 0)
            goto done;
        if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
            goto done;
        goto ok;
    }
    if (pn == 2){
        retval = api_root_restconf_exact(h, req, request_method, pretty, media_out);
        goto done;
    }
    if ((api_resource = pvec[2]) == NULL){
        if (netconf_invalid_value_xml(&xerr, "protocol", "Invalid path, /restconf/ expected") < 0)
            goto done;
        if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
            goto done;
        goto ok;
    }
    clixon_debug(CLIXON_DBG_RESTCONF, "api_resource=%s", api_resource);
    if (uri_str2cvec(path, '/', '=', 1, &pcvec) < 0) /* rest url eg /album=ricky/foo */
        goto done;
    /* data */
    if ((cb = restconf_get_indata(req)) == NULL) /* XXX NYI ACTUALLY not always needed, do this later? */
        goto done;
    indata = cbuf_get(cb);
    clixon_debug(CLIXON_DBG_RESTCONF, "DATA=%s", indata);

    /* If present, check credentials. See "plugin_credentials" in plugin  
     * retvals:
     *    -1    Error
     *     0    Not authenticated
     *     1    Authenticated
     * See RFC 8040 section 2.5
     */
    if ((ret = restconf_authentication_cb(h, req, pretty, media_out)) < 0)
        goto done;
    if (ret == 0)
        goto ok;
    if (strcmp(api_resource, "yang-library-version")==0){
        if (api_yang_library_version(h, req, pretty, media_out) < 0)
            goto done;
    }
    else if (strcmp(api_resource, NETCONF_OUTPUT_DATA) == 0){ /* restconf, skip /api/data */
        if (api_data(h, req, path, pcvec, 2, qvec, indata,
                     pretty, media_out, IETF_DS_NONE) < 0)
            goto done;
    }
    else if (strcmp(api_resource, "ds") == 0) {
        /* We should really be getting the supported datastore types from the
         * application model, but at this time the datastore model of startup/
         * running/cadidate is hardcoded into the clixon implementation. 20201104 */
        ietf_ds_t ds = IETF_DS_NONE;

        if (4 > pn) { /* Malformed request, no "ietf-datastores:<datastore>" component */
            if (netconf_invalid_value_xml(&xerr, "protocol", "Invalid path, No ietf-datastores:<datastore> component") < 0)
                goto done;
            if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
                goto done;
            goto ok;
        }

        /* Assign ds; See https://tools.ietf.org/html/rfc8342#section-7 */
        if (0 == strcmp(pvec[3], "ietf-datastores:running"))
            ds = IETF_DS_RUNNING;
        else if (0 == strcmp(pvec[3], "ietf-datastores:candidate"))
            ds = IETF_DS_CANDIDATE;
        else if (0 == strcmp(pvec[3], "ietf-datastores:startup"))
            ds = IETF_DS_STARTUP;
        else if (0 == strcmp(pvec[3], "ietf-datastores:operational")) {
            /* See https://tools.ietf.org/html/rfc8527#section-3.1
             *     https://tools.ietf.org/html/rfc8342#section-5.3 */
            if (0 > api_operational_state(h, req, request_method, pretty, media_out)) {
                goto done;
            }
            goto ok;
        }
        else { /* Malformed request, unsupported datastore type */
            if (netconf_invalid_value_xml(&xerr, "protocol", "Unsupported datastore type") < 0)
                goto done;
            if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
                goto done;
            goto ok;
        }
        /* ds is assigned at this point */
        if (0 > api_data(h, req, path, pcvec, 3, qvec, indata, pretty, media_out, ds))
            goto done;
    }
    else if (strcmp(api_resource, "operations") == 0){ /* rpc */
        if (api_operations(h, req, request_method, path, pcvec, 2, qvec, indata,
                           pretty, media_out) < 0)
            goto done;
    }
    else{
        if (netconf_invalid_value_xml(&xerr, "protocol", "API-resource type") < 0)
            goto done;
        if (api_return_err0(h, req, xerr, pretty, media_out, 0) < 0)
            goto done;
        goto ok;
    }
 ok:
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_RESTCONF, "retval:%d", retval);
#ifdef WITH_RESTCONF_FCGI
    if (cb)
        cbuf_free(cb);
#endif
    if (xerr)
        xml_free(xerr);
    if (username)
        free(username);
    if (pcvec)
        cvec_free(pcvec);
    if (pvec)
        free(pvec);
    if (path)
        free(path);
    return retval;
}
