#!/usr/bin/env bash
# Test explicit search index.
# Test done by clixon explicit-index extension
# Test explicit indexes in lists these cases:
#   - not a key string
#   - not a key int
#   - key in an ordered-by user
#   - key in state data
# Use instance-id for tests,since api-path can only handle keys, and xpath is too complex.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_path:=clixon_util_path -D $DBG -Y /usr/local/share/clixon}

# Number of list/leaf-list entries
: ${nr:=10}

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
        description "extra index";
        type string;
	cc:search_index;
      }
    }
  }
}
EOF

# key random
rnd=$(( ( RANDOM % $nr ) ))
# Let key index rndi be reverse of rnd
rndi=$(( $nr - $rnd - 1 ))

# Single string key
# Assign index i in reverse order
new "generate list with $nr single string key to $xml1"
echo -n '<x1 xmlns="urn:example:a">' > $xml1
for (( i=0; i<$nr; i++ )); do  
    let ii=$nr-$i-1  
    echo -n "<y><k1>a$i</k1><z>foo$i</z><i>i$ii</i></y>" >> $xml1
done
echo -n '</x1>' >> $xml1

# How should I know it is an optimized search?
new "instance-id single string key i=i$rndi"
echo "$clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:i=\"i$rndi\"]"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:i=\"i$rndi\"])" 0 "^0: <y><k1>a$rnd</k1><z>foo$rnd</z><i>i$rndi</i></y>$"

#rm -rf $dir

unset nr
unset clixon_util_path # for other script reusing it


