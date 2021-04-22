#!/bin/sh
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
LDFLAGS=-coverage CFLAGS="-O2 -Wall -coverage" ./configure --with-restconf=native

# Build
sh ./test/cicd/clixon-mk.sh

# Kludge to run restconf as root, and touch all gcda files, cant do as wwwuser
(cd test; clixon_restconf="/www-data/clixon_restconf -r" ./test_api.sh)
find . -name "*.gcda" | xargs sudo chmod 777
# Run all tests
(cd test; ./sum.sh)

#GITHUB_SHA=
# Push upstream
# The -f dont seem to work
bash <(curl -s https://codecov.io/bash) -t ${TOKEN}

