#!/usr/bin/env bash
# Test of path dispatcher

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_dispatcher:="clixon_util_dispatcher"}

new "null test"
expectpart "$($clixon_util_dispatcher)" 0 "^$"

new "path /, nothing regged. Expect fail"
expectpart "$($clixon_util_dispatcher -c /)" 255 "^$"

new "reg /, path / arg foo"
expectpart "$($clixon_util_dispatcher -a foo -p / -r -c /)" 0 "cb1 foo"

new "reg /foo and /bar same cb1, call /"
expectpart "$($clixon_util_dispatcher -a foo -p /foo -r -a bar -p /bar -r -c /)" 0 "cb1 foo" "cb1 bar"

new "reg /foo and /bar different cb, call /"
expectpart "$($clixon_util_dispatcher -i 1 -a foo -p /foo -r -a bar -p /bar -i 2 -r -c /)" 0 "cb1 foo" "cb2 bar"

new "reg /foo and /bar call /foo"
expectpart "$($clixon_util_dispatcher -i 1 -a foo -p /foo -r -a bar -p /bar -i 2 -r -c /foo)" 0 "cb1 foo"

new "reg /foo and /bar call /bar"
expectpart "$($clixon_util_dispatcher -i 1 -a foo -p /foo -r -a bar -p /bar -i 2 -r -c /bar)" 0 "cb2 bar"

new "reg /route-table ipv4 and ipv6 call /route-table"
expectpart "$($clixon_util_dispatcher -i 1 -a ipv4 -p /route-table/ipv4 -r -a ipv6 -p /route-table -i 2 -r -c /route-table)" 0 "cb1 ipv4" "cb2 ipv6"

new "reg /route-table/ ipv4,ipv6 call /route-table/ipv4"
expectpart "$($clixon_util_dispatcher -i 1 -a ipv4 -p /route-table/ipv4 -r -a ipv6 -p /route-table/ipv6 -i 2 -r -c /route-table/ipv4)" 0 "cb1 ipv4" --not-- cb2

new "reg /route-table/ ipv4,ipv6 call /route-table/ipv6"
expectpart "$($clixon_util_dispatcher -i 1 -a ipv4 -p /route-table/ipv4 -r -a ipv6 -p /route-table/ipv6 -i 2 -r -c /route-table/ipv6)" 0 "cb2 ipv6"  --not-- cb1

new "reg /route-table/ ipv4,ipv6 call /route-table[proto='ipv4']/ipv4"
expectpart "$($clixon_util_dispatcher -i 1 -a ipv4 -p /route-table/ipv4 -r -a ipv6 -p /route-table/ipv6 -i 2 -r -c /route-table[proto='ipv4']/ipv4)" 0 "cb1 ipv4" --not-- "cb2 ipv6"

new "reg /route-table/ ipv4,ipv6 call /route-table[proto='ipv6']/ipv6"
expectpart "$($clixon_util_dispatcher -i 1 -a ipv4 -p /route-table/ipv4 -r -a ipv6 -p /route-table/ipv6 -i 2 -r -c /route-table[proto='ipv6']/ipv6)" 0 "cb2 ipv6" --not-- "cb1 ipv4"

new "reg /route-table/ ipv4,ipv6 call /route-table=/ipv4"
expectpart "$($clixon_util_dispatcher -i 1 -a ipv4 -p /route-table/ipv4 -r -a ipv6 -p /route-table/ipv6 -i 2 -r -c /route-table=/ipv4)" 0 "cb1 ipv4" --not-- "cb2 ipv6"

# unset conditional parameters 
unset clixon_util_dispatcher

rm -rf $dir

new "endtest"
endtest
