# Clixon

Clixon is a YANG-based configuration manager, with interactive CLI,
NETCONF and RESTCONF interfaces, an embedded database and transaction
support.

  * [Background](#background)
  * [Frequently asked questions](doc/FAQ.md)
  * [Installation](#installation)
  * [Licenses](#licenses)
  * [Support](#support)
  * [Dependencies](#dependencies)
  * [Extending](#extending)
  * [XML and XPATH](#xml)
  * [Yang](#yang)
  * [Netconf](#netconf)
  * [Restconf](#restconf)
  * [Datastore](datastore/README.md)
  * [Authentication](#auth)
  * [NACM Access control](#nacm)
  * [Example](example/)
  * [Changelog](CHANGELOG.md)
  * [Runtime](#runtime)
  * [Clixon project page](http://www.clicon.org)
  * [Tests](test/)
  * [Docker](docker/)
  * [Roadmap](ROADMAP.md)
  * [Reference manual](http://www.clicon.org/doxygen/index.html) (Note: the link may not be up-to-date. It is better to build your own: `cd doc; make doc`)
  
Background
==========

Clixon was implemented to provide an open-source generic configuration
tool. The existing [CLIgen](http://www.cligen.se) tool was for command-lines only, while clixon is a system with configuration database, xml and rest interfaces. Most of the projects using clixon are for embedded network and measuring devices. But Clixon is more generic than that.

Users of clixon currently include:
  * [Netgate](https://www.netgate.com)
  * [CloudMon360](http://cloudmon360.com)
  * [Grideye](http://hagsand.se/grideye)	
  * [Netclean](https://www.netclean.com/solutions/whitebox) # only CLIgen
  * [Prosilient's PTAnalyzer](https://prosilient.com) # only CLIgen

See also [Clicon project page](http://clicon.org).

Clixon runs on Linux, [FreeBSD port](https://www.freshports.org/devel/clixon) and Mac/Apple. CPU architecures include x86_64, i686, ARM32.

Installation
============
A typical installation is as follows:
```
     configure	       	       # Configure clixon to platform
     make                      # Compile
     sudo make install         # Install libs, binaries, and config-files
     sudo make install-include # Install include files (for compiling)
```

One [example application](example/README.md) is provided, a IETF IP YANG datamodel with
generated CLI, Netconf and restconf interface.

Licenses
========
Clixon is open-source and dual licensed. Either Apache License, Version 2.0 or GNU
General Public License Version 2; you choose.

See [LICENSE.md](LICENSE.md) for the license.

Dependencies
============
Clixon depends on the following software packages, which need to exist on the target machine.
- [CLIgen](http://www.cligen.se) If you need to build and install CLIgen: 
```
    git clone https://github.com/olofhagsand/cligen.git
    cd cligen; configure; make; make install
```
- Yacc/bison
- Lex/Flex
- Fcgi (if restconf is enabled)

Support
=======
Clixon interaction is best done posting issues, pull requests, or joining the
[slack channel](https://clixondev.slack.com).
[Slack invite](https://join.slack.com/t/clixondev/shared_invite/enQtMzI3OTM4MzA3Nzk3LTA3NWM4OWYwYWMxZDhiYTNhNjRkNjQ1NWI1Zjk5M2JjMDk4MTUzMTljYTZiYmNhODkwMDI2ZTkyNWU3ZWMyN2U). 

Extending
=========
Clixon provides a core system and can be used as-is using available
Yang specifications.  However, an application very quickly needs to
specialize functions.  Clixon is extended by writing
plugins for cli and backend. Extensions for netconf and restconf
are also available.

Plugins are written in C and easiest is to look at
[example](example/README.md) or consulting the [FAQ](doc/FAQ.md).

XML
===
Clixon has its own implementation of XML and XPATH implementation.

The standards covered include:
- [XML](https://www.w3.org/TR/2008/REC-xml-20081126)
- [Namespaces](https://www.w3.org/TR/2009/REC-xml-names-20091208)
- [XPATH](https://www.w3.org/TR/xpath-10)

Not supported:
- <!DOCTYPE

Yang
====
YANG and XML is at the heart of Clixon.  Yang modules are used as a
specification for handling XML configuration data. The YANG spec is
used to generate an interactive CLI, netconf and restconf clients. It
also manages an XML datastore.

Clixon follows:
- [YANG 1.0 RFC 6020](https://www.rfc-editor.org/rfc/rfc6020.txt)
- [YANG 1.1 RFC 7950](https://www.rfc-editor.org/rfc/rfc7950.txt).
- [RFC 7895: YANG module library](http://www.rfc-base.org/txt/rfc-7895.txt)

However, the following YANG syntax modules are not implemented:
- deviation
- min/max-elements
- unique
- action
- belongs-to

Netconf
=======
Clixon implements the following NETCONF proposals or standards:
- [RFC 6241: NETCONF Configuration Protocol](http://www.rfc-base.org/txt/rfc-6241.txt)
- [RFC 6242: Using the NETCONF Configuration Protocol over Secure Shell (SSH)](http://www.rfc-base.org/txt/rfc-6242.txt)
- [RFC 5277: NETCONF Event Notifications](http://www.rfc-base.org/txt/rfc-5277.txt)
- [RFC 8341: Network Configuration Access Control Model](http://www.rfc-base.org/txt/rfc-8341.txt)

Clixon does not yet support the following netconf features:

- :url capability
- copy-config source config
- edit-config testopts 
- edit-config erropts
- edit-config config-text
- edit-config operation

Restconf
========
Clixon Restconf is a daemon based on FastCGI C-API. Instructions are available to
run with NGINX.
The implementatation is based on [RFC 8040: RESTCONF Protocol](https://tools.ietf.org/html/rfc8040).

The following features are supported:
- OPTIONS, HEAD, GET, POST, PUT, DELETE
- stream notifications (RFC8040 sec 6)
- query parameters start-time and stop-time(RFC8040 section 4.9)

The following features are not implemented:
- PATCH
- query parameters other than start/stop-time.

See [more detailed instructions](apps/restconf/README.md).

Datastore
=========
The Clixon datastore is a stand-alone XML based datastore. The idea is
to be able to use different datastores backends with the same
API.

The datastore is primarily designed to be used by Clixon but can be used
separately.

See [more detailed instructions](datastore/README.md).

Auth
====
Authentication is managed outside Clixon using SSH, SSL, Oauth2, etc.

For CLI, login is typically made via SSH. For netconf, SSH netconf
subsystem can be used. 
  
Restconf however needs credentials.  This is done by writing a credentials callback in a restconf plugin. See:
  * [FAQ](doc/FAQ.md#how-do-i-write-an-authentication-callback).
  * [Example](example/README.md) has an example how to do this with HTTP basic auth.
  * I have done this for another project using Oauth2 or (https://github.com/CESNET/Netopeer2/tree/master/server/configuration)

The clients send the ID of the user using a "username" attribute with
the RPC calls to the backend. Note that the backend trusts the clients
so the clients can in principle fake a username.

NACM
====
Clixon includes an experimental Network Configuration Access Control Model (NACM) according to [RFC8341(NACM)](https://tools.ietf.org/html/rfc8341). It has limited functionality.

The support is as follows:

* There is a yang config variable `CLICON_NACM_MODE` to set whether NACM is disabled, uses internal(embedded) NACM configuration, or external configuration. (See yang/clixon-config.yang)
* If the mode is internal, NACM configurations is expected to be in the regular configuration, managed by regular candidate/runing/commit procedures. This mode may have some problems with bootstrapping.
* If the mode is `external`, the `CLICON_NACM_FILE` yang config variable contains the name of a separate configuration file containing the NACM configurations. After changes in this file, the backend needs to be restarted.
* The [example](example/README.md) contains a http basic auth and a NACM backend callback for mandatory state variables.
* There are two [tests](test/README.md) using internal and external NACM config
* The backend provides a limited NACM support (when enabled) described below

NACM is implemented in the backend and a single access check is made
in `from_client_msg()` when an internal netconf RPC has
just been received and decoded. The code is in `nacm_access()`.

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


Runtime
=======

<img src="doc/clixon_example_sdk.png" alt="clixon sdk" style="width: 180px;"/>

The figure shows the SDK runtime of Clixon.

