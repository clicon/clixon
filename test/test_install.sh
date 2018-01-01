#!/bin/bash
# Install test

# include err() and new() functions
. ./lib.sh

DIR=/tmp/clixoninstall

new "Set up installdir $DIR"
rm -rf $DIR
mkdir $DIR

new "Make DESTDIR install"
(cd ..; make DESTDIR=$DIR install)
if [ $? -ne 0 ]; then
    err
fi

new "Check installed files"
if [ ! -d $DIR/usr ]; then
    err $DIR/usr
fi
if [ ! -d $DIR/www-data ]; then
    err $DIR/www-data
fi
if [ ! -f $DIR/usr/local/share/clixon/clixon.mk ]; then
    err $DIR/usr/local/share/clixon/clixon.mk
fi
if [ ! -f $DIR/usr/local/share/clixon/clixon-config* ]; then
    err $DIR/usr/local/share/clixon/clixon-config*
fi
if [ ! -h $DIR/usr/local/lib/libclixon.so ]; then
    err $DIR/usr/local/lib/libclixon.so
fi
if [ ! -h $DIR/usr/local/lib/libclixon_backend.so ]; then
    err $DIR/usr/local/lib/libclixon_backend.so
fi

new "Make DESTDIR install include"
(cd ..; make DESTDIR=$DIR install-include)
if [ $? -ne 0 ]; then
    err
fi
new "Check installed includes"
if [ ! -f $DIR/usr/local/include/clixon/clixon.h ]; then
    err $DIR/usr/local/include/clixon/clixon.h
fi
new "Make DESTDIR uninstall"
(cd ..; make DESTDIR=$DIR uninstall)
if [ $? -ne 0 ]; then
    err
fi

new "Check remaining files"
f=$(find $DIR -type f)
if [ -n "$f" ]; then
    err "$f"
fi

new "Check remaining symlinks"
l=$(find $DIR -type l)
if [ -n "$l" ]; then
    err "$l"
fi
