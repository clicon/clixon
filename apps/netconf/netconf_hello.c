#include <cligen/cligen.h>
#include <clixon/clixon.h>
#include <stddef.h>
#include <errno.h>

#include "netconf_hello.h"
#include "netconf_capabilities.h"

#define CLICON_MODULE_SET_ID "CLICON_MODULE_SET_ID"

extern int cc_closed;

/* Hello request received */
static int _netconf_hello_nr = 0;

/*! Report that a netconf hello message has been received.
 */
void netconf_hello_report_received()
{
    _netconf_hello_nr++;
}

/*! Checks if a netconf hello message has been received
 *
 * @retval  1   netconf hello received
 * @retval  0   netconf hello not received
 */
int netconf_hello_check_received()
{
    if (_netconf_hello_nr == 0)
        return 0;

    return 1;
}

static void netconf_hello_add_capability(clicon_handle h, cbuf *cb, char *capability)
{
    cprintf(cb, "<capability>%s</capability>", capability);
    netconf_capabilities_put(h, capability, SERVER);
}

/*! Create Netconf server hello. Single cap and defer individual to querying modules

 * @param[in]  h           Clicon handle
 * @param[in]  cb          Msg buffer
 * @param[in]  session_id  Id of client session
 * Lots of dependencies here. regarding the hello protocol.
 * RFC6241 NETCONF Protocol says: (8.1)
 *    MUST send a <hello> element containing a list of that peer's capabilities
 *    MUST send at least the base NETCONF capability, urn:ietf:params:netconf:base:1.1
 *    MAY include capabilities for previous NETCONF versions
 *    A server MUST include a <session-id>
 *    A client MUST NOT include a <session-id>
 *    A server receiving <session-id> MUST terminate the NETCONF session.
 *    A client not receiving <session-id> MUST terminate w/o sending<close-session>
 * the example shows urn:ietf:params:netconf:capability:startup:1.0

 * RFC5277 NETCONF Event Notifications
 *  urn:ietf:params:netconf:capability:notification:1.0 is advertised during the capability exchange
 *
 * RFC6022 YANG Module for NETCONF Monitoring
 *     MUST advertise the capability URI "urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring"
 * RFC7895 Yang module library defines how to announce module features (not hello capabilities)
 * RFC7950 YANG 1.1 says (5.6.4);
 *    MUST announce the modules it implements by implementing the YANG module
 *    "ietf-yang-library" (RFC7895) and listing all implemented modules in the
 *    "/modules-state/module" list.
 *    MUST advertise urn:ietf:params:netconf:capability:yang-library:1.0?
 *    revision=<date>&module-set-id=<id> in the <hello> message.
 *
 * Question: should the NETCONF in RFC6241 sections 8.2-8.9 be announced both
 * as features and as capabilities in the <hello> message according to RFC6241?
 *   urn:ietf:params:netconf:capability:candidate:1.0 (8.3)
 *   urn:ietf:params:netconf:capability:validate:1.1 (8.6)
 *   urn:ietf:params:netconf:capability:startup:1.0 (8.7)
 *   urn:ietf:params:netconf:capability:xpath:1.0 (8.9)
 *   urn:ietf:params:netconf:capability:notification:1.0 (RFC5277)
 *
 * @note the hello message is created bythe netconf application, not the
 *  backend, and backend may implement more modules - please consider if using
 *  library routines for detecting capabilities here. In contrast, yang module
 * list (RFC7895) is processed by the backend.
 * @note encode bodies, see xml_chardata_encode()
 * @see yang_modules_state_get
 * @see netconf_module_load
 */
int
netconf_hello_server(clicon_handle h,
                     cbuf *cb,
                     uint32_t session_id)
{
    int  returnValue = -1;
    char *module_set_id;
    char *ietf_yang_library_revision;
    char *encstr     = NULL;

    module_set_id = clicon_option_str(h, CLICON_MODULE_SET_ID);

    cprintf(cb, "<hello xmlns=\"%s\" message-id=\"%u\">", NETCONF_BASE_NAMESPACE, 42);
    cprintf(cb, "<capabilities>");

    /* Each peer MUST send at least the base NETCONF capability, "urn:ietf:params:netconf:base:1.1"
       RFC 6241 Sec 8.1 */
    netconf_hello_add_capability(h, cb, NETCONF_BASE_CAPABILITY_1_1);

    /* A peer MAY include capabilities for previous NETCONF versions, to indicate
       that it supports multiple protocol versions. */
    netconf_hello_add_capability(h, cb, NETCONF_BASE_CAPABILITY_1_0);

    /* Check if RFC7895 loaded and revision found */
    ietf_yang_library_revision = yang_modules_revision(h);
    if (ietf_yang_library_revision != NULL) {
        if (xml_chardata_encode(&encstr,
                                "urn:ietf:params:netconf:capability:yang-library:1.0?revision=%s&module-set-id=%s",
                                ietf_yang_library_revision,
                                module_set_id) < 0)
            goto done;

        netconf_hello_add_capability(h, cb, encstr);
    }

    netconf_hello_add_capability(h, cb, "urn:ietf:params:netconf:capability:candidate:1.0");
    netconf_hello_add_capability(h, cb, "urn:ietf:params:netconf:capability:validate:1.1");
    netconf_hello_add_capability(h, cb, "urn:ietf:params:netconf:capability:startup:1.0");
    netconf_hello_add_capability(h, cb, "urn:ietf:params:netconf:capability:xpath:1.0");
    netconf_hello_add_capability(h, cb, "urn:ietf:params:netconf:capability:notification:1.0");

    cprintf(cb, "</capabilities>");

    if (session_id)
        cprintf(cb, "<session-id>%lu</session-id>", (long unsigned int) session_id);

    cprintf(cb, "</hello>");
    cprintf(cb, "]]>]]>");

    netconf_capabilities_lock(h, SERVER);

    returnValue = 0;

    done:
    if (encstr)
        free(encstr);

    return returnValue;
}


/*
 * A server receiving a <hello> message with a <session-id> element MUST
 * terminate the NETCONF session.
 */
int
netconf_hello_process_client_msg(clicon_handle h,
                                 cxobj *xn)
{
    int returnValue = -1;
    int foundBase   = 0;

    cxobj  **vec = NULL;
    size_t veclen;
    cxobj  *x;
    cxobj  *xcap;
    char   *body;

    netconf_hello_report_received();

    if (xml_find_type(xn, NULL, "session-id", CX_ELMNT) != NULL) {
        clicon_err(OE_XML, errno,
                   "Server received hello with session-id from client, terminating (see RFC 6241 Sec 8.1)");
        cc_closed++;
        goto done;
    }
    if (xpath_vec(xn, NULL, "capabilities/capability", &vec, &veclen) < 0)
        goto done;

    /* Each peer MUST send at least the base NETCONF capability, "urn:ietf:params:netconf:base:1.1"*/
    if ((xcap = xml_find_type(xn, NULL, "capabilities", CX_ELMNT)) != NULL) {
        x = NULL;

        while ((x = xml_child_each(xcap, x, CX_ELMNT)) != NULL) {
            if (strcmp(xml_name(x), "capability") != 0)
                continue;

            if ((body = xml_body(x)) == NULL)
                continue;

            netconf_capabilities_put(h, body, CLIENT);

            /* When comparing protocol version capability URIs, only the base part is used, in the
               event any parameters are encoded at the end of the URI string. */
            if (strncmp(body, NETCONF_BASE_CAPABILITY_1_0, strlen(NETCONF_BASE_CAPABILITY_1_0)) == 0) /* RFC 4741 */
                foundBase++;
            else if (strncmp(body, NETCONF_BASE_CAPABILITY_1_1, strlen(NETCONF_BASE_CAPABILITY_1_1)) ==
                     0) /* RFC 6241 */
                foundBase++;
        }
    }

    netconf_capabilities_lock(h, CLIENT);

    if (foundBase == 0) {
        clicon_err(OE_XML, errno,
                   "Server received hello without netconf base capability %s, terminating (see RFC 6241 Sec 8.1",
                   NETCONF_BASE_CAPABILITY_1_1);
        cc_closed++;
        goto done;
    }

    returnValue = 0;

    done:
    if (vec)
        free(vec);

    return returnValue;
}