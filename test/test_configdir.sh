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
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
cdir=$dir/conf.d
cfile1=$cdir/00a.xml
cfile2=$cdir/01a.xml

test -d $cdir || mkdir $cdir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
</clixon-config>
EOF

cat <<EOF > $cfile1
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_MODULE_SET_ID>2</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test2</CLICON_FEATURE>
</clixon-config>
EOF

new "Start without configdir as baseline"
expectpart "$($clixon_cli -1 -f $cfg show options)" 0 'CLICON_MODULE_SET_ID: "1"' 'CLICON_FEATURE: "test1"' --not-- 'CLICON_FEATURE: "test2"'

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGDIR>$dir/dontexist</CLICON_CONFIGDIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
</clixon-config>
EOF

new "Start with wrong configdir"
expectpart "$($clixon_cli -1 -f $cfg -l o show options)" 255 "UNIX error: CLICON_CONFIGDIR:" "opendir: No such file or directory"

rm -f $cfile1
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGDIR>$dir/notexist</CLICON_CONFIGDIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
</clixon-config>
EOF

new "Start with wrong configdir -E override"
expectpart "$($clixon_cli -1 -f $cfg -E $cdir show options)" 0 'CLICON_MODULE_SET_ID: "1"' 'CLICON_FEATURE: "test1"' --not-- 'CLICON_FEATURE: "test2"'

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGDIR>$cdir</CLICON_CONFIGDIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_SET_ID>1</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test1</CLICON_FEATURE>
</clixon-config>
EOF

new "Start with empty configdir"
expectpart "$($clixon_cli -1 -f $cfg -l o show options)" 0 'CLICON_MODULE_SET_ID: "1"' 'CLICON_FEATURE: "test1"' --not-- 'CLICON_FEATURE: "test2"'

cat <<EOF > $cfile1
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_MODULE_SET_ID>2</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test2</CLICON_FEATURE>
</clixon-config>
EOF

new "Start with 1 extra configfile"
expectpart "$($clixon_cli -1 -f $cfg -l o show options)" 0 'CLICON_MODULE_SET_ID: "2"' 'CLICON_FEATURE: "test1"' 'CLICON_FEATURE: "test2"'

cat <<EOF > $cfile2
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_MODULE_SET_ID>3</CLICON_MODULE_SET_ID>
  <CLICON_FEATURE>test3</CLICON_FEATURE>
</clixon-config>
EOF

new "Start with 2 extra configfiles"
expectpart "$($clixon_cli -1 -f $cfg -l o show options)" 0 'CLICON_MODULE_SET_ID: "3"' 'CLICON_FEATURE: "test1"' 'CLICON_FEATURE: "test2"' 'CLICON_FEATURE: "test3"'

new "Start with 2 extra configfiles + command-line"
expectpart "$($clixon_cli -1 -f $cfg -o CLICON_MODULE_SET_ID=4 -o CLICON_FEATURE=test4 -l o show options)" 0 'CLICON_MODULE_SET_ID: "4"' 'CLICON_FEATURE: "test1"' 'CLICON_FEATURE: "test2"' 'CLICON_FEATURE: "test3"' 'CLICON_FEATURE: "test4"'

rm -rf $dir

new "endtest"
endtest
