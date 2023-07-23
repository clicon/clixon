#!/usr/bin/env bash
# Tests for saving memory by not expanding grouping/uses in the autocli

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
fyang2=$dir/example-external.yang
fyang3=$dir/example-external3.yang

# Whether grouping treeref is enabled
grouping_treeref=true

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <autocli>
    <module-default>false</module-default>
     <list-keyword-default>kw-nokey</list-keyword-default>
     <grouping-treeref>${grouping_treeref}</grouping-treeref>
     <rule>
        <name>include ${APPNAME}</name>
        <operation>enable</operation>
        <module-name>${APPNAME}*</module-name>
     </rule>
  </autocli>
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
module example {
  namespace "urn:example:clixon";
  prefix ex;
  import clixon-autocli{
      prefix autocli;
  }
  import example-external{
      prefix ext;
  }
  grouping pg1 {
     leaf value1{
        description "a value";
        type string;
     }
     list index1{
       key i;
       leaf i{
         type string;
       }
       leaf iv{
         description "a value";
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
      leaf value0{
        description "a value";
        type string;
      }
      uses pg1;
      uses ext:pg2;
    }
  }
  uses pg1;
}
EOF

# Original no annotations for backend
cat <<EOF > $fyang2
module example-external {
   namespace "urn:example:external";
   prefix ext;
   import example-external3{
      prefix ext3;
   }
   grouping pg2 {
      leaf value2{
        description "a value";
        type string;
      }
      container c2{
         uses ext3:pg3;
      }
   }
}
EOF

# Original no annotations for backend
cat <<EOF > $fyang3
module example-external3 {
   namespace "urn:example:external";
   prefix ext3;
   grouping pg3 {
      leaf value3{
        description "a value";
        type string;
      }
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

# Test of generated clispecs. With autocli grouping_treeref, there should be treerefs for
# groupings. Without they should not be present
# The testcase assumes enabled
if ${grouping_treeref}; then
    new "verify grouping is enabled"
    expectpart "$($clixon_cli -f $cfg -G -1 2>&1)" 0 "@grouping-urn:example:clixon-pg1" "@grouping-urn:example:external-pg2" "@grouping-urn:example:external-pg3"
else
    new "verify grouping is disabled"
    expectpart "$($clixon_cli -f $cfg -G -1 2>&1)" 0 --not-- "@grouping-urn:example:clixon-pg1" "@grouping-urn:example:external-pg2" "@grouping-urn:example:external-pg3"
fi

new "set top-level grouping"
expectpart "$($clixon_cli -f $cfg -1 set value1 39)" 0 ""

new "set inline grouping value"
expectpart "$($clixon_cli -f $cfg -1 set table parameter x value0 40)" 0 ""

new "set grouping in same module"
expectpart "$($clixon_cli -f $cfg -1 set table parameter x value1 41)" 0 ""

new "set list grouping in same module"
expectpart "$($clixon_cli -f $cfg -1 set table parameter x index1 a iv foo)" 0 ""

new "set grouping in other module"
expectpart "$($clixon_cli -f $cfg -1 set table parameter x value2 42)" 0 ""

new "set grouping in other+other module"
expectpart "$($clixon_cli -f $cfg -1 set table parameter x c2 value3 43)" 0 ""

new "commit"
expectpart "$($clixon_cli -f $cfg -1 commit)" 0 ""

new "show config"
expectpart "$($clixon_cli -f $cfg -1 show config)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value0>40</value0><value1>41</value1><index1><i>a</i><iv>foo</iv></index1><value2>42</value2><c2><value3>43</value3></c2></parameter></table>" "<value1 xmlns=\"urn:example:clixon\">39</value1>"

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
