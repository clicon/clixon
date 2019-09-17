#!/usr/bin/env bash
# Range type tests.
# Mainly error messages and multiple ranges
# Tests all int types including decimal64 and string length ranges
# See also test_type.sh

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Which format to use as datastore format internally
: ${format:=xml}

cfg=$dir/conf_yang.xml
fyang=$dir/type.yang
dclispec=$dir/clispec/

# XXX: add more types, now only uint8 and int8
cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   typedef tint8{
      type int8{
         range "1..10 | 14..20";
      }
   }
   typedef tint16{
      type int16{
         range "1..10 | 14..20";
      }
   }
   typedef tint32{
      type int32{
         range "1..10 | 14..20";
      }
   }
   typedef tint64{
      type int64{
         range "1..10 | 14..20";
      }
   }
   typedef tuint8{
      type uint8{
         range "1..10 | 14..20";
      }
   }
   typedef tuint16{
      type uint16{
         range "1..10 | 14..20";
      }
   }
   typedef tuint32{
      type uint32{
         range "1..10 | 14..20";
      }
   }
   typedef tuint64{
      type uint64{
         range "1..10 | 14..20";
      }
   }
   typedef tdecimal64{
      type decimal64{
         fraction-digits 3;
         range "1..10 | 14..20";
      }
   }
   typedef tstring{
      type string{
         length "1..10 | 14..20";
      }
   }
  /* here follows constrained ints */
   leaf lint8 {
       type tint8;
   }
   leaf lint16 {
       type tint16;
   }
   leaf lint32 {
       type tint32;
   }
   leaf lint64 {
       type tint64;
   }
   leaf luint8 {
       type tuint8;
   }
   leaf luint16 {
       type tuint16;
   }
   leaf luint32 {
       type tuint32;
   }
   leaf luint64 {
       type tuint64;
   }
   leaf ldecimal64 {
       type tdecimal64;
   }
   leaf lstring {
       type tstring;
   }
  /* here follows unlimited ints */
   leaf rint8 {
       type int8;
   }
   leaf rint16 {
       type int16;
   }
   leaf rint32 {
       type int32;
   }
   leaf rint64 {
       type int64;
   }
   leaf ruint8 {
       type uint8;
   }
   leaf ruint16 {
       type uint16;
   }
   leaf ruint32 {
       type uint32;
   }
   leaf ruint64 {
       type uint64;
   }
   leaf rdecimal64 {
       type decimal64{
          fraction-digits 3;
       }
   }
}
EOF

mkdir $dclispec

# clispec for both generated cli and a hardcoded range check
cat <<EOF > $dclispec/clispec.cli
   CLICON_MODE="example";
   CLICON_PROMPT="%U@%H> ";
   CLICON_PLUGIN="example_cli";

   # Manually added (not generated)
   manual hint8   <id:int8  range[1:10]   range[14:20]>;
   manual hint16  <id:int16 range[1:10]  range[14:20]>;
   manual hint32  <id:int32 range[1:10]  range[14:20]>;
   manual hint64  <id:int64 range[1:10]  range[14:20]>;

   manual huint8  <id:uint8 range[1:10]  range[14:20]>;
   manual huint16 <id:uint16 range[1:10] range[14:20]>;
   manual huint32 <id:uint32 range[1:10] range[14:20]>;
   manual huint64 <id:uint64 range[1:10] range[14:20]>;

   manual hdecimal64 <id:decimal64 range[1:10] range[14:20]>;

   manual hstring <id:string length[1:10] length[14:20]>;

   # Generated cli
   set @datamodel, cli_set();
   merge @datamodel, cli_merge();
   create @datamodel, cli_create();
   show, cli_show_config("candidate", "text", "/");
   quit("Quit"), cli_quit();
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$dclispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
</clixon-config>
EOF

# Type range tests.
# Parameters: 1: type (eg uint8)
#             2: val OK
#             3: eval Invalid value
#             4: post (eg .000 - special for decimal64, others should have "")
testrange(){
    t=$1
    val=$2
    eval=$3
    post=$4

    if [ $t = "string" ]; then # special case for string type error msg
	len=$(echo -n "$eval" | wc -c)
	errmsg="String length $len out of range: 1$post - 10$post, 14$post - 20$post"
    else
	errmsg="Number $eval$post out of range: 1$post - 10$post, 14$post - 20$post"
    fi

    new "generated cli set $t leaf invalid"
    expectfn "$clixon_cli -1f $cfg -l o set l$t $eval" 255 "$errmsg";

    new "generated cli set $t leaf OK"
    expectfn "$clixon_cli -1f $cfg -l o set l$t $val" 0 '^$'

    # XXX Error in cligen order: Unknown command vs Number out of range
    # olof@vandal> set luint8 0
    # CLI syntax error: "set luint8 0": Number 0 is out of range: 14 - 20
    # olof@vandal> set luint8 1
    # olof@vandal> set luint8 0
    # CLI syntax error: "set luint8 0": Unknown command
# (SAME AS FIRST ^)
    new "generated cli set $t leaf invalid"
    expectfn "$clixon_cli -1f $cfg -l o set l$t $eval" 255 "$errmsg"
    
    new "manual cli set $t leaf OK"
    expectfn "$clixon_cli -1f $cfg -l o man h$t $val" 0 '^$'

    new "manual cli set $t leaf invalid"
    echo "$clixon_cli -1f $cfg -l o set h$t $eval"
    expectfn "$clixon_cli -1f $cfg -l o set l$t $eval" 255 "$errmsg"
    
    new "discard"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    new "Netconf set invalid $t leaf"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><l$t xmlns=\"urn:example:clixon\">$eval</l$t></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    new "netconf get config"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><l$t xmlns=\"urn:example:clixon\">$eval</l$t></data></rpc-reply>]]>]]>$"

    new "netconf validate invalid range"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>l$t</bad-element></error-info><error-severity>error</error-severity><error-message>$errmsg</error-message></rpc-error></rpc-reply>]]>]]>$"

    new "discard"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
}

# Type unlimited value range test. Only test invalid number out of range of type
# Parameters: 1: type (eg uint8)
#             2: val 
#             3: post (eg .000 - special for decimal64, others should have "")
testunlimit(){
    t=$1
    val=$2
    rmin=$3
    rmax=$4
    post=$5
    
    errmsg="Number $val$post out of range: $rmin$post - $rmax$post"
    
    new "Netconf set invalid $t leaf"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><r$t xmlns=\"urn:example:clixon\">$val</r$t></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
    
    new "netconf validate invalid range"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>r$t</bad-element></error-info><error-severity>error</error-severity><error-message>$errmsg</error-message></rpc-error></rpc-reply>]]>]]>$"

    new "discard"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
}

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
    
    new "waiting"
    wait_backend
fi

new "test params: -f $cfg"

# Test all int types
testunlimit int8 300 -128 127 ""
testunlimit int16 73000 -32768 32767 ""
testunlimit int32 4900000000 -2147483648 2147483647 ""
testunlimit int64 49739274983274983274983274 -9223372036854775808 9223372036854775807 ""
testunlimit uint8 300 0 255 ""
testunlimit uint16 73000 0 65535 ""
testunlimit uint32 4900000000 0 4294967295 ""
testunlimit uint64 49739274983274983274983274 0 18446744073709551615 ""
#testunlimit decimal64 49739274983274983274983274  -9223372036854775808 9223372036854775807 ".000"

# Test all int types
for t in int8 int16 int32 int64 uint8 uint16 uint32 uint64; do
    testrange $t 1 0 ""
done

# decimal64 requires 3 decimals as postfix
testrange decimal64 1 0 ".000"

# test string with lengthlimit
testrange string "012" "01234567890" ""

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
