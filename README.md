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
  * [Authentication and Authorization](#auth)
  * [Example](example/)
  * [Changelog](CHANGELOG.md)
  * [Runtime](#runtime)
  * [Clixon project page](http://www.clicon.org)
  * [Tests](test/)
  * [Docker](docker/)
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

There is no yum/apt/ostree package for Clixon (please help?)

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
`deviation`, `min/max-elements`, `unique`, and `action`.

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

Restconf
========
Clixon restconf is a daemon based on FASTCGI. Instructions are available to
run with NGINX.
The implementatation is based on [RFC 8040: RESTCONF Protocol](https://tools.ietf.org/html/rfc8040).
The following features are supported:
- OPTIONS, HEAD, GET, POST, PUT, DELETE
- stream notifications

The following are not implemented
- PATCH
- query parameters (section 4.9)

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

There is an ongoing effort to implement authorization for Clixon
according to [RFC8341(NACM)](https://tools.ietf.org/html/rfc8341), at
least a subset of the functionality. See more information here:
[NACM](README_NACM.md).

Runtime
=======

<img src="doc/clixon_example_sdk.png" alt="clixon sdk" style="width: 180px;"/>

The figure shows the SDK runtime of Clixon.

