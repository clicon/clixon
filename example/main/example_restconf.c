/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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
#include <fcgiapp.h>
#include <curl/curl.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>
#include <clixon/clixon_restconf.h>

static const char Base64[] =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char Pad64 = '=';

/* Use http basic auth. Set by starting restonf with:
 *   clixon_restconf ... -- -a
 */
static int basic_auth = 0;

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
	if (isspace(ch))	/* Skip whitespace anywhere. */
	    continue;

	if (ch == Pad64)
	    break;

	pos = strchr(Base64, ch);
	if (pos == 0) 		/* A non-base64 character. */
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

    if (ch == Pad64) {		/* We got a pad char. */
	ch = *src++;		/* Skip it, get next. */
	switch (state) {
	case 0:		/* Invalid = in first position */
	case 1:		/* Invalid = in second position */
	    return (-1);

	case 2:		/* Valid, means one byte of info */
			/* Skip any number of spaces. */
	    for ((void)NULL; ch != '\0'; ch = *src++)
		if (!isspace(ch))
		    break;
	    /* Make sure there is another trailing = sign. */
	    if (ch != Pad64)
		return (-1);
	    ch = *src++;		/* Skip the = */
	    /* Fall through to "single trailing =" case. */
	    /* FALLTHROUGH */

	case 3:		/* Valid, means two bytes of info */
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

/*! Process a rest request that requires (cookie) "authentication"
 * @param[in]  h        Clixon handle
 * @param[in]  arg      Argument. Here: Fastcgi request handle
 * @retval -1  Fatal error
 * @retval  0  Unauth
 * @retval  1  Auth
 * @note: Three hardwired users: andy, wilma, guest w password "bar".
 * Enabled by passing -- -a to the main function
 */
int
example_restconf_credentials(clicon_handle h,     
			     void         *arg)
{
    int     retval = -1;
    FCGX_Request *r = (FCGX_Request *)arg;
    cxobj  *xt = NULL;
    char   *auth;
    char   *user = NULL;
    char   *passwd;
    char   *passwd2 = "";
    size_t  authlen;
    cbuf   *cb = NULL;
    int     ret;

    /* HTTP basic authentication not enabled, pass with user "none" */
    if (basic_auth==0)
	goto ok;
    /* At this point in the code we must use HTTP basic authentication */
    if ((auth = FCGX_GetParam("HTTP_AUTHORIZATION", r->envp)) == NULL)
	goto fail; 
   if (strlen(auth) < strlen("Basic "))
	goto fail;
    if (strncmp("Basic ", auth, strlen("Basic ")))
	goto fail;
    auth += strlen("Basic ");
    authlen = strlen(auth)*2;
    if ((user = malloc(authlen)) == NULL){
	clicon_err(OE_UNIX, errno, "malloc");
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
    clicon_debug(1, "%s http user:%s passwd:%s", __FUNCTION__, user, passwd);
    /* Here get auth sub-tree whjere all the users are */
    if ((cb = cbuf_new()) == NULL)
	goto done;
    /* XXX Three hardcoded user/passwd (from RFC8341 A.1)*/
    if (strcmp(user, "wilma")==0 || strcmp(user, "andy")==0 ||
	strcmp(user, "guest")==0){
	passwd2 = "bar";
    }
    if (strcmp(passwd, passwd2))
	goto fail;
    retval = 1;
    clicon_debug(1, "%s user:%s", __FUNCTION__, user);
    if (clicon_username_set(h, user) < 0)
	goto done;
 ok:   /* authenticated */
    retval = 1;
 done: /* error */
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (user)
	free(user);
    if (cb)
	cbuf_free(cb);
    if (xt)
        xml_free(xt);
    return retval;
 fail:  /* unauthenticated */
    retval = 0;
    goto done;
}

/*! Local example restconf rpc callback 
 */
int
restconf_client_rpc(clicon_handle h, 
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
	clicon_err(OE_XML, ENOENT, "No namespace given in rpc %s", xml_name(xe));
	goto done;
    }
    cprintf(cbret, "<rpc-reply>");
    if (!xml_child_nr_type(xe, CX_ELMNT))
	cprintf(cbret, "<ok/>");
    else while ((x = xml_child_each(xe, x, CX_ELMNT)) != NULL) {
	    if (xmlns_set(x, NULL, namespace) < 0)
		goto done;
	    if (clicon_xml2cbuf(cbret, x, 0, 0) < 0)
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
example_restconf_start(clicon_handle h)
{
    clicon_debug(1, "%s", __FUNCTION__);
    return 0;
}

clixon_plugin_api * clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api = {
    "example",           /* name */
    clixon_plugin_init,  /* init */
    example_restconf_start,/* start */
    NULL,                /* exit */
    .ca_auth=example_restconf_credentials   /* auth */
};

/*! Restconf plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 * Arguments are argc/argv after --
 * Currently defined: -a  enable http basic authentication
 * @note There are three hardwired users andy, wilma and guest from RFC8341 A.1
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    int       argc; /* command-line options (after --) */
    char    **argv = NULL;
    char      c;
    
    clicon_debug(1, "%s restconf", __FUNCTION__);
    /* Get user command-line options (after --) */
    if (clicon_argv_get(h, &argc, &argv) < 0)
	return NULL;
    opterr = 0;
    optind = 1;
    while ((c = getopt(argc, argv, "a")) != -1)
	switch (c) {
	case 'a':
	    basic_auth = 1;
	    break;
	default:
	    break;
	}
    /* Register local netconf rpc client (note not backend rpc client) */
    if (rpc_callback_register(h, restconf_client_rpc, NULL, "urn:example:clixon", "client-rpc") < 0)
	return NULL;
    return &api;
}
