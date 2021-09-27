#!/usr/bin/env bash
# Install system test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Eg on FreeBSD use gmake
: ${make:=make}

# Check for soft links for .so files in case of dynamic linkage, but .a files f static linking
if [ ${LINKAGE} = static ]; then
    LIBOPT=-f
else
    LIBOPT=-h
fi

new "Set up installdir $dir"

new "Make DESTDIR install ($dir)"

# Not for static linkage, libcligen.a may be taken from elsewhere
(cd ..; $make DESTDIR=$dir install)
if [ $? -ne 0 ]; then
    err
fi

new "Check installed files /usr"
if [ ! -d $dir/usr ]; then
    err $dir/usr
fi
new "Check installed files clixon-config"
if [ ! -f $dir/usr/local/share/clixon/clixon-config* ]; then
    err $dir/usr/local/share/clixon/clixon-config*
fi
new "Check installed files libclixon${SH_SUFFIX}"
# Check both /usr/local/lib and /usr/lib 
# This is a problem on some platforms that dont have /usr/local/ in LD_LIBRARY_PATH
if [ ! ${LIBOPT} $dir/usr/local/lib/libclixon${SH_SUFFIX} ]; then
    if [ ! ${LIBOPT} $dir/usr/lib/libclixon${SH_SUFFIX} ]; then
	err $dir/usr/local/lib/libclixon${SH_SUFFIX}
    fi
fi
new "Check installed files libclixon_backend${SH_SUFFIX}"
if [ ! ${LIBOPT} $dir/usr/local/lib/libclixon_backend${SH_SUFFIX} ]; then
    if [ ! ${LIBOPT} $dir/usr/lib/libclixon_backend${SH_SUFFIX} ]; then
	err $dir/usr/local/lib/libclixon_backend${SH_SUFFIX}
    fi
fi


new "Make DESTDIR install include"
(cd ..; $make DESTDIR=$dir install-include)
if [ $? -ne 0 ]; then
    err
fi
new "Check installed includes"
if [ ! -f $dir/usr/local/include/clixon/clixon.h ]; then
    err $dir/usr/local/include/clixon/clixon.h
fi
new "Make DESTDIR uninstall"
(cd ..; $make DESTDIR=$dir uninstall)
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

# unset conditional parameters 
unset make

new "endtest"
endtest
