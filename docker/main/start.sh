#!/bin/bash
# ***** BEGIN LICENSE BLOCK *****
# 
# Copyright (C) 2017-2019 Olof Hagsand
# Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC
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

# Usage: ./startup.sh
# Debug: DBG=1 ./startup.sh
# See also cleanup.sh

>&2 echo "Running script: $0"

# Error function
# usage: err $msg
err(){
    echo  "\e[31m\n[Error $1]"
    echo  "\e[0m"
    exit 1
}

# Turn on debug in containers (restconf, backend)
DBG=${DBG:-0}

# Expose other host port than port 80
PORT=${PORT:-80}

# Initial running datastore content (other than empty)
STORE=${STORE:-}

CONFIG0=$(cat <<EOF
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>/usr/local/etc/example.xml</CLICON_CONFIGFILE>
  <CLICON_FEATURE>*:*</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/example/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/example/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/example/example.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/example.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_CLI_GENMODEL_TYPE>VARS</CLICON_CLI_GENMODEL_TYPE>
  <CLICON_XMLDB_DIR>/usr/local/var/example</CLICON_XMLDB_DIR>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_NACM_MODE>disabled</CLICON_NACM_MODE>
</clixon-config>
EOF
)

CONFIG=${CONFIG:-$CONFIG0}

# Start clixon-example backend
>&2 echo -n "Starting Backend..."
sudo docker run -p $PORT:80 --name clixon-system --rm -e DBG=$DBG -e CONFIG="$CONFIG" -e STORE="$STORE" -td clixon/clixon-system || err "Error starting clixon-system"

>&2 echo "clixon-system started"




