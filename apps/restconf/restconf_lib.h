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
int badrequest(FCGX_Request *r);
int clicon_debug_xml(int dbglevel, char *str, cxobj *cx);
int str2cvec(char *string, char delim1, char delim2, cvec **cvp);
int test(FCGX_Request *r, int dbg);
cbuf *readdata(FCGX_Request *r);


int restconf_plugin_load(clicon_handle h);
int restconf_plugin_start(clicon_handle h, int argc, char **argv);
int restconf_plugin_unload(clicon_handle h);
int plugin_credentials(clicon_handle h, FCGX_Request *r, int *auth);

#endif /* _RESTCONF_LIB_H_ */
