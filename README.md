# Clixon

Clixon is an automatic configuration manager where you from a YANG
specification generate interactive CLI, NETCONF, RESTCONF and embedded
databases with transaction support.

Presentations and tutorial is found on the [Clicon project page](http://www.clicon.org)

Table of contents
=================
  * [Table of contents](#table-of-contents)
  * [Installation](#installation)
  * [Documentation](#documentation)
  * [Dependencies](#dependencies)
  * [Licenses](#licenses)
  * [History](#history)
  * [Yang](#yang)

Installation
============
A typical installation is as follows:
```
     configure	       	       # Configure clixon to platform
     make                      # Compile
     sudo make install         # Install libs, binaries, and config-files
     sudo make install-include # Install include files (for compiling)
```
One example applications is provided, a IETF IP YANG datamodel with generated CLI and configuration interface. 

Documentation
=============
- [Frequently asked questions](doc/FAQ.md)
- [XML datastore](datastore/README.md)
- [Netconf support](apps/netconf/README.md)
- [Restconf support](apps/restconf/README.md)
- [Reference manual](http://www.clicon.org/doxygen/index.html) (Better: cd doc; make doc)
- [Routing example](example/README.md)
- [Tests](test/README.md)

Dependencies
============
Clixon is dependend on the following packages
- [CLIgen](http://www.cligen.se) is required for building Clixon. If you need 
to build and install CLIgen: 
```
    git clone https://github.com/olofhagsand/cligen.git
    cd cligen; configure; make; make install
```
- Yacc/bison
- Lex/Flex
- Fcgi (if restconf is enabled)
- Qdbm key-value store (if keyvalue datastore is enabled)

Licenses
========
Clixon is dual license. Either Apache License, Version 2.0 or GNU
General Public License Version 2. You choose.

See [LICENSE.md](LICENSE.md) for license, [CHANGELOG](CHANGELOG.md) for recent changes.

Background
==========

We implemented Clixon since we needed a generic configuration tool in
several projects, including
[KTH](http://www.csc.kth.se/~olofh/10G_OSR). Most of these projects
were for embedded network and measuring-probe devices. We started with
something called Clicon which was based on a key-value specification
and data-store. But as time passed new standards evaolved and we
started adapting it to XML, Yang and netconf. Finally we made Clixon
where the legacy key specification has been replaced completely by
YANG and using XML as configuration data. This means that legacy
Clicon applications do not run on Clixon.

YANG
====

YANG is at the heart of Clixon. RFC 6020 is implemented with some
exceptions as noted below. A Yang specification is used to generated
an interactive CLI client. Clixon also provides a Netconf and Restconf
client based on Yang.

The following features are (not yet) implemented:
- type object-references
- if-feature
- unique
- rpc



