#!/bin/sh
# A top-level configurer for clixon
set -eux

if [ $# -ne 1 ]; then
    echo "usage: $0 <restconf>"
    echo "      where <restconf> is fcgi or native"
    exit -1
fi
restconf=$1

if [ $(uname) = "FreeBSD" ]; then
    ./configure  --with-cligen=/usr/local --with-restconf=$restconf
else
   ./configure --with-restconf=$restconf
fi
