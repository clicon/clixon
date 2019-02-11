#!/bin/sh
# Travis pre-config script.
# Clone and install CLIgen (needed for clixon configure and make)
git clone https://github.com/olofhagsand/cligen.git
(cd cligen && ./configure && make && sudo make install)
