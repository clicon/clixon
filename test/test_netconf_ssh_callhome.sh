#!/usr/bin/env bash
# Netconf callhome RFC 8071

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Skip it if no openssh
if ! [ -x "$(command -v ssh)" ]; then
    echo "...ssh not installed"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

# Dont run this test with valgrind
if [ $valgrindtest -ne 0 ]; then
    echo "...skipped "
    return 0 # skip
fi

: ${clixon_netconf_ssh_callhome:="clixon_netconf_ssh_callhome"}
: ${clixon_netconf_ssh_callhome_client:="clixon_netconf_ssh_callhome_client"}

APPNAME=example
cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
sshcfg=$dir/ssh.conf
sshdcfg=$dir/sshd.conf
rpccmd=$dir/rpccmd.xml
keydir=$dir/keydir
test -d $keydir || mkdir $keydir
chmod 700 $keydir
key=$keydir/mykey
# XXX cant get it to work with this file under tmp dir so have to place it in homedir
authfile=$HOME/.ssh/clixon_authorized_keys_removeme 

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_BASE_CAPABILITY>1</CLICON_NETCONF_BASE_CAPABILITY>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
}
EOF

cat <<EOF > $rpccmd
$DEFAULTHELLO$(chunked_framing "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>")
$(chunked_framing "<rpc $DEFAULTNS><close-session/></rpc>")
EOF

# Generate temporary ssh keys without passphrase
# This is to avoid being prompt for password or passhrase
rm -f $key $key.pub
ssh-keygen -q -f $key -b 256 -t ed25519 -N "" -C "Clixon test temporary key"
cp $key.pub $authfile

# Make the callback after a sleep in separate thread simulating the server
# The result is not checked, only the client-side
function callhomefn()
{
     cat<<EOF>$sshdcfg
PasswordAuthentication no
AuthorizedKeysFile     $authfile

EOF
    sleep 1 # There may be a far-fetched race condition here if this is too early

    new "Start Callhome in background"
    # sudo does not look in /usr/local/bin on eg cento8
    cmd=$(which ${clixon_netconf_ssh_callhome})
    echo "sudo ${cmd} -D 1 -a 127.0.0.1 -C $sshdcfg -c $cfg"
    expectpart "$(sudo ${cmd} -D 1 -a 127.0.0.1 -C $sshdcfg -c $cfg)" 255 "" 

    rm -f $authfile
}

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
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

# Start callhome server-side in background thread
callhomefn &

# Choose unhashed host key
# See rfc8071 Sec 3.1
#    C5  As part of establishing an SSH or TLS connection, the NETCONF/
#       RESTCONF client MUST validate the server's presented host key or
#       certificate.  This validation MAY be accomplished by certificate
#       path validation or by comparing the host key or certificate to a
#       previously trusted or "pinned" value.  If a certificate is
#       presented and it contains revocation-checking information, the
#       NETCONF/RESTCONF client SHOULD check the revocation status of the
#       certificate.  If it is determined that a certificate has been
#       revoked, the client MUST immediately close the connection.

cat<<EOF > $dir/knownhosts
. $(cat /etc/ssh/ssh_host_ed25519_key.pub)
. $(cat /etc/ssh/ssh_host_ecdsa_key.pub)
EOF
cat<<EOF > $sshcfg
StrictHostKeyChecking yes
UserKnownHostsFile $dir/knownhosts
HashKnownHosts no
EOF

new "Start Listener client"
echo "ssh -s -F $sshcfg -v -i $key -o ProxyUseFdpass=yes -o ProxyCommand=\"clixon_netconf_ssh_callhome_client -a 127.0.0.1\" . netconf"
#-F $sshcfg
expectpart "$(ssh -s -F $sshcfg -v -i $key -o ProxyUseFdpass=yes -o ProxyCommand="${clixon_netconf_ssh_callhome_client} -a 127.0.0.1" . netconf < $rpccmd)" 0 "<hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:capability:yang-library:1.0?revision=2019-01-04&amp;module-set-id=42</capability><capability>urn:ietf:params:netconf:capability:candidate:1.0</capability><capability>urn:ietf:params:netconf:capability:validate:1.1</capability><capability>urn:ietf:params:netconf:capability:startup:1.0</capability><capability>urn:ietf:params:netconf:capability:xpath:1.0</capability><capability>urn:ietf:params:netconf:capability:notification:1.0</capability><capability>urn:ietf:params:netconf:capability:with-defaults:1.0?basic-mode=explicit</capability></capabilities><session-id>2</session-id></hello>" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

# Wait 
wait

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

new "Endtest"
endtest

rm -f $authfile

rm -rf $dir
