#!/bin/bash
# Parse yangmodels from https://github.com/YangModels/yang
# Notes:
# - Env variable YANGMODELS should point to checkout place. (define it in site.sh for example)
# - Only cisco/nx/9.2-2 # Many other versions
# - Only cisco/xe/1631  # Many other versions
# - Only cisco/xr/530   # Many other versions
# - Only juniper/18.2/18.2R/junos # Many other versions and platoforms

# These are the test scripts:
#./experimental/ieee/check.sh
#./standard/ieee/check.sh
#./standard/ietf/check.sh
#./vendor/cisco/xr/check.sh
#./vendor/cisco/check.sh
#./vendor/cisco/xe/check.sh
#./vendor/cisco/nx/check.sh

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Yang specifics: multi-keys and empty type
APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

if [ ! -d "$YANGMODELS" ]; then
#    err "Hmm Yangmodels dir does not seem to exist, try git clone https://github.com/YangModels/yang?"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Experimental IEEE
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$YANGMODELS/standard/ietf/RFC</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$YANGMODELS/standard/ieee/draft/802.1</CLICON_YANG_DIR> 
  <CLICON_YANG_DIR>$YANGMODELS/standard/ieee/draft/802</CLICON_YANG_DIR> 
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL>1</CLICON_CLI_GENMODEL>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

new "yangmodels parse: -f $cfg"

new "yangmodel Experimental IEEE 802.1: $YANGMODELS/experimental/ieee/802.1"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/experimental/ieee/802.1 -p $YANGMODELS/experimental/ieee/1588 show version" 0 "3."

new "yangmodel Experimental IEEE 1588: $YANGMODELS/experimental/ieee/1588"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/experimental/ieee/1588 show version" 0 "3."

# Standard IEEE
new "yangmodel Standard IEEE 802.1: $YANGMODELS/standard/ieee/draft/802.1"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/draft/802.1 show version" 0 "3."

new "yangmodel Standard IEEE 802.3: $YANGMODELS/standard/ieee/draft/802.3"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ieee/draft/802.3 show version" 0 "3."

# Standard IETF
new "yangmodel Standard IETF: $YANGMODELS/standard/ietf/RFC"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/standard/ietf/RFC show version" 0 "3."

# vendor/junos
#junos           : M/MX, T/TX, Some EX platforms, ACX
#junos-es        : SRX, Jseries, LN-*
#junos-ex        : EX series
#junos-qfx       : QFX series
#junos-nfx       : NFX series

# Juniper JunOS. Junos files have 4 lines copyright, then "<space>module" on
# line 5. No sub-modules.
# NOTE: We DISABLE CLI generation, because some juniper are very large.
# and cli generation consumes memory.
# For example (100K lines):
#wc /usr/local/share/yangmodels/vendor/juniper/18.2/18.2R1/junos/conf/junos-conf-system@2018-01-01.yang
#  92853  274279 3228229 /usr/local/share/yangmodels/vendor/juniper/18.2/18.2R1/junos/conf/junos-conf-system@2018-01-01.yan
# But junos-conf-logical-systems@2018-01-01.yang takes longest time

files=$(find $YANGMODELS/vendor/juniper/18.2/18.2R1/junos/conf -name "*.yang")
let i=0;
for f in $files; do
    if [ -n "$(head -5 $f|grep '^ module')" ]; then
	new "$clixon_cli -1f $cfg -o CLICON_YANG_MAIN_FILE=$f -p $YANGMODELS/vendor/juniper/18.2/18.2R1/common -p $YANGMODELS/vendor/juniper/18.2/18.2R1/junos/conf show version"
	expectfn "$clixon_cli -1f $cfg -o CLICON_YANG_MAIN_FILE=$f -p $YANGMODELS/vendor/juniper/18.2/18.2R1/common -p $YANGMODELS/vendor/juniper/18.2/18.2R1/junos/conf -o CLICON_CLI_GENMODEL=0 show version" 0 "3."
	let i++;
	sleep 1
    fi
done

# We skip CISCO because we have errors that vilates the RFC (I think)
# eg: Test 7(7) [yangmodel vendor cisco xr 623: /usr/local/share/yangmodels/vendor/cisco/xr/623]
#  yang_abs_schema_nodeid: Absolute schema nodeid /bgp-rib/afi-safis/afi-safi/ipv4-unicast/loc-rib must have prefix

if false; then
# vendor/cisco/xr
new "yangmodel vendor cisco xr 623: $YANGMODELS/vendor/cisco/xr/623"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/vendor/cisco/xr/623 show version" 0 "3."

new "yangmodel vendor cisco xr 632: $YANGMODELS/vendor/cisco/xr/632"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/vendor/cisco/xr/632 show version" 0 "3."

new "yangmodel vendor cisco xr 623: $YANGMODELS/vendor/cisco/xr/642"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/vendor/cisco/xr/642 show version" 0 "3."

new "yangmodel vendor cisco xr 651: $YANGMODELS/vendor/cisco/xr/651"
expectfn "$clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=$YANGMODELS/vendor/cisco/xr/651 show version" 0 "3."
fi ### cisco

rm -rf $dir

