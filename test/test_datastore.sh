#!/bin/bash
# Test5: datastore tests. 
# Just run a binary direct to datastore. No clixon.

# include err() and new() functions and creates $dir
. ./lib.sh
fyang=$dir/ietf-ip.yang

datastore=../datastore/datastore_client

cat <<EOF > $fyang
module ietf-ip{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ip;
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



xml='<config><x xmlns="urn:example:clixon"><y><a>1</a><b>2</b><c>first-entry</c></y><y><a>1</a><b>3</b><c>second-entry</c></y><y><a>2</a><b>3</b><c>third-entry</c></y><d/><f><e>a</e><e>b</e><e>c</e></f><g>astring</g></x></config>'

# Without xmlns
xmlxxx='<config><x><y><a>1</a><b>2</b><c>first-entry</c></y><y><a>1</a><b>3</b><c>second-entry</c></y><y><a>2</a><b>3</b><c>third-entry</c></y><d/><f><e>a</e><e>b</e><e>c</e></f><g>astring</g></x></config>'

run(){
    name=$1
    mydir=$dir/$name

    if [ ! -d $mydir ]; then
	mkdir $mydir
    fi
    rm -rf $mydir/*

    conf="-d candidate -b $mydir -p ../datastore/$name/$name.so -y $dir/ietf-ip.yang"
  
    new "datastore $name init"
    expectfn "$datastore $conf init" 0 ""

    new "datastore $name put all replace"
    ret=$($datastore $conf put replace "$xml")
    expectmatch "$ret" $? "0" ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" 0 "^$xmlxxx$"

    new "datastore $name put all remove"
    expectfn "$datastore $conf put remove <config/>" 0 ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" 0 "^<config/>$" 

    new "datastore $name put all merge"
    ret=$($datastore $conf put merge "$xml")
    expectmatch "$ret" $? "0" ""
    
#    expectfn "$datastore $conf put merge $xml" 0 ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" 0 "^$xmlxxx$"

    new "datastore $name put all delete"
    expectfn "$datastore $conf put remove <config/>" 0 ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" 0 "^<config/>$"

    new "datastore $name put all create"
    ret=$($datastore $conf put create "$xml")
    expectmatch "$ret" $? "0" ""

    new "datastore $name get"
    expectfn "$datastore $conf get /" 0 "^$xmlxxx$"

    new "datastore $name put top create"
    expectfn "$datastore $conf put create <config><x/></config>" 0 "" # error

    # Single key operations
    # leaf
    new "datastore $name put all delete"
    expectfn "$datastore $conf delete" 0 ""

    new "datastore $name init"
    expectfn "$datastore $conf init" 0 ""

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>" 0 ""

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>" 0 ""

    new "datastore $name delete leaf"
    expectfn "$datastore $conf put delete <config><x><y><a>1</a><b>3</b></y></x></config>" 0 ""

    new "datastore $name replace leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>" 0 ""

    new "datastore $name remove leaf"
    expectfn "$datastore $conf put remove <config><x><g/></x></config>" 0 ""

    new "datastore $name remove leaf"
    expectfn "$datastore $conf put remove <config><x><y><a>1</a><b>3</b><c/></y></x></config>" 0 ""

    new "datastore $name delete leaf"
    expectfn "$datastore $conf put delete <config><x><g/></x></config>" 0 ""

    new "datastore $name merge leaf"
    expectfn "$datastore $conf put merge <config><x><g>nalle</g></x></config>" 0 ""

    new "datastore $name replace leaf"
    expectfn "$datastore $conf put replace <config><x><g>nalle</g></x></config>" 0 ""

    new "datastore $name merge leaf"
    expectfn "$datastore $conf put merge <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>" 0 ""

    new "datastore $name replace leaf"
    expectfn "$datastore $conf put replace <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>" 0 ""

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><h><j>aaa</j></h></x></config>" 0 ""

    new "datastore $name create leaf"
    expectfn "$datastore $conf put create <config><x><y><a>1</a><b>3</b><c>newentry</c></y></x></config>" 0 ""

    new "datastore other db init"
    expectfn "$datastore -d kalle -b $mydir -p ../datastore/$name/$name.so -y $dir/ietf-ip.yang init" 0 ""

    new "datastore other db copy"
    expectfn "$datastore $conf copy kalle" 0 ""

    diff $mydir/kalle_db $mydir/candidate_db

    new "datastore lock"
    expectfn "$datastore $conf lock 756" 0 ""

#leaf-list

    rm -rf $mydir
}

run text

rm -rf $dir

