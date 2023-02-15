#!/usr/bin/env bash
# JSON performance test:
# 1. parse a long string

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:="clixon_util_json"}

# Number of list/leaf-list entries in file
: ${perfnr:=100000}

fjson=$dir/long.json

new "generate long file $fjson"
echo -n '{"foo": "' > $fjson
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "a" >> $fjson
done
echo '"}' >> $fjson
echo "$fjson"

new "json parse long string"
expecteof_file "time -p $clixon_util_json" 0 "$fjson" 2>&1 | awk '/real/ {print $2}'

rm -rf $dir

new "endtest"
endtest
