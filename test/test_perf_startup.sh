#!/usr/bin/env bash
# Startup performance tests for different formats and startup modes.
# Generate file in different formats:
# xml, xml pretty-printed, xml with prefixes, json

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Number of list/leaf-list entries in file
: ${perfnr:=20000}

APPNAME=example

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang

sx=$dir/sx.xml
sxpp=$dir/sxpp.xml
sxpre=$dir/sxpre.xml
sj=$dir/sj.xml

# NOTE, added a deep yang structure (x0,x1,x2) to expose performance due to turned off caching.
cat <<EOF > $fyang
module scaling{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ip;
   container "x0" {
     container x1 {
       list x2 {
         key "name";
         leaf name {
           type string;
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
           leaf-list c {
             type string;
           }
         }
       }
     }
  }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
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

new "generate plain xml startup config ($sx) with $perfnr entries"
echo -n "<config><x0 xmlns=\"urn:example:clixon\"><x1><x2><name>ip</name><x>" > $sx
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $sx
done
echo "</x></x2></x1></x0></config>" >> $sx

new "generate prefixed xml startup config ($sxpre) with $perfnr entries"
echo -n "<config><ex:x0 xmlns:ex=\"urn:example:clixon\"><ex:x1><ex:x2><ex:name>ip</ex:name><ex:x>" > $sxpre
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<ex:y><ex:a>$i</ex:a><ex:b>$i</ex:b></ex:y>" >> $sxpre
done
echo "</ex:x></ex:x2></ex:x1></ex:x0></config>" >> $sxpre
    
new "generate pretty-printed xml startup config ($sxpp) with $perfnr entries"
cat<<EOF >  $sxpp
<config>
   <x0 xmlns="urn:example:clixon">
      <x1>
         <x2>
            <name>ip</name>
            <x>
EOF
    for (( i=0; i<$perfnr; i++ )); do  
        echo "               <y>" >> $sxpp
        echo "                  <a>$i</a>" >> $sxpp
        echo "                  <b>$i</b>" >> $sxpp
        echo "               </y>" >> $sxpp
    done
cat<<EOF >>  $sxpp
            </x>
         </x2>
      </x1>
   </x0>
</config>
EOF

if false; then # ---------- not supported
new "generate pretty-printed json startup config ($sj) with $perfnr entries"
echo -n '{"config": {"scaling:x":{"y":[' > $sj
for (( i=0; i<$perfnr; i++ )); do  
    if [ $i -ne 0 ]; then
        echo -n ",{\"a\":$i,\"b\":$i}" >> $sj
    else
        echo -n "{\"a\":$i,\"b\":$i}" >> $sj
    fi

done
echo "]}}}" >> $sj
fi

# Loop over mode and format
mode=startup # running
format=xml
sdb=$dir/${mode}_db
for variant in prefix plain pretty; do
    case $variant in
        plain)
            f=$sx
            ;;
        pretty)
            f=$sxpp
            ;;
        prefix)
            f=$sxpre
            ;;
       esac

    sudo rm -f $sdb
    sudo touch $sdb
    sudo chmod 666 $sdb
    
    cp $f $sdb
    new "Startup $format $variant"
    # Cannot use start_backend here due to expected error case
    { time -p sudo $clixon_backend -F1 -D $DBG -s $mode -f $cfg -y $fyang -o CLICON_XMLDB_FORMAT=$format 2> /dev/null; } 2>&1 | awk '/real/ {print $2}'
done

rm -rf $dir

# unset conditional parameters 
unset perfnr
unset format

new "endtest"
endtest
