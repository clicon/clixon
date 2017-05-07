#
# ***** BEGIN LICENSE BLOCK *****
# 
# Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren
#
# This file is part of CLIXON
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Alternatively, the contents of this file may be used under the terms of
# the GNU General Public License Version 3 or later (the "GPL"),
# in which case the provisions of the GPL are applicable instead
# of those above. If you wish to allow use of your version of this file only
# under the terms of the GPL, and not to allow others to
# use your version of this file under the terms of Apache License version 2, 
# indicate your decision by deleting the provisions above and replace them with
# the notice and other provisions required by the GPL. If you do not delete
# the provisions above, a recipient may use your version of this file under
# the terms of any one of the Apache License version 2 or the GPL.
#
# ***** END LICENSE BLOCK *****
#

# To rebuild the `configure' script from this, execute the command
# 	autoconf
# in the directory containing this script.
#

AC_INIT(lib/clixon/clixon.h.in)

# Default CFLAGS unless set by environment.
: ${CFLAGS="-O2"}

CLIXON_VERSION_MAJOR="3"
CLIXON_VERSION_MINOR="3"
CLIXON_VERSION_PATCH="0"
CLIXON_VERSION="\"${CLIXON_VERSION_MAJOR}.${CLIXON_VERSION_MINOR}.${CLIXON_VERSION_PATCH}\""
# Fix to specific version (eg 3.5) or head (3) 
CLIGEN_VERSION="3" 

AC_CONFIG_HEADERS([include/clixon_config.h lib/clixon/clixon.h])

AC_DEFINE_UNQUOTED(CLIXON_VERSION_STRING, $CLIXON_VERSION, [Clixon version string])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_MAJOR, $CLIXON_VERSION_MAJOR, [Clixon major release])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_MINOR, $CLIXON_VERSION_MINOR, [Clixon minor release])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_PATCH, $CLIXON_VERSION_PATCH, [Clixon path version])

# clixon versions spread to Makefile's (.so files) and variable in build.c
AC_SUBST(CLIXON_VERSION)
AC_SUBST(CLIXON_VERSION_STRING)
AC_SUBST(CLIXON_VERSION_MAJOR)
AC_SUBST(CLIXON_VERSION_MINOR)
AC_SUBST(CLIGEN_VERSION) # Bind to specific CLIgen version

AC_MSG_RESULT(CLIXON version is ${CLIXON_VERSION}_PRE1)

AC_CANONICAL_TARGET
AC_SUBST(CC)
AC_SUBST(CFLAGS)
AC_SUBST(LDFLAGS)
AC_SUBST(INCLUDES)
AC_SUBST(CPPFLAGS)
AC_SUBST(LIBS)
AC_SUBST(OBJ_SUFFIX)
AC_SUBST(AR_SUFFIX)
AC_SUBST(SH_SUFFIX)
AC_SUBST(EXE_SUFFIX)
AC_SUBST(AR)
AC_SUBST(RANLIB)
AC_SUBST(with_restconf) # If yes, compile apps/restconf
AC_SUBST(with_keyvalue) # If yes, compile datastore/keyvalue

#
AC_PROG_CC()
AC_PROG_CPP

CPPFLAGS="-DHAVE_CONFIG_H ${CPPFLAGS}"

AC_MSG_RESULT(compiler is $CC)	

CFLAGS="${CFLAGS} -Wall" 

AC_MSG_RESULT(CPPFLAGS is $CPPFLAGS)	
AC_MSG_RESULT(CFLAGS is $CFLAGS)	

AC_PROG_YACC
AC_PROG_LEX
if test "$LEX" = ":"; then
   AC_MSG_ERROR(CLIXON does not find lex or flex.)
fi
if test "$YACC" != "bison -y"; then
   AC_MSG_ERROR(CLIXON does not find bison.  There are several problems with yacc and byacc. Please install bison.)
fi

if test "$prefix" = "NONE"; then
     prefix=${ac_default_prefix}
fi

AC_CHECK_LIB(m, main)
EXE_SUFFIX=""
OBJ_SUFFIX=".o"
AR_SUFFIX=".a"
SH_SUFFIX=".so"
AR="ar"

# This is for cligen
AC_ARG_WITH(cligen,  [  --with-cligen=dir       Use CLIGEN here ] )
if test "${with_cligen}"; then
  echo "Using CLIGEN here: ${with_cligen}"
  CPPFLAGS="-I${with_cligen}/include ${CPPFLAGS}"
  LDFLAGS="-L${with_cligen}/lib ${LDFLAGS}"
fi

AC_CHECK_HEADERS(cligen/cligen.h,, AC_MSG_ERROR(cligen missing. Try: git clone https://github.com/olofhagsand/cligen.git))

AC_CHECK_LIB(:libcligen.so.${CLIGEN_VERSION}, cligen_init,, AC_MSG_ERROR([CLIgen${CLIGEN_VERSION} missing. Try: git clone https://github.com/olofhagsand/cligen.git]))

# This is for restconf (and fastcgi)
AC_ARG_WITH([restconf],
            [AS_HELP_STRING([--without-restconf],[disable support for restconf])],
            [],
            [with_restconf=yes])
if test "x${with_restconf}" == xyes; then
   # Lives in libfcgi-dev
   AC_CHECK_LIB(fcgi, FCGX_Init,, AC_MSG_ERROR([libfcgi-dev missing])) 
fi

# This is for keyvalue datastore (and qdbm)
AC_ARG_WITH([keyvalue],
            [AS_HELP_STRING([--without-keyvalue],[disable support for key-value xmldb datastore])],
            [],
            [with_keyvalue=yes])

if test "x${with_keyvalue}" == xyes; then
   echo "yes keyvalue" 
   # This is for qdbm
   AC_ARG_WITH(qdbm,  [  --with-qdbm=dir         Use QDBM here, if keyvalue ] )
   if test "${with_qdbm}"; then
      echo "Using QDBM here: ${with_qdbm}"
      CPPFLAGS="-I${with_qdbm}/include ${CPPFLAGS}"
      LDFLAGS="-L${with_qdbm}/lib ${LDFLAGS}"
   fi
   # Problem: depot.h may be in qdbm/depot.h. 
   AC_CHECK_HEADERS(depot.h,,[AC_CHECK_HEADERS(qdbm/depot.h,,AC_MSG_ERROR(libqdbm-dev required))])
   AC_CHECK_LIB(qdbm, dpopen,, AC_MSG_ERROR(libqdbm-dev required))
fi

AC_CHECK_LIB(crypt, crypt)
AC_CHECK_HEADERS(crypt.h)

# user credentials for unix sockets
AC_CHECK_HEADERS([sys/ucred.h],[],[],
     [[# include <sys/param.h>]]
)

# This is for Linux vlan code
AC_CHECK_HEADERS(linux/if_vlan.h)

AC_CHECK_LIB(socket, socket)
AC_CHECK_LIB(nsl, xdr_char)
AC_CHECK_LIB(dl, dlopen)

AC_CHECK_FUNCS(inet_aton sigaction sigvec strlcpy strsep strndup alphasort versionsort strverscmp)

AH_BOTTOM([#include <clixon_custom.h>])

AC_OUTPUT(Makefile
	  lib/Makefile
	  lib/src/Makefile 
	  lib/clixon/Makefile 
	  apps/Makefile 
	  apps/cli/Makefile 
	  apps/backend/Makefile 
	  apps/netconf/Makefile
	  apps/restconf/Makefile
	  include/Makefile
	  etc/Makefile
	  etc/clixonrc
	  example/Makefile
	  example/docker/Makefile
	  docker/Makefile 
	  docker/cli/Makefile 
	  docker/cli/Dockerfile
	  docker/backend/Makefile 
	  docker/backend/Dockerfile
	  docker/netconf/Makefile 
	  docker/netconf/Dockerfile
	  datastore/Makefile
	  datastore/keyvalue/Makefile
	  datastore/text/Makefile
	  doc/Makefile 
)

