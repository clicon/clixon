#!/usr/bin/env bash
# Restconf error-code functionality
# See RFC8040
# Testcases:
# Sec 4.3 (GET): If a retrieval request for a data resource represents an
# instance that does not exist, then an error response containing a "404 Not
# Found" status-line MUST be returned by the server.  The error-tag
# value "invalid-value" is used in this case.
# RFC 7231:
# Response messages with an error status code
# usually contain a payload that represents the error condition, such
# that it describes the error state and what next steps are suggested
# for resolving it.


# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang
fyang2=$dir/aug.yang
fxml=$dir/initial.xml

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang2
module augm{
   yang-version 1.1;
   namespace "urn:example:aug";
   prefix aug;
   description "Used as a base for augment";
   container route-state {
	description
	    "Root container for routing models";
	config "false";
	container dynamic {
	}
   }
}
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import aug {
        description "Just for augment";
	prefix "aug";
   }

   list a {
      key k;
      leaf k {
         type int32;
      }
      leaf description{
         type string;
      }
      leaf b{
         type string;
      }
      container c{
         presence "for test";
      }
      list d{
         key k;
         leaf k {
            type string;
         }
      }
   }
   augment "/aug:route-config/aug:dynamic" {
      container ospf {
         container routers {
	    container auto-cost {
            	leaf reference-bandwidth {
			    type uint32;
                }
            }
         }
      }
   }
}
EOF

# Initial tree
XML=$(cat <<EOF
<a xmlns="urn:example:clixon"><k>0</k><description>No leaf b, No container c, No leaf d</description></a>
EOF
   )

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill clixon_backend # to be sure
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "restconf POST initial tree"
expecteq "$(curl -s -X POST -H 'Content-Type: application/yang-data+xml' -d "$XML" http://localhost/restconf/data)" 0 ''

new "restconf GET initial datastore"
expecteq "$(curl -s -X GET -H 'Accept: application/yang-data+xml' http://localhost/restconf/data/example:a)" 0 "$XML
"

new "restconf GET non-existent container body"
expectpart "$(curl -si -X GET http://localhost/restconf/data/example:a/c)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"rpc-error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}}'

new "restconf GET invalid (no yang) container body"
expectpart "$(curl -si -X GET http://localhost/restconf/data/example:a/xxx)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

new "restconf GET invalid (no yang) element"
expectpart "$(curl -si -X GET http://localhost/restconf/data/example:xxx)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

if false; then
new "restconf POST non-existent (no yang) element"
# should be invalid element
expectpart "$(curl -is -X POST -H 'Content-Type: application/yang-data+xml' -d "$XML" http://localhost/restconf/data/example:a=23/xxx)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Unknown element: '


new "restconf GET multi-namespace path"
# simplify yang
# works for config?
expectpart "$(curl -si -X GET http://localhost/restconf/data/augm:route-state/dynamic/ospf/routers/auto-cost/reference-bandwidth)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"rpc-error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Unknown element: 'xxx'"}}}}'
fi
new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
