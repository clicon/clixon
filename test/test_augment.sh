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

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>a:test</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

# Stub ietf-interfaces for test
# This is the target module (where the augment is applied to)
# The grouping is from rfc7950 Sec 7.12 with simplified types
cat <<EOF > $fyang2
module ietf-interfaces {
  yang-version 1.1;
  namespace "urn:ietf:params:xml:ns:yang:ietf-interfaces";
  revision "2019-03-04";
  prefix if;
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
}
EOF

# From rfc7950 sec 7.17
# This is the main module where the augment exists
cat <<EOF > $fyang
module example-augment {
       yang-version 1.1;
       namespace "urn:example:augment";
       prefix mymod;
       revision "2019-03-04";
       import ietf-interfaces {
         prefix if;
       }
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
          }
          uses localgroup {
            description "Use a local grouping defining lip and lport";
            refine lport {
              default 8080;
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
new "waiting"
wait_backend

if [ $RC -ne 0 ]; then

    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

    new "waiting"
    wait_restconf
fi

# mandatory-leaf See RFC7950 Sec 7.17
new "netconf set interface with augmented type and mandatory leaf"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
  <interface xmlns:mymod="urn:example:augment">
    <name>e1</name>
    <type>mymod:some-new-iftype</type>
    <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
  </interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf verify get with refined ports"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface xmlns:mymod="urn:example:augment"><name>e1</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><mymod:port>80</mymod:port><mymod:lport>8080</mymod:lport></interface></interfaces></data></rpc-reply>]]>]]>$'

new "netconf set identity defined in other"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
  <interface xmlns:mymod="urn:example:augment">
    <name>e2</name>
    <type>fddi</type>
    <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
    <mymod:other>if:fddi</mymod:other>
  </interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf set identity defined in main"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
<interface xmlns:mymod="urn:example:augment">
   <name>e3</name>
   <type>fddi</type>
   <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
   <mymod:me>mymod:you</mymod:me>
 </interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

# restconf and augment
new "restconf get augment json"
echo "curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/1.1 200 OK" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"e1","type":"example-augment:some-new-iftype","example-augment:mandatory-leaf":"true","example-augment:port":80,"example-augment:lport":8080},{"name":"e2","type":"fddi","example-augment:mandatory-leaf":"true","example-augment:other":"ietf-interfaces:fddi","example-augment:port":80,"example-augment:lport":8080},{"name":"e3","type":"fddi","example-augment:mandatory-leaf":"true","example-augment:me":"you","example-augment:port":80,"example-augment:lport":8080}\]}}'

new "restconf get augment xml"
expectpart "$(curl -sik -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 'HTTP/1.1 200 OK' '<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface xmlns:mymod="urn:example:augment"><name>e1</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><mymod:port>80</mymod:port><mymod:lport>8080</mymod:lport></interface><interface><name>e2</name><type>fddi</type><mymod:mandatory-leaf xmlns:mymod="urn:example:augment">true</mymod:mandatory-leaf><mymod:other xmlns:mymod="urn:example:augment">if:fddi</mymod:other><mymod:port xmlns:mymod="urn:example:augment">80</mymod:port><mymod:lport xmlns:mymod="urn:example:augment">8080</mymod:lport></interface><interface><name>e3</name><type>fddi</type><mymod:mandatory-leaf xmlns:mymod="urn:example:augment">true</mymod:mandatory-leaf><mymod:me xmlns:mymod="urn:example:augment">mymod:you</mymod:me><mymod:port xmlns:mymod="urn:example:augment">80</mymod:port><mymod:lport xmlns:mymod="urn:example:augment">8080</mymod:lport></interface></interfaces>'

#<interface xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>e1</name><ospf xmlns="urn:example:augment"><reference-bandwidth>23</reference-bandwidth></ospf></interface>'

XML=$(cat <<EOF
<interface xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces" xmlns:mymod="urn:example:augment"><name>e1</name><type>mymod:some-new-iftype</type><mymod:mandatory-leaf>true</mymod:mandatory-leaf><ospf xmlns="urn:example:augment"><reference-bandwidth>23</reference-bandwidth></ospf></interface>
EOF
   )

# XXX: Since derived-from etc are NOT implemented, this test may have false positives
# revisit when it is implemented.
new "restconf PUT augment multi-namespace path e1 (whole path)"
expectpart "$(curl -sik -X PUT -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1 -d "$XML")" 0 "HTTP/1.1 204 No Content"

XML=$(cat <<EOF
<ospf xmlns="urn:example:augment"><reference-bandwidth>23</reference-bandwidth></ospf>
EOF
   )

new "restconf POST augment multi-namespace path e2 (middle path)"
expectpart "$(curl -sik -X POST -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e2 -d "$XML" )" 0 "HTTP/1.1 201 Created"

new "restconf GET augment multi-namespace top"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 'HTTP/1.1 200 OK' '{"ietf-interfaces:interfaces":{"interface":\[{"name":"e1","type":"example-augment:some-new-iftype","example-augment:ospf":{"reference-bandwidth":23},"example-augment:mandatory-leaf":"true","example-augment:port":80,"example-augment:lport":8080},{"name":"e2","type":"fddi","example-augment:ospf":{"reference-bandwidth":23},"example-augment:mandatory-leaf":"true","example-augment:other":"ietf-interfaces:fddi","example-augment:port":80,"example-augment:lport":8080},{"name":"e3","type":"fddi","example-augment:mandatory-leaf":"true","example-augment:me":"you","example-augment:port":80,"example-augment:lport":8080}\]}}'

new "restconf GET augment multi-namespace level 1"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1)" 0 'HTTP/1.1 200 OK' '{"ietf-interfaces:interface":\[{"name":"e1","type":"example-augment:some-new-iftype","example-augment:ospf":{"reference-bandwidth":23},"example-augment:mandatory-leaf":"true","example-augment:port":80,"example-augment:lport":8080}\]}'

new "restconf GET augment multi-namespace cross"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1/example-augment:ospf)" 0 'HTTP/1.1 200 OK' '{"example-augment:ospf":{"reference-bandwidth":23}}'

new "restconf GET augment multi-namespace cross level 2"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1/example-augment:ospf/reference-bandwidth)" 0 'HTTP/1.1 200 OK' '{"example-augment:reference-bandwidth":23}'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

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
