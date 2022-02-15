#!/usr/bin/env bash
# Restconf HTTP/1.1 Expect/Continue functionality
# Trigger Expect by curl -H. Some curls seem to trigger one on large PUTs but not all
# If both HTTP/1 and /2, force to /1 to test native http/1 implementation

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

if ! ${HAVE_HTTP1}; then
    echo "...skipped: Must run with http/1"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

APPNAME=example

if [ ${HAVE_LIBNGHTTP2} = true ]; then
    # Pin to http/1
    HAVE_LIBNGHTTP2=false
    CURLOPTS="${CURLOPTS} --http1.1"
    HVER=1.1
fi

cfg=$dir/conf.xml
fyang=$dir/restconf.yang
fjson=$dir/large.json

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
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

new "generate large request"
# Add large put, curl seems to create a Expect:100-continue after 1024 bytes
# Alt: add in file if nr=5000 reacts with "Argument list too long"
echo -n '{"example:table":{"parameter":[' > $fjson

nr=1000
for (( i=0; i<$nr; i++ )); do  
    if [ $i -ne 0 ]; then
	echo -n ",
" >> $fjson
    fi
    echo -n "{\"name\":\"A$i\",\"value\":\"$i\"}" >> $fjson
done
echo -n "]}}" >> $fjson

new "restconf large PUT"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -H "Expect: 100-continue" -d @$fjson $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 100 Continue" "HTTP/$HVER 201"

new "restconf PUT with expect" 
expectpart "$(curl $CURLOPTS -H "Expect: 100-continue" -X POST -H "Content-Type: application/yang-data+json" -d '{"example:parameter":[{"name":"A","value":"42"}]}' $RCPROTO://localhost/restconf/data/example:table)" 0 "HTTP/$HVER 100 Continue" "HTTP/$HVER 201"

new "restconf GET"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:table/parameter=A)" 0 "HTTP/$HVER 200" '{"example:parameter":\[{"name":"A","value":"42"}\]}'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

# Set by restconf_config
unset RESTCONFIG
unset nr
unset HAVE_LIBNGHTTP2

rm -rf $dir

new "endtest"
endtest
