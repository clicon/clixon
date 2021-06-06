#include <cligen/cligen.h>
#include <clixon/clixon.h>
#include <malloc.h>
#include <string.h>
#include <errno.h>
#include <sys/syslog.h>

#include "netconf_capabilities.h"

#define NETCONF_HASH_CAPABILITIES "netconf_capabilities"

enum netconf_capabilities_state
{
    INITIALIZED,
    LOCKED
};

struct netconf_capabilities
{
    clicon_hash_t *hashTable;
    enum netconf_capabilities_state state;
};

struct netconf_capability_context
{
    struct netconf_capabilities *clientCapabilities;
    struct netconf_capabilities *serverCapabilities;
};

struct netconf_capability
{
    char *name;

    // char * parameters;
};

struct netconf_capability_listitem
{
    struct netconf_capability          *item;
    struct netconf_capability_listitem *next;
};

static int
netconf_capabilities_get_root(clicon_handle ch,
                              struct netconf_capability_context **context)
{
    int           returnValue   = -1;
    size_t        hashValueSize = 0;
    void          *hashValue;
    clicon_hash_t *cliconData   = clicon_data(ch);

    hashValue = clicon_hash_value(cliconData, NETCONF_HASH_CAPABILITIES, &hashValueSize);
    if (hashValue == NULL) {
        goto done;
    }

    *context = *(struct netconf_capability_context **) hashValue;

    returnValue = 0;

    done:
    return returnValue;
}

static int
netconf_capabilities_get_store(clicon_handle ch,
                               enum netconf_capability_store store,
                               struct netconf_capabilities **capabilities)
{
    int                               returnValue = -1;
    struct netconf_capability_context *context;

    if (netconf_capabilities_get_root(ch, &context) < 0)
        goto done;

    switch (store) {
        case CLIENT:
            *capabilities = context->clientCapabilities;
            break;
        case SERVER:
            *capabilities = context->serverCapabilities;
            break;
        default:
            clicon_err(OE_NETCONF, errno, "Invalid capability store %i", store);
            goto done;
    }

    returnValue = 0;

    done:
    return returnValue;
}

/*! Marks the capability table as locked so that no edits can be made
 *
 * @param[in]   ch                 The clicon handle for this session
 * @param[in]   store              Defines which store to lock (either CLIENT or SERVER)
 *
 * @returnval   -1                 Unable to lock capabilities table
 * @returnval   0                  Capabilities table locked successfully

 */
int
netconf_capabilities_lock(clicon_handle ch,
                          enum netconf_capability_store store)
{
    struct netconf_capabilities *capabilities;

    if (netconf_capabilities_get_store(ch, store, &capabilities) < 0) {
        return -1;
    }

    capabilities->state = LOCKED;

    return 0;
}

/*! Initializes the netconf capability hashtable
 *
 * @param       ch      The clicon handle
 * @returnval   0       Hashtable initialized successfully
 * @returnval   -1      Unable to initialize
 * @returnval   -2      Hashtable already initialized
 */
int
netconf_capabilities_init(clicon_handle ch)
{
    void          *hashValue;
    int           returnValue   = -1;
    size_t        hashValueSize = 0;
    clicon_hash_t *cliconData   = clicon_data(ch);

    struct netconf_capability_context *context = NULL;

    hashValue = clicon_hash_value(cliconData, NETCONF_HASH_CAPABILITIES, &hashValueSize);
    if (hashValue != NULL) {
        returnValue = -2;
        goto done;
    }

    context = malloc(sizeof(struct netconf_capability_context));
    context->serverCapabilities            = malloc(sizeof(struct netconf_capabilities));
    context->serverCapabilities->state     = INITIALIZED;
    context->serverCapabilities->hashTable = clicon_hash_init();

    context->clientCapabilities            = malloc(sizeof(struct netconf_capabilities));
    context->clientCapabilities->state     = INITIALIZED;
    context->clientCapabilities->hashTable = clicon_hash_init();

    hashValue = clicon_hash_add(cliconData, NETCONF_HASH_CAPABILITIES, &context,
                                sizeof(struct netconf_capability_context *));
    if (hashValue == NULL) {
        goto done;
    }

    returnValue = 0;

    done:
    return returnValue;
}


/*! Adds a capability to the hashtable
 *
 * @param[in]   ch                 The clicon handle for this session
 * @param       rawCapability      The name of the capability
 * @param       store              Defines if this is a server or client capability
 *
 * @returnval   -1                  Unable to add capability
 * @returnval   0                   Capability added successfully
 */
int netconf_capabilities_put(clicon_handle ch,
                             char *rawCapability,
                             enum netconf_capability_store store)
{
    int                         returnValue = -1;
    struct netconf_capabilities *capabilities;
    struct netconf_capability   *capability;

    if (netconf_capabilities_get_store(ch, store, &capabilities) < 0) {
        goto done;
    }

    if (capabilities->state == LOCKED) {
        clicon_log(LOG_WARNING, "An attempt has been made to add a capability to a locked capability store.");
        goto done;
    }

    capability = malloc(sizeof(struct netconf_capability));
    capability->name = malloc(strlen(rawCapability) + 1);
    strcpy(capability->name, rawCapability);

    clicon_hash_add(capabilities->hashTable, capability->name, capability, sizeof(struct netconf_capability));

    returnValue = 0;

    done:
    return returnValue;
}

/*! Checks if a given capability has been announced by the peer
 *
 * @param[in]   ch                  The clicon handle for this session
 * @param       capabilityName      The name of the capability to check for
 * @param       store               Defined whether to search in the client or server capability list
 *
 * @returnval   -1                  Unable to check capability
 * @returnval   0                   Capability not supported
 * @returnval   1                   Capability supported
 */
int netconf_capabilities_check(clicon_handle ch,
                               char *capabilityName,
                               enum netconf_capability_store store)
{
    struct netconf_capabilities *capabilities;
    size_t                      hashValueSize = 0;
    void                        *hashValue;

    if (netconf_capabilities_get_store(ch, store, &capabilities) < 0) {
        return -1;
    }

    hashValue = clicon_hash_value(capabilities->hashTable, capabilityName, &hashValueSize);
    return (hashValue != NULL);
}

/*! Free the used memory
 *
 * @param[in]   ch  The clicon handle
 * @returnval   -1  Failure
 * @returnval   0   Success
 */
int netconf_capabilities_free(clicon_handle ch)
{
    struct netconf_capability_context *context;
    clicon_hash_t                     *cliconData = clicon_data(ch);

    if (netconf_capabilities_get_root(ch, &context) < 0) {
        return -1;
    }

    clicon_hash_free(context->clientCapabilities->hashTable);
    free(context->clientCapabilities);

    clicon_hash_free(context->serverCapabilities->hashTable);
    free(context->serverCapabilities);

    clicon_hash_del(cliconData, NETCONF_HASH_CAPABILITIES);

    return 0;
}