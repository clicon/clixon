#!/usr/bin/env bash
# Private candidate performance test
# Reuse generation of test data from test_perf_leafref.sh
# Baseline perfnr=10.000 on Macbook Air M2:
# real	0m2.059s
# user	0m0.001s
# sys	0m0.002s


# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Number of entries in file
: ${perfnr:=10000}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/leafref.yang
file=$dir/myconfig.xml
dbdir=$dir/db
test -d $dbdir || mkdir -p $dbdir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf-private-candidate:private-candidate</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRIVATE_CANDIDATE>true</CLICON_XMLDB_PRIVATE_CANDIDATE>
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

new "Generate file"
generate "$dbdir/startup_db" $perfnr true true

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


new "Spawn expect script to simulate two CLI sessions"
# -d to debug matching info
time sudo expect -f- "$cfg" $(whoami) <<'EOF'

log_user 0
set timeout 5
set CFG [lindex $argv 0]
set USER [lindex $argv 1]

proc cli { session command { reply "" }} {
    send -i $session "$command\n"
    expect {
        -i $session
        -re "$command.*$reply.*\@.*\/> " {puts -nonewline " $expect_out(buffer)"}
	    timeout { puts "\n\ntimeout"; exit 2 }
	    eof { puts "\n\neof"; exit 3 }
    }
}

spawn {*}sudo -u $USER clixon_cli -f $CFG
set session_1 $spawn_id
puts "cli-$session_1 spawned"
# wait for prompt
cli $session_1 ""

spawn {*}sudo -u $USER clixon_cli -f $CFG
set session_2 $spawn_id
puts "cli-$session_2 spawned"
# wait for prompt
cli $session_2 ""

# No conflict
cli $session_1 "set a b \"cli1\""
cli $session_2 "set a b \"cli2\""
cli $session_2 "commit"

# Conflict
cli $session_1 "commit" "Conflict occured"
cli $session_1 "discard"
cli $session_1 "update"
cli $session_1 "set a b \"cli1\""
cli $session_1 "commit"

puts "\nClose sessions"
close $session_1
close $session_2

EOF

if [ $? -ne 0 ]; then
    err1 "Failed: session test using expect"
fi

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
