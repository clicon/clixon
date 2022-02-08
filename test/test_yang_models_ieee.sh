#!/usr/bin/env bash
# Parse "all" IEEE yangmodels from https://github.com/YangModels/yang/standard/ietf/RFC
# Notes:
# - Only a simple smoketest (CLI check) is made, essentially YANG parsing. A full system may not work
# - Env variable YANG_STANDARD_DIR should point to yangmodels/standard
# - Some FEATURES are set to make it work
# - Some DIFFs are necessary in yangmodels
#    - standard/ieee/published/802.3/ieee802-ethernet-pon.yang:
#        -      when "../ompe-mode = olt'";
#        +      when "../ompe-mode = 'olt'";


# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Yang specifics: multi-keys and empty type
APPNAME=example

cfg=$dir/conf_yang.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ni-ieee1588-ptp:cmlds</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ietf/RFC</CLICON_YANG_DIR>
  <!--CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ieee/draft/802.1/Qcr</CLICON_YANG_DIR> 
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ieee/draft/802</CLICON_YANG_DIR--> 
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ieee/published</CLICON_YANG_DIR> 
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

new "yangmodels parse: -f $cfg"

# Publishged IEEE YANGs
# 1906.1 something w spaces
for d in 802 802.1 802.3; do
    new "Published IEEE Yangs: ${YANG_STANDARD_DIR}/ieee/published/$d"
    expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=${YANG_STANDARD_DIR}/ieee/published/$d show version)" 0 "${CLIXON_VERSION}"
done

# Draft IEEE YANGs
for d in 1588 802.1/ABcu 802.1/AEdk  802.1/CBcv  802.1/CBdb  802.1/Qcw 802.1/Qcz 802.1/QRev ; do
    new "Draft IEEE Yangs: ${YANG_STANDARD_DIR}/ieee/draft/$d"
    expectpart "$($clixon_cli -D $DBG -1f $cfg -o CLICON_YANG_MAIN_DIR=${YANG_STANDARD_DIR}/ieee/published/$d show version)" 0 "${CLIXON_VERSION}"
done

rm -rf $dir

new "endtest"
endtest
