# Clixon

Clixon is an automatic configuration manager where you from a YANG
specification generate interactive CLI, NETCONF, RESTCONF and embedded
databases with transaction support.

Presentations and tutorial is found on the [CLICON project page](http://www.clicon.org)

## Installation

A typical installation is as follows:

    > configure	       	        # Configure clixon to platform
    > make                      # Compile
    > sudo make install         # Install libs, binaries, and config-files
    > sudo make install-include # Install include files (for compiling)

One example applications is provided, a IETF IP YANG datamodel with generated CLI and configuration interface. 

## More info

- [Datastore](datastore).
- [Restconf](apps/restconf).
- [Netconf](apps/netconf).

## Dependencies

[CLIgen](http://www.cligen.se) is required for building CLIXON. If you need 
to build and install CLIgen: 

    git clone https://github.com/olofhagsand/cligen.git
    cd cligen; configure; make; make install

## Licenses

CLIXON is dual license. Either Apache License, Version 2.0 or GNU
General Public License Version 2. You choose.

See LICENSE.md for license, CHANGELOG for recent changes.

## Related

CLIXON is a fork of CLICON where legacy key specification has been
replaced completely by YANG. This means that legacy CLICON
applications such as CLICON/ROST does not run on CLIXON.

Clixon origins from work at [KTH](http://www.csc.kth.se/~olofh/10G_OSR)



