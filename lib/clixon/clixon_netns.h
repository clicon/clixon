/*! Network namespace code
 *
 * @thanks Anders Franzén, especially get_sock() and send_sock() functions
*/

#ifndef _CLIXON_NETNS_H_
#define _CLIXON_NETNS_H_

/*
 * Prototypes
 */
int clixon_netns_socket(const char *netns, struct sockaddr *sa, size_t sin_len, int backlog, int flags, const char *addrstr, int *sock);

#endif  /* _CLIXON_NETNS_H_ */
