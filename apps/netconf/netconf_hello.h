
#ifndef NETCONF_NETCONF_HELLO_H
#define NETCONF_NETCONF_HELLO_H

int netconf_hello_process_client_msg(clicon_handle h, cxobj *xn);
int netconf_hello_server(clicon_handle h, cbuf *cb, uint32_t session_id);
int netconf_hello_check_received();
void netconf_hello_report_received();

#endif //NETCONF_NETCONF_HELLO_H
