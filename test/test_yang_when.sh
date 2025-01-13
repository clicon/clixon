#!/usr/bin/env bash
# Tests for yang uses/augment + when 
# Uses+when, test:
# 1. set/get/validate matching and non-matching when statement
# 2 RFC 7950 7.21.5: If a key leaf is defined in a grouping that is used in a list, the
#  "uses" statement MUST NOT have a "when" statement.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

fin=$dir/in
cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
clidir=$dir/cli
if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Generate autocli for these modules
AUTOCLI=$(autocli_config ${APPNAME}\*  kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);{
      xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", false, false);
}
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
EOF

# Start backend, add entry with matching name / non-matrching and check get/validation
function testrun()
{
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

    # no match: name != kalle
    new "netconf set non-match"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>paul</name></parameter></table></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf get default value not set"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>paul</name></parameter></table></data></rpc-reply>"

    new "netconf set non-match value expect fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>paul</name><value>42</value></parameter></table></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>value</bad-element></error-info><error-severity>error</error-severity><error-message>Node 'value' tagged with 'when' condition 'ex:name = 'kalle'' in module 'example' evaluates to false in edit-config operation (see RFC 7950 Sec 8.3.2)</error-message></rpc-error></rpc-reply>"

    new "netconf get value without default"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>paul</name></parameter></table></data></rpc-reply>"

    new "netconf validate default not set"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf discard non-match"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    # no match: name != kalle full put
    new "netconf set non-match full"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>paul</name><value>42</value></parameter></table></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>value</bad-element></error-info><error-severity>error</error-severity><error-message>Node 'value' tagged with 'when' condition 'ex:name = 'kalle'' in module 'example' evaluates to false in edit-config operation (see RFC 7950 Sec 8.3.2)</error-message></rpc-error></rpc-reply>"

    new "netconf get value empty"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

    # match: name = kalle
    new "netconf set match"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>kalle</name></parameter></table></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf get default value set X"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>kalle</name><value>foo</value></parameter></table>"

    new "netconf set non-match value expect ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>kalle</name><value>42</value></parameter></table></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf get value ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>kalle</name><value>42</value></parameter></table></data></rpc-reply>"

    new "netconf validate default set"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
}

cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;

  grouping value-top {
    leaf value{
       type string;
       default foo;
    }
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      uses value-top {
        when "ex:name = 'kalle'";
      }
    }
  }
}
EOF

new "1. uses/when test edit,default"
testrun

cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;

  grouping value-top {
    leaf value{
       type string;
       default foo;
    }
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }

    }
  }
  augment /table/parameter {
      uses value-top {
        when "ex:name = 'kalle'";
      }  
  }
}
EOF

new "2. augment/uses/when test edit,default (same but with augment)"
testrun

cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;

  grouping value-top {
    leaf name{
       type string;
    }
  }
  container table{
    list parameter{
      key name;
      uses value-top {
        when "ex:name = 'kalle'";
      }
    }
  }
}
EOF
new "3. RFC 7950 7.21.5: If a key leaf is defined in a grouping that is used in a list"
# the "uses" statement MUST NOT have a "when" statement.

if [ ${valgrindtest} -eq 0 ]; then # Error dont cleanup mem OK
    new "start backend -s init -f $cfg, expect yang when fail"
    expectpart "$(sudo $clixon_backend -F -D $DBG -s init -f $cfg 2>&1)" 255 "Yang error: Key leaf 'name' defined in grouping 'value-top' is used in a 'uses' statement, This is not allowed according to RFC 7950 Sec 7.21.5"
fi

cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;

  leaf allow {
     type boolean;
     default false;
  }
  grouping value-top {
    leaf value{
       type string;
       default foo;
    }
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      uses value-top {
        when "../../ex:allow = 'true'";
      }
    }
  }
}
EOF


new "3. Check a top-level value as allowed value"

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

new "netconf set allow true"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><allow xmlns=\"urn:example:clixon\">true</allow></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set value expect OK"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>kalle</name><value>42</value></parameter></table></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set allow false"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><allow xmlns=\"urn:example:clixon\">false</allow></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set value expect fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>kalle</name><value>42</value></parameter></table></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>value</bad-element></error-info><error-severity>error</error-severity><error-message>Node 'value' tagged with 'when' condition '../../ex:allow = 'true'' in module 'example' evaluates to false in edit-config operation (see RFC 7950 Sec 8.3.2)</error-message></rpc-error></rpc-reply>"

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
