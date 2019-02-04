#!/bin/sh
# Travis pre-config script.
# Clone and install CLIgen
git clone https://github.com/olofhagsand/cligen.git
(cd cligen && ./configure && make && sudo make install)
(./configure && make && sudo make install)
