#!/usr/bin/env bash
# Test xpath inverse function.
# That is, given an xml + xpath -> specific node x in xml -> xml2xpath(x)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xpath:=clixon_util_xpath}

ydir=$dir/yang
xml1=$dir/xml1.xml
xml2=$dir/xml2.xml

if [ ! -d $ydir ]; then
    mkdir $ydir
fi

# canonical namespace xpath tests
# need yang modules
cat <<EOF > $ydir/a.yang
module a{
  namespace "urn:example:a";
  prefix a;
  container x{
    leaf y{
      type string;
    }
    list z {
      key k;
      leaf k{
         type string;
      }
    }
  }
}
EOF

# Default prefix
cat <<EOF > $xml1
<x xmlns="urn:example:a">
   <y>foo</y>
   <z>
     <k>1</k>
   </z>
   <z>
     <k>2</k>
   </z>
</x>
EOF

# Explicit indexes
cat <<EOF > $xml2
<a:x xmlns:a="urn:example:a">
   <a:y>foo</a:y>
   <a:z>
     <a:k>1</a:k>
   </a:z>
   <a:z>
     <a:k>2</a:k>
   </a:z>
</a:x>
EOF

new "xpath leaf default ns"
expectpart "$($clixon_util_xpath -If $xml1 -y $ydir -p /x/y)" 0 'Inverse: /x/y'

new "xpath leaf explicit prefix"
expectpart "$($clixon_util_xpath -If $xml2 -y $ydir -p /a:x/a:y)" 0 'Inverse: /a:x/a:y'

new "xpath leaf explicit prefix"
expectpart "$($clixon_util_xpath -If $xml2 -y $ydir -p /a:x/a:y -n a:urn:example:a)" 0 'Inverse: /a:x/a:y'

new "xpath leaf no prefix"
expectpart "$($clixon_util_xpath -If $xml1 -y $ydir -p /x/y -n a:urn:example:a)" 0 'Inverse: /a:x/a:y'

new "xpath leaf other nsc"
expectpart "$($clixon_util_xpath -If $xml1 -y $ydir -p /a:x/a:y -n b:urn:example:a)" 0 'Inverse: /b:x/b:y' --not-- /a:x/a:y

new "xpath list same nsc"
expectpart "$($clixon_util_xpath -If $xml1 -y $ydir -p /a:x/a:z[a:k='2'] -n a:urn:example:a)" 0 'Inverse: /a:x/a:z\[a:k="2"\]'

new "xpath list same nsc"
expectpart "$($clixon_util_xpath -If $xml1 -y $ydir -p /a:x/a:z[a:k='2'] -n b:urn:example:a)" 0 'Inverse: /b:x/b:z\[b:k="2"\]' --not-- '/a:x/a:z'

rm -rf $dir

new "endtest"
endtest
