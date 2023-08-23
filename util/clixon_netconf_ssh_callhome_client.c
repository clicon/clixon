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

Example sshd-config (-c option):n
  ssh -s -v -o ProxyUseFdpass=yes -o ProxyCommand="clixon_netconf_ssh_callhome_client -a 127.0.0.1" . netconf
  sudo clixon_netconf_ssh_callhome -a 127.0.0.1

 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <errno.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#include <cligen/cligen_buf.h>
#include <clixon/clixon_err.h>

#define NETCONF_CH_SSH 4334
#define UTIL_OPTS "hD:f:a:p:"

/*
 * fdpass()
 * Pass the connected file descriptor to stdout and exit.
 * This is taken from:
 * https://github.com/openbsd/src/blob/master/usr.bin/nc/netcat.c
 * Copyright (c) 2001 Eric Jackson <ericj@monkey.org>
 * Copyright (c) 2015 Bob Beck.  All rights reserved.
 */
static int
fdpass(int nfd)
{
    struct msghdr mh;
    union {
        struct cmsghdr hdr;
        char buf[CMSG_SPACE(sizeof(int))];
    } cmsgbuf;
    struct cmsghdr *cmsg;
    struct iovec iov;
    char c = '\0';
    ssize_t r;
    struct pollfd pfd;

    /* Avoid obvious stupidity */
    if (isatty(STDOUT_FILENO)){
        errno = EINVAL;
        clicon_err(OE_UNIX, errno, "isatty");
        return -1;
    }
    memset(&mh, 0, sizeof(mh));
    memset(&cmsgbuf, 0, sizeof(cmsgbuf));
    memset(&iov, 0, sizeof(iov));

    mh.msg_control = (char*)&cmsgbuf.buf;
    mh.msg_controllen = sizeof(cmsgbuf.buf);
    cmsg = CMSG_FIRSTHDR(&mh);
    cmsg->cmsg_len = CMSG_LEN(sizeof(int));
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    *(int *)CMSG_DATA(cmsg) = nfd;

    iov.iov_base = &c;
    iov.iov_len = 1;
    mh.msg_iov = &iov;
    mh.msg_iovlen = 1;

    memset(&pfd, 0, sizeof(pfd));
    pfd.fd = STDOUT_FILENO;
    pfd.events = POLLOUT;
    for (;;) {
        r = sendmsg(STDOUT_FILENO, &mh, 0);
        if (r == -1) {
            if (errno == EAGAIN || errno == EINTR) {
                if (poll(&pfd, 1, -1) == -1){
                    clicon_err(OE_UNIX, errno, "poll");
                    return -1;
                }
                continue;
            }
            clicon_err(OE_UNIX, errno, "sendmsg");
            return -1;
        } else if (r != 1){
            clicon_err(OE_UNIX, errno, "sendmsg: unexpected value");
            return -1;
        }
        else
            break;
    }
    //  exit(0);
    return 0;
}

/*! Create and bind stream socket
 * @param[in]  sa       Socketaddress
 * @param[in]  sa_len   Length of sa. Tecynicaliyu to be independent of sockaddr sa_len
 * @param[in]  backlog  Listen backlog, queie of pending connections
 * @param[out] sock     Server socket (bound for accept)
 */
int
callhome_bind(struct sockaddr *sa,
              size_t           sin_len,             
              int              backlog,
              int             *sock)
{
    int    retval = -1;
    int    s = -1;
    int    on = 1;
    
    if (sock == NULL){
        errno = EINVAL;
        clicon_err(OE_UNIX, errno, "sock");
        goto done;
    }
    /* create inet socket */
    if ((s = socket(sa->sa_family, SOCK_STREAM, 0)) < 0) {
        clicon_err(OE_UNIX, errno, "socket");
        goto done;
    }
    if (setsockopt(s, SOL_SOCKET, SO_KEEPALIVE, (void *)&on, sizeof(on)) == -1) {
        clicon_err(OE_UNIX, errno, "setsockopt SO_KEEPALIVE");
        goto done;
    }
    if (setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (void *)&on, sizeof(on)) == -1) {
        clicon_err(OE_UNIX, errno, "setsockopt SO_REUSEADDR");
        goto done;
    }
    /* only bind ipv6, otherwise it may bind to ipv4 as well which is strange but seems default */
    if (sa->sa_family == AF_INET6 &&
        setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, &on, sizeof(on)) == -1) {
        clicon_err(OE_UNIX, errno, "setsockopt IPPROTO_IPV6");
        goto done;
    }
    if (bind(s, sa, sin_len) == -1) {
        clicon_err(OE_UNIX, errno, "bind");
        goto done;
    }
    if (listen(s, backlog) < 0){
        clicon_err(OE_UNIX, errno, "listen");
        goto done;
    }
    if (sock)
        *sock = s;
    retval = 0;
 done:
    if (retval != 0 && s != -1)
        close(s);
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
            ,
            argv0);
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
    struct sockaddr     from = {0,};
    socklen_t           len;
    size_t              sin_len;
    uint16_t            port = NETCONF_CH_SSH;
    int                 ss = -1; /* server socket */
    int                 s = -1;  /* accepted session socket */

    optind = 1;
    opterr = 0;
    while ((c = getopt(argc, argv, UTIL_OPTS)) != -1)
        switch (c) {
        case 'h':
            usage(argv[0]);
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
    /* Bind port */
    if (callhome_bind(sa, sin_len, 1, &ss) < 0) 
        goto done;
    /* Wait until connect */
    len = sizeof(from);
    if ((s = accept(ss, &from, &len)) < 0){
        clicon_err(OE_UNIX, errno, "accept");
        goto done;
    }
    /* s Pass the first connected socket using sendmsg(2) to stdout and exit. */
    if (fdpass(s) < 0)
        goto done;
    retval = 0;
 done:
    return retval;
}

