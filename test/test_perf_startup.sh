#!/bin/bash
# Startup performance tests for different formats and startup modes.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Number of list/leaf-list entries in file
: ${perfnr:=10000}

APPNAME=example

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang

cat <<EOF > $fyang
module scaling{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ip;
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
    leaf-list c {
       type string;
    }
  }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_CLI_GENMODEL_TYPE>VARS</CLICON_CLI_GENMODEL_TYPE>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
</clixon-config>
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi
fi

# First generate large XML file
# Use it latter to generate startup-db in xml, tree formats
tmpx=$dir/tmp.xml
new "generate large startup config ($tmpx) with $perfnr entries"
echo -n "<config><x xmlns=\"urn:example:clixon\">" > $tmpx
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $tmpx
done
echo "</x></config>" >> $tmpx

if false; then # XXX JSON dont work as datastore yet
# Then generate large JSON file (cant translate namespace - long story)
tmpj=$dir/tmp.json
new "generate large startup config ($tmpj) with $perfnr entries"
echo -n '{"config": {"scaling:x":{"y":[' > $tmpj
for (( i=0; i<$perfnr; i++ )); do  
    if [ $i -ne 0 ]; then
	echo -n ",{\"a\":$i,\"b\":$i}" >> $tmpj
    else
	echo -n "{\"a\":$i,\"b\":$i}" >> $tmpj
    fi

done
echo "]}}}" >> $tmpj
fi

# Loop over mode and format
for mode in startup running; do
    file=$dir/${mode}_db
    for format in tree xml; do # json - something w namespaces
	sudo rm -f $file
	sudo touch $file
	sudo chmod 666 $file
	case $format in
	    xml)
		echo "cp $tmpx $file"
		cp $tmpx $file
	    ;;
	    json)
		cp $tmpj $file
	    ;;
	    tree)
		echo "clixon_util_datastore -d ${mode} -f tree -y $fyang -b $dir -x $tmpx put create"

		clixon_util_datastore -d ${mode} -f tree -y $fyang -b $dir -x $tmpx put create
	    ;;
	esac
	new "Startup format: $format mode:$mode"
#	echo "time sudo $clixon_backend -F1 -D $DBG -s $mode -f $cfg -y $fyang -o CLICON_XMLDB_FORMAT=$format"
	# Cannot use start_backend here due to expected error case
{ time -p sudo $clixon_backend -F1 -D $DBG -s $mode -f $cfg -y $fyang -o CLICON_XMLDB_FORMAT=$format 2> /dev/null; } 2>&1 | awk '/real/ {print $2}'

    done
done

rm -rf $dir
