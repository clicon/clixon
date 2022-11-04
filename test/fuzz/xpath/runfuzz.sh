#!/usr/bin/env bash
# Run a fuzzing test using american fuzzy lop
set -eux

if [ $# -ne 0 ]; then 
    echo "usage: $0\n"
    exit 255
fi

APPNAME=example
xml=example.xml


cat <<EOF > $xml
<table xmlns="urn:example:clixon">
   <parameter>
      <name>x</name>
      <value>42</value>
   </parameter>
</table>
EOF

MEGS=500 # memory limit for child process (50 MB)

# remove input and input dirs
#test ! -d input || rm -rf input
test ! -d output || rm -rf output

# create if dirs dont exists
#test -d input || mkdir input
test -d output || mkdir output

# Run script 
afl-fuzz -i input -o output -m $MEGS -- clixon_util_xpath -f $xml -n ex:urn:example:clixon -y /usr/local/share/clixon/clixon-example@2022-11-01.yang  -Y /usr/local/share/clixon
