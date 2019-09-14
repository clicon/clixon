#!/bin/bash
# Yang list / leaf-list min/max-element tests.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  container c{
    presence true;
    list a0{
      key k;
      leaf k {
        type string;
      }
      min-elements 0;
      max-elements "unbounded";
    }
    list a1{
      key k;
      leaf k {
        type string;
      }
      description "There must be at least one of these";
      min-elements 1;
      max-elements 2;
    }
    leaf-list b0{
      type string;
      min-elements 0;
      max-elements "unbounded";
    }
    leaf-list b1{
      description "There must be at least one of these";
      type string;
      min-elements 1;
      max-elements 2;
    }
  }
  container c2{
    description "with choices";
    choice ch1{
      case x{
        list a1{
          key k;
          leaf k {
            type string;
          }
          min-elements 1;
          max-elements 2;
        }
      }
      case y{
        list a2{
          key k;
          leaf k {
            type string;
          }
          min-elements 0;
          max-elements 3;
        }
      }
    }
    choice ch2{
      leaf-list b1{
        type string;
        min-elements 1;
        max-elements 2;
      }
    }
  }
  leaf-list b3{
     description "top-level";
     type int32;
     min-elements 1;
     max-elements 2;
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
    new "start backend -s init -f $cfg"
    # start new backend
    start_backend -s init -f $cfg

    new "waiting"
    wait_backend
fi

new "minmax: minimal"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns="urn:example:clixon">
  <a1><k>0</k></a1>
  <b1>0</b1>
</c></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax: minimal validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax: maximal"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns="urn:example:clixon"><a0><k>0</k></a0><a0><k>1</k></a0><a0><k>unbounded</k></a0><a1><k>0</k></a1><a1><k>1</k></a1><b0>0</b0><b0>1</b0><b0>unbounded</b0><b1>0</b1><b0>1</b0></c></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "minmax: validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax: empty"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns="urn:example:clixon"/></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

#XXX echo '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' |$clixon_netconf -qf $cfg 
new "minmax: validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>c</error-path></rpc-error></rpc-reply>]]>]]>$'

new "minmax: no list"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns="urn:example:clixon"><b1>0</b1></c></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "minmax: validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>c</error-path></rpc-error></rpc-reply>]]>]]>$'

new "minmax: no leaf-list"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns="urn:example:clixon"><a1><k>0</k></a1></c></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "minmax: validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>c</error-path></rpc-error></rpc-reply>]]>]]>$'

new "minmax: Too large list"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns="urn:example:clixon"><a1><k>0</k></a1><a1><k>1</k></a1><a1><k>2</k></a1><b1>0</b1></c></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "minmax: validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>a1</error-path></rpc-error></rpc-reply>]]>]]>$'

new "minmax: Too large leaf-list"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns="urn:example:clixon"><a1><k>0</k></a1><b1>0</b1><b1>1</b1><b1>2</b1></c></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "minmax: validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>b1</error-path></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# With choice c1
new "minmax choice: minimal"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c2 xmlns="urn:example:clixon">
  <a1><k>0</k></a1>
  <b1>0</b1>
</c2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax choice: minimal validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax choice: many a2"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c2 xmlns="urn:example:clixon">
  <a2><k>0</k></a2>
  <a2><k>1</k></a2>
  <a2><k>2</k></a2>
  <b1>0</b1>
</c2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax choice: many a2 validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax choice: too many a1"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c2 xmlns="urn:example:clixon">
  <a1><k>0</k></a1>
  <a1><k>1</k></a1>
  <a1><k>2</k></a1>
  <b1>0</b1>
</c2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax choice: too many validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>a1</error-path></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# top config level
new "minmax top level"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>
   <b3 xmlns="urn:example:clixon">0</b3>
   <b3 xmlns="urn:example:clixon">1</b3>
</config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax top level ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax top level too many"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>
   <b3 xmlns="urn:example:clixon">0</b3>
   <b3 xmlns="urn:example:clixon">1</b3>
   <b3 xmlns="urn:example:clixon">2</b3>
</config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "minmax top level too many should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>b3</error-path></rpc-error></rpc-reply>]]>]]>'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
