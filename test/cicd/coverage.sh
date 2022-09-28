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
./configure LDFLAGS=-coverage LINKAGE=static CFLAGS="-g -Wall -coverage" INSTALLFLAGS="" 

# Build
make clean
# Special rule to include static linked cligen
make CLIGEN_LIB=/usr/local/lib/libcligen.a
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
codecov -t ${CODECOV_TOKEN} -g -f *.gcda -r clicon/clixon.git

# Remove all coverage files (after gcov push)
find . -name "*.gcda" | xargs rm
find . -name "*.gcno" | xargs rm

sleep 1 # ensure OK is last
echo OK
