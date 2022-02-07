#!/usr/bin/env bash
# Test netconf / xml whitespaces
# Insignicant and significant
# See      https://www.w3.org/TR/xml-c14n
# where "clean", "dirty" and "mixed" whitespaces are defined
#   <clean>   </clean>
#   <dirty>   A   B   </dirty>
#   <mixed>
#      A
#      <clean>   </clean>
#      B
#      <dirty>   A   B   </dirty>
#      C
#   </mixed>

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/whitespace.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module whitespace{
  yang-version 1.1;
  namespace "urn:example:whitespace";
  prefix fi;
  container x{
     presence true;
     list y {
        key a;
        leaf a{
          type string;
        }
        container b{
	  presence true;
        }
     }
  }
}
EOF

new "test params: -f $cfg -s startup"

# Keep the following as is (whitespace)
echo "<${DATASTORE_TOP}><ex:x xmlns:ex=\"urn:example:whitespace\">    
 <ex:y>   <ex:a>foo</ex:a>\n  <ex:b>  </ex:b></ex:y>   </ex:x></${DATASTORE_TOP}>" > $dir/startup_db

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -s startup
    if [ $? -ne 0 ]; then
	err
   fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg 
fi

new "waiting"
wait_backend

new "get startup"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><ex:x xmlns:ex=\"urn:example:whitespace\"><ex:y><ex:a>foo</ex:a><ex:b/></ex:y></ex:x></data></rpc-reply>]]>]]>$"

new "remove"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:whitespace\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "add insignificant 'dirty' whitespaces"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:whitespace\">   \t \ <y>   <a>foo</a>\n  </y>   </x></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "get stripped whitespace"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:whitespace\"><y><a>foo</a></y></x></data></rpc-reply>]]>]]>$"

new "validate"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "add insignificant 'dirty' whitespaces with prefixes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><ex:x xmlns:ex=\"urn:example:whitespace\">   \t \ <ex:y>   <ex:a>foo</ex:a>\n  </ex:y>   </ex:x></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "get stripped whitespace"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><ex:x xmlns:ex=\"urn:example:whitespace\"><ex:y><ex:a>foo</ex:a></ex:y></ex:x></data></rpc-reply>]]>]]>$"

new "validate"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "add insignificant 'clean' whitespaces"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:whitespace\">  \n \t   </x></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "add more insignificant 'clean' whitespaces"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:whitespace\"><y><a>foo</a><b>     </b></y></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "get stripped whitespace"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:whitespace\"><y><a>foo</a><b/></y></x></data></rpc-reply>]]>]]>"

new "validate"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "add significant whitespaces"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:whitespace\"><y><a> foo 
 	  bar </a></y></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "get significant whitespace"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:whitespace\"><y><a> foo 
	  bar </a></y></x></data></rpc-reply>]]>]]>"

new "validate"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

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
