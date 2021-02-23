#!/usr/bin/env bash
# Parse "all" IETF yangmodels from https://github.com/YangModels/yang/standard/ieee and experimental/ieee
# Notes:
# - Only a simple smoketest (CLI check) is made, A full system may not work
# - Env variable YANGMODELS should point to checkout place. (define it in site.sh for example)
# - Some FEATURES are set to make it work
# - Some DIFFs are necessary in yangmodels (see end of script)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Yang specifics: multi-keys and empty type
APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

YANGMODELS=/home/olof/tmp/yang
if [ ! -d "$YANGMODELS" ]; then
#    err "Hmm Yangmodels dir does not seem to exist, try git clone https://github.com/YangModels/yang?"
    echo "...skipped: YANGMODELS not set"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-alarms:alarm-shelving</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-subscribed-notifications:configured</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-subscribed-notifications:replay</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-access-control-list:match-on-tcp</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$YANGMODELS/standard/ieee/published/802.1</CLICON_YANG_DIR> 
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Standard IETF
new "yangmodel Standard IETF: $YANGMODELS/standard/ietf/RFC"
echo "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ietf/RFC show version"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ietf/RFC show version)" 0 "$version."

rm -rf $dir
