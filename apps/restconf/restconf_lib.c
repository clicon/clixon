/*
 */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>
#include <ctype.h>
#include <time.h>
#include <fcgi_stdio.h>
#include <signal.h>
#include <dlfcn.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <curl/curl.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include "restconf_lib.h"


/*!
 */
int
notfound(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 404\r\n"); /* 404 not found */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Clixon Not Found</h1>\n");
    FCGX_FPrintF(r->out, "The requested URL %s was not found on this server.\n",
		 path);
    return 0;
}
int
badrequest(FCGX_Request *r)
{
    char *path;

    clicon_debug(1, "%s", __FUNCTION__);
    path = FCGX_GetParam("DOCUMENT_URI", r->envp);
    FCGX_FPrintF(r->out, "Status: 400\r\n"); /* 400 bad request */
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n\r\n");
    FCGX_FPrintF(r->out, "<h1>Clixon Bad request/h1>\n");
    FCGX_FPrintF(r->out, "The requested URL %s or data is in some way badly formed.\n",
		 path);
    return 0;
}

/*! Specialization of clicon_debug with xml tree */
int 
clicon_debug_xml(int    dbglevel, 
		 char  *str,
		 cxobj *x)
{
    int   retval = -1;
    cbuf *cb;

    if ((cb = cbuf_new()) == NULL)
	goto done;
    if (clicon_xml2cbuf(cb, x, 0, 0) < 0)
	goto done;
    clicon_debug(1, "%s %s", str, cbuf_get(cb));
    retval = 0;
 done:
    if (cb!=NULL)
	cbuf_free(cb);
    return retval;
}

/*! Split a string into a cligen variable vector using 1st and 2nd delimiter 
 * Split a string first into elements delimited by delim1, then into
 * pairs delimited by delim2.
 * @param[in] string  String to split
 * @param[in] delim1  First delimiter char that delimits between elements
 * @param[in] delim2  Second delimiter char for pairs within an element
 * @param[out] cvp    Created cligen variable vector, NOTE: can be NULL
 * @retval    0       on OK
 * @retval    -1      error
 *
 * Example, assuming delim1 = '&' and delim2 = '='
 * a=b&c=d    ->  [[a,"b"][c="d"]
 * kalle&c=d  ->  [[c="d"]]  # Discard elements with no delim2
 * XXX differentiate between error and null cvec.
 */
int
str2cvec(char  *string, 
	 char   delim1, 
	 char   delim2, 
	 cvec **cvp)
{
    int     retval = -1;
    char   *s;
    char   *s0 = NULL;;
    char   *val;     /* value */
    char   *valu;    /* unescaped value */
    char   *snext; /* next element in string */
    cvec   *cvv = NULL;
    cg_var *cv;

    clicon_debug(1, "%s %s", __FUNCTION__, string);
    if ((s0 = strdup(string)) == NULL){
	clicon_debug(1, "error strdup %s", strerror(errno));
	goto err;
    }
    s = s0;
    if ((cvv = cvec_new(0)) ==NULL){
	clicon_debug(1, "error cvec_new %s", strerror(errno));
	goto err;
    }
    while (s != NULL) {
	/*
	 * In the pointer algorithm below:
	 * name1=val1;  name2=val2;
	 * ^     ^      ^
	 * |     |      |
	 * s     val    snext
	 */
	if ((snext = index(s, delim1)) != NULL)
	    *(snext++) = '\0';
	if ((val = index(s, delim2)) != NULL){
	    *(val++) = '\0';
	    if ((valu = curl_easy_unescape(NULL, val, 0, NULL)) == NULL){
		clicon_debug(1, "curl_easy_unescape %s", strerror(errno));
		goto err;
	    }
	    if ((cv = cvec_add(cvv, CGV_STRING)) == NULL){
		clicon_debug(1, "error cvec_add %s", strerror(errno));
		goto err;
	    }
	    cv_name_set(cv, s);
	    cv_string_set(cv, valu);
	    free(valu);
	}
	else{
	    if (strlen(s)){
		if ((cv = cvec_add(cvv, CGV_STRING)) == NULL){
		    clicon_debug(1, "error cvec_add %s", strerror(errno));
		    goto err;
		}
		cv_name_set(cv, s);
		cv_string_set(cv, "");
	    }
	}
	s = snext;
    }
    retval = 0;
 done:
    *cvp = cvv;
    if (s0)
	free(s0);
    return retval;
 err:
    if (cvv){
	cvec_free(cvv);
	cvv = NULL;
    }
    goto done;
}

/*!
 * @param[in]  r        Fastcgi request handle
 */
static int
printparam(FCGX_Request *r, 
	   char         *e, 
	   int           dbgp)
{
    char *p = FCGX_GetParam(e, r->envp);

    if (dbgp)
	clicon_debug(1, "%s = '%s'", e, p?p:"");
    else
	FCGX_FPrintF(r->out, "%s = '%s'\n", e, p?p:"");
    return 0;
}

/*!
 * @param[in]  r        Fastcgi request handle
 */
int
test(FCGX_Request *r, 
     int           dbg)
{
    printparam(r, "QUERY_STRING", dbg);
    printparam(r, "REQUEST_METHOD", dbg);	
    printparam(r, "CONTENT_TYPE", dbg);	
    printparam(r, "CONTENT_LENGTH", dbg);	
    printparam(r, "SCRIPT_FILENAME", dbg);	
    printparam(r, "SCRIPT_NAME", dbg);	
    printparam(r, "REQUEST_URI", dbg);	
    printparam(r, "DOCUMENT_URI", dbg);	
    printparam(r, "DOCUMENT_ROOT", dbg);	
    printparam(r, "SERVER_PROTOCOL", dbg);	
    printparam(r, "GATEWAY_INTERFACE", dbg);
    printparam(r, "SERVER_SOFTWARE", dbg);
    printparam(r, "REMOTE_ADDR", dbg);
    printparam(r, "REMOTE_PORT", dbg);
    printparam(r, "SERVER_ADDR", dbg);
    printparam(r, "SERVER_PORT", dbg);
    printparam(r, "SERVER_NAME", dbg);
    printparam(r, "HTTP_COOKIE", dbg);
    printparam(r, "HTTPS", dbg);

    return 0;
}

/*!
 * @param[in]  r        Fastcgi request handle
 */
cbuf *
readdata(FCGX_Request *r)
{
    int   c;
    cbuf *cb;

    if ((cb = cbuf_new()) == NULL)
	return NULL;
    while ((c = FCGX_GetChar(r->in)) != -1)
	cprintf(cb, "%c", c);
    return cb;
}

typedef int (credentials_t)(clicon_handle h, FCGX_Request *r); 

static int nplugins = 0;
static plghndl_t *plugins = NULL;
static credentials_t *p_credentials = NULL; /* Credentials callback */

/*! Load a dynamic plugin object and call it's init-function
 * Note 'file' may be destructively modified
 */
static plghndl_t 
plugin_load (clicon_handle h, 
	     char         *file, 
	     int           dlflags, 
	     const char   *cnklbl)
{
    char      *error;
    void      *handle = NULL;
    plginit_t *initfn;

    clicon_debug(1, "%s", __FUNCTION__);
    dlerror();    /* Clear any existing error */
    if ((handle = dlopen (file, dlflags)) == NULL) {
        error = (char*)dlerror();
	clicon_err(OE_PLUGIN, errno, "dlopen: %s\n", error ? error : "Unknown error");
	goto done;
    }
    /* call plugin_init() if defined */
    if ((initfn = dlsym(handle, PLUGIN_INIT)) == NULL){
	clicon_err(OE_PLUGIN, errno, "Failed to find plugin_init when loading restconf plugin %s", file);
	goto err;
    }
    if (initfn(h) != 0) {
	clicon_err(OE_PLUGIN, errno, "Failed to initiate %s", strrchr(file,'/')?strchr(file, '/'):file);
	goto err;
    }
    p_credentials    = dlsym(handle, "restconf_credentials");
 done:
    return handle;
 err:
    if (handle)
	dlclose(handle);
    return NULL;
}


/*! Load all plugins you can find in CLICON_RESTCONF_DIR
 */
int 
restconf_plugin_load(clicon_handle h)
{
    int            retval = -1;
    char          *dir;
    int            ndp;
    struct dirent *dp;
    int            i;
    char          *filename;
    plghndl_t     *handle;

    if ((dir = clicon_restconf_dir(h)) == NULL){
	clicon_err(OE_PLUGIN, 0, "clicon_restconf_dir not defined");
	goto quit;
    }
    /* Get plugin objects names from plugin directory */
    if((ndp = clicon_file_dirent(dir, &dp, "(.so)$", S_IFREG, __FUNCTION__))<0)
	goto quit;

    /* Load all plugins */
    for (i = 0; i < ndp; i++) {
	filename = chunk_sprintf(__FUNCTION__, "%s/%s", dir, dp[i].d_name);
	clicon_debug(1, "DEBUG: Loading plugin '%.*s' ...", 
		     (int)strlen(filename), filename);
	if (filename == NULL) {
	    clicon_err(OE_UNIX, errno, "chunk");
	    goto quit;
	}
	if ((handle = plugin_load (h, filename, RTLD_NOW, __FUNCTION__)) == NULL)
	    goto quit;
	if ((plugins = rechunk(plugins, (nplugins+1) * sizeof (*plugins), NULL)) == NULL) {
	    clicon_err(OE_UNIX, errno, "chunk");
	    goto quit;
	}
	plugins[nplugins++] = handle;
	unchunk (filename);
    }
    retval = 0;
quit:
    unchunk_group(__FUNCTION__);
    return retval;
}

/*! Unload a plugin
 */
static int
plugin_unload(clicon_handle h, void *handle)
{
    int retval = 0;
    char *error;
    plgexit_t *exitfn;

    /* Call exit function is it exists */
    exitfn = dlsym(handle, PLUGIN_EXIT);
    if (dlerror() == NULL)
	exitfn(h);

    dlerror();    /* Clear any existing error */
    if (dlclose(handle) != 0) {
	error = (char*)dlerror();
	clicon_err(OE_PLUGIN, errno, "dlclose: %s\n", error ? error : "Unknown error");
	/* Just report */
    }
    return retval;
}

/*! Unload all restconf plugins */
int
restconf_plugin_unload(clicon_handle h)
{
    int i;

    for (i = 0; i < nplugins; i++) 
	plugin_unload(h, plugins[i]);
    if (plugins)
	unchunk(plugins);
    nplugins = 0;
    return 0;
}

/*! Call plugin_start in all plugins
 */
int
restconf_plugin_start(clicon_handle h, 
		      int           argc, 
		      char        **argv)
{
    int i;
    plgstart_t *startfn;

    for (i = 0; i < nplugins; i++) {
	/* Call exit function is it exists */
	if ((startfn = dlsym(plugins[i], PLUGIN_START)) == NULL)
	    break;
	optind = 0;
	if (startfn(h, argc, argv) < 0) {
	    clicon_debug(1, "plugin_start() failed\n");
	    return -1;
	}
    }
    return 0;
}

int 
plugin_credentials(clicon_handle h,     
		   FCGX_Request *r,
		   int          *auth)
{
    int retval = -1;

    clicon_debug(1, "%s", __FUNCTION__);
    /* If no authentication callback then allow anything. Is this OK? */
    if (p_credentials == 0){
	*auth = 1;
	retval = 0;
	goto done;
    }
    if (p_credentials(h, r) < 0) 
	*auth = 0;
    else
	*auth = 1;
    retval = 0;
 done:
    return retval;
}
