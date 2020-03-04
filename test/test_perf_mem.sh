#!/usr/bin/env bash
# Backend Memory tests, footprint using the clixon-conf state statistics
# Create a large datastore, load it and measure

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# ENable this for massif memory profiling
#clixon_backend="valgrind --tool=massif clixon_backend"

clixon_util_xpath=clixon_util_xpath 

# Number of list/leaf-list entries in file
: ${perfnr:=10000}

APPNAME=example

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang
pidfile=$dir/pidfile

cat <<EOF > $fyang
module scaling{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import "clixon-config" {
     prefix cc;
   }
   container x {
    list y {
      key "a";
      leaf a {
        type int32;
      }
      leaf b {
        type int32;
      }
    }
  }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
</clixon-config>
EOF

# Test function
# Arguments:
# 1: nr   size of large list
testrun(){
    nr=$1

    new "test params: -f $cfg"
    if [ $BE -ne 0 ]; then

	new "generate config with $nr list entries"
	echo -n "<config><x xmlns=\"urn:example:clixon\">" > $dir/startup_db
	for (( i=0; i<$nr; i++ )); do  
	    echo -n "<y><a>$i</a><b>$i</b></y>" >> $dir/startup_db
	done
	echo "</x></config>" >> $dir/startup_db


	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s startup -f $cfg"
	start_backend -s startup -f $cfg
    fi

    new "waiting"
    wait_backend

    pid=$(cat $pidfile)

    new "netconf get state"
    res=$(echo "<rpc><get><filter type=\"xpath\" select=\"/cc:clixon-stats\" xmlns:cc=\"http://clicon.org/config\"/></get></rpc>]]>]]>" | $clixon_netconf -qf $cfg)

    echo "Total"
    echo -n "   objects: "
    echo $res | $clixon_util_xpath -p "/rpc-reply/data/clixon-stats/global/xmlnr" | awk -F ">" '{print $2}' | awk -F "<" '{print $1}'
    if [ -f /proc/$pid/statm ]; then     # This ony works on Linux 
#	cat /proc/$pid/statm
	echo -n "   mem: "
	cat /proc/$pid/statm|awk '{print $1*4/1000 "M"}'
    fi
    for db in running candidate startup; do
	echo "$db"
	resdb=$(echo "$res" | $clixon_util_xpath -p "/rpc-reply/data/clixon-stats/datastore[name=\"$db\"]")
	resdb=${resdb#"nodeset:0:"}
	echo -n "   objects: "
	echo $resdb | $clixon_util_xpath -p "datastore/nr" | awk -F ">" '{print $2}' | awk -F "<" '{print $1}'
	echo -n "   mem: "
	echo $resdb | $clixon_util_xpath -p "datastore/size" | awk -F ">" '{print $2}' | awk -F "<" '{print $1}' | awk '{print $1/1000000 "M"}'
    done

    if [ $BE -ne 0 ]; then
	new "Kill backend"
	# Check if premature kill
	pid=$(pgrep -u root -f clixon_backend)
	if [ -z "$pid" ]; then
	    err "backend already dead"
	fi
	# kill backend

	new "Zap backend"
	stop_backend -f $cfg
    fi
}

new "Memory test for backend with 1 $perfnr entries"
testrun $perfnr

rm -rf $dir

# unset conditional parameters 
unset perfnr

