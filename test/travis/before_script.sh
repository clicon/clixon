#!/bin/sh
# Travis pre-config script.
# Clone and install CLIgen (needed for clixon configure and make)
# Note travis builds and installs, then starts a clixon container where all tests are run from.
git clone https://github.com/clicon/cligen.git
(cd cligen && ./configure && make && sudo make install)
