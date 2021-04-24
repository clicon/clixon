#!/usr/bin/env bash
# Yang deviate tests
# See RFC 7950 5.6.3 and 7.20.3
# Four examples: not supported, add, replace, delete

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangbase=$dir/example-base.yang
fyangdev=$dir/example-deviations.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

cat <<EOF > $fyangbase
module example-base{
   yang-version 1.1;
   prefix base;
   namespace "urn:example:base";
   container system {
       must "daytime or time";
       leaf daytime{
	   type string;
       }
       list name-server {
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
         } 
       }
   }
}
EOF

# Example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module $APPNAME{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";

   import example-base {
         prefix base;
   }

   deviation /base:system/base:daytime {
        deviate not-supported;
   }
   deviation /base:system/base:user/base:type {
       deviate add {
         default "admin"; // new users are 'admin' by default
       }
   }
   deviation /base:system {
       deviate delete {
         must "daytime or time";
       }
   }
}
EOF

new "test params: -f $cfg"

if [ "$BE" -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf "$cfg"
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f "$cfg"

    new "waiting"
    wait_backend
fi


if [ "$BE" -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f "$cfg"

rm -rf "$dir"

new "endtest"
endtest
