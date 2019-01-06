#!/bin/bash
# Parse yang openconfig tests
# Note that the openconfig test suites are patched to counter CLixon issues as follows:
# - release/models/mpls/openconfig-mpls-te.yang
#      issue: https://github.com/clicon/clixon/issues/60
# - release/models/wifi/types/openconfig-wifi-types.yang
#      issue: https://github.com/clicon/clixon/issues/59
# 

# Yang specifics: multi-keys and empty type
APPNAME=example

# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

new "openconfig"
if [ ! -d "$OPENCONFIG" ]; then
    err "Hmm Openconfig dir does not seem to exist, try git clone https://github.com/openconfig/public?"
fi

OCDIR=$OPENCONFIG/release/models


cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$OCDIR</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/acl</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/aft</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/bfd</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/bgp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/catalog</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/interfaces</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/isis</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/lacp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/lldp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/local-routing</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/mpls</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/multicast</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/network-instance</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/openflow</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/optical-transport</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/ospf</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/platform</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/policy</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/policy-forwarding</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/probes</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/qos</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/relay-agent</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/rib</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/segment-routing</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/stp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/system</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/telemetry</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/types</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/vlan</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/access-points</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/ap-manager</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/mac</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/phy</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/types</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$APPNAME</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</config>
EOF

files=$(find $OPENCONFIG -name "*.yang")
# Count nr of modules (exclude submodule) Assume "module" or "submodule"
# first word on first line
let ms=0; # Nr of modules
let ss=0; # Nr of smodules
for f in $files; do
    let m=0; # Nr of modules
    let s=0; # Nr of modules
    if [ -n "$(head -15 $f|grep '^[ ]*module')" ]; then
	let m++;
	let ms++;
    elif [ -n "$(head -15 $f|grep '^[ ]*submodule')" ]; then
	let s++;
	let ss++;
    else
	echo "No module or submodule found $f"
	exit
    fi
    if [ $m -eq 1 -a $s -eq 1 ]; then
	echo "Double match $f"
	exit
    fi
done
echo "m:$ms s:$ss"
new "Openconfig test: $clixon_cli -1f $cfg -y $f show version ($m modules)"
for f in $files; do
    if [ -n "$(head -1 $f|grep '^module')" ]; then
	new "$clixon_cli -1f $cfg -y $f show version"
	expectfn "$clixon_cli -1f $cfg -y $f show version" 0 "3."
    fi

done

rm -rf $dir

