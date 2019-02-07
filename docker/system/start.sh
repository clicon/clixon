#!/bin/bash
# Build grideye containers, start all containers, setup networking
# Usage: ./startup.sh
# Debug: DBG=1 ./startup.sh
# See also cleanup.sh

>&2 echo "Running script: $0"

# include err(), stat() and other functions
. ./lib.sh

# Turn on debug in containers (restconf, backend)
DBG=${DBG:-1}

CONFIG0=$(cat <<EOF
<config>
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
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_NACM_MODE>disabled</CLICON_NACM_MODE>
</config>
EOF
)

CONFIG=${CONFIG:-$CONFIG0}
STORE=${STORE:-}

# Start clixon-example backend
# -p 4535 to access via cli from host
>&2 echo -n "Starting Backend..."
sudo docker run -p 80:80 --rm -e DBG=$DBG -e CONFIG="$CONFIG" -e STORE="$STORE" -td clixon/clixon-system || err "Error starting clixon-system"

>&2 echo "clixon-system started"

name=clixon/clixon-system
ps=$(sudo docker ps -f ancestor=$name|tail -n +2|grep $name|awk '{print $1}')
echo "sudo docker exec -it $ps clixon_cli # example command"



