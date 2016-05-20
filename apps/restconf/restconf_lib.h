/*
 *
 *  $COPYRIGHTSTATEMENT$
 *
 *  $LICENSE$
 * This is backend headend sender code, ie communication with a pmagent
 */

#ifndef _RESTCONF_LIB_H_
#define _RESTCONF_LIB_H_

/*
 * Constants
 */
#define USER_COOKIE  "c-user" /* connected user cookie */
#define WWW_USER "root"
#define WWW_PASSWD "9rundpaj" // XXX
#define DEFAULT_TEMPLATE "nordunet" /* XXX Default sender template must be in conf */
#define CONFIG_FILE  "/usr/local/etc/grideye.conf"
#define NETCONF_BIN  "/usr/local/bin/clixon_netconf"
#define NETCONF_OPTS "-qS"

/*
 * Prototypes
 */
int notfound(FCGX_Request *r);

char *ival2influxdb(char *ival);
int openfile(FCGX_Request *r, char *dir, char *filename);
int errorfn(FCGX_Request *r, char *root, char *reason);
int str2cvec(char *string, char delim1, char delim2, cvec **cvp);
int netconf_rpc(cbuf *result, char *format, ...);
int netconf_cmd(FCGX_Request *r, char *data);
int cli_rpc(cbuf *result, char *mode, char *format, ...);
int cli_cmd(FCGX_Request *r, char *mode, char *cmd);
int check_credentials(char *passwd, cxobj *cx);
int get_db_entry(char *entry, char *attr, char *val, cxobj **cx);
int get_user_cookie(char *cookiestr, char *attribute, char **val);
int test(FCGX_Request *r, int dbg);
cbuf *readdata(FCGX_Request *r);

int create_database(char *server_addr, char *database, char *www_user, char *www_passwd);
int create_db_user(char *server_addr, char *database, char *user, char *password, char *www_user, char *www_passwd);
int url_post(char *url, char *username, char *passwd, char *putdata, 
	     char *expect, char **getdata);
int b64_decode(const char *b64_buf, char *buf, size_t buf_len);
int metric_spec_description(char *metric, char **result);
int metric_spec_units(char *metric, char **result);

#endif /* _RESTCONF_LIB_H_ */
