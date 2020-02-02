#!/bin/sh
# A top-level configurer for clixon
set -eux
if [ $(uname) = "FreeBSD" ]; then
    ./configure  --with-cligen=/usr/local --with-wwwuser=www --enable-optyangs
else
   ./configure --enable-optyangs
fi
