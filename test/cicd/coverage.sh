#!/usr/bin/env bash
# Run coverage using codecov
# Assume pwd is in top-level srcdir

set -eux

if [ $# -ne 1 ]; then 
    echo "usage: $0 <token>"
    exit -1
fi

TOKEN=$1

# LINKAGE=static
# Configure (clixon)
#CFLAGS="-g -Wall" INSTALLFLAGS="" ./configure
#sudo ldconfig
LDFLAGS=-coverage LINKAGE=static CFLAGS="-g -Wall -coverage" INSTALLFLAGS="" ./configure

# Build
make clean
make -j10
sudo make install
sudo make install-include
(cd example; make)
(cd util; make)
(cd example; sudo make install)
(cd util; sudo make install)

# Kludge for netconf to touch all gcda files as root
(cd test; sudo ./test_netconf_hello.sh) || true
find . -name "*.gcda" | xargs sudo chmod 777

# Run restconf as root
(cd test; clixon_restconf="clixon_restconf -r" ./sum.sh)

# Push coverage
bash <(curl -s https://codecov.io/bash) -t ${TOKEN}

# Remove all coverage files (after gcov push)
find . -name "*.gcda" | xargs rm
find . -name "*.gcno" | xargs rm

sleep 1 # ensure OK is last
echo OK
