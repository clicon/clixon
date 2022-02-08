#!/usr/bin/env bash
# Parse "all" IETF yangmodels from https://github.com/YangModels/yang/standard/ieee and experimental/ieee
# Notes:
# - Only a simple smoketest (CLI check) is made, essentially YANG parsing. A full system may not work
# - Env variable YANG_STANDARD_DIR should point to yangmodels/standard
# - Some FEATURES are set to make it work
# - Some YANGmodels are broken, therefore CLICON_YANG_AUGMENT_ACCEPT_BROKEN is true

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Yang specifics: multi-keys and empty type
APPNAME=example

cfg=$dir/conf_yang.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-alarms:alarm-shelving</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-subscribed-notifications:configured</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-subscribed-notifications:replay</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-access-control-list:match-on-tcp</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-te-topology:template</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-te-topology:te-topology-hierarchy</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-te-types:path-optimization-metric</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ieee/published</CLICON_YANG_DIR> 
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ietf/RFC</CLICON_YANG_DIR>	
  <CLICON_YANG_AUGMENT_ACCEPT_BROKEN>true</CLICON_YANG_AUGMENT_ACCEPT_BROKEN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Standard IETF
files=$(find ${YANG_STANDARD_DIR}/ietf/RFC -name "*.yang")
for f in $files; do
    if [ -n "$(head -1 $f|grep '^module')" ]; then
	# Mask old revision
	if [ $f != ${YANG_STANDARD_DIR}/ietf/RFC/ietf-yang-types@2010-09-24.yang ]; then
	    new "$clixon_cli -D $DBG -1f $cfg -y $f show version"
	    expectpart "$($clixon_cli -D $DBG -1f $cfg -y $f show version)" 0 "${CLIXON_VERSION}"
	fi
    fi
done

rm -rf $dir

new "endtest"
endtest
