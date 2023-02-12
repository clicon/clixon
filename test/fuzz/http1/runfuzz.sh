#!/usr/bin/env bash
# Run a fuzzing test using american fuzzy lop
# Add input strings in input
set -eux

if [ $# -ne 0 ]; then 
    echo "usage: $0"
    exit 255
fi

APPNAME=example
cfg=$(pwd)/conf.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-hello</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLI_MODE>hello</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/hello/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/hello.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/hello.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/hello</CLICON_XMLDB_DIR>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_SOCK_GROUP>clicon</CLICON_SOCK_GROUP>
  <CLICON_NETCONF_HELLO_OPTIONAL>true</CLICON_NETCONF_HELLO_OPTIONAL>
  <CLICON_RESTCONF_USER>www-data</CLICON_RESTCONF_USER>
  <CLICON_RESTCONF_PRIVILEGES>drop_perm</CLICON_RESTCONF_PRIVILEGES>
  <restconf>
      <enable>true</enable>
      <auth-type>none</auth-type>
      <pretty>false</pretty>
      <debug>0</debug>
      <log-destination>file</log-destination>
      <socket>
         <namespace>default</namespace>
         <address>0.0.0.0</address>
         <port>8088</port>
         <ssl>false</ssl>
      </socket>
   </restconf>
</clixon-config>
EOF

MEGS=500 # memory limit for child process (50 MB)

# Kill previous
echo "cfg: $cfg"
sudo clixon_backend -z -f $cfg -s init 

# Start backend
sudo clixon_backend -f $cfg -s init

# remove input and input dirs
#test ! -d input || rm -rf input
test ! -d output || sudo rm -rf output

# create if dirs dont exists
#test -d input || mkdir input
test -d output || mkdir output

if false; then
    # Dryrun without afl (comment this if you run for real)
    sudo /usr/local/sbin/clixon_restconf -rf $cfg < input/1.http || true
    sudo /usr/local/sbin/clixon_restconf -rf $cfg < input/2.http || true
    sudo /usr/local/sbin/clixon_restconf -rf $cfg < input/3.http || true
    sudo /usr/local/sbin/clixon_restconf -rf $cfg < input/4.http || true
    exit
fi

# Run script 
#  CC=/usr/bin/afl-clang 
sudo afl-fuzz -i input -o output -d -m $MEGS -- /usr/local/sbin/clixon_restconf -rf $cfg

# To continue existing
#sudo afl-fuzz -i - -o output -d -m $MEGS -- /usr/local/sbin/clixon_restconf -rf $cfg



