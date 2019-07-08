#!/bin/bash
# Order test. test ordered-by user and ordered-by system.
# For each leaf and leaf-lists, there are two lists,
# one ordered-by user and one ordered by system.
# The ordered-by user MUST be the order it is entered.
# No test of ordered-by system is done yet
# (we may want to sort them alphabetically for better performance).

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/order.yang
tmp=$dir/tmp.x

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"

dbdir=$dir/order

rm -rf $dbdir
if [ ! -d $dbdir ]; then
    mkdir $dbdir
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>/tmp/conf_yang.xml</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
</clixon-config>
EOF

cat <<EOF > $fyang
module order-example{
    yang-version 1.1;
    namespace "urn:example:order";
    prefix exo;
    import clixon-example { /* for state callback */
       prefix ex;
    }
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
    container types{
      description "For testing ordering using other types than strings";
      leaf-list strings{
        type string;
        ordered-by system;
      }
      leaf-list ints{
        type int32;
        ordered-by system;
      }
      list listints{
        ordered-by system;
        key a;
        leaf a {
          type int32;
        }
      }
      leaf-list decs{
        type decimal64{
           fraction-digits 3;
        }
        ordered-by system;
      }
      list listdecs{
        ordered-by system;
        key a;
        leaf a {
          type decimal64{
            fraction-digits 3;
          }
        }
      }
    }
}
EOF

rm -f $dbdir/candidate_db
# alt
cat <<EOF > $dbdir/running_db
<config>
  <y0 xmlns="urn:example:order">d</y0>
  <y1 xmlns="urn:example:order">d</y1>
  <y2 xmlns="urn:example:order"><k>d</k><a>bar</a></y2>
  <y3 xmlns="urn:example:order"><k>d</k><a>bar</a></y3>
  <y0 xmlns="urn:example:order">b</y0>
  <y1 xmlns="urn:example:order">b</y1>
  <c xmlns="urn:example:order"><d>hej</d></c>
  <y0 xmlns="urn:example:order">c</y0>
  <y1 xmlns="urn:example:order">c</y1>
  <y2 xmlns="urn:example:order"><k>a</k><a>bar</a></y2>
  <y3 xmlns="urn:example:order"><k>a</k><a>bar</a></y3>
  <l xmlns="urn:example:order">hopp</l>
  <y0 xmlns="urn:example:order">a</y0>
  <y1 xmlns="urn:example:order">a</y1>
  <y2 xmlns="urn:example:order"><k>c</k><a>bar</a></y2>
  <y3 xmlns="urn:example:order"><k>c</k><a>bar</a></y3>
  <y2 xmlns="urn:example:order"><k>b</k><a>bar</a></y2>
  <y3 xmlns="urn:example:order"><k>b</k><a>bar</a></y3>
</config>
EOF

new "test params: -s running -f $cfg -- -s"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend"
    start_backend -s running -f $cfg -- -s

    new "waiting"
    wait_backend
fi

# STATE (should not be ordered)
new "state data (should be unordered: 42,41,43)"
cat <<EOF > $tmp
<rpc><get><filter type="xpath" select="ex:state" xmlns:ex="urn:example:clixon" /></get></rpc>]]>]]>
EOF
expecteof "$clixon_netconf -qf $cfg" 0 "$(cat $tmp)" '<rpc-reply><data><state xmlns="urn:example:clixon"><op>42</op><op>41</op><op>43</op></state></data></rpc-reply>]]>]]>'

# Check as file
new "verify running from start, should be: c,l,y0,y1,y2,y3; y1 and y3 sorted."
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' '^<rpc-reply><data><c xmlns="urn:example:order"><d>hej</d></c><l xmlns="urn:example:order">hopp</l><y0 xmlns="urn:example:order">d</y0><y0 xmlns="urn:example:order">b</y0><y0 xmlns="urn:example:order">c</y0><y0 xmlns="urn:example:order">a</y0><y1 xmlns="urn:example:order">a</y1><y1 xmlns="urn:example:order">b</y1><y1 xmlns="urn:example:order">c</y1><y1 xmlns="urn:example:order">d</y1><y2 xmlns="urn:example:order"><k>d</k><a>bar</a></y2><y2 xmlns="urn:example:order"><k>a</k><a>bar</a></y2><y2 xmlns="urn:example:order"><k>c</k><a>bar</a></y2><y2 xmlns="urn:example:order"><k>b</k><a>bar</a></y2><y3 xmlns="urn:example:order"><k>a</k><a>bar</a></y3><y3 xmlns="urn:example:order"><k>b</k><a>bar</a></y3><y3 xmlns="urn:example:order"><k>c</k><a>bar</a></y3><y3 xmlns="urn:example:order"><k>d</k><a>bar</a></y3></data></rpc-reply>]]>]]>$'

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y2[exo:k='a']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>]]>]]>" '^<rpc-reply><data><y2 xmlns="urn:example:order"><k>a</k><a>bar</a></y2></data></rpc-reply>]]>]]>$'

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y3[exo:k='a']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>]]>]]>" '^<rpc-reply><data><y3 xmlns="urn:example:order"><k>a</k><a>bar</a></y3></data></rpc-reply>]]>]]>$'

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y2[exo:k='b']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>]]>]]>" '^<rpc-reply><data><y2 xmlns="urn:example:order"><k>b</k><a>bar</a></y2></data></rpc-reply>]]>]]>$'

new "get each ordered-by user leaf-list"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y3[exo:k='b']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>]]>]]>" '^<rpc-reply><data><y3 xmlns="urn:example:order"><k>b</k><a>bar</a></y3></data></rpc-reply>]]>]]>$'

new "delete candidate"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation="delete"/></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# LEAF_LISTS

new "add two entries (c,b) to leaf-list user order"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y0 xmlns="urn:example:order">c</y0><y0 xmlns="urn:example:order">b</y0></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "add one entry (a) to leaf-list user order"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y0 xmlns="urn:example:order">a</y0></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "add one entry (0) to leaf-list user order after commit"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y0 xmlns="urn:example:order">0</y0></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "verify leaf-list user order in running (as entered: c,b,a,0)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source><filter type="xpath" select="/exo:y0" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><y0 xmlns="urn:example:order">c</y0><y0 xmlns="urn:example:order">b</y0><y0 xmlns="urn:example:order">a</y0><y0 xmlns="urn:example:order">0</y0></data></rpc-reply>]]>]]>$'

# LISTS

new "add two entries to list user order"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y2 xmlns="urn:example:order"><k>c</k><a>bar</a></y2><y2 xmlns="urn:example:order"><k>b</k><a>foo</a></y2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "add one entry to list user order"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y2 xmlns="urn:example:order"><k>a</k><a>fie</a></y2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "verify list user order (as entered)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/exo:y2" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><y2 xmlns="urn:example:order"><k>c</k><a>bar</a></y2><y2 xmlns="urn:example:order"><k>b</k><a>foo</a></y2><y2 xmlns="urn:example:order"><k>a</k><a>fie</a></y2></data></rpc-reply>]]>]]>$'

new "Overwrite existing ordered-by user y2->c"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y2 xmlns="urn:example:order">
<k>c</k><a>newc</a>
</y2></config></edit-config></rpc>]]>]]>'

new "Overwrite existing ordered-by user y2->b"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y2 xmlns="urn:example:order">
<k>b</k><a>newb</a>
</y2></config></edit-config></rpc>]]>]]>'

new "Overwrite existing ordered-by user y2->a"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><y2 xmlns="urn:example:order">
<k>a</k><a>newa</a>
</y2></config></edit-config></rpc>]]>]]>'

new "Tests for no duplicates."
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/exo:y2" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><y2 xmlns="urn:example:order"><k>c</k><a>newc</a></y2><y2 xmlns="urn:example:order"><k>b</k><a>newb</a></y2><y2 xmlns="urn:example:order"><k>a</k><a>newa</a></y2></data></rpc-reply>]]>]]>$'

#-- order by type rather than strings.
# there are three leaf-lists:strings, ints, and decimal64, and two lists:
# listints and listdecs
# the strings is there for comparison
# The check is to write the entries as: 10,2,1, and then expect them to
# get back as 1,2,10 (if typed).
new "put strings (10,2,1)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><types xmlns="urn:example:order">
<strings>10</strings><strings>2</strings><strings>1</strings>
</types></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "check string order (1,10,2)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/exo:types/exo:strings" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><types xmlns="urn:example:order"><strings>1</strings><strings>10</strings><strings>2</strings></types></data></rpc-reply>]]>]]>$'

new "put leaf-list int (10,2,1)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><types xmlns="urn:example:order">
<ints>10</ints><ints>2</ints><ints>1</ints>
</types></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "check leaf-list int order (1,2,10)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/exo:types/exo:ints" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><types xmlns="urn:example:order"><ints>1</ints><ints>2</ints><ints>10</ints></types></data></rpc-reply>]]>]]>$'

new "put list int (10,2,1)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><types xmlns="urn:example:order">
<listints><a>10</a></listints><listints><a>2</a></listints><listints><a>1</a></listints>
</types></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "check list int order (1,2,10)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/exo:types/exo:listints" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><types xmlns="urn:example:order"><listints><a>1</a></listints><listints><a>2</a></listints><listints><a>10</a></listints></types></data></rpc-reply>]]>]]>$'

new "put leaf-list decimal64 (10,2,1)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><types xmlns="urn:example:order">
<decs>10.0</decs><decs>2.0</decs><decs>1.0</decs>
</types></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "check leaf-list decimal64 order (1,2,10)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/exo:types/exo:decs" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><types xmlns="urn:example:order"><decs>1.0</decs><decs>2.0</decs><decs>10.0</decs></types></data></rpc-reply>]]>]]>$'

new "put list decimal64 (10,2,1)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><types xmlns="urn:example:order">
<listdecs><a>10.0</a></listdecs><listdecs><a>2.0</a></listdecs><listdecs><a>1.0</a></listdecs>
</types></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "check list decimal64 order (1,2,10)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/exo:types/exo:listdecs" xmlns:exo="urn:example:order"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><types xmlns="urn:example:order"><listdecs><a>1.0</a></listdecs><listdecs><a>2.0</a></listdecs><listdecs><a>10.0</a></listdecs></types></data></rpc-reply>]]>]]>$'

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
