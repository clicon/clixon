#!/usr/bin/env bash
# Yang deviate tests
# See RFC 7950 5.6.3 and 7.20.3
# Four examples: not supported, add, replace, delete
# Also:
# - keyword with/without string
# - use grouping

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangbase=$dir/example-base.yang
fyangdev=$dir/example-deviations.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyangbase
module example-base{
   yang-version 1.1;
   prefix base;
   namespace "urn:example:base";
   grouping system-top {
     container system {
      must "daytime or time"; /* deviate delete removes this */
      leaf daytime{           /* deviate not-supported removes this */
         type string;
      }
      leaf time{            
         type string;
      }
      list name-server {
         max-elements 1;      /* deviate replace replaces to "max.elements 3" here */
         key name;
         leaf name {
            type string;
         } 
      }
      list user {
         key name;
         leaf name {
            type string;
         } 
         leaf type {
            type string;
            /* deviate add adds "default admin" here */
         } 
      }
     }
   }
   uses system-top;
}
EOF

# Args:
# 1: daytime implemented: true/false
# 2: admin type default: true/false
# 3: mustdate default: true/false
# 4: maxelement of name-server is 1: true/false (if false the # is 3)
function testrun()
{
    daytime=$1
    admindefault=$2
    mustdate=$3
    maxel1=$4

    new "test params: -f $cfg"

    if [ "$BE" -ne 0 ]; then
        new "kill old backend"
        sudo clixon_backend -zf "$cfg"
        if [ $? -ne 0 ]; then
            err
        fi
        new "start backend -s init -f $cfg"
        start_backend -s init -f "$cfg"
    fi

    new "wait backend"
    wait_backend

    new "Add user bob"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><user><name>bob</name></user></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    if $mustdate; then # fail since there is neither date or daytime (delete rule)
        new "netconf validate expect error"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Failed MUST xpath 'daytime or time' of 'system' in module example-base</error-message></rpc-error></rpc-reply>"
    else
        new "netconf validate ok"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
    fi

    new "Add time"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><time>yes</time></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    if $daytime; then # not-supported rule
        new "Add example-base daytime - supported"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><daytime>Sept17</daytime></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
    else # Not supported
        new "Add example-base daytime - expect error not supported"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><daytime>Sept17</daytime></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>daytime</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: daytime with parent: system in namespace: urn:example:base</error-message></rpc-error></rpc-reply>"
    fi # daytime supported

    new "netconf commit"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
        
    if $admindefault; then # add rule
        new "Get type admin expected"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults><source><running/></source><filter type=\"xpath\" select=\"/base:system/base:user[base:name='bob']/base:type\" xmlns:base=\"urn:example:base\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:base\"><user><name>bob</name><type>admin</type></user></system></data></rpc-reply>"
    else
        new "Get type none expected"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:system/base:user[base:name='bob']/base:type\" xmlns:base=\"urn:example:base\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"
    fi

    # Add 2 name-servers
    new "Add two name-servers"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><name-server><name>aa</name></name-server><name-server><name>bb</name></name-server></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
    if $maxel1; then # add two and check if it fails
        new "netconf validate 2 element fail"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>/system/name-server</error-path></rpc-error></rpc-reply>"
    else
        new "netconf validate 2 elements ok"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
    fi

    if [ "$BE" -ne 0 ]; then
        new "Kill backend"
        # Check if premature kill
        pid=$(pgrep -u root -f clixon_backend)
        if [ -z "$pid" ]; then
            err "backend already dead"
        fi
        # kill backend
        stop_backend -f "$cfg"
    fi
} # testrun

# Example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
}
EOF
new "1. Baseline: no deviations"
testrun true false true true

# Example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
   deviation /base:system/base:daytime {
      deviate "not-supported"; // Note a string
   }
}
EOF
new "2. daytime not supported"
testrun false false true true

# Add example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
   deviation /base:system/base:user/base:type {
      deviate add {
         default "admin"; 
      }
   }
}
EOF
new "3. deviate add, check admin default"
testrun true true true true

# Delete example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
   deviation /base:system/base:name-server {
      deviate replace {
         max-elements 3;
      }
   }
}
EOF
new "4. deviate replace"
testrun true false true false

# Replace example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
   deviation /base:system {
      deviate delete {
         must "daytime or time";
      }
   }
}
EOF

new "5. deviate delete"
testrun true false false true

rm -rf "$dir"

new "endtest"
endtest
