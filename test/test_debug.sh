#!/usr/bin/env bash
# Turn on debug on backend/cli/netconf
# Also some log destination tests
# CLI tests setting debug level via CLI, -o config option and -D command-line: hex, decimal, symbol
# Note no restconf debug test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/restconf.yang
fin=$dir/in

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  $RESTCONFIG
</clixon-config>nn
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
    /* Generic config data */
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "Set backend debug using netconf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><debug $LIBNS><level>1</level></debug></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# CLI: via cli

new "cli debug initial 0"
expectpart "$($clixon_cli -1 -f $cfg show debug cli)" 0 "CLI debug:0x0"

# Use APP2 debug level
cat <<EOF > $fin
debug cli 0x00200002
show debug cli
example 42
EOF
new "cli set debug via cli hex"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "CLI debug:0x200002" "mycallback: 42" "This is a long debug message"

cat <<EOF > $fin
debug cli 2097154
show debug cli
EOF
new "cli set debug via cli decimal"
expectpart "$(cat $fin | $clixon_cli -f $cfg)" 0 "CLI debug:0x200002"

cat <<EOF > $fin
debug cli app2
show debug cli
EOF
new "cli set debug via cli symbol"
expectpart "$(cat $fin | $clixon_cli -f $cfg)" 0 "CLI debug:0x200000"

# CLI: via -o CLICON_DEBUG

new "cli set debug via -o CLICON_DEBUG"
expectpart "$($clixon_cli -1 -f $cfg -o CLICON_DEBUG=app2 show debug cli)" 0 "CLI debug:0x200000"

new "cli example debug level via -o expect fail"
expectpart "$($clixon_cli -1 -f $cfg -o CLICON_DEBUG=example show debug cli 2>&1)" 255 "Bit string invalid: example"

new "cli debug several -o"
expectpart "$($clixon_cli -1 -f $cfg -o CLICON_DEBUG="msg app2" show debug cli)" 0 "CLI debug:0x200002"

new "cli set debug via -o hex"
expectpart "$($clixon_cli -1 -f $cfg -o CLICON_DEBUG=0x200002 show debug cli)" 0 "CLI debug:0x200002"

new "cli set debug via -o number"
expectpart "$($clixon_cli -1 -f $cfg -o CLICON_DEBUG=2097154 show debug cli)" 0 "CLI debug:0x200002"

# CLI: via -D command-line

new "cli debug several -D"
expectpart "$($clixon_cli -1 -f $cfg -D msg -D example show debug cli)" 0 "CLI debug:0x200002"

new "cli -D decimal"
expectpart "$($clixon_cli -1 -f $cfg -D 2097154 show debug cli)" 0 "CLI debug:0x200002"

new "cli -D hex"
expectpart "$($clixon_cli -1 -f $cfg -D 0x200002 show debug cli)" 0 "CLI debug:0x200002"

new "cli debug -D notexist"
expectpart "$($clixon_cli -1 -f $cfg -D notexist show debug cli 2>&1)" 1 "usage:clixon_cli"

new "cli debug extended and trunced"
expectpart "$($clixon_cli -1 -f $cfg -D example example 42 2>&1)" 0 "mycallback: 42" "This is a long debug message" --not-- "invisible"

# Log destination
new "cli log -lf<file>"
rm -f $dir/clixon.log
expectpart "$($clixon_cli -1 -lf$dir/clixon.log -f $cfg show version)" 0
if [ ! -f "$dir/clixon.log" ]; then
    err "$dir/clixon.log" "No file"
fi

new "cli log -lfile"
rm -f $dir/clixon.log
expectpart "$($clixon_cli -1 -lfile -f $cfg show version)" 0
if [ -f "$dir/clixon.log" ]; then
    err "No file" "$dir/clixon.log"
fi

new "cli log -lfile + CLICON_LOG_FILE"
rm -f $dir/clixon.log
expectpart "$($clixon_cli -1 -lfile -o CLICON_LOG_FILE=$dir/clixon.log -f $cfg show version)" 0
if [ ! -f "$dir/clixon.log" ]; then
    err "$dir/clixon.log" "No file"
fi

rm -f $dir/clixon.log
new "cli log -o CLICON_LOG_DESTINATION + CLICON_LOG_FILE"
expectpart "$($clixon_cli -1 -o CLICON_LOG_DESTINATION=file -o CLICON_LOG_FILE=$dir/clixon.log -f $cfg show version)" 0
if [ ! -f "$dir/clixon.log" ]; then
    err "$dir/clixon.log" "No file"
fi

rm -f $dir/clixon.log
new "cli log -o CLICON_LOG_DESTINATION + CLICON_LOG_FILE multi"
expectpart "$($clixon_cli -1 -o CLICON_LOG_DESTINATION="stdout file" -o CLICON_LOG_FILE=$dir/clixon.log -f $cfg show version)" 0
if [ ! -f "$dir/clixon.log" ]; then
    err "$dir/clixon.log" "No file"
fi

new "Set backend debug using cli"
expectpart "$($clixon_cli -1 -f $cfg -l o debug backend 1)" 0 "^$"

# Exercise debug code
new "get and put config using restconf"
expectpart "$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config --next $CURLOPTS -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data -d '{"example:table":{"parameter":{"name":"local0","value":"foo"}}}')" 0 "HTTP/$HVER 200" "<data $DEFAULTONLY/>" "HTTP/$HVER 201"

# In freebsd, backend dies in stop_restconf below unless sleep
sleep $DEMSLEEP 

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err1 "backend pid !=0" 0
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
