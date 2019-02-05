#!/bin/sh
# Travis pre-config script.
# Clone and install CLIgen
git clone https://github.com/olofhagsand/cligen.git
(cd cligen && ./configure && make && sudo make install)
./configure && make && sudo make install
sudo /sbin/ldconfig
sudo make install-include
(cd example && make && sudo make install)
sudo groupadd clicon
sudo usermod -a -G clicon $(whoami)
sudo usermod -a -G clicon root
sudo usermod -a -G clicon www-data
