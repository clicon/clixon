#!/usr/bin/env bash
# Autocli show tests
# Go through all formats and show for all formats
# Formats: XML, JSON, TEXT, CLI, NETCONF
# Pretty-print: false, true, indentation-level is 3 (see PRETTYPRINT_INDENT)
# API: cli_show_auto_mode(), cli_show_auto(), cli_show_config()

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clidir=$dir/cli

fyang=$dir/clixon-example.yang

formatdir=$dir/format
test -d ${formatdir} || rm -rf ${formatdir}
mkdir $formatdir

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
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

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    /* Generic config data */
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
            leaf-list array1{
              type string;
            }
        }
    }
    container table2{
        presence true;
    }
}
EOF

cat <<EOF > $clidir/ex.cli
# Clixon example specification
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, @add:leafref-no-refer, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
discard("Discard edits (rollback 0)"), discard_changes();
show("Show a particular state of the system"){
   configuration("Show configuration"){
      xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", false, false);{
         pretty-print, cli_show_auto_mode("candidate", "xml", true, false);
         config, cli_show_config("candidate", "xml", "/", NULL, false, false);
      }
      json("Show configuration as JSON"), cli_show_auto_mode("candidate", "json", false, false);{
         pretty-print, cli_show_auto_mode("candidate", "json", true, false);
         config, cli_show_config("candidate", "json", "/", NULL, false, false);
       }
      text("Show configuration as TEXT"), cli_show_auto_mode("candidate", "text", false, false);{
         pretty-print, cli_show_auto_mode("candidate", "text", true, false);
         config, cli_show_config("candidate", "text", "/", NULL, false, false);
      }
      cli("Show configuration as CLI commands"), cli_show_auto_mode("candidate", "cli", false, false, NULL, "set ");
      netconf("Show configuration as NETCONF"), cli_show_auto_mode("candidate", "netconf", false, false);
   }
   auto("Show auto") {
      xml("Show configuration as XML") @datamodelshow, cli_show_auto("candidate", "xml", false, false, NULL);
      json("Show configuration as JSON") @datamodelshow, cli_show_auto("candidate", "json", false, false, NULL);
      text("Show configuration as TEXT")@datamodelshow, cli_show_auto("candidate", "text", false, false, NULL);
      cli("Show configuration as CLI commands") @datamodelshow, cli_show_auto("candidate", "cli", false, false, NULL, "set ");
      netconf("Show configuration as NETCONF")@datamodelshow, cli_show_auto("candidate", "netconf", false, false, NULL);
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

# Create two lists elements
new "cli create list table x"
expectpart "$($clixon_cli -1 -f $cfg -l o set table parameter x value 1)" 0 "^$"

new "cli create list table y"
expectpart "$($clixon_cli -1 -f $cfg -l o set table parameter y value 2)" 0 "^$"

# Create two leaf-lists
new "cli create leaflist array1 a"
expectpart "$($clixon_cli -1 -f $cfg -l o set table parameter x array1 a)" 0 "^$"

new "cli create leaflist array1 b"
expectpart "$($clixon_cli -1 -f $cfg -l o set table parameter x array1 b)" 0 "^$"

new "cli commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

# Create a second top-level element
new "cli create list table2"
expectpart "$($clixon_cli -1 -f $cfg -l o set table2)" 0 "^$"

# XML
format=xml

new "cli check show config $format"
X='<table xmlns="urn:example:clixon"><parameter><name>x</name><value>1</value><array1>a</array1><array1>b</array1></parameter><parameter><name>y</name><value>2</value></parameter></table><table2 xmlns="urn:example:clixon"/>'
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format)" 0 "^$X$"

new "cli check show config $format pretty-print"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format pretty-print)" 0 "      <name>x</name>" --not-- "       <name>x</name>"

new "cli check show config $format non-auto"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format config)" 0 "$X"

new "cli check show auto $format table"
X='<table xmlns="urn:example:clixon"><parameter><name>x</name><value>1</value><array1>a</array1><array1>b</array1></parameter><parameter><name>y</name><value>2</value></parameter></table>'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table)" 0 "^$X$"

new "cli check show auto $format table parameter"
X='<parameter><name>x</name><value>1</value><array1>a</array1><array1>b</array1></parameter><parameter><name>y</name><value>2</value></parameter>'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter)" 0 "^$X$"

new "cli check show auto $format table parameter x"
X='<parameter><name>x</name><value>1</value><array1>a</array1><array1>b</array1></parameter>'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter x)" 0 "^$X$"

new "cli check show auto $format table parameter x array1"
X='<array1>a</array1><array1>b</array1>'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter x array1)" 0 "^$X$"

# JSON
format=json

new "cli check show config $format"
X='{"clixon-example:table":{"parameter":\[{"name":"x","value":"1","array1":\["a","b"\]},{"name":"y","value":"2"}\]},"clixon-example:table2":{}}'
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format)" 0 "^$X$"

new "cli check show config $format pretty-print"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format pretty-print)" 0 '   "clixon-example:table": {' --not-- '    "clixon-example:table": {'

new "cli check show config $format non-auto"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format config)" 0 "$X"

new "cli check show auto $format table"
X='{"clixon-example:table":{"parameter":\[{"name":"x","value":"1","array1":\["a","b"\]},{"name":"y","value":"2"}\]}}'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table)" 0 "^$X$"

new "cli check show auto $format table parameter"
X='{"clixon-example:parameter":\[{"name":"x","value":"1","array1":\["a","b"\]},{"name":"y","value":"2"}\]}'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter)" 0 "^$X$"

new "cli check show auto $format table parameter x"
X='{"clixon-example:parameter":\[{"name":"x","value":"1","array1":\["a","b"\]}\]}'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter x)" 0 "^$X$"

new "cli check show auto $format table parameter x array1"
X='{"clixon-example:array1":\["a","b"\]}'
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter x array1)" 0 "^$X$"

# TEXT
format=text

new "cli check show config $format"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format)" 0 "clixon-example:table {" "parameter x {" "array1 \[" "parameter y {"

new "cli check show config $format pretty-print"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format pretty-print)" 0 "   parameter x {" --not-- "    parameter x {"

new "cli check show config $format non-auto"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format config)" 0 "clixon-example:table {" "parameter x {" "array1 \[" "parameter y {"

new "cli check show auto $format table"
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table)" 0

new "cli check show auto $format table parameter"
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter)" 0 "parameter x {" "array1 \[" "parameter y {" --not-- "clixon-example:table {"

new "cli check show auto $format table parameter x"

expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter x)" 0 "parameter x {" "array1 \[" --not-- "clixon-example:table {" "parameter y {"

# XXX prints two [] lists, should only print one
new "cli check show auto $format table parameter x array1"
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table parameter x array1)" 0 "array1 \[" --not-- "clixon-example:table {" "parameter y {" "parameter x {"

# CLI
format=cli

new "cli check show config $format"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format)" 0 "set table parameter x" "set table parameter x value 1" "set table parameter x array1 a" "set table parameter x array1 b" "set table parameter y" "set table parameter y value 2"

new "cli check show auto $format table"
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table)" 0 "set table parameter x" "set table parameter x value 1" "set table parameter x array1 a" "set table parameter x array1 b" "set table parameter y" "set table parameter y value 2"

# XXX rest does not print whole CLI path to root, eg does not include "table"

# NETCONF
format=netconf

# XXX netconf base capability 0, EOM framing
new "cli check show config $format"
X="<rpc ${DEFAULTNS}><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value>1</value><array1>a</array1><array1>b</array1></parameter><parameter><name>y</name><value>2</value></parameter></table><table2 xmlns=\"urn:example:clixon\"/></config></edit-config></rpc>]]>]]>"
expectpart "$($clixon_cli -1 -f $cfg -l o show config $format)" 0 "^$X$"

new "cli check show auto $format table"
X="<rpc ${DEFAULTNS}><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value>1</value><array1>a</array1><array1>b</array1></parameter><parameter><name>y</name><value>2</value></parameter></table></config></edit-config></rpc>]]>]]>"
expectpart "$($clixon_cli -1 -f $cfg -l o show auto $format table)" 0 "^$X$"

# XXX rest does not print whole NETCONF path to root, eg does not include "table"

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
