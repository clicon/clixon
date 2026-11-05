#!/usr/bin/env bash
# CLI -e option: exit with error on first failed command read from stdin or file (-F)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
clidir=$dir/cli
fyang=$dir/clixon-example.yang
fcmd=$dir/cmd.cli

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $(autocli_config clixon-example kw-nokey false)
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
                must "not(. = 'bad')";
            }
        }
    }
}
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="$APPNAME";
CLICON_PROMPT="%U@%H %W> ";
set @datamodel, cli_auto_set();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
discard("Discard edits"), discard_changes();
show("Show") configuration("Show running"), cli_show_auto_mode("running", "text", true, false);
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

cat <<EOF > $fcmd
nosuchcommand
set table parameter nobreak value 1
commit
EOF

new "syntax error without -e: continue and return ok"
expectpart "$($clixon_cli -f $cfg -F $fcmd 2>&1)" 0 "Unknown command"

new "syntax error without -e: later commit applied"
expectpart "$($clixon_cli -1 -f $cfg show configuration)" 0 "parameter nobreak"

cat <<EOF > $fcmd
nosuchcommand
set table parameter syntaxfile value 1
commit
EOF

new "-e -F syntax error: return error"
expectpart "$($clixon_cli -e -f $cfg -F $fcmd 2>&1)" 255 "Unknown command"

new "-e -F syntax error: later commit not applied"
expectpart "$($clixon_cli -1 -f $cfg show configuration)" 0 --not-- "parameter syntaxfile"

new "-e stdin syntax error: return error"
expectpart "$($clixon_cli -e -f $cfg < $fcmd 2>&1)" 255 "Unknown command"

new "-e stdin syntax error: later commit not applied"
expectpart "$($clixon_cli -1 -f $cfg show configuration)" 0 --not-- "parameter syntaxfile"

cat <<EOF > $fcmd
set table parameter failvalidate value bad
validate
discard
set table parameter aftervalidate value 1
commit
EOF

new "-e -F failed validate: return error"
expectpart "$($clixon_cli -e -f $cfg -F $fcmd 2>&1)" 255 "Validate failed"

new "-e -F failed validate: discard and later commit not run"
expectpart "$($clixon_cli -1 -f $cfg show configuration)" 0 --not-- "parameter aftervalidate" "parameter failvalidate"

new "discard failed validate"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 "^$"

cat <<EOF > $fcmd
set table parameter failcommit value bad
commit
discard
set table parameter aftercommit value 1
commit
EOF

new "-e -F failed commit: return error"
expectpart "$($clixon_cli -e -f $cfg -F $fcmd 2>&1)" 255 "Commit failed"

new "-e -F failed commit: running unchanged and later commands not run"
expectpart "$($clixon_cli -1 -f $cfg show configuration)" 0 --not-- "parameter aftercommit" "parameter failcommit"

new "discard failed commit"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 "^$"

cat <<EOF > $fcmd
# Comment and empty lines are accepted

set table parameter okfile1 value 1

set table parameter okfile2 value 2
validate
commit
EOF

new "-e -F no errors: return ok"
expectpart "$($clixon_cli -e -f $cfg -F $fcmd 2>&1)" 0 --not-- "error" "Unknown command"

new "-e -F no errors: all commands committed"
expectpart "$($clixon_cli -1 -f $cfg show configuration)" 0 "parameter okfile1" "parameter okfile2"

new "-e -q stdin no errors: no prompt in output"
expectpart "$(echo 'show configuration' | $clixon_cli -e -q -f $cfg 2>&1)" 0 "parameter okfile1" --not-- "@"

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
