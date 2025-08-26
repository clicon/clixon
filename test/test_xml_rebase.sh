#!/usr/bin/env bash
# XML rebase and conflict tests
# Check conflict detection as defined in draft-ietf-netconf-privcand
# Tests use clixon_util_xml_diff with three trees:
# x0 - Orig
# x1 - Candidate
# x2 - Running

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml_diff:=clixon_util_xml_diff}

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
    container a{
      list b{
        key x;
        leaf x{
            type string;
        }
        leaf c{
            type string;
        }
        leaf d{
            type string;
        }
        leaf-list e{
            type string;
        }
      }
    }
}
EOF

# Check diff conflict of x0 vs x1 and x2
# Args:
# 1: yang
# 2: tree0
# 3: tree1
# 4: tree2
# 5: result
function testconflict(){
    fyang=$1
    x0=$2
    x1=$3
    x2=$4
    res=$5

    new "$clixon_util_xml_diff -y $fyang -f $x0 -f $x1 -f $x2"
    expectpart "$($clixon_util_xml_diff -y $fyang -f $x0 -f $x1 -f $x2)" 0 $res
}

new "test params: -y $fyang $OPTS"

# Example if draft-ietf-netconf-privcand
# Where interfaces/interface/name corresponds to a/b/x and description is c

cat <<EOF > $dir/x0
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to London</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF
# Session 1 edits the config by changing the descr of intf_one to San Fransisco
cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to San Fransisco</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

# Session 2 deletes intf_one and updates the description on intf_two
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>intf_two</x>
      <c>Link moved to Paris</c>
   </b>
</a>
EOF

new "draft-ietf example orig"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" conflict

# Session 1 edits the config by changing the descr of intf_one to San Fransisco
cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>intf_two</x>
      <c>Link moved to Paris</c>
   </b>
</a>
EOF

# Session 2 deletes intf_one and updates the description on intf_two
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to San Fransisco</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

new "draft-ietf example reverse"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" conflict


# Session 1 edits the config by changing the descr of intf_one to San Fransisco
cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to Jamaica</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

# Session 2 deletes intf_one and updates the description on intf_two
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to London</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Brussel</c>
   </b>
</a>
EOF

new "draft-ietf example ok"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" ok

# Session 1 edits the config by changing the descr of intf_one to San Fransisco
cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

# Session 2 deletes intf_one and updates the description on intf_two
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to London</c>
   </b>
</a>
EOF

new "draft-ietf example remove one each"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" ok

# Session 1 edits the config by changing the descr of intf_one to San Fransisco
cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to London</c>
   </b>
   <b>
      <x>intf_onetwo</x>
      <c>Link to Beijing</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

# Session 2 deletes intf_one and updates the description on intf_two
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to London</c>
   </b>
   <b>
      <x>intf_onetwo</x>
      <c>Link to Kuala Lumpur</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

new "draft-ietf example add same object w different content"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" conflict

# Session 1 edits the config by changing the descr of intf_one to San Fransisco
cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to Stockholm</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

# Session 2 deletes intf_one and updates the description on intf_two
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>intf_one</x>
      <c>Link to Oslo</c>
   </b>
   <b>
      <x>intf_two</x>
      <c>Link to Tokyo</c>
   </b>
</a>
EOF

new "draft-ietf example both edit description"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" conflict

cat <<EOF > $dir/x0
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <c>2</c>
      <d>3</d>
   </b>
</a>
EOF

cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <c>12</c>
      <d>3</d>
   </b>
</a>
EOF
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <c>2</c>
      <d>23</d>
   </b>
</a>
EOF

new "Edit different variables"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" ok

cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <c>22</c>
      <d>23</d>
   </b>
</a>
EOF

new "Edit same variable: conflict"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" conflict

# Add different list elements
cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <c>2</c>
      <d>3</d>
   </b>
   <b>
      <x>12</x>
      <c>2</c>
      <d>3</d>
   </b>
</a>
EOF
cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <c>2</c>
      <d>3</d>
   </b>
   <b>
      <x>22</x>
      <c>2</c>
      <d>3</d>
   </b>
</a>
EOF

new "Add two different elements"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" ok

# leaf-list
#   *  There is a change of any component member of a leaf-list
#   *  There is a change to the order of any items in a leaf-list
#      configured as "ordered-by user"

cat <<EOF > $dir/x0
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
   </b>
</a>
EOF

cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <e>13</e>
   </b>
</a>
EOF

cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
   </b>
</a>
EOF

new "Add leaf-list"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" ok

cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <e>23</e>
   </b>
</a>
EOF

new "Add different leaf-list"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" conflict

cat <<EOF > $dir/x0
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <e>2</e>
   </b>
</a>
EOF

cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
   </b>
</a>
EOF

cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <e>2</e>
   </b>
</a>
EOF

new "Remove leaf-list"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" ok

if false; then # notyet
cat <<EOF > $dir/x0
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <e>2</e>
      <e>4</e>
   </b>
</a>
EOF

cat <<EOF > $dir/x1
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <e>2</e>
      <e>3</e>
      <e>4</e>
   </b>
</a>
EOF

cat <<EOF > $dir/x2
<a xmlns="urn:example:example">
   <b>
      <x>1</x>
      <e>2</e>
      <e>4</e>
      <e>5</e>
   </b>
</a>
EOF

new "Add separate leaf-list elements"
testconflict $fyang "$dir/x0" "$dir/x1" "$dir/x2" conflict

fi # notyet

rm -rf $dir

new "endtest"
endtest
