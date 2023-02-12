#!/usr/bin/env bash
# Run a fuzzing test using american fuzzy lop
# Add input strings in input
set -eux

if [ $# -ne 0 ]; then 
    echo "usage: $0"
    exit 255
fi

if [ ! -x /usr/local/lib/desock.so ] ; then
    echo "preeny desock.so not found"
    exit 255
fi

MEGS=500 # memory limit for child process (50 MB)

# remove input and input dirs
#test ! -d input || rm -rf input
test ! -d output || sudo rm -rf output

# create if dirs dont exists
#test -d input || mkdir input
test -d output || mkdir output

APPNAME=example
cfg=conf.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>*:*</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/hello.sock</CLICON_SOCK>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <restconf><enable>true</enable><auth-type>none</auth-type><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket></restconf>
</clixon-config>
EOF

# Kill previous
echo "cfg: $cfg"
sudo clixon_backend -z -f $cfg -s init 

# Start backend
sudo clixon_backend -f $cfg -s init

# Dryrun without afl (comment this if you run for real)
sudo LD_PRELOAD="/usr/local/lib/desock.so" clixon_restconf -rf $cfg < input/1.http || true
sudo LD_PRELOAD="/usr/local/lib/desock.so" clixon_restconf -rf $cfg < input/2.http || true
sudo LD_PRELOAD="/usr/local/lib/desock.so" clixon_restconf -rf $cfg < input/3.http || true
sudo LD_PRELOAD="/usr/local/lib/desock.so" clixon_restconf -rf $cfg < input/4.http || true
exit

# Run script 
#  CC=/usr/bin/afl-clang 
sudo LD_PRELOAD="/usr/local/lib/desock.so" afl-fuzz -i input -o output -d -m $MEGS -- /usr/local/sbin/clixon_restconf -rf $cfg


