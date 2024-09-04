/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgat)e

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
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <signal.h>

/* cligen */
#include <cligen/cligen.h>

/* clixon */
#include <clixon/clixon.h>
#include <clixon/clixon_restconf.h>  /* minor use */

/* Command line options to be passed to getopt(3) 
 */
#define RESTCONF_EXAMPLE_OPTS "m:M:"

static const char Base64[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char Pad64 = '=';

/*! Yang schema mount
 *
 * Start restconf with -- -m <yang> -M <namespace>
 * Mount this yang on mountpoint
 * Note module-set hard-coded to "mylabel"
 */
static char *_mount_yang = NULL;
static char *_mount_namespace = NULL;

/* skips all whitespace anywhere.
   converts characters, four at a time, starting at (or after)
   src from base - 64 numbers into three 8 bit bytes in the target area.
   it returns the number of data bytes stored at the target, or -1 on error.
 @note what is copyright of this?
 */
int
b64_decode(const char *src,
           char       *target,
           size_t      targsize)
{
    int tarindex, state, ch;
    char *pos;

    state = 0;
    tarindex = 0;

    while ((ch = *src++) != '\0') {
        if (isspace(ch))        /* Skip whitespace anywhere. */
            continue;

        if (ch == Pad64)
            break;

        pos = strchr(Base64, ch);
        if (pos == 0)           /* A non-base64 character. */
            return (-1);

        switch (state) {
        case 0:
            if (target) {
                if ((size_t)tarindex >= targsize)
                    return (-1);
                target[tarindex] = (pos - Base64) << 2;
            }
            state = 1;
            break;
        case 1:
            if (target) {
                if ((size_t)tarindex + 1 >= targsize)
                    return (-1);
                target[tarindex]   |=  (pos - Base64) >> 4;
                target[tarindex+1]  = ((pos - Base64) & 0x0f)
                    << 4 ;
            }
            tarindex++;
            state = 2;
            break;
        case 2:
            if (target) {
                if ((size_t)tarindex + 1 >= targsize)
                    return (-1);
                target[tarindex]   |=  (pos - Base64) >> 2;
                target[tarindex+1]  = ((pos - Base64) & 0x03)
                    << 6;
            }
            tarindex++;
            state = 3;
            break;
        case 3:
            if (target) {
                if ((size_t)tarindex >= targsize)
                    return (-1);
                target[tarindex] |= (pos - Base64);
            }
            tarindex++;
            state = 0;
            break;
        default:
            return -1;
        }
    }

    /*
     * We are done decoding Base-64 chars.  Let's see if we ended
     * on a byte boundary, and/or with erroneous trailing characters.
     */

    if (ch == Pad64) {          /* We got a pad char. */
        ch = *src++;            /* Skip it, get next. */
        switch (state) {
        case 0:         /* Invalid = in first position */
        case 1:         /* Invalid = in second position */
            return (-1);

        case 2:         /* Valid, means one byte of info */
                        /* Skip any number of spaces. */
            for ((void)NULL; ch != '\0'; ch = *src++)
                if (!isspace(ch))
                    break;
            /* Make sure there is another trailing = sign. */
            if (ch != Pad64)
                return (-1);
            ch = *src++;                /* Skip the = */
            /* Fall through to "single trailing =" case. */
            /* FALLTHROUGH */

        case 3:         /* Valid, means two bytes of info */
                        /*
                         * We know this char is an =.  Is there anything but
                         * whitespace after it?
                         */
            for ((void)NULL; ch != '\0'; ch = *src++)
                if (!isspace(ch))
                    return (-1);

            /*
             * Now make sure for cases 2 and 3 that the "extra"
             * bits that slopped past the last full byte were
             * zeros.  If we don't check them, they become a
             * subliminal channel.
             */
            if (target && target[tarindex] != 0)
                return (-1);
        }
    } else {
        /*
         * We ended by seeing the end of the string.  Make sure we
         * have no partial bytes lying around.
         */
        if (state != 0)
            return (-1);
    }

    return (tarindex);
}

/*! HTTP basic authentication example (note hardwired)
 *
 * @param[in]  h         Clixon handle
 * @param[in]  req       Per-message request www handle to use with restconf_api.h
 * @param[out] authp     NULL: Credentials failed, no user set (401 returned). 
 *                       String: Credentials OK, the associated user, must be mallloc:ed
 *                       Parameter signtificant only if retval is 1/OK
 * @retval     1         OK, see authp parameter for result.
 * @retval     0         Ignore, undecided, not handled, same as no callback
 * @retval    -1         Fatal error
 * @note authp should be malloced
 * @note: Three hardwired users: andy, wilma, guest w password "bar".
 */
static int
example_basic_auth(clixon_handle      h,
                   void              *req,
                   char             **authp)
{
    int     retval = -1;
    cxobj  *xt = NULL;
    char   *user = NULL;
    cbuf   *cb = NULL;
    char   *auth;
    char   *passwd;
    char   *passwd2 = "";
    size_t  authlen;
    int     ret;

    clixon_debug(CLIXON_DBG_DEFAULT, "");
    if (authp == NULL){
        clixon_err(OE_PLUGIN, EINVAL, "Authp output parameter is NULL");
        goto done;
    }
    /* At this point in the code we must use HTTP basic authentication */
    if ((auth = restconf_param_get(h, "HTTP_AUTHORIZATION")) == NULL)
        goto fail;
    if (strlen(auth) < strlen("Basic "))
        goto fail;
    if (strncmp("Basic ", auth, strlen("Basic ")))
        goto fail;
    auth += strlen("Basic ");
    authlen = strlen(auth)*2;
    if ((user = malloc(authlen)) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memset(user, 0, authlen);
    if ((ret = b64_decode(auth, user, authlen)) < 0)
        goto done;
    /* auth string is on the format user:passwd */
    if ((passwd = index(user,':')) == NULL)
        goto fail;
    *passwd = '\0';
    passwd++;
    clixon_debug(CLIXON_DBG_DEFAULT, "http user:%s passwd:%s", user, passwd);
    /* Here get auth sub-tree where all the users are */
    if ((cb = cbuf_new()) == NULL)
        goto done;
    /* XXX Three hardcoded user/passwd (from RFC8341 A.1)*/
    if (strcmp(user, "wilma")==0 || strcmp(user, "andy")==0 ||
        strcmp(user, "guest")==0){
        passwd2 = "bar";
    }
    if (strcmp(passwd, passwd2))
        goto fail;
    *authp = user;     /* authenticated */
    user=NULL; /* to avoid free below */
    retval = 1;
 done: /* error */
    clixon_debug(CLIXON_DBG_DEFAULT, "retval:%d authp:%s", retval, authp?"":*authp);
    if (user)
       free(user);
    if (cb)
        cbuf_free(cb);
    if (xt)
        xml_free(xt);
    return retval;
 fail:  /* unauthenticated */
    *authp = NULL;
    retval = 1;
    goto done;
}

/*! Authentication callback
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
 * @note authp should be malloced
 */
int
example_restconf_credentials(clixon_handle      h,
                             void              *req,
                             clixon_auth_type_t auth_type,
                             char             **authp)
{
    int retval = -1;

    clixon_debug(CLIXON_DBG_DEFAULT, "auth:%s", clixon_auth_type_int2str(auth_type));
    switch (auth_type){
    case CLIXON_AUTH_NONE: /* FEATURE clixon-restconf:allow-auth-none must be enabled */
        retval = 0;
        break;
    case CLIXON_AUTH_CLIENT_CERTIFICATE:
        retval = 0; /* Ignore, use default */
        break;
    case CLIXON_AUTH_USER:
        if ((retval = example_basic_auth(h, req, authp)) < 0)
            goto done;
        break;
    }
 done:
    clixon_debug(CLIXON_DBG_DEFAULT, "retval:%d authp:%s", retval, *authp);
    return retval;
}

/*! Local example restconf rpc callback 
 */
int
restconf_client_rpc(clixon_handle h,
                    cxobj        *xe,
                    cbuf         *cbret,
                    void         *arg,
                    void         *regarg)
{
    int    retval = -1;
    cxobj *x = NULL;
    char  *namespace;

    /* get namespace from rpc name, return back in each output parameter */
    if ((namespace = xml_find_type_value(xe, NULL, "xmlns", CX_ATTR)) == NULL){
        clixon_err(OE_XML, ENOENT, "No namespace given in rpc %s", xml_name(xe));
        goto done;
    }
    cprintf(cbret, "<rpc-reply xmlns=\"%s\">", NETCONF_BASE_NAMESPACE);
    if (!xml_child_nr_type(xe, CX_ELMNT))
        cprintf(cbret, "<ok/>");
    else {
        while ((x = xml_child_each(xe, x, CX_ELMNT)) != NULL) {
            if (xmlns_set(x, NULL, namespace) < 0)
                goto done;
        }
        if (clixon_xml2cbuf(cbret, xe, 0, 0, NULL, -1, 1) < 0)
            goto done;
    }
    cprintf(cbret, "</rpc-reply>");
    retval = 0;
 done:
    return retval;
}

/*! Start example restonf plugin. Set authentication method
 */
int
example_restconf_start(clixon_handle h)
{
    clixon_debug(CLIXON_DBG_DEFAULT, "");
    return 0;
}

/*! Example YANG schema mount
 *
 * Given an XML mount-point xt, return XML yang-lib modules-set
 * @param[in]  h       Clixon handle
 * @param[in]  xt      XML mount-point in XML tree
 * @param[out] config  If '0' all data nodes in the mounted schema are read-only
 * @param[out] validate Do or dont do full RFC 7950 validation
 * @param[out] yanglib XML yang-lib module-set tree
 * @retval     0       OK
 * @retval    -1       Error
 * XXX hardcoded to clixon-example@2022-11-01.yang regardless of xt
 * @see RFC 8528
 */
int
restconf_yang_mount(clixon_handle   h,
                    cxobj          *xt,
                    int            *config,
                    validate_level *vl,
                    cxobj         **yanglib)
{
    int   retval = -1;
    cbuf *cb = NULL;

    if (config)
        *config = 1;
    if (vl)
        *vl = VL_FULL;
    if (yanglib && _mount_yang){
        if ((cb = cbuf_new()) == NULL){
            clixon_err(OE_UNIX, errno, "cbuf_new");
            goto done;
        }
        cprintf(cb, "<yang-library xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\">");
        cprintf(cb, "<module-set>");
        cprintf(cb, "<name>mylabel</name>"); // XXX label in test_yang_schema_mount
        cprintf(cb, "<module>");
        /* In yang name+namespace is mandatory, but not revision */
        cprintf(cb, "<name>%s</name>", _mount_yang); // mandatory
        cprintf(cb, "<namespace>%s</namespace>", _mount_namespace); // mandatory
        //        cprintf(cb, "<revision>2022-11-01</revision>");
        cprintf(cb, "</module>");
        cprintf(cb, "</module-set>");
        cprintf(cb, "</yang-library>");
        if (clixon_xml_parse_string(cbuf_get(cb), YB_NONE, NULL, yanglib, NULL) < 0)
            goto done;
        if (xml_rootchild(*yanglib, 0, yanglib) < 0)
            goto done;
    }

    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
}

clixon_plugin_api * clixon_plugin_init(clixon_handle h);

static clixon_plugin_api api = {
    "example",           /* name */
    clixon_plugin_init,  /* init */
    example_restconf_start,/* start */
    NULL,                /* exit */
    .ca_auth=example_restconf_credentials,   /* auth */
    .ca_yang_mount=restconf_yang_mount,  /* RFC 8528 schema mount */
};

/*! Restconf plugin initialization
 *
 * @param[in]  h    Clixon handle
 * @retval     NULL Error
 * @retval     api  Pointer to API struct
 * Arguments are argc/argv after --
 */
clixon_plugin_api *
clixon_plugin_init(clixon_handle h)
{
    int       argc; /* command-line options (after --) */
    char    **argv = NULL;
    int       c;

    clixon_debug(CLIXON_DBG_DEFAULT, "restconf");
    /* Get user command-line options (after --) */
    if (clicon_argv_get(h, &argc, &argv) < 0)
        return NULL;
    opterr = 0;
    optind = 1;
    while ((c = getopt(argc, argv, RESTCONF_EXAMPLE_OPTS)) != -1)
        switch (c) {
        case 'm':
            _mount_yang = optarg;
            break;
        case 'M':
            _mount_namespace = optarg;
            break;
        default:
            break;
        }
    if ((_mount_yang && !_mount_namespace) || (!_mount_yang && _mount_namespace)){
        clixon_err(OE_PLUGIN, EINVAL, "Both -m and -M must be given for mounts");
        goto done;
    }
    /* Register local netconf rpc client (note not backend rpc client) */
    if (rpc_callback_register(h, restconf_client_rpc, NULL, "urn:example:clixon", "client-rpc") < 0)
        return NULL;
    return &api;
 done:
    return NULL;
}
