#
# ***** BEGIN LICENSE BLOCK *****
# 
# Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren
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

# Default CFLAGS and INSTALLFLAGS unless set by environment
: ${CFLAGS="-O2 -Wall"}
: ${INSTALLFLAGS="-s"}

CLIXON_VERSION_MAJOR="3"
CLIXON_VERSION_MINOR="10"
CLIXON_VERSION_PATCH="0"
CLIXON_VERSION="\"${CLIXON_VERSION_MAJOR}.${CLIXON_VERSION_MINOR}.${CLIXON_VERSION_PATCH}.PRE\""

# Fix to specific CLIgen version (eg 3.5) or head (3) 
CLIGEN_VERSION="3" 
if test "$prefix" = "NONE"; then
	CLIGEN_PREFIX="$ac_default_prefix"
else
	CLIGEN_PREFIX="$prefix"
fi

AC_CONFIG_HEADERS([include/clixon_config.h lib/clixon/clixon.h])

AC_DEFINE_UNQUOTED(CLIXON_VERSION_STRING, $CLIXON_VERSION, [Clixon version string])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_MAJOR, $CLIXON_VERSION_MAJOR, [Clixon major release])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_MINOR, $CLIXON_VERSION_MINOR, [Clixon minor release])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_PATCH, $CLIXON_VERSION_PATCH, [Clixon path version])


# AC_SUBST(var) makes @var@ appear in makefiles.
# clixon versions spread to Makefile's (.so files) and variable in build.c
AC_SUBST(CLIXON_VERSION)
AC_SUBST(CLIXON_VERSION_STRING)
AC_SUBST(CLIXON_VERSION_MAJOR)
AC_SUBST(CLIXON_VERSION_MINOR)
AC_SUBST(CLIGEN_VERSION) # Bind to specific CLIgen version
AC_SUBST(CLIGEN_PREFIX)

AC_MSG_RESULT(CLIXON version is ${CLIXON_VERSION})

AC_CANONICAL_TARGET

AC_SUBST(CC)
AC_SUBST(CFLAGS)
AC_SUBST(LDFLAGS)
AC_SUBST(INCLUDES)
AC_SUBST(CPPFLAGS)
AC_PROG_INSTALL
AC_SUBST(INSTALL)
AC_SUBST(INSTALL_DATA)
AC_SUBST(INSTALL_PROGRAM)
AC_SUBST(INSTALLFLAGS)
AC_SUBST(CLIXON_DEFAULT_CONFIG)
AC_SUBST(LIBS)
AC_SUBST(SH_SUFFIX)
AC_SUBST(RANLIB)
AC_SUBST(with_restconf) # If yes, compile apps/restconf
AC_SUBST(enable_stdyangs) 
AC_SUBST(wwwdir,/www-data)
AC_SUBST(wwwuser,www-data)
#
AC_PROG_CC()
AC_PROG_CPP

CPPFLAGS="-DHAVE_CONFIG_H ${CPPFLAGS}"

AC_MSG_RESULT(compiler is $CC)	
# Debug flag
AC_ARG_ENABLE(debug, AS_HELP_STRING([--enable-debug],[Build with debug symbols, default: no]),[
	  if test "$enableval" = no; then
	      ac_enable_debug=no
	  else	      
	      ac_enable_debug=yes
          fi
        ],
	[ ac_enable_debug=no])

AC_MSG_RESULT(debug is $ac_enable_debug)	
if test "$ac_enable_debug" = "yes"; then
   CFLAGS="-g -Wall"
   INSTALLFLAGS=""	
fi

AC_MSG_RESULT(CPPFLAGS is $CPPFLAGS)	
AC_MSG_RESULT(CFLAGS is $CFLAGS)
AC_MSG_RESULT(INSTALLFLAGS is $INSTALLFLAGS)	

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
SH_SUFFIX=".so"

# This is for cligen
AC_ARG_WITH(cligen,  [  --with-cligen=dir       Use CLIGEN here ] )
if test "${with_cligen}"; then
  echo "Using CLIGEN here: ${with_cligen}"
  CPPFLAGS="-I${with_cligen}/include ${CPPFLAGS}"
  LDFLAGS="-L${with_cligen}/lib ${LDFLAGS}"
  test -d "$with_cligen" && CLIGEN_PREFIX="$with_cligen"
fi

# Disable/enable standard Yang files.
# If enable - include yang/standard/*.yang in clixon yang files (default)
# If disable - get standard yang files from elsewhere
AC_ARG_ENABLE(stdyangs, AS_HELP_STRING([--disable-stdyangs],[Include standard yang files in clixon install, default: yes]),[
	  if test "$enableval" = no; then
	      enable_stdyangs=no
	  else	      
	      enable_stdyangs=yes
          fi
        ],
	[ enable_stdyangs=yes])

AC_MSG_RESULT(stdyangs is $enable_stdyangs)	

# Experimental: Curl publish notification stream to eg Nginx nchan. 
AC_ARG_ENABLE(publish, AS_HELP_STRING([--enable-publish],[Enable publish of notification streams using SSE and curl]),[
	  if test "$enableval" = no; then
	      ac_enable_publish=no
	  else	      
	      ac_enable_publish=yes
          fi
        ],
	[ ac_enable_publish=no])
AC_MSG_RESULT(publish is $ac_enable_publish)	

if test "$ac_enable_publish" = "yes"; then
   # publish streams uses libcurl
   AC_CHECK_LIB(curl, curl_global_init,, AC_MSG_ERROR([libcurl missing]))
   AC_DEFINE(CLIXON_PUBLISH_STREAMS, 1, [Enable publish of notification streams using SSE and curl])
fi

AC_CHECK_HEADERS(cligen/cligen.h,, AC_MSG_ERROR(cligen missing. Try: git clone https://github.com/olofhagsand/cligen.git))

AC_CHECK_LIB(cligen, cligen_init,, AC_MSG_ERROR([CLIgen${CLIGEN_VERSION} missing. Try: git clone https://github.com/olofhagsand/cligen.git]))

# This is for restconf (and fastcgi)
AC_ARG_WITH([restconf],
            [AS_HELP_STRING([--without-restconf],[disable support for restconf])],
            [],
            [with_restconf=yes])
if test "x${with_restconf}" == xyes; then
   # Lives in libfcgi-dev
   AC_CHECK_LIB(fcgi, FCGX_Init,, AC_MSG_ERROR([libfcgi-dev missing])) 
fi

# This is for changing web user default www-data
AC_ARG_WITH([wwwuser],
            [AS_HELP_STRING([--with-wwwuser=<user>],[Set www user different from www-data])])
if test "${with_wwwuser}"; then
   wwwuser=${with_wwwuser}
fi
echo "wwwuser:$wwwuser"

# Set default config file location
CLIXON_DEFAULT_CONFIG=/usr/local/etc/clixon.xml
AC_ARG_WITH([configfile],
	    [AS_HELP_STRING([--with-configfile=FILE],[set default path to config file])],
	    [CLIXON_DEFAULT_CONFIG="$withval"],)

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

# This is for libxml2 XSD regex engine
# Note this only enables the compiling of the code. In order to actually
# use it you need to set Clixon config option CLICON_YANG_REGEXP to libxml2
AC_ARG_WITH(libxml2,  [  --with-libxml2          use gnome/libxml2 regex engine ] )
if test "${with_libxml2}"; then
   # Find libxml2 lib
   AC_CHECK_LIB(xml2, xmlRegexpCompile,[], AC_MSG_ERROR([libxml2 not found]))
fi 

#
AC_CHECK_FUNCS(inet_aton sigaction sigvec strlcpy strsep strndup alphasort versionsort)

# CLIXON_DATADIR is where clixon installs the "system" yang files in yang/Makfile
# This directory should most probably be included in each application,
# so each application designer may need to place CLIXON_DATADIR in their config
# (last in yang dir list):
# <CLIXON-YANG-DIR>$CLIXON_DATADIR</CLIXON-YANG_DIR>
AC_SUBST(CLIXON_DATADIR)
CLIXON_DATADIR="${prefix}/share/clixon"

# Default location for config file
AC_DEFINE_UNQUOTED(CLIXON_DEFAULT_CONFIG,"${CLIXON_DEFAULT_CONFIG}",[Location for apps to find default config file])

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
  	  example/main/Makefile
	  example/hello/Makefile	
	  extras/rpm/Makefile
	  docker/Makefile
  	  docker/main/Makefile
    	  docker/base/Makefile
  	  util/Makefile 
	  yang/Makefile
  	  yang/clixon/Makefile
  	  yang/standard/Makefile
	  doc/Makefile
	  test/Makefile	
)

