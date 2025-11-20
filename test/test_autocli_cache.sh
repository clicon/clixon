#!/usr/bin/env bash
# Tests for autocli cache in backend
# Matrix flag tests:
#
#  cache    | CLICON_AUTOCLI_CACHE_DIR  | result
# ----------+---------------------------+---------
#  disabled | -                         | local
#  read     | null                      | error
#  read     | dir                       | server
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
cfd=$dir/conf_yang.d
if [ ! -d $cfd ]; then
    mkdir $cfd
fi
cachedir=$dir/autocli
if [ ! -d $cachedir ]; then
    mkdir $cachedir
fi
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
      @datamodel, @add:leafref-no-refer, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
clear("Clear system state") {
    autocli("Autocli file cache"), cli_cache_clear("autocli", "default"); # clixon-cache branch
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

cat <<EOF > $cfd/extra.xml
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_AUTOCLI_CACHE_DIR>$cachedir</CLICON_AUTOCLI_CACHE_DIR>
</clixon-config>
EOF

new "cache = disabled"
cache=disabled
cat <<EOF > $cfd/autocli.xml
<clixon-config xmlns="http://clicon.org/config">
   <autocli>
      <module-default>false</module-default>
      <list-keyword-default>kw-nokey</list-keyword-default>
      <grouping-treeref>true</grouping-treeref>
      <treeref-state-default>false</treeref-state-default>
      <rule>
         <name>include example</name>
         <operation>enable</operation>
         <module-name>clixon-example*</module-name>
      </rule>
      <clispec-cache>$cache</clispec-cache>
   </autocli>
</clixon-config>
EOF

new "Remove $cachedir"
sudo rm -rf $cachedir/*

new "Add some to $cachedir"
cat <<EOF > $cachedir/foo.cli
Foo cli;
EOF

new "Check cache"
ret=$(ls $cachedir)
if [ "$ret" != "foo.cli" ]; then
    err "foo.cli" "$res"
fi

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

new "wait backend 1"
wait_backend

# Bootstrap: cannot clear cache from cli before use by autocli, must use netconf
new "clear cache"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><clixon-cache $LIBNS><operation>clear</operation><type>autocli</type></clixon-cache></rpc>" "<ok/>"

new "set top-level grouping"
expectpart "$($clixon_cli -f $cfg -1 set table parameter x index1 a)" 0 ""

new "Check cache empty"
ret=$(ls $cachedir)
if [ -n "$ret" ]; then
    err "empty dir" "$res"
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

new "cache = read, dir = NULL"
cache=read
cat <<EOF > $cfd/autocli.xml
<clixon-config xmlns="http://clicon.org/config">
   <autocli>
      <module-default>false</module-default>
      <list-keyword-default>kw-nokey</list-keyword-default>
      <grouping-treeref>true</grouping-treeref>
      <treeref-state-default>false</treeref-state-default>
      <rule>
         <name>include example</name>
         <operation>enable</operation>
         <module-name>clixon-example*</module-name>
      </rule>
      <clispec-cache>$cache</clispec-cache>
   </autocli>
</clixon-config>
EOF

cat <<EOF > $cfd/extra.xml
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_AUTOCLI_CACHE_DIR></CLICON_AUTOCLI_CACHE_DIR>
</clixon-config>
EOF

if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend 2"
wait_backend

new "clear cache"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><clixon-cache $LIBNS><operation>clear</operation><type>autocli</type></clixon-cache></rpc>" "<rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Autocli cache requires CLICON_AUTOCLI_CACHE_DIR to be set</error-message></rpc-error>"

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

new "cache = read, dir = NULL"
cache=read
cat <<EOF > $cfd/autocli.xml
<clixon-config xmlns="http://clicon.org/config">
   <autocli>
      <module-default>false</module-default>
      <list-keyword-default>kw-nokey</list-keyword-default>
      <grouping-treeref>true</grouping-treeref>
      <treeref-state-default>false</treeref-state-default>
      <rule>
         <name>include example</name>
         <operation>enable</operation>
         <module-name>clixon-example*</module-name>
      </rule>
      <clispec-cache>$cache</clispec-cache>
   </autocli>
</clixon-config>
EOF

cat <<EOF > $cfd/extra.xml
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_AUTOCLI_CACHE_DIR>$cachedir</CLICON_AUTOCLI_CACHE_DIR>
</clixon-config>
EOF

if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend 3"
wait_backend

new "clear cache"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><clixon-cache $LIBNS><operation>clear</operation><type>autocli</type></clixon-cache></rpc>" "<ok/>"

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
