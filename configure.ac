#
# ***** BEGIN LICENSE BLOCK *****
# 
# Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
# Copyright (C) 2017-2019 Olof Hagsand
# Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC
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
: ${LINKAGE=dynamic}

# where autotool scripts are: install-sh, config.sub, config.guess
AC_CONFIG_AUX_DIR(config-aux)

CLIXON_VERSION_MAJOR="5"
CLIXON_VERSION_MINOR="3"
CLIXON_VERSION_PATCH="0"
CLIXON_VERSION="\"${CLIXON_VERSION_MAJOR}.${CLIXON_VERSION_MINOR}.${CLIXON_VERSION_PATCH}.PRE\""

# Check CLIgen
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

AC_CHECK_LIB(m, main)

# AC_SUBST(var) makes @var@ appear in makefiles.
# clixon versions spread to Makefile's (.so files) and variable in build.c
AC_SUBST(CLIXON_VERSION)
AC_SUBST(CLIXON_VERSION_STRING)
AC_SUBST(CLIXON_VERSION_MAJOR)
AC_SUBST(CLIXON_VERSION_MINOR)
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
AC_SUBST(LINKAGE)
AC_SUBST(with_restconf) # Set to native or fcgi -> compile apps/restconf
AC_SUBST(HAVE_LIBEVHTP,false)   # consider using neutral constant such as with-http1
AC_SUBST(HAVE_LIBNGHTTP2,false) # consider using neutral constant such as with-http2
AC_SUBST(with_libxml2)  
AC_SUBST(enable_optyangs) 
# Home dir for web user, such as nginx fcgi sockets
AC_SUBST(wwwdir,/www-data)

#
AC_PROG_CC()
AC_PROG_CPP
AC_PROG_CXX

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

# Get "bison" from bison -y or other string
if test "$YACC" = "${YACC##bison}" ; then
   AC_MSG_ERROR(CLIXON does not find bison.  There are several problems with yacc and byacc. Please install bison. YACC="$YACC")
fi
# Hardcoded to bison -y, seems to work in all bisons?
YACC="bison -y"

if test "$prefix" = "NONE"; then
     prefix=${ac_default_prefix}
fi

if test "$LINKAGE" = "dynamic" ; then
   SH_SUFFIX=".so"
elif test "$LINKAGE" = "static" ; then
   SH_SUFFIX=".a"
else
   AC_MSG_ERROR([No such linkage: ${LINKAGE}])
fi	

# This is for cligen
AC_ARG_WITH([cligen], AS_HELP_STRING([--with-cligen=dir],[Use CLIGEN installation in this dir]))
if test -n "${CLIGEN_DIR}" -a -d "${CLIGEN_DIR}"; then
        with_cligen=${CLIGEN_DIR}
fi
if test -d "${with_cligen}"; then
  echo "Using CLIGEN here: ${with_cligen}"
  CPPFLAGS="-I${with_cligen}/include ${CPPFLAGS}"
  LDFLAGS="-L${with_cligen}/lib ${LDFLAGS}"
  test -d "$with_cligen" && CLIGEN_PREFIX="$with_cligen"
fi

# Disable/enable standard Yang files.
# If enable - include yang/standard/*.yang in clixon yang files (default)
# If disable - get standard yang files from elsewhere
AC_ARG_ENABLE(optyangs, AS_HELP_STRING([--enable-optyangs],[Include optional yang files for examples and testing in clixon install, default: no]),[
	  if test "$enableval" = no; then
	      enable_optyangs=no
	  else	      
	      enable_optyangs=yes
          fi
        ],
	[ enable_optyangs=no])

AC_MSG_RESULT(optyangs is $enable_optyangs)	

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

AC_CHECK_HEADERS(cligen/cligen.h,, AC_MSG_ERROR([CLIgen missing. Try: git clone https://github.com/clicon/cligen.git]))

AC_CHECK_LIB(cligen, cligen_init,, AC_MSG_ERROR([CLIgen missing. Try: git clone https://github.com/clicon/cligen.git]))

# This is for restconf.  There are three options:
# --without-restconf     No restconf support
# --with-restconf=fcgi   FCGI interface for separate web reverse proxy like nginx
# --with-restconf=native Integration with embedded web server
AC_ARG_WITH([restconf],
	AS_HELP_STRING([--with-restconf=fcgi],[FCGI interface for stand-alone web rev-proxy eg nginx (default)]),
	,
	[with_restconf=fcgi])
# Actions for each specific package
if test "x${with_restconf}" == xfcgi; then
   # Lives in libfcgi-dev
   AC_CHECK_LIB(fcgi, FCGX_Init,, AC_MSG_ERROR([libfcgi-dev missing])) 
   AC_DEFINE(WITH_RESTCONF_FCGI, 1, [Use fcgi restconf mode]) # For c-code that cant use strings
   AC_DEFINE_UNQUOTED(WWWDIR, "$wwwdir", [WWW dir for fcgi stuff / nginx])
elif test "x${with_restconf}" == xnative; then
   AC_CHECK_LIB(ssl, OPENSSL_init_ssl ,, AC_MSG_ERROR([libssl missing]))
   AC_CHECK_LIB(crypto, CRYPTO_new_ex_data, , AC_MSG_ERROR([libcrypto missing])) 
   # Check if evhtp is enabled for http/1
   AC_ARG_ENABLE(evhtp, AS_HELP_STRING([--disable-evhtp],[Disable evhtp for native restconf http/1, default: yes]),[
   	  if test "$enableval" = no; then
	      ac_enable_evhtp=no
	  else	      
	      ac_enable_evhtp=yes
          fi
        ],
	[ ac_enable_evhtp=yes])
   AC_MSG_RESULT(checking evhtp is enabled: $ac_enable_evhtp)
   if test "$ac_enable_evhtp" = "yes"; then
      AC_CHECK_HEADERS(evhtp/evhtp.h,
          [],
      	  AC_MSG_ERROR([evhtp header missing. See https://github.com/clicon/libevhtp]),
	  [AC_INCLUDES_DEFAULT[
	  #define EVHTP_DISABLE_REGEX
	  #define EVHTP_DISABLE_EVTHR
      ]])
      AC_CHECK_LIB(event, event_init,, AC_MSG_ERROR([libevent missing]))
      AC_CHECK_LIB(evhtp, evhtp_new,, AC_MSG_ERROR([libevhtp missing]),[-levent -lssl -lcrypto]) 
      HAVE_LIBEVHTP=true 
   fi		  

   # Check if nghttp2 is enabled for http/2
   AC_ARG_ENABLE(nghttp2, AS_HELP_STRING([--disable-nghttp2],[Disable nghttp2 for native restconf http/2, default: yes]),[
	  if test "$enableval" = no; then
	      ac_enable_nghttp2=no
	  else	      
	      ac_enable_nghttp2=yes
          fi
        ],
	[ ac_enable_nghttp2=yes])
   AC_MSG_RESULT(checking nghttp2 is enabled: $ac_enable_nghttp2)
   if test "$ac_enable_nghttp2" = "yes"; then
      AC_CHECK_HEADERS(nghttp2/nghttp2.h,[], AC_MSG_ERROR([nghttp2 missing]))
      AC_CHECK_LIB(nghttp2, nghttp2_session_server_new,, AC_MSG_ERROR([nghttp2 missing]))
      HAVE_LIBNGHTTP2=true 
   fi    
   AC_DEFINE(WITH_RESTCONF_NATIVE, 1, [Use native restconf mode]) # For c-code that cant use strings
elif test "x${with_restconf}" == xno; then
   # Cant get around "no" as an answer for --without-restconf that is reset here to undefined
   with_restconf=   
else
   AC_MSG_ERROR([No such restconf package: ${with_restconf}])
fi

if test "x${with_restconf}" != "x"; then
   # This is so it appears in config.h
   AC_DEFINE_UNQUOTED(WITH_RESTCONF, ${with_restconf}, [Restconf package])
fi
# These are dummies just to get the help strings right
AC_ARG_WITH([restconf],
	AS_HELP_STRING([--with-restconf=fcgi],[FCGI interface for stand-alone web rev-proxy eg nginx (default)]))
AC_ARG_WITH([restconf],
            AS_HELP_STRING([--with-restconf=native],[Integrate restconf with embedded http server]))
AC_ARG_WITH([restconf],
	    AS_HELP_STRING([--without-restconf],[Disable restconf altogether]))

# Set default config file location
CLIXON_DEFAULT_CONFIG=/usr/local/etc/clixon.xml
AC_ARG_WITH([configfile],
	    [AS_HELP_STRING([--with-configfile=FILE],[Set default path to config file])],
	    [CLIXON_DEFAULT_CONFIG="$withval"],)

AC_CHECK_LIB(socket, socket)
AC_CHECK_LIB(dl, dlopen)

# This is for libxml2 XSD regex engine
# Note this only enables the compiling of the code. In order to actually
# use it you need to set Clixon config option CLICON_YANG_REGEXP to libxml2
AC_ARG_WITH([libxml2],
	[AS_HELP_STRING([--with-libxml2],[Use gnome/libxml2 regex engine])])
if test "${with_libxml2}"; then
   # Find libxml2 lib
   AC_CHECK_LIB(xml2, xmlRegexpCompile,[], AC_MSG_ERROR([libxml2 not found]))
fi 

#
AC_CHECK_FUNCS(inet_aton sigaction sigvec strlcpy strsep strndup alphasort versionsort getpeereid setns getresuid)

# Checks for getsockopt options for getting unix socket peer credentials on
# Linux
AC_TRY_COMPILE([#include <sys/socket.h>], [getsockopt(1, SOL_SOCKET, SO_PEERCRED, 0, 0);], [AC_DEFINE(HAVE_SO_PEERCRED, 1, [Have getsockopt SO_PEERCRED])
AC_MSG_RESULT(Have getsockopt SO_PEERCRED)])

# YANG_INSTALLDIR is where clixon installs the Clixon yang files and mandatory
# standard yang files: the files in in yang/clixon and yang/mandatory
# Each application designer may need to place YANG_INSTALLDIR in their config:
# <CLICON_YANG_DIR>$YANG_INSTALLDIR</CLICON_YANG_DIR>
AC_ARG_WITH(yang-installdir,
            [AS_HELP_STRING([--with-yang-installdir=DIR],[Install Clixon yang files here (default: ${prefix}/share/clixon)])],
	    [YANG_INSTALLDIR="$withval"],
    	    [YANG_INSTALLDIR="${prefix}/share/clixon"]		
	    )
AC_SUBST(YANG_INSTALLDIR)
AC_MSG_RESULT(Clixon yang files are installed in ${YANG_INSTALLDIR})	

# OPT_YANG_INSTALLDIR is where clixon installs standard yang files
# (  the files in in yang/standard)
# that Clixon needs to run (or examples rely on). These may be retreived from
# elsewhere (eg yangmodels repo)
AC_ARG_WITH(opt-yang-installdir,
	    [AS_HELP_STRING([--with-opt-yang-installdir=DIR],[Install optional yang files here (default: ${prefix}/share/clixon)])],
	    [OPT_YANG_INSTALLDIR="$withval"],
    	    [OPT_YANG_INSTALLDIR="${prefix}/share/clixon"]		
	    )
AC_SUBST(OPT_YANG_INSTALLDIR)
AC_MSG_RESULT(Optional yang files are installed in ${OPT_YANG_INSTALLDIR} (if enabled))	

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
	  extras/rpm/Makefile
	  docker/Makefile
  	  docker/main/Makefile
    	  docker/base/Makefile
  	  util/Makefile 
	  yang/Makefile
  	  yang/clixon/Makefile
    	  yang/mandatory/Makefile
  	  yang/optional/Makefile
	  doc/Makefile
	  test/Makefile
  	  test/config.sh
	  test/cicd/Makefile
  	  test/vagrant/Makefile	
)

