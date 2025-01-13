#!/usr/bin/env bash
# XPath crossref tests
# Load datastrore XML as follows:
# 1. Without prefix
# 2. With canonical prefix
# 3. With non-canonical prefix
# Access using XPath:
# 1. Without prefix
# 2. With canonical prefix
# 3. With non-canonical prefix
# With namespace context:
# 1. Yes
# 2. No
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xpath:=clixon_util_xpath}

# XML file (alt provide it in stdin after xpath)
xml1=$dir/xml1.xml
xml2=$dir/xml2.xml
xml3=$dir/xml3.xml

fyang=$dir/clixon-example.yang

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    container table1 {
       description "1. Without prefix";
       list parameter {
            key name;
            leaf name {
                type string;
            }
        }
    }
    container table2 {
       description "2. With canonical prefix";
        list parameter {
            key name;
            leaf name {
                type string;
            }
        }
    }
    container table3 {
       description "3. With non-canonical prefix";
        list parameter {
            key name;
            leaf name {
                type string;
            }
        }
    }
}
EOF

# 
cat <<EOF > $xml1
<table1 xmlns="urn:example:clixon">
   <parameter>
      <name>A</name>
   </parameter>
</table1>
EOF
cat <<EOF > $xml2
<ex:table2 xmlns:ex="urn:example:clixon">
   <ex:parameter>
      <ex:name>B</ex:name>
   </ex:parameter>
</ex:table2>
EOF
cat <<EOF > $xml3
<xe:table3 xmlns:xe="urn:example:clixon">
   <xe:parameter>
      <xe:name>C</xe:name>
   </xe:parameter>
</xe:table3>
EOF

unset y
#-------------------------------------- Name only
prefix=xxx:
localonly="-L"
nsc=
xi=1
xml=$dir/xml$xi.xml
new "Name only $xi"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<parameter><name>A</name></parameter>"

new "Name only $xi"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}xxx $y $nsc)" 0 "nodeset:$"

xi=2
xml=$dir/xml$xi.xml
new "Name only $xi"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<ex:parameter><ex:name>B</ex:name></ex:parameter>"

xi=3
xml=$dir/xml$xi.xml
new "Name only $xi"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<xe:parameter><xe:name>C</xe:name></xe:parameter>"

#-------------------------------------- Prefix only
localonly=
nsc=

xi=1
xml=$dir/xml$xi.xml
unset prefix
new "Prefix only $xi prefix=$prefix"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<parameter><name>A</name></parameter>"

prefix=xe:
new "Prefix only $xi prefix=$prefix fail"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:$"

xi=2
xml=$dir/xml$xi.xml
unset prefix
new "Prefix only $xi prefix=$prefix"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:$"

prefix=ex:
new "Prefix only $xi prefix=$prefix"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<ex:parameter><ex:name>B</ex:name></ex:parameter>"

prefix=xe:
new "Prefix only $xi prefix=$prefix"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:$"

xi=3
xml=$dir/xml$xi.xml
unset prefix
new "Prefix only $xi prefix=$prefix"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:$"

prefix=ex:
new "Prefix only $xi prefix=$prefix"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:$"

prefix=xe:
new "Prefix only $xi prefix=$prefix"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<xe:parameter><xe:name>C</xe:name></xe:parameter>"

#-------------------------------------- Namespace
localonly=
nsc="-n null:urn:example:clixon"
xi=1
xml=$dir/xml$xi.xml
prefix=
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<parameter><name>A</name></parameter>"

nsc="-n m:urn:example:clixon"
prefix=m:
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<parameter><name>A</name></parameter>"

if false; then # SEE XPATH_NS_ACCEPT_UNRESOLVED
    nsc="-n n:urn:example:clixon"
    prefix=m:
    new "Namespace $xi prefix=$prefix nsc=$nsc"
    #echo "$clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc"
    expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:$"
fi

xi=2
xml=$dir/xml$xi.xml

nsc="-n null:urn:example:clixon"
prefix=
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<ex:parameter><ex:name>B</ex:name></ex:parameter>"

nsc="-n ex:urn:example:clixon"
prefix=ex:
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<ex:parameter><ex:name>B</ex:name></ex:parameter>"

nsc="-n xe:urn:example:clixon"
prefix=xe:
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<ex:parameter><ex:name>B</ex:name></ex:parameter>"

nsc="-n xe:urn:example:xxx"
prefix=xe:
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:$"

xi=3
xml=$dir/xml$xi.xml
nsc="-n null:urn:example:clixon"
prefix=
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<xe:parameter><xe:name>C</xe:name></xe:parameter>"

nsc="-n ex:urn:example:clixon"
prefix=ex:
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<xe:parameter><xe:name>C</xe:name></xe:parameter>"

nsc="-n xe:urn:example:clixon"
prefix=xe:
new "Namespace $xi prefix=$prefix nsc=$nsc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml ${localonly} -p ${prefix}table$xi/${prefix}parameter $y $nsc)" 0 "nodeset:0:<xe:parameter><xe:name>C</xe:name></xe:parameter>"

rm -rf $dir

new "endtest"
endtest
