#!/usr/bin/env bash
# Create restconf backend config with a single socket
# ipv4 no-ssl
# The script defines a VARIABLE containing XML config
# This is either inserted into the startup db, or installed in the backend using the
# restconfigrun() function.
# The config relies on clixon-restconf.yang being loaded.

RESTCONFIG=$(cat <<EOF
<restconf xmlns="https://clicon.org/restconf">
   <ssl-enable>false</ssl-enable>
   <auth-type>password</auth-type>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
</restconf>
EOF
)

# Install the config above on a backend
restconfigrun()
{
    new "netconf edit config"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

    new "netconf commit"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"
}
