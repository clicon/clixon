#!/usr/bin/env bash
# XML inserty and merge two trees
# This is mainly a development API check

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml_mod:=clixon_util_xml_mod}

OPTS="-D $DBG"

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
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
      leaf d{
        type int32;
      }
      list a{
	key x;
	leaf x{
	    type int32;
	}
      }
    }
}
EOF

# insert/merge a tree into a base tree
# Args:
# 1: operation
# 2: base tree
# 3: insert tree
# 4: xpath
# 5: retval
# 6: result
testrun(){
    op=$1
    x0=$2
    x1=$3
    xp=$4
    ret=$5
    res=$6

    echo "$clixon_util_xml_mod -o $op -y $fyang -b "$x0" -x "$x1" -p $xp $OPTS"
    expectpart "$($clixon_util_xml_mod -o $op -y $fyang -b "$x0" -x "$x1" -p $xp $OPTS)" $ret "$res"
}

new "test params: -y $fyang $OPTS"

# -------- insert
# Empty element base list
x0a='<c xmlns="urn:example:example">'
x0b='</c>'
p=c

new "insert 1st element"
testrun insert "$x0a$x0b" "$x0a<a><x>1</x></a>$x0b" $p 0 '<c xmlns="urn:example:example"><a><x>1</x></a></c>'

new "insert 2nd element"
testrun insert "$x0a<a><x>2</x></a>$x0b" "$x0a<a><x>1</x></a>$x0b" $p 0 '<c xmlns="urn:example:example"><a><x>1</x></a><a><x>2</x></a></c>'

new "insert container"
testrun insert "$x0a<a><x>1</x></a>$x0b" "$x0a<d>42</d>$x0b" c 0 '<c xmlns="urn:example:example"><d>42</d><a><x>1</x></a></c>'

# -------- parse parent
new "parent 1st element"
testrun parent "$x0a$x0b" "<a><x>1</x></a>" $p 0 '<c xmlns="urn:example:example"><a><x>1</x></a></c>'

new "parse parent element"
testrun parent "$x0a<a><x>2</x></a>$x0b" '<a><x>1</x></a>' $p 0 '<c xmlns="urn:example:example"><a><x>1</x></a><a><x>2</x></a></c>'

new "parse parent container"
testrun parent "$x0a<a><x>1</x></a>$x0b" '<d>42</d>' c 0 '<c xmlns="urn:example:example"><d>42</d><a><x>1</x></a></c>'

# -------- merge

new "merge empty"
testrun merge "$x0a$x0b" "$x0a$x0b" $p 0 '<c xmlns="urn:example:example"/>'

new "merge single w empty"
testrun merge "$x0a<a><x>1</x></a>$x0b" "$x0a$x0b" . 0 '<c xmlns="urn:example:example"><a><x>1</x></a></c>'

new "merge empty w single"
testrun merge "$x0a$x0b" "$x0a<a><x>1</x></a>$x0b" . 0 '<c xmlns="urn:example:example"><a><x>1</x></a></c>'

new "merge equal single"
testrun merge "$x0a<a><x>1</x></a>$x0b" "$x0a<a><x>1</x></a>$x0b" . 0 '<c xmlns="urn:example:example"><a><x>1</x></a></c>'

new "merge overlap"
testrun merge "$x0a<a><x>1</x></a><a><x>2</x></a>$x0b" "$x0a<a><x>2</x></a><a><x>3</x></a>$x0b" . 0 '<c xmlns="urn:example:example"><a><x>1</x></a><a><x>2</x></a><a><x>3</x></a></c>'

new "merge list and leaf"
testrun merge "$x0a<a><x>1</x></a><a><x>2</x></a>$x0b" "$x0a<d>42</d>$x0b" . 0 '<c xmlns="urn:example:example"><d>42</d><a><x>1</x></a><a><x>2</x></a></c>'

new "merge leaf and list"
testrun merge "$x0a<d>42</d>$x0b" "$x0a<a><x>1</x></a><a><x>2</x></a>$x0b" . 0 '<c xmlns="urn:example:example"><d>42</d><a><x>1</x></a><a><x>2</x></a></c>'

new "merge overlap with path fail, merge does not work w subtrees"
testrun merge "$x0a<a><x>1</x></a><a><x>2</x></a>$x0b" "$x0a<a><x>2</x></a><a><x>3</x></a>$x0b" c 255 ''

rm -rf $dir

# unset conditional parameters 
unset clixon_util_xml_mod
