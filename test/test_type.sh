#!/usr/bin/env bash
# Advanced union types and generated code
# and enum w values
# The test is run three times, with dbcache turned on, cache off and zero-copy
# It is the only test with dbcache off.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Which format to use as datastore format internally
: ${format:=xml}

cfg=$dir/conf_yang.xml
fyang=$dir/type.yang
fyang2=$dir/example2.yang
fyang3=$dir/example3.yang

# Generate autocli for these modules
AUTOCLI=$(autocli_config ${APPNAME}\* kw-nokey false)

# transitive type, exists in fyang3, referenced from fyang2, but not declared in fyang
cat <<EOF > $fyang3
module example3{
  prefix ex3;
  namespace "urn:example:example3";
  typedef w{
    type union{
       type int32{
          range "4..44";
       }
    }
  }
  typedef u{
     type union {
       type w;
       type enumeration {
         enum bounded;
       }
     }
  }
  typedef t{
    type string{
      pattern '[a-z][0-9]*';
    }
  }
}
EOF
cat <<EOF > $fyang2
module example2{
  namespace "urn:example:example2";
  prefix ex2;
  import example3 { prefix ex3; }
  grouping gr2 {
    leaf talle{
      type ex3:t;
    }
    leaf ulle{
      type ex3:u;
    }
  }
}
EOF
cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import example2 { prefix ex2; }
   typedef ab {
       type string {
         pattern
           '(([a-b])\.){3}[a-b]';
       }
   }
   typedef cd {
       type string {
         pattern
           '(([c-d])\.){3}[c-d]';
       }
   }
   typedef ef {
       type string {
         pattern
           '(([e-f])\.){3}[e-f]';
         length "1..253";
       }
   }
   typedef ad {
       type union {
         type ab;
         type cd;
       }
   }
   typedef af {
       type union {
         type ad;
         type ef;
       }
   }
   list list {
     key ip;
     leaf ip {
         type af; 
     }
   }
   leaf status {
      type enumeration {
         enum up {
            value 1;
         }
         enum down;
      }
   }
   leaf num0 {
       type int32;
   }
   leaf num1 {
       type int32 {
       range "1";
      }
   }
   leaf num2 { /* range and blanks */
       type int32 {
         range " 4 .. 4000 ";
      }
   }
   leaf num3 {
       type uint8 {
         range "min..max";
      }
   }
   leaf num4 { 
       type uint8 {
         range "1..2 |  42..50";
      }
   }
   leaf dec { 
       /* For test of multiple ranges with decimal64. More than 2, single range*/
       type decimal64 {
         fraction-digits 3;
         range "-3.5..-2.5 | 0.0 | 10.0..20.0";
      }
   }
   leaf len1 {
       type string {
       length "2";
      }
   }
   leaf len2 {
       type string {
         length " 4 .. 4000 ";
      }
   }
   leaf len3 {
       type string {
         length "min..max";
      }
   }
   leaf len4 {
       type string {
         length "2  ..  3 |  20..29";
      }
   }
   typedef mybits {
        description "Test adding several bits";
	type bits {
	    bit create;
	    bit read;
	    bit write;
        }
   }
   leaf mbits{
      type mybits;
   }
  container c{
    description "transitive type- exists in ex3";
    uses 'ex2:gr2';
  }
  leaf digit4{
     type string {
         pattern '\d{4}';
       }
  }
  leaf word4{
     type string {
         pattern '\w{4}';
       }
  }
  leaf minus{
      description "Problem with minus";
      type string{
         pattern '[a-zA-Z_][a-zA-Z0-9_\-.]*';
      }
  }
  leaf bool {
     description "For testing different truth values in CLI";
     type boolean;
  }
  container manc{
    presence true;
    description "mandatory test";
    leaf man{
      type string;
      mandatory true;
    }
  }
}
EOF

# Type tests.
# Parameters:
# 1: dbcache: cache, nocache, cache-zerocopy
function testrun(){
    dbcache=$1
    new "test params: -f $cfg  # dbcache: $dbcache"

    cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_DATASTORE_CACHE>$dbcache</CLICON_DATASTORE_CACHE>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  ${AUTOCLI}
</clixon-config>
EOF

    if [ $BE -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s init -f $cfg"
	start_backend -s init -f $cfg
    fi

    new "wait backend"
    wait_backend

    new "cli set transitive string. type is alpha followed by number and is defined in three levels of modules"
    expectpart "$($clixon_cli -1f $cfg -l o set c talle x99)" 0 '^$'

    new "cli set transitive string error. Wrong type"
    expectpart "$($clixon_cli -1f $cfg -l o set c talle 9xx)" 255 '^CLI syntax error: "set c talle 9xx": "9xx" is invalid input for cli command: talle$'

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf set transitive string error"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><talle>9xx</talle></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate should fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>talle</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail:" ""

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "cli set transitive union int (ulle should accept 4.44|bounded|unbounded)"
    expectpart "$($clixon_cli -1f $cfg -l o set c ulle 33)" 0 '^$'

    new "cli validate"
    expectpart "$($clixon_cli -1f $cfg -l o -l o validate)" 0 '^$'

    new "cli validate"
    expectpart "$($clixon_cli -1f $cfg -l o -l o validate)" 0 '^$'

    new "cli set transitive union error. should fail"
    expectpart "$($clixon_cli -1f $cfg -l o set c ulle kalle)" 255 "^CLI syntax error: \"set c ulle kalle\": 'kalle' is not a number$"

    new "cli set transitive union error int"
    expectpart "$($clixon_cli -1f $cfg -l o set c ulle 55)" 255 '^CLI syntax error: "set c ulle 55": Number 55 out of range: 4 - 44$'

    new "netconf set transitive union error int"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><ulle>55</ulle></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate should fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>ulle</bad-element></error-info><error-severity>error</error-severity><error-message>'55' does not match enumeration</error-message></rpc-error></rpc-reply>"

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #-----------

    new "cli set ab"
    expectpart "$($clixon_cli -1f $cfg -l o set list a.b.a.b)" 0 '^$'

    new "cli set cd"
    expectpart "$($clixon_cli -1f $cfg -l o set list c.d.c.d)" 0 '^$'

    new "cli set ef"
    expectpart "$($clixon_cli -1f $cfg -l o set list e.f.e.f)" 0 '^$'

    new "cli set ab fail"
    expectpart "$($clixon_cli -1f $cfg -l o set list "a&b&a&b")" 255 "^CLI syntax error"

    new "cli set ad fail"
    expectpart "$($clixon_cli -1f $cfg -l o set list a.b.c.d)" 255 "^CLI syntax error"

    new "cli validate"
    expectpart "$($clixon_cli -1f $cfg -l o -l o validate)" 0 '^$'

    new "cli commit"
    expectpart "$($clixon_cli -1f $cfg -l o -l o commit)" 0 '^$'

    new "netconf validate ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf set ab wrong"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><list xmlns=\"urn:example:clixon\"><ip>a.b&amp; c.d</ip></list></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error>" ""

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf commit"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "cli enum value"
    expectpart "$($clixon_cli -1f $cfg -l o set status down)" 0 '^$'

    new "cli bits value"
    expectpart "$($clixon_cli -1f $cfg -l o set mbits create)" 0 '^$'

    #XXX No, cli cant assign two bit values
    #new "cli bits two values"
    #expectpart "$($clixon_cli -1f $cfg -l o set mbits \)"create read\"" 0 '^$'

    new "netconf bits two values"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><mbits xmlns=\"urn:example:clixon\">create read</mbits></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "cli bits validate"
    expectpart "$($clixon_cli -1f $cfg -l o validate)" 0 '^$'

    #-------- num0 empty value

    new "netconf num0 no value"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num0 xmlns=\"urn:example:clixon\"/></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate no value wrong"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num0</bad-element></error-info><error-severity>error</error-severity><error-message>Invalid NULL value</error-message></rpc-error></rpc-reply>"

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #-------- num1 single range (1)

    new "cli range test num1 1 OK"
    expectpart "$($clixon_cli -1f $cfg -l o set num1 1)" 0 '^$'

    #new "cli range test num1 -100 ok" # XXX -/minus cant be given as argv
    #expectpart "$($clixon_cli -1f $cfg -l o set num1 \-100)" 0 '^$'

    new "cli range test num1 2 error"
    expectpart "$($clixon_cli -1f $cfg -l o set num1 2)" 255 '^CLI syntax error: "set num1 2": Number 2 out of range: 1 - 1$'

    new "netconf range set num1 -1"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num1 xmlns=\"urn:example:clixon\">-1</num1></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num1 -1 wrong"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num1</bad-element></error-info><error-severity>error</error-severity><error-message>Number -1 out of range: 1 - 1</error-message></rpc-error></rpc-reply>"

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #-------- num2 range and blanks

    new "cli range test num2 3 error"
    expectpart "$($clixon_cli -1f $cfg -l o set num2 3)" 255 '^CLI syntax error: "set num2 3": Number 3 out of range: 4 - 4000$'

    new "cli range test num2 1000 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set num2 1000)" 0 '^$'

    new "cli range test num2 5000 error"
    expectpart "$($clixon_cli -1f $cfg -l o set num2 5000)" 255 '^CLI syntax error: "set num2 5000": Number 5000 out of range: 4 - 4000$'

    new "netconf range set num2 3 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num2 xmlns=\"urn:example:clixon\">3</num2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num2 3 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num2</bad-element></error-info><error-severity>error</error-severity><error-message>Number 3 out of range: 4 - 4000</error-message></rpc-error></rpc-reply>"

    new "netconf range set num2 1000 ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num2 xmlns=\"urn:example:clixon\">1000</num2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num2 1000 ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range set num2 5000 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num2 xmlns=\"urn:example:clixon\">5000</num2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num2 5000 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num2</bad-element></error-info><error-severity>error</error-severity><error-message>Number 5000 out of range: 4 - 4000</error-message></rpc-error></rpc-reply>"

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #-------- num3 min max range

    new "cli range test num3 42 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set num3 42)" 0 '^$'

    new "cli range test num3 260 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set num3 260)" 255 '^CLI syntax error: "set num3 260": Number 260 out of range: 0 - 255$'

    new "cli range test num3 -1 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set num3 -1)" 255 "CLI syntax error:"

    new "netconf range set num3 260 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num3 xmlns=\"urn:example:clixon\">260</num3></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num3 260 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num3</bad-element></error-info><error-severity>error</error-severity><error-message>Number 260 out of range: 0 - 255</error-message></rpc-error></rpc-reply>"

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #-------- num4 multiple ranges 1..2 |  42..50

    new "cli range test num4 multiple 0 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set num4 0)" 255 '^CLI syntax error: "set num4 0": Number 0 out of range: 1 - 2, 42 - 50$'

    new "cli range test num4 multiple 2 ok"
    expectpart "$($clixon_cli -1f $cfg -l e set num4 2)" 0 '^$'

    new "cli range test num4 multiple 20 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set num4 20)" 255 '^CLI syntax error: "set num4 20": Number 20 out of range: 1 - 2, 42 - 50$'

    new "cli range test num4 multiple 42 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set num4 42)" 0 '^$'

    new "cli range test num4 multiple 99 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set num4 99)" 255 '^CLI syntax error: "set num4 99": Number 99 out of range: 1 - 2, 42 - 50$'

    new "netconf range set num4 multiple 2"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num4 xmlns=\"urn:example:clixon\">42</num4></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num4 OK"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range set num4 multiple 20"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num4 xmlns=\"urn:example:clixon\">42</num4></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num4 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range set num4 multiple 42"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><num4 xmlns=\"urn:example:clixon\">42</num4></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate num4 fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #-------- dec64 multiple ranges -3.5..-2.5 | 0.0 | 10.0..20.0
    # XXX how to enter negative numbers in bash string and cli -1?
    new "cli range dec64 multiple 0 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set dec 0)" 0 '^$'

    new "cli range dec64 multiple 0.1 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set num4 0.1)" 255 '^CLI syntax error: "set num4 0.1": '"'"'0.1'"'"' is not a number$'

    new "cli range dec64 multiple 15.0 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set dec 15.0)" 0 '^$'

    new "cli range dec64 multiple 30.0 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set dec 30.0)" 255 '^CLI syntax error: "set dec 30.0": Number 30.000 out of range: -3.500 - -2.500, 0.000 - 0.000, 10.000 - 20.000$'

    new "dec64 discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    # Same with netconf
    new "netconf range dec64 -3.59"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><dec xmlns=\"urn:example:clixon\">-3.59</dec></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 -3.59 validate fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number -3.590 out of range" ""

    new "netconf range dec64 -3.5"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><dec xmlns=\"urn:example:clixon\">-3.500</dec></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 -3.5 validate ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 -2"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><dec xmlns=\"urn:example:clixon\">-2</dec></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 -2 validate fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number -2.000 out of range" ""

    new "netconf range dec64 -0.001"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><dec xmlns=\"urn:example:clixon\">-0.001</dec></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 -0.001 validate fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number -0.001 out of range" ""

    new "netconf range dec64 0.0"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><dec xmlns=\"urn:example:clixon\">0.0</dec></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 0.0 validate ok"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 +0.001"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><dec xmlns=\"urn:example:clixon\">+0.001</dec></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf range dec64 +0.001 validate fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number 0.001 out of range" ""

    #----------------string ranges---------------------
    #-------- len1 single range (2)
    new "cli length test len1 1 fail"
    expectpart "$($clixon_cli -1f $cfg -l o set len1 x)" 255 '^CLI syntax error: "set len1 x": String length 1 out of range: 2 - 2$'

    new "cli length test len1 2 OK"
    expectpart "$($clixon_cli -1f $cfg -l o set len1 xy)" 0 '^$'

    new "cli length test len1 3 error"
    expectpart "$($clixon_cli -1f $cfg -l o set len1 hej)" 255 '^CLI syntax error: "set len1 hej": String length 3 out of range: 2 - 2$'

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf length set len1 1"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><len1 xmlns=\"urn:example:clixon\">x</len1></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate len1 1 wrong"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>len1</bad-element></error-info><error-severity>error</error-severity><error-message>String length 1 out of range: 2 - 2</error-message></rpc-error></rpc-reply>"

    #-------- len2 range and blanks

    new "cli length test len2 3 error"
    expectpart "$($clixon_cli -1f $cfg -l o set len2 ab)" 255 '^CLI syntax error: "set len2 ab": String length 2 out of range: 4 - 4000$'

    new "cli length test len2 42 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set len2 hejhophdsakjhkjsadhkjsahdkjsad)" 0 '^$'

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #-------- len3 min max range

    new "cli range ptest len3 42 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set len3 hsakjdhkjsahdkjsahdksahdksajdhsakjhd)" 0 '^$'

    #-------- len4 multiple ranges 2..3 |  20-29
    new "cli length test len4 1 error"
    expectpart "$($clixon_cli -1f $cfg -l o set len4 a)" 255 '^CLI syntax error: "set len4 a": String length 1 out of range: 2 - 3, 20 - 29$'

    new "cli length test len4 2 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set len4 ab)" 0 '^$'

    new "cli length test len4 10 error"
    expectpart "$($clixon_cli -1f $cfg -l o set len4 abcdefghij)" 255 '^CLI syntax error: "set len4 abcdefghij": String length 10 out of range: 2 - 3, 20 - 29$'

    new "cli length test len4 20 ok"
    expectpart "$($clixon_cli -1f $cfg -l o set len4 abcdefghijabcdefghija)" 0 '^$'

    new "cli length test len4 30 error"
    expectpart "$($clixon_cli -1f $cfg -l o set len4 abcdefghijabcdefghijabcdefghij)" 255 '^CLI syntax error: "set len4 abcdefghijabcdefghijabcdefghij": String length 30 out of range: 2 - 3, 20 - 29$'

    # XSD schema -> POSIX ECE translation
    new "cli yang pattern \d ok"
    expectpart "$($clixon_cli -1f $cfg -l o set digit4 0123)" 0 '^$'

    new "cli yang pattern \d error"
    expectpart "$($clixon_cli -1f $cfg -l o set digit4 01b2)" 255 '^CLI syntax error: "set digit4 01b2": "01b2" is invalid input for cli command: digit4$'

    new "cli yang pattern \w ok"
    expectpart "$($clixon_cli -1f $cfg -l o set word4 abc9)" 0 '^$'

    new "cli yang pattern \w error"
    expectpart "$($clixon_cli -1f $cfg -l o set word4 ab%3)" 255 '^CLI syntax error: "set word4 ab%3": "ab%3" is invalid input for cli command: word4$'

    new "netconf pattern \w"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><word4 xmlns=\"urn:example:clixon\">aXG9</word4></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf pattern \w valid"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf pattern \w error"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><word4 xmlns=\"urn:example:clixon\">ab%d3</word4></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf pattern \w invalid"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>word4</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail:" ""

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #------ Mandatory

    new "netconf set container w/o mandatory leaf"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><manc xmlns=\"urn:example:clixon\"/></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate should fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>man</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory variable of manc in module example</error-message></rpc-error></rpc-reply>"

    new "netconf set container with mandatory leaf"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><manc xmlns=\"urn:example:clixon\"><man>foo</man></manc></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf commit"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf delete mandatory variable"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><manc xmlns=\"urn:example:clixon\"><man nc:operation=\"delete\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\">foo</man></manc></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "get mandatory"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/ex:manc\" xmlns:ex=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><manc xmlns=\"urn:example:clixon\"/></data></rpc-reply>"

    new "netconf validate should fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>missing-element</error-tag><error-info><bad-element>man</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory variable of manc in module example</error-message></rpc-error></rpc-reply>"

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #------ minus

    new "type with minus"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><minus xmlns=\"urn:example:clixon\">my-name</minus></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "validate minus"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    #new "cli type with minus"
    #expectpart "$($clixon_cli -1f $cfg -l o set name my-name)" 0 "^$"

    #------ cli truth-values: true/on/enable false/off/disable

    new "cli truth: true"
    expectpart "$($clixon_cli -1f $cfg -l o set bool true)" 0 "^$"
    new "cli truth: false"
    expectpart "$($clixon_cli -1f $cfg -l o set bool false)" 0 "^$"
    new "cli truth: on"
    expectpart "$($clixon_cli -1f $cfg -l o set bool on)" 0 "^$"
    new "cli verify on translates to true"
    expectpart "$($clixon_cli -1f $cfg -l o show conf)" 0 "bool true;"
    new "cli truth: off"
    expectpart "$($clixon_cli -1f $cfg -l o set bool off)" 0 "^$"
    new "cli verify off translates to false"
    expectpart "$($clixon_cli -1f $cfg -l o show conf)" 0 "bool false;"
    new "cli truth: enable"
    expectpart "$($clixon_cli -1f $cfg -l o set bool enable)" 0 "^$"
    new "cli truth: disable"
    expectpart "$($clixon_cli -1f $cfg -l o set bool disable)" 0 "^$"
    new "cli truth: wrong"
    expectpart "$($clixon_cli -1f $cfg -l o set bool wrong)" 255 "'wrong' is not a boolean value"
    
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
}

# Run without db cache
testrun nocache

# Run with db cache
testrun cache

# Run with zero-copy
testrun cache-zerocopy

rm -rf $dir

new "endtest"
endtest
