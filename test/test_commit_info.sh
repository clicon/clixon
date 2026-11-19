#!/usr/bin/env bash
# clixon-lib commit-info rpc: digest of the running datastore
# The digest is computed on running as compact XML without default values.
# Checks:
# - Empty running gives the digest of the empty string
# - Edits to candidate do not change the digest until commit
# - After commit, digest equals the digest of the compact XML of running, without defaults
#   including a nested non-presence container with only default values
# - Digest is stable between calls
# - Digest survives backend restart (-s running), also with explicit default and presence container
# - A leaf explicitly set to its default value is part of the digest (RFC 6243 explicit)
# - A presence container with only default values is part of the digest
# - Digest depends on content only: reverting the config gives the original digest

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    container c {
        leaf x {
            type uint32;
        }
        leaf d {
            description "Default value, not part of digest";
            type uint32;
            default 17;
        }
        container inner {
            description "Non-presence container with only default values";
            leaf dd {
                type uint32;
                default 5;
            }
        }
        container p {
            presence "Presence container";
            leaf dp {
                type uint32;
                default 7;
            }
        }
    }
}
EOF

NS='xmlns="urn:example:clixon"'

# Get digest of running via commit-info rpc
function get_digest()
{
    local ret
    ret=$($clixon_netconf -qf $cfg <<EOF
${DEFAULTHELLO}$(chunked_framing "<rpc $DEFAULTNS><commit-info $LIBNS/></rpc>")
EOF
)
    echo "$ret" | grep -o "<digest $LIBNS>[0-9a-f]*</digest>" | sed -e 's/<[^>]*>//g'
}

# Compute digest of string locally, SHA-1 or SHA-256 depending on length of reference digest
# Args: 1: string, 2: reference digest
function local_digest()
{
    if [ ${#2} -eq 64 ]; then
        printf '%s' "$1" | sha256sum | cut -d' ' -f1
    else
        printf '%s' "$1" | sha1sum | cut -d' ' -f1
    fi
}

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

new "commit-info: empty running"
d0=$(get_digest)
if [ -z "$d0" ]; then
    err "digest" "$d0"
fi

new "commit-info: empty running is digest of empty string"
expect=$(local_digest "" "$d0")
if [ "$d0" != "$expect" ]; then
    err "$expect" "$d0"
fi

new "edit-config candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c $NS><x>42</x></c></config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit-info: unchanged before commit"
d=$(get_digest)
if [ "$d" != "$d0" ]; then
    err "$d0" "$d"
fi

new "commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit-info: changed after commit"
d1=$(get_digest)
if [ -z "$d1" -o "$d1" = "$d0" ]; then
    err "new digest" "$d1"
fi

new "commit-info: digest of compact XML without default values"
expect=$(local_digest "<c $NS><x>42</x></c>" "$d1")
if [ "$d1" != "$expect" ]; then
    err "$expect" "$d1"
fi

new "commit-info: stable"
d=$(get_digest)
if [ "$d" != "$d1" ]; then
    err "$d1" "$d"
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
    new "start backend -s running -f $cfg"
    start_backend -s running -f $cfg
fi

new "wait backend"
wait_backend

new "commit-info: survives restart"
d=$(get_digest)
if [ "$d" != "$d1" ]; then
    err "$d1" "$d"
fi

new "edit-config: set default leaf d explicitly to its default value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c $NS><d>17</d></c></config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit-info: explicitly set default value is part of digest"
d=$(get_digest)
expect=$(local_digest "<c $NS><x>42</x><d>17</d></c>" "$d")
if [ "$d" != "$expect" ]; then
    err "$expect" "$d"
fi

new "edit-config: create presence container"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c $NS><p/></c></config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit-info: presence container with only defaults is part of digest"
# Note: printed as <p></p> since its default child is filtered after the empty-tag decision
d=$(get_digest)
expect=$(local_digest "<c $NS><x>42</x><d>17</d><p></p></c>" "$d")
if [ "$d" != "$expect" ]; then
    err "$expect" "$d"
fi
d2=$d

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
    new "start backend -s running -f $cfg"
    start_backend -s running -f $cfg
fi

new "wait backend"
wait_backend

new "commit-info: explicit default and presence container survive restart"
d=$(get_digest)
if [ "$d" != "$d2" ]; then
    err "$d2" "$d"
fi

new "delete config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c $NS xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/></config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit-info: reverted config gives original digest"
d=$(get_digest)
if [ "$d" != "$d0" ]; then
    err "$d0" "$d"
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
