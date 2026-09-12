#!/usr/bin/env bash
# Sanity checks for the TEXT (curly-brace) pretty-printer.
#
# Includes a regression check: a YANG list whose only child is its own key
# leaf (and no other data) must still be printed as a proper multi-line
# block with "{"/"}" and one entry per line, eg:
#   peer a {
#   }
#   peer b {
#   }
#
# Also checks basic leaf-list formatting, eg:
#   tag [
#      x1
#      x2
#   ]
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
clidir=$dir/cli

fyang=$dir/clixon-example.yang

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# "peer" is a list whose only child is its own key leaf and nothing else --
# this is the precise shape that triggers the bug. "tag" is a plain
# leaf-list, checked here as a baseline for comparison.
cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    container peers {
        list peer {
            key name;
            leaf name {
                type string;
            }
        }
        leaf-list tag {
            type string;
        }
    }
}
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

set @datamodel, cli_auto_set();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);{
            text("Show configuration as TEXT"), cli_show_auto_mode("candidate", "text", true, false);
    }
}
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "cli set peer a"
expectpart "$($clixon_cli -1 -f $cfg -l o set peers peer a)" 0 "^$"

new "cli set peer b"
expectpart "$($clixon_cli -1 -f $cfg -l o set peers peer b)" 0 "^$"

new "cli set tag x1"
expectpart "$($clixon_cli -1 -f $cfg -l o set peers tag x1)" 0 "^$"

new "cli set tag x2"
expectpart "$($clixon_cli -1 -f $cfg -l o set peers tag x2)" 0 "^$"

new "cli commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

new "cli show configuration text"
ret=$($clixon_cli -1 -f $cfg -l o show configuration text)
if [ $? -ne 0 ]; then
    err "show configuration text failed" "$ret"
fi

new "check each peer entry starts its own line (not collapsed onto one line)"
nlines=$(echo "$ret" | grep -c '^ *peer ')
if [ "$nlines" -ne 2 ]; then
    err "2 lines starting with 'peer '" "$ret"
fi

new "check no line contains more than one peer entry"
if echo "$ret" | grep -Eq 'peer.*peer'; then
    err "no line with two 'peer' entries" "$ret"
fi

new "check each peer entry opens a brace block"
nbraces=$(echo "$ret" | grep -c '^ *peer .* {$')
if [ "$nbraces" -ne 2 ]; then
    err "2 lines matching 'peer <name> {'" "$ret"
fi

new "check leaf-list opens with tag ["
nopen=$(echo "$ret" | grep -c '^ *tag \[$')
if [ "$nopen" -ne 1 ]; then
    err "1 line matching 'tag ['" "$ret"
fi

new "check leaf-list closes with ]"
nclose=$(echo "$ret" | grep -c '^ *\]$')
if [ "$nclose" -ne 1 ]; then
    err "1 line matching ']'" "$ret"
fi

new "check each leaf-list value on its own line"
if ! echo "$ret" | grep -q '^ *x1$'; then
    err "a line matching 'x1'" "$ret"
fi
if ! echo "$ret" | grep -q '^ *x2$'; then
    err "a line matching 'x2'" "$ret"
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

new "endtest"
endtest
