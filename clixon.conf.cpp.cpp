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

#
# CLIXON options - Default values
# The origin of this file is run a _first_ time through a pre-processor at 
# clixon make install time causing autoconf constants (such as "prefix" and 
# "localstatedir") to be replaced with their installed values.
# It should be run a _second_ time as a part of installation of the application,
# in case clixon.mk is included in the application include file, and 
# "$(APPNAME).conf" rule is accessed.
# 
# See clicon_tutorial for more documentation

# Location of configuration-file for default values (this file)
CLICON_CONFIGFILE      sysconfdir/APPNAME.conf

# Location of YANG module and submodule files. 
CLICON_YANG_DIR        prefix/share/APPNAME/yang

# Main yang module or absolute filename. If module then search as follows:
#     <yangdir>/<module>[@<revision>]
# CLICON_YANG_MODULE_MAIN clicon                

# Option used to construct initial yang file:
#     <module>[@<revision>]
CLICON_YANG_MODULE_REVISION

# Location of backend .so plugins
CLICON_BACKEND_DIR     libdir/APPNAME/backend

# Location of netconf (frontend) .so plugins
CLICON_NETCONF_DIR    libdir/APPNAME/netconf 

# Location of restconf (frontend) .so plugins
CLICON_RESTCONF_DIR    libdir/APPNAME/restconf 

# Location of cli frontend .so plugins
CLICON_CLI_DIR        libdir/APPNAME/cli

# Location of frontend .cli cligen spec files
CLICON_CLISPEC_DIR    libdir/APPNAME/clispec

# Enabled uses "startup" configuration on boot
CLICON_USE_STARTUP_CONFIG    0

# Address family for communicating with clixon_backend (UNIX|IPv4|IPv6)
CLICON_SOCK_FAMILY  UNIX

# If family above is AF_UNIX: Unix socket for communicating with clixon_backend
# If family above is AF_INET: IPv4 address
CLICON_SOCK         localstatedir/APPNAME/APPNAME.sock

# Inet socket port for communicating with clixon_backend (only IPv4|IPv6)
CLICON_SOCK_PORT    4535

# Process-id file
CLICON_BACKEND_PIDFILE  localstatedir/APPNAME/APPNAME.pidfile

# Group membership to access clixon_backend unix socket
# CLICON_SOCK_GROUP       clicon

# Set if all configuration changes are committed directly, commit command unnecessary
# CLICON_AUTOCOMMIT       0

# Name of master plugin (both frontend and backend). Master plugin has special 
# callbacks for frontends. See clicon user manual for more info.
# CLICON_MASTER_PLUGIN    master

# Startup CLI mode. This should match the CLICON_MODE in your startup clispec file
# CLICON_CLI_MODE         base

# Generate code for CLI completion of existing db symbols. Add name="myspec" in 
# datamodel spec and reference as @myspec.
# CLICON_CLI_GENMODEL     1

# Generate code for CLI completion of existing db symbols
# CLICON_CLI_GENMODEL_COMPLETION 0

# How to generate and show CLI syntax: VARS|ALL
# CLICON_CLI_GENMODEL_TYPE   VARS

# Directory where "running", "candidate" and "startup" are placed
CLICON_XMLDB_DIR      localstatedir/APPNAME

# XMLDB datastore plugin filename (see datastore/ and clixon_xml_db.[ch])
CLICON_XMLDB_PLUGIN libdir/xmldb/text.so

# Dont include keys in cvec in cli vars callbacks, ie a & k in 'a <b> k <c>' ignored
# CLICON_CLI_VARONLY      1

# Set to 0 if you want CLI to wrap to next line.
# Set to 1 if you  want CLI to scroll sideways when approaching right margin
# CLICON_CLI_LINESCROLLING      1

# FastCGI unix socket. Should be specified in webserver
# Eg in nginx: fastcgi_pass unix:/www-data/clicon_restconf.sock;
CLICON_RESTCONF_PATH /www-data/fastcgi_restconf.sock

