#!/bin/bash
# Order test. test ordered-by user and ordered-by system.
# For each leaf and leaf-lists, there are two lists,
# one ordered-by user and one ordered by system.
# The ordered-by user MUST be the order it is entered.
# No test of ordered-by system is done yet
# (we may want to sort them alphabetically for better performance).
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh
cfg=$dir/conf_yang.xml
fyang=$dir/order.yang

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"

dbdir=$dir/order

new "Set up $dbdir"
rm -rf $dbdir
if [ ! -d $dbdir ]; then
    mkdir $dbdir
fi

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>/tmp/conf_yang.xml</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_XML_SORT>true</CLICON_XML_SORT>
</config>
EOF

cat <<EOF > $fyang
module example{
    container c{
      leaf d{
         type string;
      }
    }
    leaf l{
       type string;
    }
    leaf-list y0 {
      ordered-by user;
      type string;
    }
    leaf-list y1 {
      ordered-by system;
      type string;
    }
    list y2 {
      ordered-by user;
      key "k";
      leaf k {
        type string;
      }
      leaf a {
        type string;
      }   
    }
    list y3 {
      ordered-by system;
      key "k";
      leaf k {
        type string;
      }
      leaf a {
        type string;
      }   
    }
}
EOF

cat <<EOF > $dbdir/running_db
<config>
  <y0>d</y0>
  <y1>d</y1>
  <y2><k>d</k><a>bar</a></y2>
  <y3><k>d</k><a>bar</a></y3>
  <y0>b</y0>
  <y1>b</y1>
  <c><d>hej</d></c>
  <y0>c</y0>
  <y1>c</y1>
  <y2><k>a</k><a>bar</a></y2>
  <y3><k>a</k><a>bar</a></y3>
  <l>hopp</l>
  <y0>a</y0>
  <y1>a</y1>
  <y2><k>c</k><a>bar</a></y2>
  <y3><k>c</k><a>bar</a></y3>
  <y2><k>b</k><a>bar</a></y2>
  <y3><k>b</k><a>bar</a></y3>
</config>
EOF

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "start backend"
# start new backend
sudo $clixon_backend -s running -f $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi

# Check as file
new "verify running from start, should be: l,c,y0,y1,y2,y3; y1 and y3 sorted. Note this fails if XML_SORT set to false"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><c><d>hej</d></c><l>hopp</l><y0>d</y0><y0>b</y0><y0>c</y0><y0>a</y0><y1>a</y1><y1>b</y1><y1>c</y1><y1>d</y1><y2><k>d</k><a>bar</a></y2><y2><k>a</k><a>bar</a></y2><y2><k>c</k><a>bar</a></y2><y2><k>b</k><a>bar</a></y2><y3><k>a</k><a>bar</a></y3><y3><k>b</k><a>bar</a></y3><y3><k>c</k><a>bar</a></y3><y3><k>d</k><a>bar</a></y3></data></rpc-reply>]]>]]>$"

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/y2[k='a']\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><y2><k>a</k><a>bar</a></y2></data></rpc-reply>]]>]]>$"

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/y3[k='a']\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><y3><k>a</k><a>bar</a></y3></data></rpc-reply>]]>]]>$"

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/y2[k='b']\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><y2><k>b</k><a>bar</a></y2></data></rpc-reply>]]>]]>$"

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/y3[k='b']\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><y3><k>b</k><a>bar</a></y3></data></rpc-reply>]]>]]>$"

new "delete candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><delete-config><target><candidate/></target></delete-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# LEAF_LISTS

new "add two entries to leaf-list user order"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><y0>c</y0><y0>b</y0></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "add one entry to leaf-list user order"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><y0>a</y0></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "add one entry to leaf-list user order after commit"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><y0>0</y0></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "verify leaf-list user order in running (as entered)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/y0\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><y0>c</y0><y0>b</y0><y0>a</y0><y0>0</y0></data></rpc-reply>]]>]]>$"

# LISTS

new "add two entries to list user order"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><y2><k>c</k><a>bar</a></y2><y2><k>b</k><a>foo</a></y2></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "add one entry to list user order"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><y2><k>a</k><a>fie</a></y2></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "verify list user order (as entered)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/y2\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><y2><k>c</k><a>bar</a></y2><y2><k>b</k><a>foo</a></y2><y2><k>a</k><a>fie</a></y2></data></rpc-reply>]]>]]>$"

pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
