#!/usr/bin/env bash
# Run a fuzzing test using american fuzzy lop
set -eux

if [ $# -ne 0 ]; then 
    echo "usage: $0\n"
    exit 255
fi

APPNAME=example
cfg=conf.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>*:*</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-hello</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLI_MODE>hello</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/hello.sock</CLICON_SOCK>
  <CLICON_CLISPEC_DIR>/usr/local/lib/hello/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

#cfg=/usr/local/etc/hello.xml # XXX
# Kill previous
sudo clixon_backend -z -f $cfg -s init 

# Start backend
sudo clixon_backend -f $cfg -s init

MEGS=500 # memory limit for child process (50 MB)

# remove input and input dirs
#test ! -d input || rm -rf input
test ! -d output || rm -rf output

# create if dirs dont exists
#test -d input || mkdir input
test -d output || mkdir output

# Run script 
afl-fuzz -i input -o output -m $MEGS -- clixon_cli -f $cfg
