#
# ***** BEGIN LICENSE BLOCK *****
#
# Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
# Copyright (C) 2017-2019 Olof Hagsand
# Copyright (C) 2020-2023 Olof Hagsand and Rubicon Communications, LLC
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

AC_INIT
AC_CONFIG_SRCDIR([lib/clixon/clixon.h.in])

# Default CFLAGS and INSTALLFLAGS unless set by environment
: ${INSTALLFLAGS="-s"}
: ${LINKAGE=dynamic}

# where autotool scripts are: install-sh, config.sub, config.guess
AC_CONFIG_AUX_DIR(config-aux)

# Use GIT version (what if no git?)
CLIXON_VERSION="$(./scripts/version.sh)"
CLIXON_VERSION2=$(echo ${CLIXON_VERSION} | awk -F- '{print $1}')
CLIXON_VERSION_MAJOR=$(echo ${CLIXON_VERSION2} | awk -F. '{print $1}')
CLIXON_VERSION_MINOR=$(echo ${CLIXON_VERSION2} | awk -F. '{print $2}')
CLIXON_VERSION_PATCH=$(echo ${CLIXON_VERSION2} | awk -F. '{print $3}')

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
   : ${CFLAGS="-g -Wall -Werror"}
   INSTALLFLAGS=""
else
   : ${CFLAGS="-O2 -Wall -Werror"}
fi

AC_CONFIG_HEADERS([include/clixon_config.h lib/clixon/clixon.h])

AC_DEFINE_UNQUOTED(CLIXON_VERSION_MAJOR, $CLIXON_VERSION_MAJOR, [Clixon major release])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_MINOR, $CLIXON_VERSION_MINOR, [Clixon minor release])
AC_DEFINE_UNQUOTED(CLIXON_VERSION_PATCH, $CLIXON_VERSION_PATCH, [Clixon path version])

# defines: target_cpu, target_vendor, and target_os.
AC_CANONICAL_TARGET

# AC_SUBST(var) makes @var@ appear in makefiles.
# Clixon versions is used in Makefile's (.so files) and variable in build.c
AC_SUBST(CLIXON_VERSION)
AC_SUBST(CLIXON_VERSION_MAJOR)
AC_SUBST(CLIXON_VERSION_MINOR)
AC_SUBST(CLIXON_VERSION_PATCH)

AC_MSG_RESULT(CLIXON version is ${CLIXON_VERSION})

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
AC_SUBST(LIBSTATIC_SUFFIX)
AC_SUBST(LINKAGE)
AC_SUBST(with_libcurl)
AC_SUBST(with_restconf)  # Set to native or fcgi -> compile apps/restconf
AC_SUBST(enable_netsnmp) # Enable build of apps/snmp
AC_SUBST(HAVE_LIBNGHTTP2,false) # consider using neutral constant such as with-http2
AC_SUBST(HAVE_HTTP1,false)
AC_SUBST(with_libxml2)
AC_SUBST(LIBXML2_CFLAGS)
AC_SUBST(CLIXON_YANG_PATCH)
# Where Clixon installs its YANG specs
AC_SUBST(YANG_INSTALLDIR)
# Examples require standard IETF YANGs. You need to provide these for example and tests
AC_SUBST(YANG_STANDARD_DIR)
# SNMP tests require generated YANGs from MIBs
AC_SUBST(MIB_GENERATED_YANG_DIR)
# Used in expansion in, e.g., example/main/example.xml.in
AC_SUBST(BINDIR)
AC_SUBST(DATADIR)
AC_SUBST(INCLUDEDIR)
AC_SUBST(LIBDIR)
AC_SUBST(LIBEXECDIR)
AC_SUBST(LOCALSTATEDIR)
AC_SUBST(SBINDIR)
AC_SUBST(SYSCONFDIR)

#
AC_PROG_CC()
AC_PROG_CPP
AC_PROG_CXX

CPPFLAGS="-DHAVE_CONFIG_H ${CPPFLAGS}"

AC_MSG_RESULT(compiler is $CC)

AC_MSG_RESULT(CPPFLAGS is $CPPFLAGS)
AC_MSG_RESULT(CFLAGS is $CFLAGS)
AC_MSG_RESULT(LDFLAGS is $LDFLAGS)
AC_MSG_RESULT(INSTALLFLAGS is $INSTALLFLAGS)

AC_PROG_YACC
AC_PROG_LEX(noyywrap)
if test "$LEX" = ":"; then
   AC_MSG_ERROR(CLIXON does not find lex or flex.)
fi

# SSH binary path for client and test
AC_PATH_PROG(SSH_BIN, ssh)
AC_DEFINE_UNQUOTED(SSH_BIN, "${SSH_BIN}", [SSH binary])

# For cli pipe output functions
AC_PROG_GREP
AC_DEFINE_UNQUOTED(GREP_BIN, "$GREP", [Grep binary])
AC_PATH_PROG(TAIL_BIN, tail)
AC_DEFINE_UNQUOTED(TAIL_BIN, "$TAIL_BIN", [tail binary])
AC_PATH_PROG(WC_BIN, wc)
AC_DEFINE_UNQUOTED(WC_BIN, "$WC_BIN", [wc binary])
AC_PATH_PROG(CAT_BIN, cat)
AC_DEFINE_UNQUOTED(CAT_BIN, "$CAT_BIN", [cat binary])

# Get "bison" from bison -y or other string
if test "$YACC" = "${YACC##bison}" ; then
   AC_MSG_ERROR(CLIXON does not find bison.  There are several problems with yacc and byacc. Please install bison. YACC="$YACC")
fi
# Hardcoded to bison -y, seems to work in all bisons?
YACC="bison -y"

if test "$prefix" = "NONE"; then
     prefix=${ac_default_prefix}
fi

if test "$exec_prefix" = "NONE"; then
     exec_prefix=${prefix}
fi

# Postfix for shared libs
SH_SUFFIX=".so"
# Postfix for static libs
LIBSTATIC_SUFFIX=".a"

# Expand for easy replacement in example/main/example.xml.in
# Special case is $libdir, which is composed from $exec_prefix
BINDIR=`eval echo $bindir`
SBINDIR=`eval echo $sbindir`
SYSCONFDIR=`eval echo $sysconfdir`
DATADIR=`eval echo \`eval echo $datadir\``
INCLUDEDIR=`eval echo $includedir`
LIBDIR=`eval echo \`eval echo $libdir\``
LIBEXECDIR=`eval echo $libexecdir`
LOCALSTATEDIR=`eval echo $localstatedir`

# This is for cligen
AC_ARG_WITH([cligen], [AS_HELP_STRING([--with-cligen=dir], [Use CLIGEN installation in this dir])], [
  CLIGEN_DIR="$withval"
])
AC_SUBST(CLIGEN_DIR)
if test -n "${CLIGEN_DIR}" -a -d "${CLIGEN_DIR}"; then
    echo "Using CLIGEN here: ${CLIGEN_DIR}"
    CPPFLAGS="-I${CLIGEN_DIR}/include ${CPPFLAGS}"
    LDFLAGS="-L${CLIGEN_DIR}/lib ${LDFLAGS}"
fi

# Disable/enable yang patch
AC_ARG_ENABLE(yang-patch, AS_HELP_STRING([--enable-yang-patch],[Enable YANG patch, RFC 8072, default: no]),[
	  if test "$enableval" = no; then
	      enable_yang_patch=no
	  else
	      enable_yang_patch=yes
          fi
        ],
	[ enable_yang_patch=no])

AC_MSG_RESULT(enable-yang-patch is ${enable_yang_patch})
if test "${enable_yang_patch}" = "yes"; then
   CLIXON_YANG_PATCH=1
   AC_DEFINE(CLIXON_YANG_PATCH, 1, [Enable YANG patch, RFC 8072])
fi

# Check curl, needed for tests but not for clixon core
AC_CHECK_HEADERS(curl/curl.h,[])
AC_CHECK_LIB(curl, curl_global_init)

# Experimental: Curl publish notification stream to eg Nginx nchan.
AC_ARG_ENABLE(publish, AS_HELP_STRING([--enable-publish],
	[Enable publish of notification streams using SSE and curl]),[
	  if test "$enableval" = no; then
	      ac_enable_publish=no
	  else
	      ac_enable_publish=yes
          fi
        ],
	[ ac_enable_publish=no])
if test "$ac_enable_publish" = "yes"; then
   if test "x${with_libcurl}" = "xno"; then
      AC_MSG_ERROR([--enable-publish conflicts with --without-libcurl])
   fi
   AC_DEFINE(CLIXON_PUBLISH_STREAMS, 1, [Enable publish of notification streams using SSE and curl])
fi
AC_MSG_RESULT(publish is $ac_enable_publish)

AC_CHECK_HEADERS(cligen/cligen.h,, AC_MSG_ERROR([CLIgen missing. Try: git clone https://github.com/clicon/cligen.git]))

AC_CHECK_LIB(cligen, cligen_init,, AC_MSG_ERROR([CLIgen missing. Try: git clone https://github.com/clicon/cligen.git]))

AC_ARG_WITH([restconf-netns],
	AS_HELP_STRING([--with-restconf-netns=NAMESPACE],[Define default restconf network namespace to NAMESPACE]),
	[restconf_netns="$withval"],
	[restconf_netns="default"])

if test -z "$restconf_netns"; then
   AC_MSG_ERROR([restconf-netns cannot be empty])
fi

AC_DEFINE_UNQUOTED([RESTCONF_NETNS_DEFAULT], "$restconf_netns", [Default restconf network namespace])

# This is for restconf.  There are three options:
# --without-restconf     No restconf support
# --with-restconf=fcgi   FCGI interface for separate web reverse proxy like nginx
# --with-restconf=native Integration with embedded web server (DEFAULT)
AC_ARG_WITH([restconf],
	AS_HELP_STRING([--with-restconf=native],[Integration with embedded web server (DEFAULT)]),
	,
	[with_restconf=native])
AC_MSG_RESULT(restconf mode ${with_restconf})
# Actions for each specific package
if test "x${with_restconf}" = xfcgi; then
   # Lives in libfcgi-dev
   AC_CHECK_LIB(fcgi, FCGX_Init,, AC_MSG_ERROR([libfcgi-dev missing]))
   AC_DEFINE(WITH_RESTCONF_FCGI, 1, [Use fcgi restconf mode]) # For c-code that cant use strings
elif test "x${with_restconf}" = xnative; then
   # Check if http/1 enabled
   AC_ARG_ENABLE(http1, AS_HELP_STRING([--disable-http1],[Disable http1 for native restconf http/1, ie http/2 only]),[
   	  if test "$enableval" = no; then
	      ac_enable_http1=no
	  else
	      ac_enable_http1=yes
          fi
        ],
	[ ac_enable_http1=yes])

   AC_MSG_RESULT(checking http1 is enabled: $ac_enable_http1)
   if test "$ac_enable_http1" = "yes"; then
      AC_DEFINE(HAVE_HTTP1, true, [Set to true to enable Native HTTP/1]) # Must be tree/false (not 0/1) used in shells
      HAVE_HTTP1=true
   fi

   # Check if nghttp2 is enabled for http/2
   AC_ARG_ENABLE(nghttp2, AS_HELP_STRING([--disable-nghttp2],[Disable nghttp2 for native restconf http/2, ie http/1 only]),[
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
elif test "x${with_restconf}" = xno; then
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
	AS_HELP_STRING([--with-restconf=fcgi],[FCGI interface for stand-alone web rev-proxy eg nginx]))
AC_ARG_WITH([restconf],
	    AS_HELP_STRING([--without-restconf],[Disable restconf altogether]))

# This is for net-snmp
AC_ARG_ENABLE(netsnmp, AS_HELP_STRING([--enable-netsnmp],[Enable net-snmp Clixon YANG mapping]),[
   if test "$enableval" = no; then
      enable_netsnmp=no
   else
      enable_netsnmp=yes
   fi
  ],
  [ enable_netsnmp=no])
AC_MSG_RESULT(checking netsnmp is enabled: $enable_netsnmp)

if test "$enable_netsnmp" = "yes"; then
   # All libs are:
   # libnetsnmp, libnetsnmpagent, libnetsnmpmibs, libnetsnmptrapd, libnetsnmphelpers
   AC_CHECK_LIB(netsnmp, init_snmp)
   AC_CHECK_LIB(netsnmpagent, init_agent)
   AC_CHECK_HEADERS(net-snmp/net-snmp-config.h,[], AC_MSG_ERROR([snmp is missing]))

   # MIB_GENERATED_YANG_DIR is where clixon assumes generated YANGs from MIBs are stored
   # This is NOT installed by Clixon and is not needed for core system
   # However, it is required by SNMP tests.
   # To generate: for i in /usr/share/snmp/mibs/*; do smidump -f yang $i > `basename -s .txt $i`.yang; done
   AC_ARG_WITH(mib-generated-yang-dir,
      [AS_HELP_STRING([--with-mib-generated-yang-dir=DIR],[Directory of generated YANG specs (default: $prefix/share/mib-yangs)])],
      [MIB_GENERATED_YANG_DIR="$withval"],
      [MIB_GENERATED_YANG_DIR="${prefix}/share/mib-yangs"]
    )
    AC_MSG_RESULT(Generated YANGs from MIB files are expected to be in ${MIB_GENERATED_YANG_DIR})
fi

# Set default config file location
CLIXON_DEFAULT_CONFIG=${SYSCONFDIR}/clixon.xml
AC_ARG_WITH([configfile],
	    [AS_HELP_STRING([--with-configfile=FILE],[Set default path to config file])],
	    [CLIXON_DEFAULT_CONFIG="$withval"],)

# Default location for config file
AC_DEFINE_UNQUOTED(CLIXON_DEFAULT_CONFIG,"${CLIXON_DEFAULT_CONFIG}",[Location for apps to find default config file])

AC_DEFINE_UNQUOTED(CLIXON_CONFIG_BINDIR, "${BINDIR}", [Pass-through $bindir])
AC_DEFINE_UNQUOTED(CLIXON_CONFIG_LOCALSTATEDIR, "${LOCALSTATEDIR}", [Pass-through $localstatedir])
AC_DEFINE_UNQUOTED(CLIXON_CONFIG_SBINDIR, "${SBINDIR}", [Pass-through $sbindir])
AC_DEFINE_UNQUOTED(CLIXON_CONFIG_SYSCONFDIR, "${SYSCONFDIR}", [Pass-through $sysconfdir])

AC_CHECK_LIB(socket, socket)
AC_CHECK_LIB(dl, dlopen)

# This is for digest / restconf
AC_CHECK_LIB(crypto, CRYPTO_new_ex_data, , AC_MSG_ERROR([libcrypto missing]))
AC_CHECK_LIB(ssl, OPENSSL_init_ssl ,, AC_MSG_ERROR([libssl missing]))

# This is for libxml2 XSD regex engine
# Note this only enables the compiling of the code. In order to actually
# use it you need to set Clixon config option CLICON_YANG_REGEXP to libxml2
AC_ARG_WITH([libxml2],
	[AS_HELP_STRING([--with-libxml2[[=/path/to/xml2-config]]],[Use libxml2 regex engine])])
if test "${with_libxml2}"; then
   # Find libxml2 lib
   if test -x "${with_libxml2}" 2>/dev/null; then
      AC_MSG_CHECKING([for libxml2 header files and libs])
      LIBXML2_CFLAGS="`${with_libxml2} --cflags`"
      LIBS="$LIBS `${with_libxml2} --libs`"
      AC_MSG_RESULT([$LIBXML2_CFLAGS])
   else
      LIBXML2_CFLAGS="-I/usr/include/libxml2"
   fi
   AC_CHECK_LIB(xml2, xmlRegexpCompile,[], AC_MSG_ERROR([libxml2 not found]))
fi

#
AC_CHECK_FUNCS(inet_aton sigvec strlcpy strsep strndup alphasort versionsort getpeereid setns getresuid)

# Check for --without-sigaction parameter
AC_ARG_WITH(
	[sigaction],
	[AS_HELP_STRING([--without-sigaction], [Don't use sigaction])],
	[],
	[with_sigaction=yes]
)

if test "x${with_sigaction}" = "xyes"; then
   AC_CHECK_FUNCS(sigaction)
fi

# Checks for getsockopt options for getting unix socket peer credentials on
# Linux
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <sys/socket.h>]], [[getsockopt(1, SOL_SOCKET, SO_PEERCRED, 0, 0);]])],[AC_DEFINE(HAVE_SO_PEERCRED, 1, [Have getsockopt SO_PEERCRED])
AC_MSG_RESULT(Have getsockopt SO_PEERCRED)],[])

# YANG_INSTALLDIR is where clixon installs the Clixon yang files and mandatory
# standard yang files: the files in in yang/clixon and yang/mandatory
# Each application designer may need to place YANG_INSTALLDIR in their config:
# <CLICON_YANG_DIR>$YANG_INSTALLDIR</CLICON_YANG_DIR>
AC_ARG_WITH(yang-installdir,
            [AS_HELP_STRING([--with-yang-installdir=DIR],[Install Clixon yang files here (default: ${prefix}/share/clixon)])],
	    [YANG_INSTALLDIR="$withval"],
    	    [YANG_INSTALLDIR="${prefix}/share/clixon"]
	    )
AC_MSG_RESULT(Clixon yang files are installed in ${YANG_INSTALLDIR})

# YANG_STANDARD_DIR is where clixon assumes standard IETF are
# This is NOT installed by Clixon and is not needed for core system
# However, it is required by the main example and some of the tests
# You can download them at https://github.com/YangModels/yang
AC_ARG_WITH(yang-standard-dir,
            [AS_HELP_STRING([--with-yang-standard-dir=DIR],[Directory of standard IETF/IEEE YANG specs (default: $prefix/share/yang/standard)])],
	    [YANG_STANDARD_DIR="$withval"],
    	    [YANG_STANDARD_DIR="${prefix}/share/yang/standard"]
	    )
AC_MSG_RESULT(Standard YANG files expected to be in ${YANG_STANDARD_DIR})

# who we run as in our examples and tests
CLICON_USER="clicon"
AC_ARG_WITH([clicon-user], [AS_HELP_STRING([--with-clicon-user=user], [Run as this user in configuration files])], [
  CLICON_USER="$withval"
])
AC_SUBST(CLICON_USER)
if test -n "${CLICON_USER}"; then
    echo "Using CLICON_USER here: ${CLICON_USER}"
fi

CLICON_GROUP="clicon"
AC_ARG_WITH([clicon-group], [AS_HELP_STRING([--with-clicon-group=group], [Run as this group in configuration files])], [
  CLICON_GROUP="$withval"
])
AC_SUBST(CLICON_GROUP)
if test -n "${CLICON_GROUP}"; then
    echo "Using CLICON_GROUP here: ${CLICON_GROUP}"
fi

# Dummy to disable native language support (nls) to remove warnings in buildroot
AC_ARG_ENABLE(nls)

# Check to use freebsd:s qsort_s instead of linux qsort_r
AC_CHECK_FUNCS(qsort_s)

AH_BOTTOM([#include <clixon_custom.h>])

test "x$prefix" = xNONE && prefix=$ac_default_prefix

AC_CONFIG_FILES([Makefile
	  lib/Makefile
	  lib/src/Makefile
	  lib/clixon/Makefile
	  apps/Makefile
	  apps/cli/Makefile
	  apps/backend/Makefile
	  apps/netconf/Makefile
	  apps/restconf/Makefile
  	  apps/snmp/Makefile
	  include/Makefile
	  etc/Makefile
	  etc/clixonrc
	  example/Makefile
  	  example/main/Makefile
    	  example/main/example.xml
	  docker/Makefile
    	  docker/clixon-dev/Makefile
    	  docker/example/Makefile
  	  docker/test/Makefile
	  yang/Makefile
  	  yang/clixon/Makefile
    	  yang/mandatory/Makefile
	  doc/Makefile
	  test/Makefile
  	  test/config.sh
	  test/cicd/Makefile
  	  test/vagrant/Makefile
])
AC_OUTPUT
