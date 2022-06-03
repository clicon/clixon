#!/usr/bin/env bash
# Yang action, use main exapl backend for registering action
# See RFC 7950 7.15

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-server-farm.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
  module example-server-farm {
       yang-version 1.1;
       namespace "urn:example:server-farm";
       prefix "sfarm";

       import ietf-yang-types {
         prefix "yang";
       }

       list server {
         key name;
         leaf name {
           type string;
         }
         action reset {
           input {
             leaf reset-at {
               type yang:date-and-time;
               mandatory true;
              }
            }
            output {
              leaf reset-finished-at {
                type yang:date-and-time;
                mandatory true;
              }
            }
          }
        }
      }
EOF

if [ $BE -ne 0 ]; then     # Bring your own backend
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -- -a /sfarm:server/sfarm:reset"
    start_backend -s init -f $cfg -- -a /sfarm:server/sfarm:reset
fi

new "wait backend"
wait_backend

rpc="<rpc $DEFAULTNS><action xmlns=\"urn:ietf:params:xml:ns:yang:1\"><server xmlns=\"urn:example:server-farm\"><name>apache-1</name><reset><reset-at>2014-07-29T13:42:00Z</reset-at></reset></server></action></rpc>"
       
new "netconf action"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$rpc" "" "<rpc-reply $DEFAULTNS><reset-finished-at xmlns=\"urn:example:server-farm\">2014-07-29T13:42:00Z</reset-finished-at></rpc-reply>"

if [ $BE -ne 0 ]; then     # Bring your own backend
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf "$dir"

new "endtest"
endtest
