#!/usr/bin/env bash
# Test config file and extra config dir.
# Use clixon_cli and assume clixon_backend/restconf/netconf behaves the same
# Start without configdir as baseline
# Start with wrong configdir
# Start with empty configfile
# Start with 1 extra configfile
# Start with 2 extra configfiles
# Start with 2 extra configfiles + command-line
# Two options are used for testing:
# CLICON_MODULE_SET_ID is a single var (replaced)
# CLICON_FEATURE is a list var (append)
# Check subconfigs, ie /restconf/server-cert-path used since it does not have default
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
cdir=$dir/conf.d
cfile1=$cdir/01a.xml
cfile2=$cdir/02a.xml
cfile3=$cdir/03a.xml
cfile4=$cdir/04a.xxxml

rm -rf $cdir
mkdir $cdir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
</clixon-config>
EOF

# dummy
touch  $dir/spec.cli

new "test params: -f $cfg"

new "Start without configdir as baseline"
cat <<EOF > $cfile1
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_MODULE_SET_ID>2</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test2</CLICON_FEATURE>
</clixon-config>
EOF

expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>" "<CLICON_FEATURE>test1</CLICON_FEATURE>" --not-- "<CLICON_FEATURE>test2</CLICON_FEATURE>"

new "Start with wrong configdir"
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGDIR>$dir/dontexist</CLICON_CONFIGDIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
</clixon-config>
EOF

expectpart "$($clixon_cli -1 -f $cfg -l o -C xml)" 0 "Warning: CLICON_CONFIGDIR:/var/tmp/./test_config_dir.sh/dontexist: No such directory"

new "Start with wrong configdir -E override"
rm -f $cfile1
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGDIR>$dir/notexist</CLICON_CONFIGDIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
</clixon-config>
EOF

expectpart "$($clixon_cli -1 -f $cfg -E $cdir -C xml)" 0 "<CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>" "<CLICON_FEATURE>test1</CLICON_FEATURE>" --not-- "<CLICON_FEATURE>test2</CLICON_FEATURE>"

new "Start with empty configdir"
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGDIR>$cdir</CLICON_CONFIGDIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
  <restconf>
     <server-cert-path>foo</server-cert-path>
  </restconf>
</clixon-config>
EOF

expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>" "<CLICON_FEATURE>test1</CLICON_FEATURE>" --not-- "<CLICON_FEATURE>test2</CLICON_FEATURE>"

new "Check subconfig"
expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<restconf>" "<server-cert-path>foo</server-cert-path>"

new "Start with 1 extra configfile"
cat <<EOF > $cfile1
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_MODULE_SET_ID>2</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test2</CLICON_FEATURE>
  <restconf>
     <server-cert-path>bar</server-cert-path>
  </restconf>
</clixon-config>
EOF

expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<CLICON_MODULE_SET_ID>2</CLICON_MODULE_SET_ID>" "<CLICON_FEATURE>test1</CLICON_FEATURE>" "<CLICON_FEATURE>test2</CLICON_FEATURE>"

new "Check subconfig override"
expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<restconf>" "<server-cert-path>bar</server-cert-path>"

new "Start with 2 extra configfiles"
cat <<EOF > $cfile2
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_MODULE_SET_ID>3</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test3</CLICON_FEATURE>
</clixon-config>
EOF

expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<CLICON_MODULE_SET_ID>3</CLICON_MODULE_SET_ID>" "<CLICON_FEATURE>test1</CLICON_FEATURE>" "<CLICON_FEATURE>test2</CLICON_FEATURE>" "<CLICON_FEATURE>test3</CLICON_FEATURE>"

new "Start with 2 extra configfiles + command-line -C xml"
expectpart "$($clixon_cli -1 -f $cfg -o CLICON_MODULE_SET_ID=4 -o CLICON_FEATURE=test4 -C xml)" 0 "<CLICON_MODULE_SET_ID>4</CLICON_MODULE_SET_ID>" "<CLICON_FEATURE>test1</CLICON_FEATURE>" "<CLICON_FEATURE>test2</CLICON_FEATURE>" "<CLICON_FEATURE>test3</CLICON_FEATURE>" "<CLICON_FEATURE>test4</CLICON_FEATURE>" 

# Ensure two sub-dirs (eg <restconf>) only last is present
cat <<EOF > $cfile3
<clixon-config xmlns="http://clicon.org/config">
  <restconf>
     <server-cert-path>nisse</server-cert-path>
  </restconf>
</clixon-config>
EOF
new "Last <restconf> replaces first"
expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<restconf>" "<server-cert-path>nisse</server-cert-path>" --not-- "<server-cert-path>bar</server-cert-path>"

# Ensure file without .xml suffix is not read
cat <<EOF > $cfile4
<clixon-config xmlns="http://clicon.org/config">
  <restconf>
     <server-cert-path>laban</server-cert-path>
  </restconf>
</clixon-config>
EOF

new "File without .xml is not read"
expectpart "$($clixon_cli -1 -f $cfg -C xml)" 0 "<restconf>" "<server-cert-path>nisse</server-cert-path>" --not-- "<server-cert-path>laban</server-cert-path>"

rm -rf $dir

new "endtest"
endtest
