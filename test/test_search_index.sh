#!/usr/bin/env bash
# Test explicit search index.
# Test done by clixon explicit-index extension
# Test explicit indexes in lists these cases:
#   - not a key string
#   - not a key int
#   - key in an ordered-by user
#   - key in state data
# Use instance-id for tests, since api-path can only handle keys, and xpath is too complex.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_path:=clixon_util_path -D $DBG -Y /usr/local/share/clixon}

# Number of list/leaf-list entries
: ${nr:=10000}

# Number of tests to generate XML for +1
max=2

# XML file (alt provide it in stdin after xpath)
for (( i=1; i<$max; i++ )); do  
    eval xml$i=$dir/xml$i.xml
done
ydir=$dir/yang

if [ ! -d $ydir ]; then
    mkdir $ydir
fi

cat <<EOF > $ydir/moda.yang
module moda{
  namespace "urn:example:a";
  prefix a;
  import clixon-config {
    prefix "cc";
  }
  container x1{
    description "extra index in list with single key";
    list y{
      ordered-by system;
      key k1;
      leaf k1{
        type string;
      }
      leaf z{
        type string;
      }
      leaf i{
        description "explicit index variable";
        type int32;
	cc:search_index;
      }
      leaf j{
        description "non-index variable";
        type int32;
      }
    }
  }
}
EOF

# Single string key
# Assign index i in reverse order
new "generate list with $nr single string key to $xml1"
echo -n '<x1 xmlns="urn:example:a">' > $xml1
for (( i=0; i<$nr; i++ )); do  
    let ii=$nr-$i-1
    echo -n "<y><k1>a$i</k1><z>foo$i</z><i>$ii</i><j>$ii</j></y>" >> $xml1
done
echo -n '</x1>' >> $xml1

# First check correctness
for (( ii=0; ii<10; ii++ )); do
    # key random
    rnd=$(( ( RANDOM % $nr ) ))
    # Let key index rndi be reverse of rnd
    rndi=$(( $nr - $rnd - 1 ))
    new "instance-id single string key i=$rndi (rnd:$rnd)"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:i=\"$rndi\"])" 0 "^0: <y><k1>a$rnd</k1><z>foo$rnd</z><i>$rndi</i><j>$rndi</j></y>$"
done

# Then measure time for index and non-index, assume correct
# For small nr, the time to parse is so much larger than searching (and also parsing involves
# searching) which makes it hard to make a  test comparing accessing the index variable "i" and the
# non-index variable "j".
new "index search latency i=$rndi"
{ time -p $clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:i=\"$rndi\"] -n 10 > /dev/null; }  2>&1 | awk '/real/ {print $2}'

new "non-index search latency j=$rndi"
{ time -p $clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:j=\"$rndi\"] > /dev/null; }  2>&1 | awk '/real/ {print $2}'

rm -rf $dir

unset nr
unset clixon_util_path # for other script reusing it

new "endtest"
endtest
