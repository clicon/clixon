#!/usr/bin/env bash
# Leafref performance test
# Create a yang with:
# - a list and with <perfnr> original values
# - a leaf-list with <perfnr> original values
# - a list of leafrefs accessing the original values
# See https://github.com/clicon/clixon/issues/600
# and LEAFREF_OPTIMIZE
# Baseline perfnr=10.000 without LEAFREF_OPTIMIZE
# leaf-list:      0m21,865s
# list:           1m8,132s
# leaf-list+list: 1m43,632s
# Optimized perfnr=100.000 with LEAFREF_OPTIMIZE
# leaf-list+list: 0m5,892s

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/leafref.yang
file=$dir/myconfig.xml

# Number of list/leaf-list entries in file
: ${perfnr:=10000}

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
</clixon-config>
EOF

cat <<EOF > $fyang
module example {
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;

   container a {
      description "Original values";
      leaf-list b{
         type string;
      }
      list c {
         key d;
         leaf d {
            type string;
         }
      }
   }
   container x {
      description "References";
      leaf-list rb {
         type leafref {
            path "../../a/b";
         }
      }
      leaf-list rd {
         type leafref {
            path "../../a/c/d";
         }
      }
   }
   list ex {
      description
         "Example that breaks bin search detection, list but not look for key";
      key name;
      leaf name {
         type string;
      }
      leaf orig0 {
         type string;
      }
      leaf ref {
         type leafref {
            path ../orig0;
         }
      }
   }
   container ex2{
      leaf orig0 {
         type string;
      }
      leaf ref {
         type leafref {
            path ../orig0;
         }
      }
   }
}
EOF

# Generate xml file containing leafref and original values
# Arguments:
# 1: file
# 2: how many
# 3: generate leafrefs referencing leafs
# 4: generate leafrefs referencing list elements
function generate()
{
    file=$1
    perfnr=$2
    leafref=$3
    list=$4

    cat <<EOF > $file
<${DATASTORE_TOP}>
   <a xmlns="urn:example:clixon">
EOF
    # Original values
    for (( i=0; i<$perfnr; i++ )); do
        if $leafref; then
            echo -n "<b>b$i</b>" >> $file
        fi
        if $list; then
            echo -n "<c><d>d$i</d></c>" >> $file
        fi
    done

    cat <<EOF >> $file
   </a>
   <x xmlns="urn:example:clixon">
EOF

    if $leafref; then
        for (( i=0; i<$perfnr; i++ )); do
            echo -n "<rb>b$i</rb>" >> $file
        done
    fi
    if $list; then
        for (( i=0; i<$perfnr; i++ )); do
            echo -n "<rd>d$i</rd>" >> $file
        done
    fi
    cat <<EOF >> $file
   </x>
</${DATASTORE_TOP}>
EOF
} # generate

new "test params: -s startup -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend  -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "Generate file"
generate $file $perfnr true true

new "Load file"
expectpart "$($clixon_cli -1 -f $cfg load $file)" 0 "^$"

new "Verify"
expectpart "$($clixon_cli -1 -f $cfg show auto a b)" 0 "<b>b$((perfnr - 1))</b>" --not-- "<b>b$perfnr</b>"

new "Validate"
time expectpart "$($clixon_cli -1 -f $cfg validate)" 0 "^$"

# Negative test
new "Add wrong leaf ref"
expectpart "$($clixon_cli -1 -f $cfg set x rb wrong)" 0 "^$"

new "Validate expect fail leaf"
expectpart "$($clixon_cli -1 -f $cfg validate 2>&1)" 255 "Validate failed. Edit and try again or discard changes: application data-missing" "<rb>wrong</rb>: instance-required : ../../a/b"

new "Delete wrong leaf"
expectpart "$($clixon_cli -1 -f $cfg delete x rb wrong)" 0 "^$"

new "Add wrong list leaf ref"
expectpart "$($clixon_cli -1 -f $cfg set x rd error)" 0 "^$"

new "Validate expect fail list"
expectpart "$($clixon_cli -1 -f $cfg validate 2>&1)" 255 "Validate failed. Edit and try again or discard changes: application data-missing" "<rd>error</rd>: instance-required : ../../a/c/d"

new "Delete wrong leaf"
expectpart "$($clixon_cli -1 -f $cfg delete x rd error)" 0 "^$"

new "Discard"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 "^$"

# Cornercase examples that may break cache
new "set orig 42"
expectpart "$($clixon_cli -1 -f $cfg set ex 1 orig0 42)" 0 "^$"

new "set ref 42"
expectpart "$($clixon_cli -1 -f $cfg set ex 1 ref 42)" 0 "^$"

new "Validate ok"
expectpart "$($clixon_cli -1 -f $cfg validate 2>&1)" 0 "^$"

new "Discard"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 "^$"

new "set orig 42"
expectpart "$($clixon_cli -1 -f $cfg set ex2 orig0 42)" 0 "^$"

new "set ref 42"
expectpart "$($clixon_cli -1 -f $cfg set ex2 ref 42)" 0 "^$"

new "Validate ok"
expectpart "$($clixon_cli -1 -f $cfg validate 2>&1)" 0 "^$"

new "Discard"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 "^$"

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

unset perfnr
unset file

new "endtest"
endtest
