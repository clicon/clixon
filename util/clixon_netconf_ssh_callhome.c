/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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

  * Create stream socket, connect to remote address, then exec sshd -e that takes over the 
  * tcp connection.

   device/server                               client
  +-----------------+   2) tcp connect   +-----------------+
  |    callhome     | ---------------->  | callhome-client |
  +-----------------+                    +-----------------+
          | 3) c                                  ^
          v                                    1) | 4)
  +-----------------+        ssh         +-----------------+   5) stdio
  |     sshd -i     | <----------------> |       ssh       |  <------  <rpc>...</rpc>]]>]]>"
  +-----------------+                    |-----------------+   
          | stdio                      
  +-----------------+
  | clixon_netconf  |
  +-----------------+
          | 
  +-----------------+
  | clixon_backend  |
  +-----------------+

1) Start ssh client using -o ProxyUseFdpass=yes -o ProxyCommand="callhome-client". 
   Callhome-client listens on port 4334 for incoming TCP connections.
2) Start callhome on server making tcp connect to client on port 4334 establishing a tcp stream
3) Callhome starts sshd -i using the established stream socket (stdio)
4) Callhome-client returns with an open stream socket to the ssh client establishing an SSH stream 
   to server
5) Client request sent on stdin to ssh client on established SSH stream using netconf subsystem
   to clixon_netconf client

ssh -s -v -o ProxyUseFdpass=yes -o ProxyCommand="clixon_netconf_ssh_callhome_client -a 127.0.0.1" . netconf
sudo clixon_netconf_ssh_callhome -a 127.0.0.1 -c /var/tmp/./test_netconf_ssh_callhome.sh/conf_yang.xml

 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define NETCONF_CH_SSH 4334
#define SSHDBIN_DEFAULT "/usr/sbin/sshd"
#define UTIL_OPTS "hD:f:a:p:s:c:C:"

static int
callhome_connect(struct sockaddr *sa,
		 size_t           sa_len,
		 int             *sp)
{
    int retval = -1;
    int s;

    if ((s = socket(sa->sa_family, SOCK_STREAM, 0)) < 0) {
	perror("socket");
	goto done;
    }
    if (connect(s, sa, sa_len) < 0){
	perror("connect");
	close(s);
	goto done;
    }
    *sp = s;
    retval = 0;
 done:
    return retval;
}

/* @see clixon_inet2sin */
static int
inet2sin(const char       *addrtype,
	 const char       *addrstr,
	 uint16_t          port,
	 struct sockaddr  *sa,
	 size_t           *sa_len)
{
    struct sockaddr_in6 *sin6;
    struct sockaddr_in  *sin;

    if (strcmp(addrtype, "inet:ipv6-address") == 0) {
	sin6 = (struct sockaddr_in6 *)sa;
        *sa_len           = sizeof(struct sockaddr_in6);
        sin6->sin6_port   = htons(port);
        sin6->sin6_family = AF_INET6;
        inet_pton(AF_INET6, addrstr, &sin6->sin6_addr);
    }
    else if (strcmp(addrtype, "inet:ipv4-address") == 0) {
	sin = (struct sockaddr_in *)sa;
        *sa_len              = sizeof(struct sockaddr_in);
        sin->sin_family      = AF_INET;
        sin->sin_port        = htons(port);
        sin->sin_addr.s_addr = inet_addr(addrstr);
    }
    else{
	fprintf(stderr, "Unexpected addrtype: %s\n", addrtype);
	return -1;
    }
    return 0;
}


static int
ssh_server_exec(int   s,
	  char *sshdbin,
	  char *sshdconfigfile,
    	  char *clixonconfigfile,
	  int   dbg)
{
    int    retval = -1;
    char **argv = NULL;
    int    i;
    int    nr;
    char  *optstr = NULL;
    size_t len;
    const char *formatstr = "Subsystem netconf /usr/local/bin/clixon_netconf -f %s";

    if (s < 0){
	errno = EINVAL;
	perror("socket s");
	goto done;
    }
    if (sshdbin == NULL){
	errno = EINVAL;
	perror("sshdbin");
	goto done;
    }
    if (sshdconfigfile == NULL){
	errno = EINVAL;
	perror("sshdconfigfile");
	goto done;
    }
    if (clixonconfigfile == NULL){
	errno = EINVAL;
	perror("clixonconfigfile");
	goto done;
    }
    /* Construct subsystem string */
    len = strlen(formatstr)+strlen(clixonconfigfile)+1;
    if ((optstr = malloc(len)) == NULL){
	perror("malloc");
	goto done;
    }
    snprintf(optstr, len, formatstr, clixonconfigfile);

    nr = 9; /* See below */
    if (dbg)
	nr++;
    if ((argv = calloc(nr, sizeof(char *))) == NULL){
	perror("calloc");
	goto done;
    }

    i = 0;
    /* Note if you change here, also change in nr = above */
    argv[i++] = sshdbin;
    argv[i++] = "-i"; /* Specifies that sshd is being run from inetd(8) */
    argv[i++] = "-D";  /* Foreground ? */
    if (dbg)
	argv[i++] = "-d"; /* Debug mode */
    argv[i++] = "-e"; /* write debug logs to stderr */
    argv[i++] = "-o"; /* option */
    argv[i++] = optstr;
    argv[i++] = "-f"; /* config file */
    argv[i++] = sshdconfigfile;
    argv[i++] = NULL;
    assert(i==nr);
    if (setreuid(0, 0) < 0){
	perror("setreuid");
	goto done;
    }
    close(0);
    close(1);
    if (dup2(s, STDIN_FILENO) < 0){
	perror("dup2");
	return -1;
    }
    if (dup2(s, STDOUT_FILENO) < 0){
	perror("dup2");
	return -1;
    }
    if (execv(argv[0], argv) < 0) {
	perror("execv");
	exit(1);
    }
    /* Should reach here */
    retval = 0;
 done:
    return retval;
}

static int
usage(char *argv0)
{
    fprintf(stderr, "usage:%s [options]\n"
	    "where options are\n"
            "\t-h           \tHelp\n"
    	    "\t-D <level>   \tDebug\n"
	    "\t-f ipv4|ipv6 \tSocket address family(inet:ipv4-address default)\n"
	    "\t-a <addrstr> \tIP address (eg 1.2.3.4) - mandatory\n"
	    "\t-p <port>    \tPort (default 4334)\n"
	    "\t-c <file>    \tClixon config file - (default /usr/local/etc/clixon.xml)\n"
	    "\t-C <file>    \tSSHD config file - (default /dev/null)\n"
	    "\t-s <sshd>    \tPath to sshd binary, default %s\n"
	    ,
	    argv0, SSHDBIN_DEFAULT);
    exit(0);
}

int
main(int    argc,
     char **argv)
{
    int                 retval = -1;
    int                 c;
    char               *family = "inet:ipv4-address";
    char               *addr = NULL;
    struct sockaddr_in6 sin6 = {0, };
    struct sockaddr    *sa = (struct sockaddr *)&sin6;
    size_t              sa_len;
    int                 dbg = 0;
    uint16_t            port = NETCONF_CH_SSH;
    int                 s = -1;
    char               *sshdbin = SSHDBIN_DEFAULT;
    char               *sshdconfigfile = "/dev/null";
    char               *clixonconfigfile = "/usr/local/etc/clixon.xml";

    optind = 1;
    opterr = 0;
    while ((c = getopt(argc, argv, UTIL_OPTS)) != -1)
	switch (c) {
	case 'h':
	    usage(argv[0]);
	    break;
    	case 'D':
	    dbg++;
	    break;
	case 'f':
	    family = optarg;
	    break;
	case 'a':
	    addr = optarg;
	    break;
	case 'p':
	    port = atoi(optarg);
	    break;
	case 'C':
	    sshdconfigfile = optarg;
	    break;
	case 'c':
	    clixonconfigfile = optarg;
	    break;
	case 's':
	    sshdbin = optarg;
	    break;
	default:
	    usage(argv[0]);
	    break;
	}
    if (port == 0){
	fprintf(stderr, "-p <port> is invalid\n");
	usage(argv[0]);
	goto done;
    }
    if (addr == NULL){
	fprintf(stderr, "-a <addr> is NULL\n");
	usage(argv[0]);
	goto done;
    }
    if (inet2sin(family, addr, port, sa, &sa_len) < 0)
	goto done;
    if (callhome_connect(sa, sa_len, &s) < 0)
	goto done;
    /* For some reason this sshd returns -1 which is unclear why */
    if (ssh_server_exec(s, sshdbin, sshdconfigfile, clixonconfigfile, dbg) < 0)
	goto done;
    /* Should not reach here */
    if (s >= 0)
	close(s);
    retval = 0;
 done:
    return retval;
}
