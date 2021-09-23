#!/usr/bin/env bash
# Test xpath canonical namespace context form

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xpath:=clixon_util_xpath}

ydir=$dir/yang

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
    leaf xa{
      type string;
    }
  }
}
EOF

cat <<EOF > $ydir/b.yang
module b{
  namespace "urn:example:b";
  prefix b;
  container y{
    leaf ya{
      type string;
    }
  }
}
EOF

new "xpath canonical form (already canonical)"
expectpart "$($clixon_util_xpath -c -y $ydir -p /a:x/b:y -n a:urn:example:a -n b:urn:example:b)" 0 '/a:x/b:y' '0 : a = "urn:example:a"' '1 : b = "urn:example:b"'

new "xpath canonical form (default)"
expectpart "$($clixon_util_xpath -c -y $ydir -p /x/b:y -n null:urn:example:a -n b:urn:example:b)" 0 '/a:x/b:y' '0 : a = "urn:example:a"' '1 : b = "urn:example:b"'

new "xpath canonical form (other)"
expectpart "$($clixon_util_xpath -c -y $ydir -p /i:x/j:y -n i:urn:example:a -n j:urn:example:b)" 0 '/a:x/b:y' '0 : a = "urn:example:a"' '1 : b = "urn:example:b"'

new "xpath canonical form predicate 1"
expectpart "$($clixon_util_xpath -c -y $ydir -p "/i:x[j:y='e1']" -n i:urn:example:a -n j:urn:example:b)" 0 "/a:x\[b:y='e1'\]" '0 : a = "urn:example:a"' '1 : b = "urn:example:b"'

new "xpath canonical form predicate self"
expectpart "$($clixon_util_xpath -c -y $ydir -p "/i:x[.='42']" -n i:urn:example:a -n j:urn:example:b)" 0 "/a:x\[.='42'\]" '0 : a = "urn:example:a"'

new "xpath canonical form descendants"
expectpart "$($clixon_util_xpath -c -y $ydir -p "//x[.='42']" -n null:urn:example:a -n j:urn:example:b)" 0 "//a:x\[.='42'\]" '0 : a = "urn:example:a"'

new "xpath canonical form (no default should fail)"
expectpart "$($clixon_util_xpath -c -y $ydir -p /x/j:y -n i:urn:example:a -n j:urn:example:b 2>&1)" 0 "/x/j:y: No namespace found for prefix"

new "xpath canonical form (wrong namespace should fail)"
expectpart "$($clixon_util_xpath -c -y $ydir -p /i:x/j:y -n i:urn:example:c -n j:urn:example:b 2>&1)" 0 "/i:x/j:y: No modules found for namespace"

rm -rf $dir

# unset conditional parameters 
unset clixon_util_xpath

new "endtest"
endtest
