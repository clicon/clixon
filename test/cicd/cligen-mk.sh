#!/bin/sh
# A top-level maker for cligen
set -eux
if [ $(uname) = "FreeBSD" ]; then
    MAKE=$(which gmake)
else
    MAKE=$(which make)
fi
$MAKE clean
$MAKE -j10
sudo $MAKE install
