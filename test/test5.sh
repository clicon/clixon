#!/bin/bash
# Test5: datastore tests. 
# Just run a binary direct to datastore. No clixon.

# include err() and new() functions
. ./lib.sh

datastore=datastore_client

cat <<EOF > /tmp/ietf-ip.yang
module ietf-ip{
   container x {
    list y {
      key "a b";
      leaf a {
        type string;
      }
      leaf b {
        type string;
      }
      leaf c {
        type string;
      }   
    }
    leaf d {
        type empty;
    }
    container f {
      leaf-list e {
        type string;
      }
    }
    leaf g {
      type string;  
    }
    container h {
      leaf j {
        type string;
      }
    }
  }
}
EOF

db='<config><x><y><a>1</a><b>2</b><c>first-entry</c></y><y><a>1</a><b>3</b><c>second-entry</c></y><y><a>2</a><b>3</b><c>third-entry</c></y><d/><f><e>a</e><e>b</e><e>c</e></f><g>astring</g></x></config>'

run(){
    name=$1
    dir=/tmp/$name

    if [ ! -d $dir ]; then
	mkdir $dir
    fi
    rm -rf $dir/*

    conf="-d candidate -b $dir -p ../datastore/$name/$name.so -y /tmp -m ietf-ip"
    echo "conf:$conf"
    new "datastore $name init"
    expectfn "$datastore $conf init" ""

    # Whole tree operations
    new "datastore $name put all replace"
    expectfn "$datastore $conf put replace $db" ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" "^$db$"

    new "datastore $name put all remove"
    expectfn "$datastore $conf put remove <config/>"

    new "datastore $name get"
    expectfn "$datastore $conf get /" "^<config/>$"

    new "datastore $name put all merge"
    expectfn "$datastore $conf put merge $db" ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" "^$db$"

    new "datastore $name put all delete"
    expectfn "$datastore $conf put remove <config/>"

    new "datastore $name get"
    expectfn "$datastore $conf get /" "^<config/>$"

    new "datastore $name put all create"
    expectfn "$datastore $conf put create $db" ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" "^$db$"

    new "datastore $name put top create"
    expectfn "$datastore $conf put create <config><x/></config>" "" # error

    # Single key operations
    # leaf
    new "datastore $name put all delete"
    expectfn "$datastore $conf delete" ""

    new "datastore $name init"
    expectfn "$datastore $conf init" ""

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>"

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>"

    new "datastore $name delete leaf"
    expectfn "$datastore $conf put delete <config><x><y><a>1</a><b>3</b></y></x></config>"

    new "datastore $name replace leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>"

    new "datastore $name remove leaf"
    expectfn "$datastore $conf put remove <config><x><g/></x></config>"

    new "datastore $name remove leaf"
    expectfn "$datastore $conf put remove <config><x><y><a>1</a><b>3</b><c/></y></x></config>"

    new "datastore $name delete leaf"
    expectfn "$datastore $conf put delete <config><x><g/></x></config>"

    new "datastore $name merge leaf"
    expectfn "$datastore $conf put merge <config><x><g>nalle</g></x></config>"

    new "datastore $name replace leaf"
    expectfn "$datastore $conf put replace <config><x><g>nalle</g></x></config>"

    new "datastore $name merge leaf"
    expectfn "$datastore $conf put merge <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>"

    new "datastore $name replace leaf"
    expectfn "$datastore $conf put replace <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>"

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><h><j>aaa</j></h></x></config>"

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>"

    new "datastore other db init"
    expectfn "$datastore -d kalle -b $dir -p ../datastore/$name/$name.so -y /tmp -m ietf-ip init"

    new "datastore other db copy"
    expectfn "$datastore $conf copy kalle" ""

    diff $dir/kalle_db $dir/candidate_db

    new "datastore lock"
    expectfn "$datastore $conf lock 756" ""

#leaf-list

    rm -rf $dir
}

#run keyvalue # cant get the put to work
run text

