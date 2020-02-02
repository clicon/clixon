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
sudo $MAKE install-include
(cd example; $MAKE)
(cd util; $MAKE)
(cd example; sudo $MAKE install)
(cd util; sudo $MAKE install)
