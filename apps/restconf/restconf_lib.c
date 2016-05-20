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
#include <sys/time.h>
#include <sys/wait.h>
#include <curl/curl.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include <clixon/clixon.h>

#include "restconf_lib.h"

#define signal_set_mask(set)	sigprocmask(SIG_SETMASK, (set), NULL)
#define signal_get_mask(set)	sigprocmask (0, NULL, (set))

/* Some hardcoded paths */
#define CLI_BIN      "/usr/local/bin/clixon_cli"
#define CLI_OPTS     "-1 -q"

/*
 * Types (curl)
 */
struct curlbuf{
    size_t b_len;
    char  *b_buf;
};

#ifdef notused
static int _log = 0; /* to log or not to log */
/*!
 */
int
dbg_init(char *ident)
{
    openlog(ident, LOG_PID, LOG_USER); 
    _log++;
    return 0;
}


/*!
 */
int
dbg(char *format, ...)
{
    va_list args;
    int     len;
    int     retval = -1;
    char   *msg    = NULL;

    if (_log == 0)
	return 0;
    /* first round: compute length of debug message */
    va_start(args, format);
    len = vsnprintf(NULL, 0, format, args);
    va_end(args);
    /* allocate a message string exactly fitting the message length */
    if ((msg = malloc(len+1)) == NULL){
	fprintf(stderr, "malloc: %s\n", strerror(errno)); /* dont use clicon_err here due to recursion */
	goto done;
    }
    /* second round: compute write message from format and args */
    va_start(args, format);
    if (vsnprintf(msg, len+1, format, args) < 0){
	va_end(args);
	fprintf(stderr, "vsnprintf: %s\n", strerror(errno)); 
	goto done;
    }
    va_end(args);
    syslog(LOG_MAKEPRI(LOG_USER, LOG_DEBUG), "%s", msg);
    retval = 0;
  done:
    if (msg)
	free(msg);
    return retval;
}
#endif /* notused */
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
    FCGX_FPrintF(r->out, "<h1>Grideye Not Found</h1>\n");
    FCGX_FPrintF(r->out, "The requested URL %s was not found on this server.\n",
		 path);
    return 0;
}



/*! Map from keywords grideye config to influxdb interval format
*/
char *
ival2influxdb(char *ival)
{
  if (strcmp(ival, "minute")==0)
    return "1m";
  else if (strcmp(ival, "hour")==0)
    return "1h";
  else if (strcmp(ival, "day")==0)
    return "1d";
  else if (strcmp(ival, "week")==0)
    return "7d"; /* 1w is sunday to sunday */
  else if (strcmp(ival, "month")==0)
    return "30d";
  else if (strcmp(ival, "year")==0 || strcmp(ival, "all")==0)
    return "365d";
  return "1w";
}

/* ripped from clicon_proc.c: clicon_proc_run() 
 * @inparam[in]  instr pipe to process stdin.
 */
static int
proc_run(char *cmd, 
	 char *instr, 
	 void (outcb)(char *, void *), 
	 void *arg)
{
    char      **argv;
    char        buf[512];
    int 	outfd[2] = { -1, -1 };
    int         infd[2]  = { -1, -1 };
    int 	n;
    int         argc;
    int         status;
    int         retval = -1;
    pid_t	child;
    sigfn_t     oldhandler = NULL;
    sigset_t    oset;
    
    clicon_debug(1, "%s %s", __FUNCTION__, cmd);
    argv = clicon_sepsplit (cmd, " \t", &argc, __FUNCTION__);
    if (!argv)
	return -1;

    if (pipe (outfd) == -1)
      goto done;
    if (pipe (infd) == -1)
      goto done;

    signal_get_mask(&oset);
    //    set_signal(SIGINT, clicon_proc_sigint, &oldhandler);

    if ((child = fork ()) < 0) {
	retval = -1;
	goto done;
    }

    if (child == 0) {	/* Child */

	/* Unblock all signals except TSTP */
	clicon_signal_unblock (0);
	signal (SIGTSTP, SIG_IGN);

	close (outfd[0]);	/* Close unused read ends */
	outfd[0] = -1;

	close (infd[1]);	/* Close unused read ends */
	infd[1] = -1;

	/* Divert stdout and stderr to pipes */
	dup2 (outfd[1], STDOUT_FILENO);
	if (0)
	  dup2 (outfd[1], STDERR_FILENO);

	dup2 (infd[0], STDIN_FILENO);
	execvp (argv[0], argv);
	perror("execvp");
	_exit(-1);
    }

    /* Parent */
    /* Close unused read ends */
    close (infd[0]);
    infd[0] = -1;
    if (instr){
	if (write(infd[1], instr, strlen(instr)) < 0){
	    perror("write");
	    goto done;
	}
	close(infd[1]);
    }

    /* Close unused write ends */
    close (outfd[1]);
    outfd[1] = -1;
    /* Read from pipe */
    while ((n = read (outfd[0], buf, sizeof (buf)-1)) != 0) {
	if (n < 0) {
	    if (errno == EINTR)
		continue;
	    break;
	}
	buf[n] = '\0';
	/* Pass read data to callback function is defined */
	if (outcb)
	    outcb (buf, arg);
    }
    /* Wait for child to finish */
    if(waitpid (child, &status, 0) == child)
	retval = WEXITSTATUS(status);
    else
	retval = -1;
 done:

    /* Clean up all pipes */
    if (outfd[0] != -1)
      close (outfd[0]);
    if (outfd[1] != -1)
      close (outfd[1]);

    /* Restore sigmask and fn */
    signal_set_mask (&oset);
    set_signal(SIGINT, oldhandler, NULL);

    unchunk_group (__FUNCTION__);
    clicon_debug(1, "%s end %d", __FUNCTION__, retval);
    return retval;
}

/*! Open dir/filename and pipe to fast-cgi output 
 * @param[in]  r        Fastcgi request handle
 * Either absolute path in filename _or_ concatenation of dir/filename.
 */
int
openfile(FCGX_Request *r, 
	 char         *dir, 
	 char         *filename)
{
    int  retval = -1;
    char buf[512];
    int  f;
    int  n;
    cbuf *cb = NULL;

    if ((cb = cbuf_new()) == NULL)
	goto done;
    if (dir)
	cprintf(cb, "%s/%s", dir, filename);
    else
	cprintf(cb, "%s", filename);
    clicon_debug(1, "%s: %s", __FUNCTION__, cbuf_get(cb));
    if ((f = open(cbuf_get(cb), O_RDONLY)) < 0){
	clicon_debug(1, "open error: %s", strerror(errno));
	perror("open");
	goto done;
    }
    while ((n = read(f, buf, sizeof (buf)-1)) != 0) {
	if (n < 0) {
	    if (errno == EINTR)
		continue;
	    perror("read");
	    goto done;
	}
	buf[n] = '\0';
	FCGX_FPrintF(r->out, "%s",  buf);
    }
    retval = 0;
 done:
    cbuf_free(cb);
    return retval;
}

/*!
 * @param[in]  r        Fastcgi request handle
 */
int
errorfn(FCGX_Request *r, 
	char         *root, 
	char         *reason)
{
    FCGX_FPrintF(r->out, "Content-Type: text/html\r\n");
    FCGX_FPrintF(r->out, "\r\n");
    openfile(r, root, "www/login.html"); /*  "user not specified" */
    FCGX_FPrintF(r->out, "<div class=\"errbox\">%s</div>\r\n", reason);
    return 0;
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
 */
static void
appendfn(char *str, 
	 void *arg)
{
    cbuf *cb = (cbuf *)arg;

    cprintf(cb, "%s", str);
}

/*!
 */
static void
outputfn(char *str, 
	 void *arg)
{
    FCGX_Request *r = (FCGX_Request *)arg;

    FCGX_FPrintF(r->out, "%s",  str);
    clicon_debug(1, "%s: %s", __FUNCTION__, str);
}

/*! Send an RPC to netconf client and return result as string
 * param[out]  result  output from cli as cligen buf
 * param[in]   format  stdarg variable list format a la printf followed by args
 */
int
netconf_rpc(cbuf *result, 
	    char *format, ...)
{
    int     retval = -1;
    cbuf   *cb = NULL;
    va_list args;
    int     len;
    char   *data = NULL;
    char   *endtag;

    clicon_debug(1, "%s", __FUNCTION__);
    if ((cb = cbuf_new()) == NULL)
	goto done;
    va_start(args, format);
    len = vsnprintf(NULL, 0, format, args);
    va_end(args);
    if ((data = malloc(len+1)) == NULL){
	fprintf(stderr, "malloc: %s\n", strerror(errno));
	goto done;
    }
    va_start(args, format);
    vsnprintf(data, len+1, format, args);
    va_end(args);
    cprintf(cb, "%s -f %s %s", 
	    NETCONF_BIN, CONFIG_FILE, NETCONF_OPTS);
    clicon_debug(1, "%s: cmd:%s", __FUNCTION__, cbuf_get(cb));
    clicon_debug(1, "%s: data=%s", __FUNCTION__, data);
    if (proc_run(cbuf_get(cb), data, appendfn, result) < 0)
	goto done;    
    if ((endtag = strstr(cbuf_get(result), "]]>]]>")) != NULL)
	*endtag = '\0';
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    if (data)
	free(data);
    return retval;
}

/*! send netconf command and return output to fastcgi request
 * @param[in]  r        Fastcgi request handle
 */
int
netconf_cmd(FCGX_Request *r, 
	    char         *data)
{
    int  retval = -1;
    cbuf *cb = NULL;

    if ((cb = cbuf_new()) == NULL)
	goto done;
    cprintf(cb, "%s -f %s %s", NETCONF_BIN, CONFIG_FILE, NETCONF_OPTS);
    if (proc_run(cbuf_get(cb), data, outputfn, r) < 0)
	goto done;    
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Send an rpc to cli client and return result as string
 * param[out]  result   output from cli as cligen buf
 * param[in]   mode     CLI mode, typically "configure" or "operation"
  * param[in]  format  stdarg variable list format a la printf followed by args
 */
int
cli_rpc(cbuf *result, 
	char *mode, 
	char *format, ...)
{
    int     retval = -1;
    cbuf   *cb = NULL;
    va_list args;
    int     len;
    char   *cmd = NULL;

    if ((cb = cbuf_new()) == NULL)
	goto done;
    va_start(args, format);
    len = vsnprintf(NULL, 0, format, args);
    va_end(args);
    if ((cmd = malloc(len+1)) == NULL){
	fprintf(stderr, "malloc: %s\n", strerror(errno));
	goto done;
    }
    va_start(args, format);
    vsnprintf(cmd, len+1, format, args);
    va_end(args);
    cprintf(cb, "%s -f %s -m %s %s -- %s", 
	    CLI_BIN, CONFIG_FILE, mode, CLI_OPTS, cmd);
    if (proc_run(cbuf_get(cb), NULL, appendfn, result) < 0)
	goto done;    
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    if (cmd)
	free(cmd);
    return retval;
}

/*! send cli command and return output to fastcgi request
 * @param[in]  r        Fastcgi request handle
 * @param[in]  mode     Command mode, eg configure, operation
 * @param[in]  cmd      Command to run in CLI
 */
int
cli_cmd(FCGX_Request *r, 
	char         *mode, 
	char         *cmd)
{
    int  retval = -1;
    cbuf *cb = NULL;

    if ((cb = cbuf_new()) == NULL)
	goto done;
    cprintf(cb, "%s -f %s -m %s %s -- %s", 
	    CLI_BIN, CONFIG_FILE, mode, CLI_OPTS, cmd);
    if (proc_run(cbuf_get(cb), NULL, outputfn, r) < 0)
	goto done;    
    retval = 0;
 done:
    if (cb)
	cbuf_free(cb);
    return retval;
}

/*! Check in db if user exists, then if passwd matches or if passwd == null
 * @param[in]  passwd Passwd. If NULL dont do passwd check
 * @param[in]  cx     Parse-tree with matching user
 */
int
check_credentials(char  *passwd, 
		  cxobj *cx)
{
    int    retval = 0;
    cxobj *x;

    if ((x = xpath_first(cx, "//user/resultdb/password")) == NULL)
	goto done;
    clicon_debug(1, "%s passwd=%s", __FUNCTION__, xml_body(x));
    if (passwd == NULL || strcmp(passwd, xml_body(x))==0)
	retval = 1;
 done:
    return retval;
}

/*! Get matching top-level list entry given an attribute value pair, eg name="foo" 
 * Construct an XPATH query and send to netconf clixon client to get config xml.
 * The xpath is canonically formed as: //<entry>[<attr>=<val>]
 * @param[in]   entry  XPATH base path
 * @param[in]   attr   Attribute name, if not given skip the [addr=val]
 * @param[in]   val    Value of attribute
 * @param[out]  cx     This is an xml tree containing the result
 */
int
get_db_entry(char   *entry, 
	     char   *attr, 
	     char   *val, 
	     cxobj **cx)
{
    int    retval = -1;
    cbuf  *resbuf = NULL;
    char  *xmlstr;

    clicon_debug(1, "%s //%s[%s=%s]", __FUNCTION__, entry, attr, val);
    if ((resbuf = cbuf_new()) == NULL)
	goto done;
    if (attr){
	if (netconf_rpc(resbuf, 
			"<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"//%s[%s=%s]\" /></get-config></rpc>]]>]]>", 
			entry, attr, val) < 0){
	    clicon_debug(1, "%s error", __FUNCTION__);
	    goto done;
	}
    }
    else
	if (netconf_rpc(resbuf, 
			"<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"//%s\" /></get-config></rpc>]]>]]>", 
			entry) < 0){
	    clicon_debug(1, "%s error", __FUNCTION__);
	    goto done;
	}
    xmlstr = cbuf_get(resbuf);
    //    clicon_debug(1, "%s: %s\n", __FUNCTION__, xmlstr);
    if (clicon_xml_parse_string(&xmlstr, cx) < 0){
	clicon_debug(1, "err:%d reason:%s", clicon_errno, clicon_err_reason);
	goto done;
    }
    if (*cx == NULL)
	goto done;
    retval = 0;
 done:
    if (resbuf)
	cbuf_free(resbuf);
    return retval;
}

/*! Parse a cookie string and return value of cookie attribute
 * @param[in]  cookiestr  cookie string according to rfc6265 (modified)
 * @param[in]  attribute  cookie attribute
 * @param[out] val        malloced cookie value, free with free()
 */
int
get_user_cookie(char  *cookiestr, 
		char  *attribute, 
		char **val)
{
    int    retval = -1;
    cvec  *cvv = NULL;
    char  *c;

    clicon_debug(1, "%s cookiestr=%s", __FUNCTION__, cookiestr);
    if (str2cvec(cookiestr, ';', '=', &cvv) < 0)
	goto done;
    if ((c = cvec_find_str(cvv, attribute)) != NULL){
	if ((*val = strdup(c)) == NULL)
	    goto done;
    }
    retval = 0;
 done:
    if (cvv)
	cvec_free(cvv);
    clicon_debug(1, "%s end %d", __FUNCTION__, retval);
    return retval;
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


/*! Create influxdb database
 * @param[in]  server_addr  Name of http server. dns or ip
 * @param[in]  database     Name of database to create
 * @param[in]  www_user     Root admin user
 * @param[in]  www_passwd   Password of root user
 */
int
create_database(char *server_addr, 
		char *database, 
		char *www_user, 
		char *www_passwd)
{
    int retval = -1;
    cbuf *curl = NULL;
    cbuf *cdata = NULL;

    if ((curl = cbuf_new()) == NULL) /* url */
	goto done;
    if ((cdata = cbuf_new()) == NULL) /* data */
	goto done;
    cprintf(curl, "http://%s:8086/db", server_addr);
    cprintf(cdata, "{\"name\": \"%s\"}", database);
    clicon_debug(1, "%s: %s %s", __FUNCTION__, cbuf_get(curl), cbuf_get(cdata));
    if (url_post(cbuf_get(curl), www_user, www_passwd, cbuf_get(cdata), NULL, NULL) < 0)
	goto done;
    retval = 0;
 done:
    if (curl)
	cbuf_free(curl);
    if (cdata)
	cbuf_free(cdata);
    return retval;
}

/*! Create user passwd  in database 
 * @param[in]  server_addr  Name of http server. dns or ip
 * @param[in]  database     Name of database to create
 * @param[in]  user         User to create for database (not root)
 * @param[in]  passwd       Password of user
 * @param[in]  www_user     Root user to create databases
 * @param[in]  www_passwd   Password of root user
 */
int
create_db_user(char *server_addr, 
	       char *database, 
	       char *user,
	       char *password,
	       char *www_user, 
	       char *www_passwd)
{
    int retval = -1;
    cbuf *curl = NULL;
    cbuf *cdata = NULL;

    if ((curl = cbuf_new()) == NULL) /* url */
	goto done;
    if ((cdata = cbuf_new()) == NULL) /* data */
	goto done;
    cprintf(curl, "http://%s:8086/db/%s/users", server_addr, database);
    cprintf(cdata, "{\"name\": \"%s\", \"password\": \"%s\"}", 
	    user, password);
    if (url_post(cbuf_get(curl), www_user, www_passwd, cbuf_get(cdata), NULL, NULL) < 0)
	goto done;
    clicon_debug(1, "%s: %s %s", __FUNCTION__, cbuf_get(curl), cbuf_get(cdata));
    cbuf_reset(curl);
    cbuf_reset(cdata);
    cprintf(curl, "http://%s:8086/db/%s/users/%s", server_addr, database, user);
    cprintf(cdata, "{\"admin\": true}", password);
    if (url_post(cbuf_get(curl), www_user, www_passwd, cbuf_get(cdata), NULL, NULL) < 0)
	goto done;
    clicon_debug(1, "%s: %s %s", __FUNCTION__, cbuf_get(curl), cbuf_get(cdata));
    retval = 0;
 done:
    if (curl)
	cbuf_free(curl);
    if (cdata)
	cbuf_free(cdata);
    return retval;
}

/*! Send a curl POST request
 * @retval  -1   fatal error
 * @retval   0   expect set but did not expected return or other non-fatal error
 * @retval   1   ok
 * Note: curl_easy_perform blocks
 * Note: New handle is created every time, the handle can be re-used for better TCP performance
 * @see same function (url_post) in grideye_curl.c
 */
int
url_post(char *url, 
	 char *username, 
	 char *passwd, 
	 char *putdata, 
	 char *expect, 
	 char **getdata)
{
    CURL      *curl = NULL;
    char      *err;
    int        retval = -1;
    cxobj     *xr = NULL; /* reply xml */
    struct curlbuf b = {0, };
    CURLcode   errcode;
    char      *output = NULL;

    /* Try it with  curl -X PUT -d '*/
    clicon_debug(1, "%s:  curl -X POST -d '%s' %s (%s:%s)",
	__FUNCTION__, putdata, url, username, passwd);
    /* Set up curl for doing the communication with the controller */
    if ((curl = curl_easy_init()) == NULL) {
	clicon_debug(1, "curl_easy_init");
	goto done;
    }
    if ((output = curl_easy_escape(curl, putdata, 0)) == NULL){
      	clicon_debug(1, "curl_easy_escape");
	goto done;
    }
    if ((err = chunk(CURL_ERROR_SIZE, __FUNCTION__)) == NULL) {
	clicon_debug(1, "%s: chunk", __FUNCTION__);
	goto done;
    }
    curl_easy_setopt(curl, CURLOPT_URL, url);
    if (username)
	curl_easy_setopt(curl, CURLOPT_USERNAME, username);
    if (passwd)
	curl_easy_setopt(curl, CURLOPT_PASSWORD, passwd);
    curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, err);
    curl_easy_setopt(curl, CURLOPT_POST, 1);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, putdata);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, strlen(putdata));
    if (debug)
	curl_easy_setopt(curl, CURLOPT_VERBOSE, 1);   
    if ((errcode = curl_easy_perform(curl)) != CURLE_OK){
	clicon_debug(1, "%s: curl: %s(%d)", __FUNCTION__, err, errcode);
	retval = 0;
	goto done; 
    }
    if (expect){
	if (b.b_buf == NULL){
	    clicon_debug(1, "%s: no match", __FUNCTION__);
	    retval = 0;
	    goto done;
	}
	else{
	    clicon_debug(1, "%s: reply:%s", __FUNCTION__, b.b_buf);
	    if (clicon_xml_parse_string(&b.b_buf, &xr) < 0)
		goto done;
	    if (xpath_first(xr, expect) == NULL){
		clicon_debug(1, "%s: no match", __FUNCTION__);
		retval = 0;
		goto done;
	    }
	}
    }
    if (getdata && b.b_buf){
	*getdata = b.b_buf;
	b.b_buf = NULL;
    }
    retval = 1;
  done:
    unchunk_group(__FUNCTION__);
    if (output)
      curl_free(output);
    if (xr != NULL)
	xml_free(xr);
    if (b.b_buf)
	free(b.b_buf);
    if (curl)
	curl_easy_cleanup(curl);   /* cleanup */ 
    return retval;
}

static const char Base64[] =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char Pad64 = '=';

#if notdef
/*! return length of dst */
int
b64_encode(const char *src, 
	   char       *dst, 
	   int         dlen)
{
    int      i;
    int      s = 0;
    int      j = 0;
    uint32_t data = 0;
    int      slen;
    
    slen = strlen(src);
    /* 
     * The encoded length will "grow" 33% in respect to the original length, 
     * i.e. 3 character will be 4 characters 
     */ 
    if (((slen * 7) / 5) > dlen) {
	clicon_debug(1, "Destination buffer to small.\n");
	return -1;
    }
    for (i = 0; i < slen; i++) {		
	data <<= 8;
	data |= ((uint32_t)src[i] & 0x000000ff);
	s++;
	if (s == 3) {
	    dst[j++] = Base64[((data >> 18) & 0x3f)]; 
	    dst[j++] = Base64[((data >> 12) & 0x3f)]; 
	    dst[j++] = Base64[((data >> 6) & 0x3f)]; 
	    dst[j++] = Base64[(data & 0x3f)]; 			
	    dst[j]   = '\0';
	    data = 0;
	    s = 0;
	}
    }
    switch (s) {
    case 0:
	break;
    case 1:
	data <<= 4;
	dst[j++] = Base64[((data >> 6) & 0x3f)]; 
	dst[j++] = Base64[(data & 0x3f)]; 			
	dst[j++] = Pad64;
	dst[j++] = Pad64;
	break;
    case 2:
	data <<= 2;
	dst[j++] = Base64[((data >> 12) & 0x3f)]; 
	dst[j++] = Base64[((data >> 6) & 0x3f)]; 
	dst[j++] = Base64[(data & 0x3f)]; 			
	dst[j++] = Pad64;
	break;
    }
    dst[j] = '\0';
    return j;
}
#endif

/* skips all whitespace anywhere.
   converts characters, four at a time, starting at (or after)
   src from base - 64 numbers into three 8 bit bytes in the target area.
   it returns the number of data bytes stored at the target, or -1 on error.
 */
int
b64_decode(const char *src, 
	   char       *target, 
	   size_t      targsize)
{
    int tarindex, state, ch;
    char *pos;

    clicon_debug(1, "%s", __FUNCTION__);
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

/*! Get field from metric yang spec
 * @param[in]   metric    Metric
 * @param[in]   fiels     Which field in metric (eg type, units)
 * @param[out]  result    Allocated string. Free after use
 */
static int
get_metric_spec(char  *metric, 
		char  *field, 
		char **result)
{
    int     retval = -1;
    cbuf   *resbuf = NULL;
    char   *xmlstr;
    cxobj  *mx;
    cxobj  *dx;
    cxobj  *sx;
    char   *val;

    clicon_debug(1, "%s metric:%s", __FUNCTION__, metric);
    *result = NULL;
    if ((resbuf = cbuf_new()) == NULL)
	goto done;
    if (netconf_rpc(resbuf, 
		    "<rpc><grideye><metric_spec>%s</metric_spec></grideye></rpc>]]>]]>",
		    metric) < 0){
	clicon_debug(1, "%s error", __FUNCTION__);
	goto done;
    }
    xmlstr = cbuf_get(resbuf);
    clicon_debug(1, "xmlstr: %s", xmlstr);
    if (clicon_xml_parse_string(&xmlstr, &mx) < 0){
	clicon_debug(1, "err:%d reason:%s", clicon_errno, clicon_err_reason);
	goto done;
    }
    if ((dx = xpath_first(mx, "//data")) != NULL){
	if ((sx = xpath_first(dx, metric)) != NULL){
	    if ((val = xml_find_body(sx, field)) != NULL)
		*result = strdup(val);
	}
    }
    retval = 0;
 done:
     if (resbuf)
	cbuf_free(resbuf);
     if (mx)
	xml_free(mx);
    return retval;    
}

int
metric_spec_description(char  *metric, 
			char **result)
{
    return get_metric_spec(metric, "description", result);
}

int
metric_spec_units(char  *metric, 
		  char **result)
{
    return get_metric_spec(metric, "units", result);
}
