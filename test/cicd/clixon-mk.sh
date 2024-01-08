#!/bin/sh
# A top-level maker for clixon
set -eux
if [ $(uname) = "FreeBSD" ]; then
    MAKE=$(which gmake)
else
    MAKE=$(which make)
fi
$MAKE clean
$MAKE -j10
sudo $MAKE install
(cd example; $MAKE)
(cd example; sudo $MAKE install)

