#!/usr/bin/env bash
# Test -C config dump 
# Check config file value, overwrite with -o, overwrite with -E configdir
# Format xml/json/text
# cli, backend, netconf, restconf

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
cfdir=$dir/conf.d
test -d $cfdir || mkdir $cfdir
fyang=$dir/example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$cfdir</CLICON_CONFIGDIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_SET_ID>0</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>orig</CLICON_FEATURE>
  <autocli>
    <module-default>false</module-default>
     <list-keyword-default>kw-nokey</list-keyword-default>
  </autocli>
</clixon-config>
EOF

cat <<EOF > $cfdir/extra
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>extradir</CLICON_FEATURE>
</clixon-config>
EOF

cat <<EOF > $dir/ex.cli
# Clixon example specification
CLICON_MODE="base";
EOF

cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  container table{
  }
}
EOF

if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi


# Extra cmdline opts, first is overwritten, second appended
CMDOPTS='-o CLICON_MODULE_SET=42 -o CLICON_FEATURE="cmdline"'

new "cli xml"
expectpart "$($clixon_cli -1 -f $cfg -C xml -o CLICON_MODULE_SET=42 -o CLICON_FEATURE="cmdline")" 0 '^<clixon-config xmlns="http://clicon.org/config">' "<CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>" "<CLICON_MODULE_SET_ID>0</CLICON_MODULE_SET_ID>" "<autocli>" "<list-keyword-default>kw-nokey</list-keyword-default>" "<CLICON_FEATURE>orig</CLICON_FEATURE>" "<CLICON_FEATURE>cmdline</CLICON_FEATURE>" "<CLICON_FEATURE>extradir</CLICON_FEATURE>" --not-- "<CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>"

new "backend xml"
expectpart "$($clixon_backend -1 -f $cfg -s none -C xml -o CLICON_MODULE_SET=42 -o CLICON_FEATURE="cmdline")" 0 '^<clixon-config xmlns="http://clicon.org/config">' "<CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>" "<CLICON_MODULE_SET_ID>0</CLICON_MODULE_SET_ID>" "<autocli>" "<list-keyword-default>kw-nokey</list-keyword-default>" "<CLICON_FEATURE>orig</CLICON_FEATURE>" "<CLICON_FEATURE>cmdline</CLICON_FEATURE>" "<CLICON_FEATURE>extradir</CLICON_FEATURE>" --not-- "<CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>"

new "netconf xml"
expectpart "$($clixon_netconf -q -f $cfg -C xml -o CLICON_MODULE_SET=42 -o CLICON_FEATURE="cmdline")" 0 '^<clixon-config xmlns="http://clicon.org/config">' "<CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>" "<CLICON_MODULE_SET_ID>0</CLICON_MODULE_SET_ID>" "<autocli>" "<list-keyword-default>kw-nokey</list-keyword-default>" "<CLICON_FEATURE>orig</CLICON_FEATURE>" "<CLICON_FEATURE>cmdline</CLICON_FEATURE>" "<CLICON_FEATURE>extradir</CLICON_FEATURE>" --not-- "<CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>"

new "restconf xml"
expectpart "$($clixon_restconf -f $cfg -C xml -o CLICON_MODULE_SET=42 -o CLICON_FEATURE="cmdline")" 0 '^<clixon-config xmlns="http://clicon.org/config">' "<CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>" "<CLICON_MODULE_SET_ID>0</CLICON_MODULE_SET_ID>" "<autocli>" "<list-keyword-default>kw-nokey</list-keyword-default>" "<CLICON_FEATURE>orig</CLICON_FEATURE>" "<CLICON_FEATURE>cmdline</CLICON_FEATURE>" "<CLICON_FEATURE>extradir</CLICON_FEATURE>" --not-- "<CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>"

new "cli json"
expectpart "$($clixon_cli -1 -f $cfg -C json -o CLICON_MODULE_SET=42 -o CLICON_FEATURE="cmdline")" 0 '"clixon-config:clixon-config": {' "\"CLICON_YANG_MAIN_DIR\": \"$dir\","

new "cli text"
expectpart "$($clixon_cli -1 -f $cfg -C text -o CLICON_MODULE_SET=42 -o CLICON_FEATURE="cmdline")" 0 '^clixon-config:clixon-config {' 'list-keyword-default kw-nokey;' 'CLICON_FEATURE \[' 'extradir' 'orig' 'cmdline'

rm -rf $dir

new "endtest"
endtest
