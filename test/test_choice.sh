#!/usr/bin/env bash
# Choice type and mandatory
# Example from RFC7950 Sec 7.9.6
# Also test mandatory behaviour as in 7.6.5
# (XXX Would need default test in 7.6.4)
# Use-case: The ietf-netconf edit-config has a shorthand version of choice w mandatory:
# container { choice target { mandatory; leaf candidate; leaf running; }}

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/choice.xml
clidir=$dir/cli
fyang=$dir/type.yang

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module system{
  yang-version 1.1;
  namespace "urn:example:config";
  prefix ex;
  container system{
    /* From RFC 7950 7.9.6 */
    container protocol {
       presence true;
         choice name {
           case a {
             leaf udp {
               type empty;
             }
           }
           case b {
             leaf tcp {
               type empty;
             }
           }
         }
     }
    /* Same but shorthand */
    container shorthand {
       presence true;
         choice name {
             leaf udp {
               type empty;
             }
             leaf tcp {
               type empty;
             }
         }
     }
    /* Same with mandatory true */
    container mandatory {
       presence true;
         choice name {
           mandatory true;
           case a {
             leaf udp {
               type empty;
             }
           }
           case b {
             leaf tcp {
               type empty;
             }
           }
         }
     }
    /* Choice with multiple items */
    choice mch {
      case first{
        leaf-list ma {
          type int32;
        }
        leaf mb {
          type int32;
        }
      }
      case second{
        leaf-list mc {
          type int32;
        }
      }
    }
    /* Choice shorthand with sub-container */
    container choice-subcontainer {
       presence true;
         choice name {
             container udp {
	       leaf udp1{
	         type string;
               }
	       leaf udp2{
	         type string;
               }
             }
             container tcp {
	       leaf tcp1{
	         type string;
               }
             }
         }
     }
  }
  /* Case with mandatory leaf */
  container manleaf {
     choice name {
        case a {
           leaf a1 {
	      type string;
           }
           leaf a2 {
	      mandatory true;
	      type string;
           }
        }
        case b {
           leaf b1 {
	      type string;
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

# Autocli syntax tree operations
set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);{
	    cli("Show configuration as CLI commands"), cli_auto_show("datamodel", "candidate", "cli", true, false, "set ");
    }
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

fi

new "wait restconf"
wait_restconf

# First vanilla (protocol) case
new "netconf validate empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set protocol both udp and tcp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><protocol><tcp/><udp/></protocol></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate both udp and tcp fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>udp</bad-element></error-info><error-severity>error</error-severity><error-message>Element in choice statement already exists</error-message></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set empty protocol"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><protocol/></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate protocol"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set protocol tcp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><protocol><tcp/></protocol></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get protocol tcp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><protocol><tcp/></protocol></system>" ""

new "netconf commit protocol tcp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf changing from TCP to UDP (RFC7950 7.9.6)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><protocol><udp nc:operation=\"create\"/></protocol></system></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><ok/></rpc-reply>$" ""

new "netconf get protocol udp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><protocol><udp/></protocol></system>" ""

new "netconf commit protocol udp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

#-- restconf
new "restconf DELETE whole datastore"
expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 204"

new "restconf set protocol tcp+udp fail"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/system:system/protocol -d '{"system:protocol":{"tcp": [null], "udp": [null]}}')" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"bad-element","error-info":{"bad-element":"udp"},"error-severity":"error","error-message":"Element in choice statement already exists"}}}'

new "restconf set protocol tcp"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/system:system/protocol -d {\"system:protocol\":{\"tcp\":[null]}})" 0 "HTTP/$HVER 201"

new "restconf get protocol tcp"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/system:system)" 0 "HTTP/$HVER 200" '{"system:system":{"protocol":{"tcp":\[null\]}}}'

new "restconf set protocol tcp+udp fail again"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/system:system/protocol -d '{"system:protocol":{"tcp": [null], "udp": [null]}}')" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"bad-element","error-info":{"bad-element":"tcp"},"error-severity":"error","error-message":"Element in choice statement already exists"}}}'

new "cli set protocol udp"
expectpart "$($clixon_cli -1 -f $cfg -l o set system protocol udp)" 0 "^$"

new "cli get protocol udp"
expectpart "$($clixon_cli -1 -f $cfg -l o show configuration cli)" 0 "set system protocol" "set system protocol udp"

new "cli change protocol to tcp"
expectpart "$($clixon_cli -1 -f $cfg -l o set system protocol tcp)" 0 "^$"

new "cli get protocol tcp"
expectpart "$($clixon_cli -1 -f $cfg -l o show configuration cli)" 0 "set system protocol" "set system protocol tcp"

new "cli delete all"
expectpart "$($clixon_cli -1 -f $cfg -l o delete all)" 0 "^$"

new "commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

# Second shorthand (no case)
new "netconf set protocol both udp and tcp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><protocol><tcp/><udp/></protocol></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate both udp and tcp fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>udp</bad-element></error-info><error-severity>error</error-severity><error-message>Element in choice statement already exists</error-message></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set shorthand tcp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><shorthand><tcp/></shorthand></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf changing from TCP to UDP (RFC7950 7.9.6)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><shorthand><udp/></shorthand></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><ok/></rpc-reply>"

new "netconf get shorthand udp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><shorthand><udp/></shorthand></system></data></rpc-reply>"

new "netconf validate shorthand"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Third check mandatory
new "netconf set empty mandatory"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><mandatory/></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get mandatory empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><mandatory/></system></data></rpc-reply>"

new "netconf validate mandatory"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>missing-choice</error-app-tag><error-info><missing-choice>name</missing-choice></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>"

new "netconf set mandatory udp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\"><mandatory><udp/></mandatory></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get mandatory udp"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><mandatory><udp/></mandatory></system></data></rpc-reply>"

new "netconf validate mandatory"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Choice with multiple items

new "netconf choice multiple items first"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\" nc:operation=\"replace\" xmlns:nc=\"$BASENS\">
  <ma>0</ma>
  <ma>1</ma>
  <mb>2</mb>
</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get multiple items"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><ma>0</ma><ma>1</ma><mb>2</mb></system>" ""

new "netconf validate multiple ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf choice multiple items second"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\" nc:operation=\"replace\" xmlns:nc=\"$BASENS\">
  <mb>0</mb>
  <mb>1</mb>
</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get items second"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><mb>0</mb><mb>1</mb></system>" ""

new "netconf validate items second expect fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>/system/mb</error-path></rpc-error></rpc-reply>"

new "netconf choice multiple items mix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\" nc:operation=\"replace\" xmlns:nc=\"$BASENS\">
  <ma>0</ma>
  <mb>2</mb>
  <mc>2</mc>
</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate multiple error"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>mc</bad-element></error-info><error-severity>error</error-severity><error-message>Element in choice statement already exists</error-message></rpc-error></rpc-reply>"

# Double merge
new "netconf choice single item"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\" nc:operation=\"replace\" xmlns:nc=\"$BASENS\">
  <ma>12</ma>
</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf choice merge second item"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\" nc:operation=\"merge\" xmlns:nc=\"$BASENS\">
  <mb>99</mb>
</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get both items"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><ma>12</ma><mb>99</mb></system>" ""

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Merge in choice-subcontainer
new "netconf choice sub-container 1st leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\" nc:operation=\"replace\" xmlns:nc=\"$BASENS\">
<choice-subcontainer><udp><udp1>42</udp1></udp></choice-subcontainer>
</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf choice sub-container 2nd leaf (dont remove 1st)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\" xmlns:nc=\"$BASENS\">
<choice-subcontainer><udp><udp2 nc:operation=\"replace\">99</udp2></udp></choice-subcontainer>
</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get both items"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:config\"><choice-subcontainer><udp><udp1>42</udp1><udp2>99</udp2></udp></choice-subcontainer></system></data></rpc-reply>" ""

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set non-mandatory leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><manleaf xmlns=\"urn:example:config\"><a1>xxx</a1></manleaf></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate missing"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>a2</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory variable a2 in module system</error-message></rpc-error></rpc-reply>"

new "netconf set mandatory leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><manleaf xmlns=\"urn:example:config\"><a2>yyy</a2></manleaf></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
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

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir

new "endtest"
endtest
