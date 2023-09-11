#!/usr/bin/env bash
# XML Insert elements and test if they are sorted according to yang
# First a list with 0-5 base elements, insert in different places
# Second varying yangs: container, leaf, list, leaf-list, choice, user-order list

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml_mod:=clixon_util_xml_mod -o insert}

OPTS="-D $DBG"

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example {
    yang-version 1.1;
    namespace "urn:example:example";
    prefix ex;
    revision 2019-01-13;
    container c{
      list a{
        key x;
        leaf x{
            type int32;
        }
      }
    }
}
EOF

# Insert a sub tree into base tree. Verify its inserted in the right place
# Args:
# 1: base tree
# 2: sub tree
function testrun(){
    x0=$1
    xi="<c xmlns=\"urn:example:example\">$2</c>"
    xp=c

    new "insert list into $x0, verify order"
    # First run sorted (assume this is the reference == correct)
    rs=$($clixon_util_xml_mod -y $fyang -x "$xi" -b "$x0" -p $xp $OPTS -s)
    # Then run actual insert
    r0=$($clixon_util_xml_mod -y $fyang -x "$xi" -b "$x0" -p $xp $OPTS)
    # If both are null something is amiss
    if [ -z "$r0" -a -z "$rs" ]; then
        err "length of retval is zero"
    fi
 #   echo "rs:$rs"
 #   echo "r0:$r0"
    # Check they are equal
    if [[ "$r0" != "$rs" ]]; then
        err "$rs" "$r0"
    fi
}

new "test params: -y $fyang $OPTS"

# Empty element base list
x0='<c xmlns="urn:example:example"></c>'
new "empty list"
testrun "$x0" "<a><x>1</x></a>"

# One element base list
x0='<c xmlns="urn:example:example"><a><x>99</x></a></c>'
new "one element list first"
testrun "$x0" "<a><x>1</x></a>"

new "one element list last"
testrun "$x0" "<a><x>100</x></a>"

# Two element base list
x0='<c xmlns="urn:example:example"><a><x>2</x></a><a><x>99</x></a></c>'
new "two element list first"
testrun "$x0" "<a><x>1</x></a>"

new "two element list mid"
testrun "$x0" "<a><x>12</x></a>"

new "two element list last"
testrun "$x0" "<a><x>3000</x></a>"

# Three element base list
x0='<c xmlns="urn:example:example"><a><x>2</x></a><a><x>99</x></a><a><x>101</x></a></c>'
new "three element list first"
testrun "$x0" "<a><x>1</x></a>"

new "three element list second"
testrun "$x0" "<a><x>10</x></a>"

new "three element list third"
testrun "$x0" "<a><x>100</x></a>"

new "three element list last"
testrun "$x0" "<a><x>1000</x></a>"

# Four element base list
x0='<c xmlns="urn:example:example"><a><x>2</x></a><a><x>99</x></a><a><x>101</x></a><a><x>200</x></a></c>'

new "four element list first"
testrun "$x0" "<a><x>1</x></a>"

new "four element list second"
testrun "$x0" "<a><x>10</x></a>"

new "four element list third"
testrun "$x0" "<a><x>100</x></a>"

new "four element list fourth"
testrun "$x0" "<a><x>102</x></a>"

new "four element list last"
testrun "$x0" "<a><x>1000</x></a>"

# Five element base list
x0='<c xmlns="urn:example:example"><a><x>2</x></a><a><x>99</x></a><a><x>101</x></a><a><x>200</x></a><a><x>300</x></a></c>'

new "five element list first"
testrun "$x0" "<a><x>1</x></a>"

new "five element list mid"
testrun "$x0" "<a><x>100</x></a>"

new "five element list last"
testrun "$x0" "<a><x>1000</x></a>"

cat <<EOF > $fyang
module example {
    yang-version 1.1;
    namespace "urn:example:example";
    prefix ex;
    revision 2019-01-13;
    container c{
      leaf a{
        type string;
      }
      container b{
        leaf a {
          type string;
        }
      }
      choice c1{ 
        case a{
          leaf x{
            type string;
          }
        }
        case b{
          leaf y{
            type int32;
          }
        }
      }
      choice c2{ 
        leaf z{
            type string;
        }
        leaf t{
            type int32;
          }
      }
      list d{
        key x;
        leaf x{
            type int32;
        }
        ordered-by user;
      }
      leaf-list e{
        type int32;
      }
    }
}
EOF

# Advanced list
# Empty base list
x0='<c xmlns="urn:example:example"></c>'
xp=c
new "adv empty list add leaf"
testrun "$x0" "<a>leaf</a>"

new "adv empty list add choice c1"
testrun "$x0" "<x>choice1</x>"

xi='<c xmlns="urn:example:example"><e>33</e></c>'
new "adv empty list add leaf-list"
testrun "$x0" "<e>33</e>"

# base list
x0='<c xmlns="urn:example:example"><a>leaf</a><x>choice</x><d><x>1</x></d><e>33</e></c>'

new "adv list add leaf-list"
testrun "$x0" "<e>32</e>"

new "adv list add leaf-list"
testrun "$x0" "<e>32</e>"

rm -rf $dir

new "endtest"
endtest




