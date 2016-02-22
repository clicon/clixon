CLIXON
======

CLIXON is an automatic configuration manager where you from a YANG
specification generate interactive CLI, NETCONF and embedded
databases with transaction support.

CLIXON is a fork of CLICON where legacy key specification has been
replaced completely by YANG. This means that legacy CLICON
applications such as CLICON/ROST does not run on CLIXON.

Presentations and tutorial is found on the [CLICON project
page](http://www.clicon.org)

A typical installation is as follows:

    > configure	       	        # Configure clixon to platform
    > make                      # Compile
    > sudo make install         # Install libs, binaries, and config-files
    > sudo make install-include # Install include files (for compiling)

One example applications is provided, the IETF IP YANG datamodel with generated CLI and configuration interface.  It all origins from work at
[KTH](http://www.csc.kth.se/~olofh/10G_OSR)

[CLIgen](http://www.cligen.se) is required for building CLIXON. If you need 
to build and install CLIgen: 

    git clone https://github.com/olofhagsand/cligen.git
    cd cligen; configure; make; make install

CLIXON is covered by GPLv3, and is also available with commercial license.

See COPYING for license, CHANGELOG for recent changes.




