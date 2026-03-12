#!/usr/bin/env bash

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Which format to use as datastore format internally
: ${format:=xml}

cfg=$dir/conf_yang.xml
fyang=$dir/type.yang

# Generate autocli for these modules
AUTOCLI=$(autocli_config ${APPNAME} kw-nokey false)

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   /* Leaves with bare (unconstrained) integer types */
   leaf myuint8 {
       type uint8;
   }
   leaf myuint16 {
       type uint16;
   }
   leaf myuint32 {
       type uint32;
   }
   leaf myuint64 {
       type uint64;
   }
   leaf myint8 {
       type int8;
   }
   leaf myint16 {
       type int16;
   }
   leaf myint32 {
       type int32;
   }
   leaf myint64 {
       type int64;
   }
   /* Leaves with constrained (range) integer types */
   leaf myruint16 {
       type uint16 {
           range "0..1000";
       }
   }
   leaf myrint32 {
       type int32 {
           range "-100..100";
       }
   }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  ${AUTOCLI}
</clixon-config>
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "test params: -f $cfg"

new "cli uint8 value exceeding type range (300 > 255)"
expectpart "$($clixon_cli -1f $cfg -l o set myuint8 300)" 255 "out of range"

new "cli uint16 value exceeding type range (99999 > 65535)"
expectpart "$($clixon_cli -1f $cfg -l o set myuint16 99999)" 255 "out of range"

new "cli uint32 value exceeding type range (4900000000 > 4294967295)"
expectpart "$($clixon_cli -1f $cfg -l o set myuint32 4900000000)" 255 "out of range"

new "cli int8 value exceeding type range (300 > 127)"
expectpart "$($clixon_cli -1f $cfg -l o set myint8 300)" 255 "out of range"

new "cli int16 value exceeding type range (99999 > 32767)"
expectpart "$($clixon_cli -1f $cfg -l o set myint16 99999)" 255 "out of range"

new "cli int32 value exceeding type range (4900000000 > 2147483647)"
expectpart "$($clixon_cli -1f $cfg -l o set myint32 4900000000)" 255 "out of range"

BIGNUM=99999999999999999999

new "cli uint8 overflow value shows correct range (not uint64 range)"
expectpart "$($clixon_cli -1f $cfg -l o set myuint8 $BIGNUM)" 255 "out of range: 0 - 255" --not-- "18446744073709551615"

new "cli uint16 overflow value shows correct range (not uint64 range)"
expectpart "$($clixon_cli -1f $cfg -l o set myuint16 $BIGNUM)" 255 "out of range: 0 - 65535" --not-- "18446744073709551615"

new "cli uint32 overflow value shows correct range (not uint64 range)"
expectpart "$($clixon_cli -1f $cfg -l o set myuint32 $BIGNUM)" 255 "out of range: 0 - 4294967295" --not-- "18446744073709551615"

new "cli int8 overflow value shows correct range (not uint64 range)"
expectpart "$($clixon_cli -1f $cfg -l o set myint8 $BIGNUM)" 255 "out of range:" "128 - 127" --not-- "18446744073709551615"

new "cli int16 overflow value shows correct range (not uint64 range)"
expectpart "$($clixon_cli -1f $cfg -l o set myint16 $BIGNUM)" 255 "out of range:" "32768 - 32767" --not-- "18446744073709551615"

new "cli int32 overflow value shows correct range (not uint64 range)"
expectpart "$($clixon_cli -1f $cfg -l o set myint32 $BIGNUM)" 255 "out of range:" "2147483648 - 2147483647" --not-- "18446744073709551615"

new "cli int64 overflow value shows correct range (not uint64 range)"
expectpart "$($clixon_cli -1f $cfg -l o set myint64 $BIGNUM)" 255 "out of range:" "9223372036854775808 - 9223372036854775807" --not-- "18446744073709551615"

BIGNEG=-99999999999999999999

new "cli uint8 negative overflow shows correct range"
expectpart "$($clixon_cli -1f $cfg -l o set myuint8 $BIGNEG)" 255 "out of range: 0 - 255"

new "cli uint16 negative overflow shows correct range"
expectpart "$($clixon_cli -1f $cfg -l o set myuint16 $BIGNEG)" 255 "out of range: 0 - 65535"

new "cli uint32 negative overflow shows correct range"
expectpart "$($clixon_cli -1f $cfg -l o set myuint32 $BIGNEG)" 255 "out of range: 0 - 4294967295"

new "cli int8 negative overflow shows correct range"
expectpart "$($clixon_cli -1f $cfg -l o set myint8 $BIGNEG)" 255 "out of range:" "128 - 127"

new "cli int16 negative overflow shows correct range"
expectpart "$($clixon_cli -1f $cfg -l o set myint16 $BIGNEG)" 255 "out of range:" "32768 - 32767"

new "cli int32 negative overflow shows correct range"
expectpart "$($clixon_cli -1f $cfg -l o set myint32 $BIGNEG)" 255 "out of range:" "2147483648 - 2147483647"

new "cli constrained uint16 overflow shows base type range"
expectpart "$($clixon_cli -1f $cfg -l o set myruint16 $BIGNUM)" 255 "out of range: 0 - 65535" --not-- "18446744073709551615"

new "cli constrained int32 overflow shows base type range"
expectpart "$($clixon_cli -1f $cfg -l o set myrint32 $BIGNUM)" 255 "out of range:" "2147483648 - 2147483647" --not-- "18446744073709551615"

new "cli constrained uint16 within type but outside YANG range"
expectpart "$($clixon_cli -1f $cfg -l o set myruint16 2000)" 255 "out of range: 0 - 1000"

new "cli constrained int32 within type but outside YANG range"
expectpart "$($clixon_cli -1f $cfg -l o set myrint32 200)" 255 "out of range:" "100 - 100"

new "cli uint16 moderate overflow error message"
expectpart "$($clixon_cli -1f $cfg -l o set myuint16 99999)" 255 "out of range" "0 - 65535"

new "cli uint16 extreme overflow error message (same range as moderate)"
expectpart "$($clixon_cli -1f $cfg -l o set myuint16 $BIGNUM)" 255 "out of range" "0 - 65535"

new "cli uint8 valid value"
expectpart "$($clixon_cli -1f $cfg -l o set myuint8 200)" 0 ""

new "cli uint16 valid value"
expectpart "$($clixon_cli -1f $cfg -l o set myuint16 60000)" 0 ""

new "cli uint32 valid value"
expectpart "$($clixon_cli -1f $cfg -l o set myuint32 3000000000)" 0 ""

new "cli int8 valid value"
expectpart "$($clixon_cli -1f $cfg -l o set myint8 -100)" 0 ""

new "cli int16 valid value"
expectpart "$($clixon_cli -1f $cfg -l o set myint16 30000)" 0 ""

new "cli int32 valid value"
expectpart "$($clixon_cli -1f $cfg -l o set myint32 2000000000)" 0 ""

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
