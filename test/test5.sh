#!/bin/bash
# Test5: datastore

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
  }
}
EOF

run(){
    name=$1
    dir=/tmp/$name
    if [ ! -d $dir ]; then
	mkdir $dir
    fi

    rm -rf $dir/*
    conf="-d candidate -b $dir -p ../datastore/$name/$name.so -y /tmp -m ietf-ip"
    new "datastore $name init"
    expectfn "$datastore $conf init" ""

    new "datastore $name get empty"
    expectfn "$datastore $conf get /" "^<config/>$"

    new "datastore $name put top"
    expectfn "$datastore $conf put replace / <config><x><y><a>foo</a><b>bar</b><c>fie</c></y></x></config>" ""

    new "datastore $name get config"
    expectfn "$datastore $conf get /" "^<config><x><y><a>foo</a><b>bar</b><c>fie</c></y></x></config>$"

    new "datastore $name put delete"
    expectfn "$datastore $conf put delete / <config/>" ""

    new "datastore $name get deleted"
    expectfn "$datastore $conf get /" "^<config/>$"

    rm -rf $dir
}

#run keyvalue # cant get the put to work
run text

