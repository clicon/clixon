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
sudo usermod -a -G clicon www-data
# Build and start the system docker container
(cd docker/system && make docker && ./start.sh)
# Run clixon testcases
(cd docker/system && sudo docker exec -it clixon-system bash -c 'cd /clixon/clixon/test; exec ./all.sh')
