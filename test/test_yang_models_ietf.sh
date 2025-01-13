#!/usr/bin/env bash
# Parse "all" IETF yangmodels from https://github.com/YangModels/yang/standard/ietf
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
  <!-- The following are errors in ietf-l3vpn-ntw@2022-02-14.yang -->
  <CLICON_FEATURE>ietf-vpn-common:vxlan</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-vpn-common:rtg-isis</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-vpn-common:bfd</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-vpn-common:qos</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-vpn-common:multicast</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-vpn-common:igmp</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-vpn-common:mld</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-tcg-algs:tpm12</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-tcg-algs:tpm20</CLICON_FEATURE>

  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/iana</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ietf/RFC</CLICON_YANG_DIR>
  <!-- order is significant, ieee has duplicate of ietf-interfaces.yang -->
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/ieee/published</CLICON_YANG_DIR> 
  <CLICON_YANG_AUGMENT_ACCEPT_BROKEN>true</CLICON_YANG_AUGMENT_ACCEPT_BROKEN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Standard IETF
files=$(find ${YANG_STANDARD_DIR}/ietf/RFC -type f -name "*.yang")
for f in $files; do
    if [ -n "$(head -1 $f|grep '^module')" ]; then
        # Mask old revision
        if [ $f = ${YANG_STANDARD_DIR}/ietf/RFC/ietf-yang-types@2010-09-24.yang ]; then
            continue;
        fi
        new "$clixon_cli -D $DBG -1f $cfg -y $f show version"
        expectpart "$($clixon_cli -D $DBG -1f $cfg -y $f show version)" 0 "${CLIXON_VERSION}"
    fi
done

rm -rf $dir

new "endtest"
endtest
