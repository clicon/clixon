#!/usr/bin/env bash
# Tests for autocli cache

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
cfd=$dir/conf_yang.d
if [ ! -d $cfd ]; then
    mkdir $cfd
fi
cachedir=$dir/clispec
cachefile=${cachedir}/top/clixon-example@2025-05-01.cli
cachefile2=${cachedir}/top/clixon-example@2025-05-01-grouping-pg1.cli

fyang=$dir/clixon-example@2025-05-01.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$cfd</CLICON_CONFIGDIR>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $dir/example.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
commit("Commit the changes"), cli_commit();
validate("Validate changes"), cli_validate();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", false, false);
}
EOF

# Yang specs must be here first for backend. But then the specs are changed but just for CLI
# Annotate original Yang spec example  directly
# First annotate /table/parameter 
# Had a problem with unknown in grouping -> test uses uses/grouping
cat <<EOF > $fyang
module clixon-example {
  namespace "urn:example:clixon";
  prefix ex;
  import clixon-autocli{
      prefix autocli;
  }
  revision 2025-05-01;
  grouping pg1 {
     list index1{
        key i;
        leaf i{
           type string;
        }
     }
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      uses pg1;
    }
  }
}
EOF

# Args:
# 1: clispec-cache
function testsetup()
{
    # Whether grouping treeref is enabled
    cache=$1
    rm -rf $cachedir
    cat <<EOF > $cfd/autocli.xml
<clixon-config xmlns="http://clicon.org/config">
  <autocli>
    <module-default>true</module-default>
     <list-keyword-default>kw-nokey</list-keyword-default>
     <grouping-treeref>true</grouping-treeref>
     <clispec-cache>$cache</clispec-cache>
     <clispec-cache-dir>$cachedir</clispec-cache-dir>
  </autocli>
</clixon-config>
EOF

    new "set top-level grouping"
#    echo "$clixon_cli -f $cfg -1 set table parameter x index1 a"
    expectpart "$($clixon_cli -f $cfg -1 set table parameter x index1 a)" 0 ""

    new "show grouping"
    expectpart "$($clixon_cli -f $cfg -1 show config)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name><index1><i>a</i></index1></parameter></table>"
}

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

new "autocli disabled"
testsetup disabled

new "Check no cache"
if [ -d ${cachedir} ]; then
    err1 "Unexpected ${cachedir}"
fi

# How should I test this?
new "autocli read"
testsetup read

new "autocli write"
testsetup write

new "Check cache file"
if [ ! ${cachefile} ]; then
    err1 "Expected ${cachefile}"
fi

# cat "${cachefile}"
new "Check cache content"
content=$(cat ${cachefile})
expected="table,overwrite_me(\"/clixon-example:table\"), act-container;{"
match=$(echo "${content}" | grep --null -o "$expected")
if [[ -z "${match}" ]]; then
    err "$expected" "${content}"
fi

new "Check grouping cache file"
if [ ! ${cachefile2} ]; then
    err1 "Expected ${cachefile2}"
fi

new "autocli readwrite"
testsetup readwrite

new "Check cache content"
content=$(cat ${cachefile})
expected="table,overwrite_me(\"/clixon-example:table\"), act-container;{"
match=$(echo "${content}" | grep --null -o "$expected")
if [[ -z "${match}" ]]; then
    err "$expected" "${content}"
fi

new "Check grouping cache file"
if [ ! ${cachefile2} ]; then
    err1 "Expected ${cachefile2}"
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
