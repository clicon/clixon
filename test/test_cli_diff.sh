#!/usr/bin/env bash
# CLI compare for all formats
# Create a diff by committing one set, then add/remove some parts in candidate and show diff in all formats

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clidir=$dir/cli
fyang=$dir/clixon-example.yang

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    import clixon-autocli{
        prefix autocli;
    }
    /* Generic config data */
    container top{
       list section{
          key name;
          leaf name{
             type string;
          }
          container table{
             list parameter{
                key name;
                leaf name{
                   type string;
                }
                leaf value{
                   type string;
                }
             }
         }
         container multi{
             list parameter{
                key "first second";
                leaf first{
                   type string;
                }
                leaf second{
                   type string;
                }
                leaf-list value{
                   type string;
                }
             }
         }
      }
   }
}
EOF

cat <<EOF > $clidir/ex.cli
# Clixon example specification
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";
CLICON_PIPETREE="|mypipe";  # Only difference from nodefault

set @datamodel, cli_auto_set();
delete("Delete a configuration item") @datamodel, cli_auto_del(); 
commit("Commit the changes"), cli_commit();
show("Show a particular state of the system"){
   compare("Compare candidate and running databases") {
      xml("Show comparison in xml"), compare_dbs("running", "candidate", "xml");
      json("Show comparison in xml"), compare_dbs("running", "candidate", "json");
      text("Show comparison in text"), compare_dbs("running", "candidate", "text");
      cli("Show comparison in text"), compare_dbs("running", "candidate", "cli", "set ");
   }
   configuration("Show configuration") {
      candidate, cli_show_auto_mode("candidate", "xml", false, false); {
         @|mypipe, cli_show_auto_mode("candidate", "xml", true, false);
      }
      running, cli_show_auto_mode("running", "xml", false, false);{
         @|mypipe, cli_show_auto_mode("running", "xml", true, false);
      }
   }
}
EOF

cat <<EOF > $clidir/clipipe.cli
CLICON_MODE="|mypipe"; # Must start with |
\| { 
   show {
     xml, pipe_showas_fn("xml");
     json, pipe_showas_fn("json");
     text, pipe_showas_fn("text");
     cli, pipe_showas_fn("cli", true, "set ");
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
    
new "add a"
expectpart "$($clixon_cli -1 -f $cfg set top section x table parameter a value 17)" 0 "^$"

new "add b"
expectpart "$($clixon_cli -1 -f $cfg set top section x table parameter b value 42)" 0 "^$"

new "add d"
expectpart "$($clixon_cli -1 -f $cfg set top section x table parameter d value 98)" 0 "^$"

new "check compare xml"
expectpart "$($clixon_cli -1 -f $cfg show compare xml)" 0 "^+  <top xmlns=\"urn:example:clixon\">" --not-- "\-" "<data>"

new "check compare text"
expectpart "$($clixon_cli -1 -f $cfg show compare text)" 0 "^+  clixon-example:top {" --not-- "^\-" data

new "commit"
expectpart "$($clixon_cli -1 -f $cfg commit)" 0 "^$"

new "check running"
expectpart "$($clixon_cli -1 -f $cfg show config running)" 0 "^<top xmlns=\"urn:example:clixon\"><section><name>x</name><table><parameter><name>a</name><value>17</value></parameter><parameter><name>b</name><value>42</value></parameter><parameter><name>d</name><value>98</value></parameter></table></section></top>$"

new "delete a"
expectpart "$($clixon_cli -1 -f $cfg delete top section x table parameter a)" 0 "^$"

new "add c"
expectpart "$($clixon_cli -1 -f $cfg set top section x table parameter c value 72)" 0 "^$"

new "change d"
expectpart "$($clixon_cli -1 -f $cfg set top section x table parameter d value 99)" 0 "^$"

new "check candidate"
expectpart "$($clixon_cli -1 -f $cfg show config candidate)" 0 "^<top xmlns=\"urn:example:clixon\"><section><name>x</name><table><parameter><name>b</name><value>42</value></parameter><parameter><name>c</name><value>72</value></parameter><parameter><name>d</name><value>99</value></parameter></table></section></top>$"

new "check compare xml"
expectpart "$($clixon_cli -1 -f $cfg show compare xml)" 0 "<table>" "^\-\ *<parameter>" "^+\ *<parameter>" "^\-\ *<name>a</name>" "^+\ *<name>c</name>" --not-- "^+\ *<name>a</name>" "^\-\ *<name>c</name>"

new "check compare text"
expectpart "$($clixon_cli -1 -f $cfg show compare text)" 0 "^\ *table {" "^\-\ *parameter a {" "^+\ *parameter c {" "^\-\ *value 98;" "^+\ *value 99;"

new "delete section x"
expectpart "$($clixon_cli -1 -f $cfg delete top section x)" 0 "^$"

# multiple and leaf-list
new "add a12 17"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter a1 a2 value 17)" 0 "^$"

new "add a12 18"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter a1 a2 value 18)" 0 "^$"

new "add b12 42"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter b1 b2 value 42)" 0 "^$"

new "add b12 43"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter b1 b2 value 43)" 0 "^$"

new "add d12 98"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter d1 d2 value 98)" 0 "^$"

new "add d12 99"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter d1 d2 value 99)" 0 "^$"

new "commit"
expectpart "$($clixon_cli -1 -f $cfg commit)" 0 "^$"

new "delete a12"
expectpart "$($clixon_cli -1 -f $cfg delete top section y multi parameter a1 a2)" 0 "^$"

new "add c12 72"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter c1 c2 value 72)" 0 "^$"

new "add c12 73"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter c1 c2 value 73)" 0 "^$"

new "delete d12 99"
expectpart "$($clixon_cli -1 -f $cfg delete top section y multi parameter d1 d2 value 99)" 0 "^$"

new "add d12 97"
expectpart "$($clixon_cli -1 -f $cfg set top section y multi parameter d1 d2 value 97)" 0 "^$"

new "check compare multi xml"
expectpart "$($clixon_cli -1 -f $cfg show compare xml)" 0 "^\-\ *<first>a1</first>" "^\-\ *<second>a2</second>" "^\-\ *<value>17</value>" "^\-\ *<value>18</value>" "^+\ *<first>c1</first>" "^+\ *<second>c2</second>" "^+\ *<value>72</value>" "^+\ *<value>73</value>" "^+\ *<value>97</value>" "^\-\ *<value>99</value>" --not-- "<value>98</value>"

new "check compare multi text"
expectpart "$($clixon_cli -1 -f $cfg show compare text)" 0 "^\-\ *parameter a1 a2 {" "^\-\ *17" "^\-\ *18" "^+\ *parameter c1 c2 {" "^+\ *72" "^+\ *73" "^+\ *97" "^\-\ *99" "parameter d1 d2 {"  --not-- "parameter b1 b2 {"
# XXX --not-- "^+\ *value \["

# NYI: json, cli

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
