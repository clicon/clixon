#!/usr/bin/env bash
# Order test. test ordered-by user and ordered-by system.
# For each leaf and leaf-lists, there are two lists,
# one ordered-by user and one ordered by system.
# The ordered-by user MUST be the order it is entered.
# No test of ordered-by system is done yet
# (we may want to sort them alphabetically for better performance).
# Also: ordered-by-user and "insert" and "key"/"value" attributes

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/order.yang
fyang2=$dir/clixon-example.yang
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
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
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
      /* Follow list of all int types mostly to get coverage */
      leaf-list myint8{
        type int8;
        ordered-by system;
      }
      leaf-list myint16{
        type int16;
        ordered-by system;
      }
      leaf-list myint32{
        type int32;
        ordered-by system;
      }
      leaf-list myint64{
        type int64;
        ordered-by system;
      }
      leaf-list myuint8{
        type uint8;
        ordered-by system;
      }
      leaf-list myuint16{
        type uint16;
        ordered-by system;
      }
      leaf-list myuint32{
        type uint32;
        ordered-by system;
      }
      leaf-list myuint64{
        type uint64;
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

cat <<EOF > $fyang2
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  /* State data (not config) for the example application*/
  container state {
         config false;
         description "state data for the example application (must be here for example get operation)";
         leaf-list op {
            type string;
         }
  }
}
EOF

rm -f $dbdir/candidate_db
# alt
cat <<EOF > $dbdir/running_db
<${DATASTORE_TOP}>
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
</${DATASTORE_TOP}>
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
fi

new "wait backend"
wait_backend

# STATE (should not be ordered)
#new "state data (should be unordered: 42,41,43)"
# Eeh I changed that to sortered unless STATE_ORDERED_BY_SYSTEM
new "state data (should be ordered: 41,42,43)"

rpc=$(chunked_framing "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"ex:state\" xmlns:ex=\"urn:example:clixon\" /></get></rpc>")

expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "$rpc" "" "<rpc-reply $DEFAULTNS><data><state xmlns=\"urn:example:clixon\"><op>41</op><op>42</op><op>43</op></state></data></rpc-reply>"

# Check as file
new "verify running from start, should be: c,l,y0,y1,y2,y3; y1 and y3 sorted."
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:order\"><d>hej</d></c><l xmlns=\"urn:example:order\">hopp</l><y0 xmlns=\"urn:example:order\">d</y0><y0 xmlns=\"urn:example:order\">b</y0><y0 xmlns=\"urn:example:order\">c</y0><y0 xmlns=\"urn:example:order\">a</y0><y1 xmlns=\"urn:example:order\">a</y1><y1 xmlns=\"urn:example:order\">b</y1><y1 xmlns=\"urn:example:order\">c</y1><y1 xmlns=\"urn:example:order\">d</y1><y2 xmlns=\"urn:example:order\"><k>d</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>a</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>c</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>b</k><a>bar</a></y2><y3 xmlns=\"urn:example:order\"><k>a</k><a>bar</a></y3><y3 xmlns=\"urn:example:order\"><k>b</k><a>bar</a></y3><y3 xmlns=\"urn:example:order\"><k>c</k><a>bar</a></y3><y3 xmlns=\"urn:example:order\"><k>d</k><a>bar</a></y3></data></rpc-reply>"

new "get each ordered-by user leaf-list"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y2[exo:k='a']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y2 xmlns=\"urn:example:order\"><k>a</k><a>bar</a></y2></data></rpc-reply>"

new "get each ordered-by user leaf-list"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y3[exo:k='a']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y3 xmlns=\"urn:example:order\"><k>a</k><a>bar</a></y3></data></rpc-reply>"

new "get each ordered-by user leaf-list"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y2[exo:k='b']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y2 xmlns=\"urn:example:order\"><k>b</k><a>bar</a></y2></data></rpc-reply>"

new "get each ordered-by user leaf-list"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y3[exo:k='b']\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y3 xmlns=\"urn:example:order\"><k>b</k><a>bar</a></y3></data></rpc-reply>"

new "delete candidate"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation=\"delete\"/></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# LEAF_LISTS

new "add two entries (c,b) to leaf-list user order"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\">c</y0><y0 xmlns=\"urn:example:order\">b</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (a) to leaf-list user order"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\">a</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (0) to leaf-list user order after commit"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\">0</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "verify leaf-list user order in running (as entered: c,b,a,0)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/exo:y0\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y0 xmlns=\"urn:example:order\">c</y0><y0 xmlns=\"urn:example:order\">b</y0><y0 xmlns=\"urn:example:order\">a</y0><y0 xmlns=\"urn:example:order\">0</y0></data></rpc-reply>"

# LISTS

new "add two entries to list user order"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\"><k>c</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>b</k><a>foo</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry to list user order"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\"><k>a</k><a>fie</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "verify list user order (as entered)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/exo:y2\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y2 xmlns=\"urn:example:order\"><k>c</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>b</k><a>foo</a></y2><y2 xmlns=\"urn:example:order\"><k>a</k><a>fie</a></y2></data></rpc-reply>"

new "Overwrite existing ordered-by user y2->c"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\">
<k>c</k><a>newc</a>
</y2></config></edit-config></rpc>"

new "Overwrite existing ordered-by user y2->b"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\">
<k>b</k><a>newb</a>
</y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Overwrite existing ordered-by user y2->a"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\">
<k>a</k><a>newa</a>
</y2></config></edit-config></rpc>"

new "Tests for no duplicates."
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/exo:y2\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y2 xmlns=\"urn:example:order\"><k>c</k><a>newc</a></y2><y2 xmlns=\"urn:example:order\"><k>b</k><a>newb</a></y2><y2 xmlns=\"urn:example:order\"><k>a</k><a>newa</a></y2></data></rpc-reply>"

#-- order by type rather than strings.
# there are three leaf-lists:strings, ints, and decimal64, and two lists:
# listints and listdecs
# the strings is there for comparison
# The check is to write the entries as: 10,2,1, and then expect them to
# get back as 1,2,10 (if typed).
new "put strings (10,2,1)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><types xmlns=\"urn:example:order\">
<strings>10</strings><strings>2</strings><strings>1</strings>
</types></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check string order (1,10,2)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/exo:types/exo:strings\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><types xmlns=\"urn:example:order\"><strings>1</strings><strings>10</strings><strings>2</strings></types></data></rpc-reply>"

for s in int uint; do
    for t in 8 16 32 64; do
	type=$s$t
	new "put leaf-list $type (10,2,1)"
	expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><types xmlns=\"urn:example:order\">
<my$type>10</my$type><my$type>2</my$type><my$type>1</my$type>
</types></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

	new "check leaf-list $type order (1,2,10)"
	expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/exo:types/exo:my$type\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><types xmlns=\"urn:example:order\"><my$type>1</my$type><my$type>2</my$type><my$type>10</my$type></types></data></rpc-reply>"
    done
done

new "netconf validate ints"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "put list int (10,2,1)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><types xmlns=\"urn:example:order\">
<listints><a>10</a></listints><listints><a>2</a></listints><listints><a>1</a></listints>
</types></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check list int order (1,2,10)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/exo:types/exo:listints\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><types xmlns=\"urn:example:order\"><listints><a>1</a></listints><listints><a>2</a></listints><listints><a>10</a></listints></types></data></rpc-reply>"

new "put leaf-list decimal64 (10,2,1)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><types xmlns=\"urn:example:order\">
<decs>10.0</decs><decs>2.0</decs><decs>1.0</decs>
</types></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check leaf-list decimal64 order (1,2,10)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/exo:types/exo:decs\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><types xmlns=\"urn:example:order\"><decs>1.0</decs><decs>2.0</decs><decs>10.0</decs></types></data></rpc-reply>"

new "put list decimal64 (10,2,1)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><types xmlns=\"urn:example:order\">
<listdecs><a>10.0</a></listdecs><listdecs><a>2.0</a></listdecs><listdecs><a>1.0</a></listdecs>
</types></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check list decimal64 order (1,2,10)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/exo:types/exo:listdecs\" xmlns:exo=\"urn:example:order\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><types xmlns=\"urn:example:order\"><listdecs><a>1.0</a></listdecs><listdecs><a>2.0</a></listdecs><listdecs><a>10.0</a></listdecs></types></data></rpc-reply>"

new "delete candidate"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation=\"delete\"/></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# leaf-list ordered-by-user, "insert" and "value" attributes
# y0 is leaf-list ordered by user
new "add one entry (c) to leaf-list"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\">c</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (a) to leaf-list first (with no yang namespace - error)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" yang:insert=\"first\">a</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-attribute</error-tag><error-info><bad-attribute>insert</bad-attribute></error-info><error-severity>error</error-severity><error-message>Unresolved attribute prefix (no namespace?)</error-message></rpc-error></rpc-reply>"

new "add one entry (b) to leaf-list first"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"first\">b</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (d) to leaf-list last"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"last\">d</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (a) to leaf-list first"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"first\">a</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (e) to leaf-list last"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"last\">e</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check ordered-by-user: a,b,c,d,e"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y0 xmlns=\"urn:example:order\">a</y0><y0 xmlns=\"urn:example:order\">b</y0><y0 xmlns=\"urn:example:order\">c</y0><y0 xmlns=\"urn:example:order\">d</y0><y0 xmlns=\"urn:example:order\">e</y0></data></rpc-reply>"

new "move one entry (e) to leaf-list first"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 nc:operation=\"replace\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"first\">e</y0></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check ordered-by-user: e,a,b,c,d"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y0 xmlns=\"urn:example:order\">e</y0><y0 xmlns=\"urn:example:order\">a</y0><y0 xmlns=\"urn:example:order\">b</y0><y0 xmlns=\"urn:example:order\">c</y0><y0 xmlns=\"urn:example:order\">d</y0></data></rpc-reply>"

# before and after and value attribute
new "add one leaf-list entry 71 before b"
XML="<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"before\" yang:value=\"b\">71</y0></config></edit-config></rpc>"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "$XML" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry 42 after b"
XML="<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"after\" yang:value=\"b\">42</y0></config></edit-config></rpc>"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "$XML" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# XXX actually not right error message, should be as RFC7950 Sec 15.7
new "add one entry 99 after Q (not found, error)"
XML="<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y0 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"after\" yang:value=\"Q\">99</y0></config></edit-config></rpc>"

expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "$XML" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>bad-attribute: value, missing-instance: Q</error-message></rpc-error></rpc-reply>"

new "check ordered-by-user: e,a,71,b,42,c,d"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y0 xmlns=\"urn:example:order\">e</y0><y0 xmlns=\"urn:example:order\">a</y0><y0 xmlns=\"urn:example:order\">71</y0><y0 xmlns=\"urn:example:order\">b</y0><y0 xmlns=\"urn:example:order\">42</y0><y0 xmlns=\"urn:example:order\">c</y0><y0 xmlns=\"urn:example:order\">d</y0></data></rpc-reply>"

new "delete candidate"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation=\"delete\"/></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# list ordered-by-user, "insert" and "value" attributes
# y2 is list ordered by user
new "add one entry (key c) to list"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\"><k>c</k><a>foo</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (key a) to list first (with no yang namespace - error)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" yang:insert=\"first\"><k>a</k><a>foo</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-attribute</error-tag><error-info><bad-attribute>insert</bad-attribute></error-info><error-severity>error</error-severity><error-message>Unresolved attribute prefix (no namespace?)</error-message></rpc-error></rpc-reply>"

new "add one entry (key b) to list first"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"first\"><k>b</k><a>bar</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (d) to list last"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"last\"><k>d</k><a>fie</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (a) to list first"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"first\"><k>a</k><a>foo</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry (e) to list last"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"last\"><k>e</k><a>bar</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check ordered-by-user: a,b,c,d,e"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y2 xmlns=\"urn:example:order\"><k>a</k><a>foo</a></y2><y2 xmlns=\"urn:example:order\"><k>b</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>c</k><a>foo</a></y2><y2 xmlns=\"urn:example:order\"><k>d</k><a>fie</a></y2><y2 xmlns=\"urn:example:order\"><k>e</k><a>bar</a></y2></data></rpc-reply>"

new "move one entry (e) to list first"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"first\"><k>e</k><a>bar</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check ordered-by-user: e,a,b,c,d"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y2 xmlns=\"urn:example:order\"><k>e</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>a</k><a>foo</a></y2><y2 xmlns=\"urn:example:order\"><k>b</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>c</k><a>foo</a></y2><y2 xmlns=\"urn:example:order\"><k>d</k><a>fie</a></y2></data></rpc-reply>"

# before and after and key attribute
new "add one entry 71 before key b"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"before\" yang:key=\"[k='b']\"><k>71</k><a>fie</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "add one entry 42 after key b"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"after\" yang:key=\"[k='b']\"><k>42</k><a>fum</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# XXX actually not right error message, should be as RFC7950 Sec 15.7
new "add one entry key 99 after Q (not found, error)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><y2 xmlns=\"urn:example:order\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang:insert=\"after\" yang:key=\"Q\"><k>99</k><a>bar</a></y2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>bad-attribute: key, missing-instance: Q</error-message></rpc-error></rpc-reply>"

new "check ordered-by-user: e,a,71,b,42,c,d"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><y2 xmlns=\"urn:example:order\"><k>e</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>a</k><a>foo</a></y2><y2 xmlns=\"urn:example:order\"><k>71</k><a>fie</a></y2><y2 xmlns=\"urn:example:order\"><k>b</k><a>bar</a></y2><y2 xmlns=\"urn:example:order\"><k>42</k><a>fum</a></y2><y2 xmlns=\"urn:example:order\"><k>c</k><a>foo</a></y2><y2 xmlns=\"urn:example:order\"><k>d</k><a>fie</a></y2></data></rpc-reply>"

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

# unset conditional parameters 
unset format

new "endtest"
endtest
