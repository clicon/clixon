/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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
        device                                 client
  +-----------------+        tcp    4321 +-----------------+
  | util_netconf_ssh| <----------------> |       xxx       |
  |          |      |                    +-----------------+
  |     exec v      |                        4322 | tcp
  |                 |        ssh         +-----------------+
  |     sshd -e     | <----------------> |       ssh       |
  +-----------------+                    +-----------------+
           | stdio                                | stdio
  +-----------------+
  | clixon_netconf  |
  +-----------------+
           | 
  +-----------------+
  | clixon_backend  |
  +-----------------+

Example sshd-config (-c option):n
  Port 2592
  UsePrivilegeSeparation no
  TCPKeepAlive yes
  AuthorizedKeysFile ~.ssh/authorized_keys
  Subsystem netconf /usr/local/bin/clixon_netconf
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define NETCONF_CH_SSH 4334
#define SSHDBIN_DEFAULT "/usr/sbin/sshd"
#define UTIL_OPTS "hD:f:a:p:s:c:"

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

static int
exec_sshd(int   s,
	  char *sshdbin,
	  char *configfile)
{
    int    retval = -1;
    char **argv = NULL;
    int    i;
    int    nr;

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
    if (configfile == NULL){
	errno = EINVAL;
	perror("configfile");
	goto done;
    }
    nr = 7; // XXX
    if ((argv = calloc(nr, sizeof(char *))) == NULL){
	perror("calloc");
	goto done;
    }
    i = 0;
    argv[i++] = sshdbin;
    argv[i++] = "-i"; /* Specifies that sshd is being run from inetd(8) */
    argv[i++] = "-d";
    argv[i++] = "-e";
    argv[i++] = "-f";
    argv[i++] = configfile;
    argv[i++] = NULL;
    assert(i==nr);
    if (setreuid(0, 0) < 0){
	perror("setreuid");
	goto done;
    }
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
	    "\t-f ipv4|ipv6 \tSocket address family(ipv4 default)\n"
	    "\t-a <addrstr> \tIP address (eg 1.2.3.4) - mandatory\n"
	    "\t-p <port>    \tPort (default 4334)\n"
	    "\t-c <file>    \tSSHD config file - mandatory\n"
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
    char               *family = "ipv4";
    char               *addr = NULL;
    struct sockaddr    *sa;
    struct sockaddr_in6 sin6   = { 0 };
    struct sockaddr_in  sin    = { 0 };
    size_t              sin_len;
    int                 debug = 0;
    uint16_t            port = NETCONF_CH_SSH;
    int                 s = -1;
    char               *sshdbin = SSHDBIN_DEFAULT;
    char               *configfile = NULL;

    optind = 1;
    opterr = 0;
    while ((c = getopt(argc, argv, UTIL_OPTS)) != -1)
	switch (c) {
	case 'h':
	    usage(argv[0]);
	    break;
    	case 'D':
	    debug++;
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
	case 'c':
	    configfile = optarg;
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
    if (configfile == NULL){
	fprintf(stderr, "-c <file> is NULL\n");
	usage(argv[0]);
	goto done;
    }
    if (strcmp(family, "ipv6") == 0){
        sin_len          = sizeof(struct sockaddr_in6);
        sin6.sin6_port   = htons(port);
        sin6.sin6_family = AF_INET6;
        inet_pton(AF_INET6, addr, &sin6.sin6_addr);
        sa = (struct sockaddr *)&sin6;	
    }
    else if (strcmp(family, "ipv4") == 0){
        sin_len             = sizeof(struct sockaddr_in);
        sin.sin_family      = AF_INET;
        sin.sin_port        = htons(port);
        sin.sin_addr.s_addr = inet_addr(addr);
        sa = (struct sockaddr *)&sin;
    }
    else{
	fprintf(stderr, "-f <%s> is invalid family\n", family);
	goto done;
    }
    if (callhome_connect(sa, sin_len, &s) < 0)
	goto done;
    if (exec_sshd(s, sshdbin, configfile) < 0)
	goto done;
    if (s >= 0)
	close(s);
    retval = 0;
 done:
    return retval;
}


