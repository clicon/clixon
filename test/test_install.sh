#!/bin/bash
# Install system test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

new "Set up installdir $dir"

new "Make DESTDIR install"
(cd ..; make DESTDIR=$dir install)
if [ $? -ne 0 ]; then
    err
fi
new "Check installed files /usr"
if [ ! -d $dir/usr ]; then
    err $dir/usr
fi
new "Check installed files /www-data"
if [ ! -d $dir/www-data ]; then
    err $dir/www-data
fi
new "Check installed files clixon-config"
if [ ! -f $dir/usr/local/share/clixon/clixon-config* ]; then
    err $dir/usr/local/share/clixon/clixon-config*
fi
new "Check installed files libclixon.so"
if [ ! -h $dir/usr/local/lib/libclixon.so ]; then
    err $dir/usr/local/lib/libclixon.so
fi
new "Check installed files libclixon_backend.so"
if [ ! -h $dir/usr/local/lib/libclixon_backend.so ]; then
    err $dir/usr/local/lib/libclixon_backend.so
fi

new "Make DESTDIR install include"
(cd ..; make DESTDIR=$dir install-include)
if [ $? -ne 0 ]; then
    err
fi
new "Check installed includes"
if [ ! -f $dir/usr/local/include/clixon/clixon.h ]; then
    err $dir/usr/local/include/clixon/clixon.h
fi
new "Make DESTDIR uninstall"
(cd ..; make DESTDIR=$dir uninstall)
if [ $? -ne 0 ]; then
    err
fi

new "Check remaining files"
f=$(find $dir -type f)
if [ -n "$f" ]; then
    err "$f"
fi

new "Check remaining symlinks"
l=$(find $dir -type l)
if [ -n "$l" ]; then
    err "$l"
fi

rm -rf $dir
