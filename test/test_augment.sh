#!/bin/bash
# yang augment and identityref tests in different modules
# See RFC7950 Sec 7.17
# This test defines an example-augment module which augments an interface
# defined in ietf-interface module. The interface then consists of identities
# both defined in the basic ietf-interfaces module (type) as well as the main
# module through the augmented module ()
# The ietf-interfaces is very restricted (not original).

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
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
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
# Note "when" is not present
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
/*       when 'derived-from-or-self(if:type, "mymod:some-new-iftype")'; */
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

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

# mandatory-leaf See RFC7950 Sec 7.17
new "netconf set interface with augmented type and mandatory leaf"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
  <interface xmlns:mymod="urn:example:augment">
    <name>e1</name>
    <type>mymod:some-new-iftype</type>
    <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
  </interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf verify get with refined ports"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface xmlns:mymod="urn:example:augment"><name>e1</name><type>mymod:some-new-iftype</type><mandatory-leaf>true</mandatory-leaf><port>80</port><lport>8080</lport></interface></interfaces></data></rpc-reply>]]>]]>$'

new "netconf set identity defined in other"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
  <interface xmlns:mymod="urn:example:augment">
    <name>e2</name>
    <type>fddi</type>
    <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
    <other>if:fddi</other>
  </interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf set identity defined in main"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
<interface xmlns:mymod="urn:example:augment">
   <name>e3</name>
   <type>fddi</type>
   <mymod:mandatory-leaf>true</mymod:mandatory-leaf>
   <me>mymod:you</me>
 </interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

# restconf and augment

new "restconf get augment"
expectpart "$(curl -s -i -X GET http://localhost/restconf/data/ietf-interfaces:interfaces)" 0 'HTTP/1.1 200 OK' '{"ietf-interfaces:interfaces":{"interface":\[{"name":"e1","type":"example-augment:some-new-iftype","example-augment:mandatory-leaf":"true","example-augment:port":80,"example-augment:lport":8080},{"name":"e2","type":"fddi","example-augment:mandatory-leaf":"true","example-augment:other":"ietf-interfaces:fddi","example-augment:port":80,"example-augment:lport":8080},{"name":"e3","type":"fddi","example-augment:mandatory-leaf":"true","example-augment:me":"you","example-augment:port":80,"example-augment:lport":8080}\]}}'

new "restconf get augment xml"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+xml' http://localhost/restconf/data/ietf-interfaces:interfaces)" 0 'HTTP/1.1 200 OK' '<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface xmlns:mymod="urn:example:augment"><name>e1</name><type>mymod:some-new-iftype</type><mandatory-leaf>true</mandatory-leaf><port>80</port><lport>8080</lport></interface><interface xmlns:mymod="urn:example:augment"><name>e2</name><type>fddi</type><mandatory-leaf>true</mandatory-leaf><other>if:fddi</other><port>80</port><lport>8080</lport></interface><interface xmlns:mymod="urn:example:augment"><name>e3</name><type>fddi</type><mandatory-leaf>true</mandatory-leaf><me>mymod:you</me><port>80</port><lport>8080</lport></interface></interfaces>'

new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg
sudo pkill -u root -f clixon_backend

rm -rf $dir
