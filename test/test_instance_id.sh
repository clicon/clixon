#!/usr/bin/env bash
# INSTANCE-ID tests

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_path:=clixon_util_path -D $DBG}

# Number of list/leaf-list entries
: ${nr:=100}

# Number of tests to generate XML for
max=9

# How many times to run ech test (go through some random numbers)
rep=10

# XML file (alt provide it in stdin after xpath)
for (( i=1; i<$max; i++ )); do  
    eval xml$i=$dir/xml$i.xml
done
ydir=$dir/yang

if [ ! -d $ydir ]; then
    mkdir $ydir
fi

# Instance-id PATH binary search in ordered-by system lists 
cat <<EOF > $ydir/moda.yang
module moda{
  namespace "urn:example:a";
  prefix a;
  container x1{
    description "list with single string key";
    list y{
      ordered-by system;
      key k1;
      leaf k1{
        type string;
      }
      leaf z{
        type string;
      }
    }
  }
  container x2{
    description "list with single int key";
    list y{
      ordered-by system;
      key k1;
      leaf k1{
        type uint32;
      }
      leaf z{
        type string;
      }
    }
  }
  container x3{
    description "list with double string keys";
    list y{
      ordered-by system;
      key "k1 k2";
      leaf k1{
        type string;
      }
      leaf k2{
        type string;
      }
      leaf z{
        type string;
      }
    }
  }
  container x4{
      description "leaf-list with int key";
      leaf-list y{
        type string;
      }
  }
  list x5{
      ordered-by system;
      description "Direct under root";
      key "k1";
      leaf k1{
        type string;
      }
      leaf z{
        type string;
      }
  }

  augment "/b:x6/b:yy" {
      list y{
        ordered-by system;
        key "k1 k2";
        leaf k1{
          type string;
        }
        leaf k2{
          type string;
        }
        leaf-list z{
          type string;
        }
      }
  }
  container x7{
    description "Single list, ordered by user";
    list y{
      ordered-by user;
      key k1;
      leaf k1{
        type string;
      }
      leaf z{
        type string;
      }
    }
  }
  container x8{
    description "Single list state data";
    config false;
    list y{
      key k1;
      leaf k1{
        type string;
      }
      leaf z{
        type string;
      }
    }
  }
}
EOF

# This is for augment usecase
cat <<EOF > $ydir/modb.yang
module modb{
  namespace "urn:example:b";
  prefix b;
  container x6{
      description "deep tree and augment";
      list yy{
        ordered-by system;
        key "kk1 kk2";
        leaf kk1{
          type string;
        }
        leaf kk2{
          type string;
        }
        leaf-list zz{
          type string;
        }
      }
    }
}
EOF

# This make it non-deterministic, some numbers may not work,...
rnd=$(( ( RANDOM % $nr ) ))

# Single string key
new "generate list with $nr single string key to $xml1"
echo -n '<x1 xmlns="urn:example:a">' > $xml1
for (( i=0; i<$nr; i++ )); do  
    echo -n "<y><k1>a$i</k1><z>foo$i</z></y>" >> $xml1
done
echo -n '</x1>' >> $xml1

for (( ii=0; ii<$rep; ii++ )); do    
    new "instance-id single string key k1=a$rnd"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:k1=\"a$rnd\"])" 0 "^0: <y><k1>a$rnd</k1><z>foo$rnd</z></y>$"

    new "instance-id single string key /x1"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1)" 0 "0: <x1 xmlns=\"urn:example:a\"><y><k1>a0</k1><z>foo0</z></y><y><k1>a1</k1><z>foo1</z></y>" # Assume at least two elements

    new "instance-id position specific position 5"
#    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[5])" 0 "0: <y><k1>a13</k1><z>foo13</z>" # sort alphanumerivc wrong 1,10,2

    new "instance-id single string key omit key"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y)" 0 '^0: <y><k1>a0</k1><z>foo0</z></y>
1: <y><k1>a0</k1><z>foo0</z></y>'

    # Fails and error handling
    new "instance-id single string search non-index"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:z=\"foo$rnd\"] )" 0 "<y><k1>a$rnd</k1><z>foo$rnd</z></y>$"

    new "instance-id single string search non-index (two variables, index first)"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:k1=\"a$rnd\"][a:z=\"foo$rnd\"] )" 0 "<y><k1>a$rnd</k1><z>foo$rnd</z></y>$"

    new "instance-id single string search non-index (two variables, index last)"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:z=\"foo$rnd\"][a:k1=\"a$rnd\"] )" 0 "<y><k1>a$rnd</k1><z>foo$rnd</z></y>$"

    new "instance-id single string wrong module, notfound"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /xxx:x1/a:y[a:k1=\"a$rnd\"] 2> /dev/null)" 255 '^$'

    new "instance-id single string no module, notfound"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /x1/a:y[a:k1=\"a$rnd\"] 2> /dev/null)" 255 '^$'

    new "instance-id single string no sub-prefixes, notfound"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/y[k1=\"a$rnd\"] 2> /dev/null)" 255 '^$'

    new "instance-id single string two keys, notfound"
    expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /a:x1/a:y[a:k1=a$rnd][a:k2=a$rnd] 2> /dev/null)" 255 '^$'
done

# Single int key
new "generate list with $nr single int key to $xml2"
echo -n '<x2 xmlns="urn:example:a">' > $xml2
for (( i=0; i<$nr; i++ )); do  
    echo -n "<y><k1>$i</k1><z>foo$i</z></y>" >> $xml2
done
echo -n '</x2>' >> $xml2

for (( ii=0; ii<$rep; ii++ )); do    
    new "instance-id single int key k1=$rnd"
    expectpart "$($clixon_util_path -f $xml2 -y $ydir -p /a:x2/a:y[a:k1=\"$rnd\"])" 0 "^0: <y><k1>$rnd</k1><z>foo$rnd</z></y>$"
done

# Double string key
new "generate list with $nr double string keys to $xml3 (two k2 entries per k1 key)"
echo -n '<x3 xmlns="urn:example:a">' > $xml3
for (( i=0; i<$nr; i++ )); do  
    echo -n "<y><k1>a$i</k1><k2>a$i</k2><z>foo$i</z></y>" >> $xml3
    echo -n "<y><k1>a$i</k1><k2>b$i</k2><z>foob$i</z></y>" >> $xml3
done
# Add two rules with empty k2 string
echo -n "<y><k1>a0</k1><k2></k2><z>foo0</z></y>" >> $xml3
echo -n "<y><k1>a1</k1><k2></k2><z>foo1</z></y>" >> $xml3
echo -n '</x3>' >> $xml3

for (( ii=0; ii<$rep; ii++ )); do    
    new "instance-id double string key k1=a$rnd k2=b$rnd"
    expectpart "$($clixon_util_path -f $xml3 -y $ydir -p /a:x3/a:y[k1=\"a$rnd\"][k2=\"b$rnd\"])" 0 "0: <y><k1>a$rnd</k1><k2>b$rnd</k2><z>foob$rnd</z></y>"

    new "instance-id double string key k1=a$rnd, - empty k2 string"
    expectpart "$($clixon_util_path -f $xml3 -y $ydir -p /a:x3/a:y[k1=\"a1\"][k2=\"\"])" 0 "0: <y><k1>a1</k1><k2/><z>foo1</z></y>"

    new "instance-id double string key k1=a$rnd, - no k2 string - three matches"
    expecteq "$($clixon_util_path -f $xml3 -y $ydir -p /a:x3/a:y[k1=\"a1\"])" 0 "0: <y><k1>a1</k1><k2/><z>foo1</z></y>
1: <y><k1>a1</k1><k2>a1</k2><z>foo1</z></y>
2: <y><k1>a1</k1><k2>b1</k2><z>foob1</z></y>"

    new "instance-id double string specific position 5"
    expectpart "$($clixon_util_path -f $xml3 -y $ydir -p /a:x3/a:y[5])" 0 "0: <y><k1>a1</k1><k2>b1</k2><z>foob1</z></y>" # sort alphanumerivc wrong 1,10,2
done

# Leaf-list
new "generate leaf-list int keys to $xml4"
echo -n '<x4 xmlns="urn:example:a">' > $xml4
for (( i=0; i<$nr; i++ )); do  
    echo -n "<y>a$i</y>" >> $xml4
done
echo -n '</x4>' >> $xml4

for (( ii=0; ii<$rep; ii++ )); do    
    new "instance-id leaf-list k1=a$rnd"
    expectpart "$($clixon_util_path -f $xml4 -y $ydir -p /a:x4/a:y[.=\"a$rnd\"])" 0 "^0: <y>a$rnd</y>$"
done

# Single string key direct under root
new "generate list with $nr single string key to $xml5"
echo -n '' > $xml5
for (( i=0; i<$nr; i++ )); do  
    echo -n "<x5 xmlns=\"urn:example:a\"><k1>a$i</k1><z>foo$i</z></x5>" >> $xml5
done

for (( ii=0; ii<$rep; ii++ )); do    
    new "instance-id direct under root single string key k1=a$rnd"
    expectpart "$($clixon_util_path -f $xml5 -y $ydir -p /a:x5[k1=\"a$rnd\"])" 0 "^0: <x5 xmlns=\"urn:example:a\"><k1>a$rnd</k1><z>foo$rnd</z></x5>$"
done

# Depth and augment
# Deep augmented xml path
new "generate deep list with augment"
echo -n '<x6 xmlns="urn:example:b">' > $xml6
for (( i=0; i<$nr; i++ )); do  
    echo -n "<yy><kk1>b$i</kk1><kk2>b$i</kk2><zz>foo$i</zz>" >> $xml6
    for (( j=0; j<3; j++ )); do
	echo -n "<y xmlns=\"urn:example:a\"><k1>a$j</k1><k2>a$j</k2><z>foo$j</z></y>" >> $xml6
    done
    echo -n "</yy>" >> $xml6
done
echo -n '</x6>' >> $xml6

for (( ii=0; ii<$rep; ii++ )); do
    new "instance-id double string key b$rnd,b$rnd in mod b"
    expectpart "$($clixon_util_path -f $xml6 -y $ydir -p /b:x6/b:yy[kk1=\"b$rnd\"][kk2=\"b$rnd\"])" 0 "0: <yy><kk1>b$rnd</kk1><kk2>b$rnd</kk2><zz>foo$rnd</zz><y xmlns=\"urn:example:a\"><k1>a0</k1><k2>a0</k2><z>foo0</z></y><y xmlns=\"urn:example:a\"><k1>a1</k1><k2>a1</k2><z>foo1</z></y><y xmlns=\"urn:example:a\"><k1>a2</k1><k2>a2</k2><z>foo2</z></y></yy>"

    new "instance-id double string key a$rnd,b$rnd in modb + augmented in moda"
    expectpart "$($clixon_util_path -f $xml6 -y $ydir -p /b:x6/b:yy[kk1=\"b$rnd\"][kk2=\"b$rnd\"]/a:y[k1=\"a1\"][k2=\"a1\"]/a:z[.=\"foo1\"])" 0 "0: <z>foo1</z>"
done
    
# Single list ordered by user
new "generate list with $nr single string key to $xml7"
echo -n '<x7 xmlns="urn:example:a">' > $xml7
for (( i=0; i<$nr; i++ )); do  
    echo -n "<y><k1>a$i</k1><z>foo$i</z></y>" >> $xml7
done
echo -n '</x7>' >> $xml7

for (( ii=0; ii<$rep; ii++ )); do
    new "instance-id single string key k1=a$rnd ordered by user"
    expectpart "$($clixon_util_path -f $xml7 -y $ydir -p /a:x7/a:y[a:k1=\"a$rnd\"])" 0 "^0: <y><k1>a$rnd</k1><z>foo$rnd</z></y>$"
done

# Single list state data (non-config)
new "generate list with $nr single string key to $xml8"
echo -n '<x8 xmlns="urn:example:a">' > $xml8
for (( i=0; i<$nr; i++ )); do  
    echo -n "<y><k1>a$i</k1><z>foo$i</z></y>" >> $xml8
done
echo -n '</x8>' >> $xml8

for (( ii=0; ii<$rep; ii++ )); do
    rnd=$(( ( RANDOM % $nr ) ))
    new "instance-id single string key k1=a$rnd ordered by user"
    expectpart "$($clixon_util_path -f $xml8 -y $ydir -p /a:x8/a:y[a:k1=\"a$rnd\"])" 0 "^0: <y><k1>a$rnd</k1><z>foo$rnd</z></y>$"
done

rm -rf $dir

unset nr
unset clixon_util_path # for other script reusing it


