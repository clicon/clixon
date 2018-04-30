# NACM

Clixon includes an experimental NACM implementation according to [RFC8341(NACM)](https://tools.ietf.org/html/rfc8341).

The support is as follows:

* There is a yang config variable `CLICON_NACM_MODE` to set whether NACM is disabled, uses internal(embedded) NACM configuration, or external configuration. (See yang/clixon-config.yang)
* If the mode is internal, NACM configurations is expected to be in the regular configuration, managed by regular candidate/runing/commit procedures. This mode may have some problems with bootstrapping.
* If the mode is `external`, the `CLICON_NACM_FILE` yang config variable contains the name of a separate configuration file containing the NACM configurations. After changes in this file, the backend needs to be restarted.
* The [example](example/README.md) contains a http basic auth and a NACM backend callback for mandatory state variables.
* There are two [tests](test/README.md) using internal and external NACM config
* The backend provides a limited NACM support (when enabled) described below

NACM functionality
==================

NACM is implemented in the backend and a single access check is made
in from_client_msg() when an internal netconf RPC has
just been received and decoded. The code is in nacm_access().

The functionality is as follows:
* Notification is not supported
* Groups are supported
* Rule-lists are supported
* Rules are supported as follows
  * module-name: Only '*' supported
  * access-operations: only '*' and 'exec' supported
  * rpc-name: fully supported (eg edit-config/get-config, etc)
  * action: fully supported (permit/deny)

The tests outlines an example of three groups (taken from the RFC): admin, limited and guest:
* admin: Full access
* limited: Read access (get and get-config)
* guest: No access
