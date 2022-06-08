#!/usr/bin/env bash
# yang augment and identityref tests in different modules
# See RFC7950 Sec 7.17
# This test defines an example-augment module which augments an interface
# defined in ietf-interface module. The interface then consists of identities
# both defined in the basic ietf-interfaces module (type) as well as the main
# module through the augmented module ()
# The ietf-interfaces is very restricted (not original).
# From a namespace perspective, there are two modules, with symbols as follows:
# 1. ietf-interface - urn:ietf:params:xml:ns:yang:ietf-interfaces
#    interfaces, interface, name, type
# 2. example-augment - urn:example:augment - mymod
#    (augmented):     mandatory-leaf, me, other,
#    (uses/grouping): ip, port, lid, lport
# Note augment+state not tested here (need plugin), simple test in test_restconf.sh
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/main.yang
fyang2=$dir/ietf-interfaces@2019-03-04.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>a:test</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  $RESTCONFIG
</clixon-config>
EOF

# Stub ietf-interfaces for test
# This is the target module (where the augment is applied to)
# The grouping is from rfc7950 Sec 7.12 with simplified types
cat <<EOF > $fyang2
module ietf-interfaces {
  yang-version 1.1;
  namespace "urn:ietf:params:xml:ns:yang:ietf-interfaces";
  prefix if;
  revision "2019-03-04";
  identity interface-type {
    description
      "Base identity from which specific interface types are
       derived.";
  }
  identity fddi {
     base interface-type;
  }
  container interfaces {
    description      "Interface parameters.";
    list interface {
      key "name";
      leaf name {
        type string;
      }
      leaf type {
        type identityref {
          base interface-type;
        }
        mandatory true;
      }
    }
  }
  grouping endpoint {
       description "A reusable endpoint group. From rf7950 Sec 7.12.2";
       leaf ip {
         type string;
       }
       leaf port {
         type uint16;
       }
   }
   /* Original choice that gets augmented */
   choice target {
      case stream {
        leaf one{
           type string;
        }
      }
   }
   notification started {
     leaf id{
       type string;
     }
   }

}
EOF

# From rfc7950 sec 7.17
# This is the main module where the augment exists
cat <<EOF > $fyang
module example-augment {
       yang-version 1.1;
       namespace "urn:example:augment";
       prefix mymod;
       import ietf-interfaces {
         prefix if;
       }
       revision "2019-03-04";
       identity some-new-iftype {
          base if:interface-type;
       }
       identity my-type {
          description "an identity based in the main module";
       }
       identity you {
          base my-type;
       }
       grouping localgroup {
         description "Local grouping defining lid and lport";
         leaf lid {
            description "this will be kept as-is";
            type string;
         }
         leaf lport {
           description "this will be refined";
           type uint16;
         }
       }
       augment "/if:interfaces/if:interface" {
          when 'derived-from-or-self(if:type, "mymod:some-new-iftype")'; 
          container ospf { /* moved from test_restconf_err (two-level augment) */
            leaf reference-bandwidth {
	      type uint32;
            }
          }
          leaf mandatory-leaf {
             mandatory true;
             type string;
          }
          leaf me {
              type identityref {
                    base mymod:my-type;
              }
          }
          leaf other {
              type identityref {
                    base if:interface-type;
              }
          }
          uses if:endpoint {
            description "Use an external grouping defining ip and port";
            refine port {
              default 80;
            }
            refine ip {
	      description "double refine triggered mem error";             
            }
          }
          uses localgroup {
            description "Use a local grouping defining lip and lport";
            refine lport {
              default 8080;
            }
          }
       }
       /* augment choice */
       augment "/if:target" {
           case datastore {
	      leaf two{
                 type uint32;
              }
           }
       }
       /* augment notification */
       augment "/if:started" {
          leaf argument{
             type string;
          }
       }
       /* augment a list */
       augment "/if:interfaces" {
          list ports{
	     key id;
	     leaf id {
                type int32;
	     }
	     leaf str {
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

# mandatory-leaf See RFC7950 Sec 7.17
new "netconf set interface with augmented type and mandatory leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
  <interface xmlns:mymod=\"urn:example:augment\">
    <name>e1</name>
    <type>mymod:some-new-iftype</type>
    <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
  </interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf verify get with refined ports"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:mymod=\"urn:example:augment\"><name>e1</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><mymod:port>80</mymod:port><mymod:lport>8080</mymod:lport></interface></interfaces>" ""

new "netconf set identity defined in other"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
  <interface xmlns:mymod=\"urn:example:augment\">
    <name>e2</name>
    <type>mymod:some-new-iftype</type> 
    <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
    <mymod:other>if:fddi</mymod:other>
  </interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set identity defined in main"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
<interface xmlns:mymod=\"urn:example:augment\">
   <name>e3</name>
   <type>mymod:some-new-iftype</type>
   <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
   <mymod:me>mymod:you</mymod:me>
 </interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# restconf and augment
new "restconf get augment json"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"e1","type":"example-augment:some-new-iftype","example-augment:mandatory-leaf":"true","example-augment:port":80,"example-augment:lport":8080},{"name":"e2","type":"example-augment:some-new-iftype","example-augment:mandatory-leaf":"true","example-augment:other":"ietf-interfaces:fddi","example-augment:port":80,"example-augment:lport":8080},{"name":"e3","type":"example-augment:some-new-iftype","example-augment:mandatory-leaf":"true","example-augment:me":"you","example-augment:port":80,"example-augment:lport":8080}\]}}'

new "restconf get augment xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" '<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
<interface xmlns:mymod="urn:example:augment"><name>e1</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><mymod:port>80</mymod:port><mymod:lport>8080</mymod:lport></interface><interface xmlns:mymod="urn:example:augment"><name>e2</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><mymod:other>if:fddi</mymod:other><mymod:port>80</mymod:port><mymod:lport>8080</mymod:lport></interface><interface xmlns:mymod="urn:example:augment"><name>e3</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><mymod:me>mymod:you</mymod:me><mymod:port>80</mymod:port><mymod:lport>8080</mymod:lport></interface></interfaces>'

#<interface xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>e1</name><ospf xmlns="urn:example:augment"><reference-bandwidth>23</reference-bandwidth></ospf></interface>'

XML=$(cat <<EOF
<interface xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces" xmlns:mymod="urn:example:augment"><name>e1</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><ospf xmlns="urn:example:augment"><reference-bandwidth>23</reference-bandwidth></ospf></interface>
EOF
   )

# XXX: Since derived-from etc are NOT implemented, this test may have false positives
# revisit when it is implemented.
new "restconf PUT augment multi-namespace path e1 (whole path)"
expectpart "$(curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1 -d "$XML")" 0 "HTTP/$HVER 204"

XML=$(cat <<EOF
<ospf xmlns="urn:example:augment"><reference-bandwidth>23</reference-bandwidth></ospf>
EOF
   )

new "restconf POST augment multi-namespace path e2 (middle path)"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e2 -d "$XML" )" 0 "HTTP/$HVER 201"

new "restconf GET augment multi-namespace top"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"e1","type":"example-augment:some-new-iftype","example-augment:ospf":{"reference-bandwidth":23},"example-augment:mandatory-leaf":"true","example-augment:port":80,"example-augment:lport":8080},{"name":"e2","type":"example-augment:some-new-iftype","example-augment:ospf":{"reference-bandwidth":23},"example-augment:mandatory-leaf":"true","example-augment:other":"ietf-interfaces:fddi","example-augment:port":80,"example-augment:lport":8080},{"name":"e3","type":"example-augment:some-new-iftype","example-augment:mandatory-leaf":"true","example-augment:me":"you","example-augment:port":80,"example-augment:lport":8080}\]}}'

new "restconf GET augment multi-namespace level 1"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interface":\[{"name":"e1","type":"example-augment:some-new-iftype","example-augment:ospf":{"reference-bandwidth":23},"example-augment:mandatory-leaf":"true","example-augment:port":80,"example-augment:lport":8080}\]}'

new "restconf GET augment multi-namespace cross"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1/example-augment:ospf)" 0 "HTTP/$HVER 200" '{"example-augment:ospf":{"reference-bandwidth":23}}'

new "restconf GET augment multi-namespace cross level 2"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1/example-augment:ospf/reference-bandwidth)" 0 "HTTP/$HVER 200" '{"example-augment:reference-bandwidth":23}'

new "delete interfaces"
expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 204"

# augmented lists
XML="<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><ports xmlns=\"urn:example:augment\"><id>22</id><str>nisse</str></ports><ports xmlns=\"urn:example:augment\"><id>44</id><str>kalle</str></ports></interfaces>"
new "netconf PUT augmented list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" 

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type='subtree'><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></filter></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data>$XML</data></rpc-reply>"

JSON='{"ietf-interfaces:interfaces":{"example-augment:ports":[{"id":22,"str":"foo"},{"id":44,"str":"bar"}]}}'

new "restconf PUT augmented list"
expectpart "$(curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces -d "$JSON")" 0 "HTTP/$HVER 204" 

# Escaped [] why?
JSON1='{"ietf-interfaces:interfaces":{"example-augment:ports":\[{"id":22,"str":"foo"},{"id":44,"str":"bar"}\]}}'
new "restconf GET augmented list"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" "$JSON1"

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

rm -rf $dir

new "endtest"
endtest
