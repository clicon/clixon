#!/usr/bin/env bash
# Parse "all" IEEE yangmodels from https://github.com/YangModels/yang/standard/ietf/RFC
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

if [ ! -d "$YANGMODELS" ]; then
#    err "Hmm Yangmodels dir does not seem to exist, try git clone https://github.com/YangModels/yang?"
    echo "...skipped: YANGMODELS not set"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Experimental IEEE
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ni-ieee1588-ptp:cmlds</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$YANGMODELS/standard/ietf/RFC</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$YANGMODELS/standard/ieee/draft/802.1/Qcr</CLICON_YANG_DIR> 
  <CLICON_YANG_DIR>$YANGMODELS/standard/ieee/draft/802</CLICON_YANG_DIR> 
  <CLICON_YANG_DIR>$YANGMODELS/standard/ieee/published/802.1</CLICON_YANG_DIR> 
  <CLICON_YANG_DIR>$YANGMODELS/standard/ieee/published/802</CLICON_YANG_DIR> 
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

new "yangmodels parse: -f $cfg"


new "yangmodel Experimental IEEE 802.1: $YANGMODELS/experimental/ieee/802.1"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/experimental/ieee/802.1 -p $YANGMODELS/experimental/ieee/1588 show version)" 0 "$version."

new "yangmodel Experimental IEEE 1588: $YANGMODELS/experimental/ieee/1588"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/experimental/ieee/1588 show version)" 0 "$version."

# Standard IEEE
new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/draft/802.1/ABcu"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/draft/802.1/ABcu show version)" 0 "$version."

new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/draft/802.1/Qcr"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/draft/802.1/Qcr show version)" 0 "$version."

new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/draft/802.1/Qcw"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/draft/802.1/Qcw show version)" 0 "$version."

new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/draft/802.1/Qcx"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/draft/802.1/Qcx -p $YANGMODELS/standard/ieee/draft/802.1/ABcu show version)" 0 "$version."

new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/draft/802.1/x"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/draft/802.1/x show version)" 0 "$version."

# Published
new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/published/802.1"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/published/802.1 show version)" 0 "$version."

new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/published/802.3"
expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/published/802.3 show version)" 0 "$version."

rm -rf $dir

