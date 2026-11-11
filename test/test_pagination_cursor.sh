#!/usr/bin/env bash
# Test for "cursor" list-pagination query parameter.
# Based on Appendix A.3.3 of draft-ietf-netconf-list-pagination, using the "example-social" module
#
# Note: A.3.3.5: the draft expects error-tag "invalid-value" + error-app-tag "cursor-with-exclude-error",
# but clixon rejects the combination earlier and more generically with the YANG compliance test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fexample=$dir/example-social.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-list-pagination:cursor</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>json</CLICON_XMLDB_FORMAT>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
</clixon-config>
EOF

# Common example-social module (fexample must be set)
. ./example_social.sh

# Members per draft-ietf-netconf-list-pagination-15 Appendix A.2, excluding
# "åsa" (see note above), trimmed to mandatory leafs only. Listed here in the
# draft's own dataset order (bob, eric, alice, lin, joe).
cat <<'EOF' > $dir/startup_db
{"config":
   {
     "example-social:members": {
       "member": [
         {"member-id": "bob",   "email-address": "bob@example.com",   "password": "$0$1543"},
         {"member-id": "eric",  "email-address": "eric@example.com",  "password": "$0$1543"},
         {"member-id": "alice", "email-address": "alice@example.com", "password": "$0$1543"},
         {"member-id": "lin",   "email-address": "lin@users.example.net", "password": "$0$1543"},
         {"member-id": "joe",   "email-address": "joe@example.com",   "password": "$0$1543"}
       ]
     }
   }
}
EOF

# Cursor values are the base64 encoding of the target member's member-id.
CURSOR_ALICE="YWxpY2U="   # base64(alice), still used for the exclusion-error case
CURSOR_BOB="Ym9i"         # base64(bob)
CURSOR_ERIC="ZXJpYw=="    # base64(eric)
CURSOR_JOE="am9l"         # base64(joe)
CURSOR_LIN="bGlu"         # base64(lin)
CURSOR_INVALID="bm9zdWNodXNlcg=="  # base64("nosuchuser"), does not match any member-id

# For the "next"/"previous" metadata annotations.
#   previous = base64(key at index first_shown-1), absent on the first page (Sec 3.4)
#   next     = base64(key at index last_shown+1), absent on the last page (Sec 3.4)

# Build the expected <members> reply for a list of member-ids
# Args: member-id...
function membersreply()
{
    local xmllist=""
    for m in "$@"; do
        case $m in
            bob)   e="bob@example.com" ;;
            eric)  e="eric@example.com" ;;
            alice) e="alice@example.com" ;;
            lin)   e="lin@users.example.net" ;;
            joe)   e="joe@example.com" ;;
        esac
        xmllist="${xmllist}<member><member-id>$m</member-id><email-address>$e</email-address><password>\$0\$1543</password></member>"
    done
    echo "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\">$xmllist</members></data></rpc-reply>"
}

# Same as membersreply(), but also expects the "remaining"/"previous"/"next" metadata
# (Sec 3.1.6, 3.1.7) as attributes on the first returned member, in the exact order clixon
# emits them.
# Args: remaining-value previous-value next-value member-id...
function membersreply_cursor()
{
    local rem="$1"
    local prev="$2"
    local next="$3"
    shift 3
    local xmllist=""
    local attrs=""
    local a
    for a in "remaining=$rem" "previous=$prev" "next=$next"; do
        if [ -n "${a#*=}" ]; then
            attrs="${attrs} lpg:${a%%=*}=\"${a#*=}\""
            if [ "${attrs#* xmlns:lpg}" = "$attrs" ]; then # first attribute: add binding
                attrs="${attrs} xmlns:lpg=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination\""
            fi
        fi
    done
    local first=1
    for m in "$@"; do
        case $m in
            bob)   e="bob@example.com" ;;
            eric)  e="eric@example.com" ;;
            alice) e="alice@example.com" ;;
            lin)   e="lin@users.example.net" ;;
            joe)   e="joe@example.com" ;;
        esac
        if [ $first -eq 1 ]; then
            xmllist="${xmllist}<member${attrs}><member-id>$m</member-id><email-address>$e</email-address><password>\$0\$1543</password></member>"
            first=0
        else
            xmllist="${xmllist}<member><member-id>$m</member-id><email-address>$e</email-address><password>\$0\$1543</password></member>"
        fi
    done
    echo "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\">$xmllist</members></data></rpc-reply>"
}

new "test params: -f $cfg -s startup"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "Baseline: no pagination returns all 5 members, canonicalized by key"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/></get-config></rpc>" "" "$(membersreply alice bob eric joe lin)"

REQ_A3311="<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><limit>2</limit></list-pagination></get-config></rpc>"
REQ_A332="<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><cursor>$CURSOR_ERIC</cursor><limit>2</limit></list-pagination></get-config></rpc>"
REQ_A333="<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><cursor>$CURSOR_LIN</cursor><limit>2</limit></list-pagination></get-config></rpc>"

new "A.3.3.1 Cursor using the default value (limit=2) -> alice, bob"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A3311" "" "$(membersreply_cursor 3 "" "$CURSOR_ERIC" alice bob)"

new "A.3.3.1 previous metadata is absent (first page)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A3311" "" "" --not-- "lpg:previous"

new "A.3.3.1 remaining metadata is 3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A3311" 'lpg:remaining="3"'

new "A.3.3.1 next metadata points to eric"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A3311" "lpg:next=\"$CURSOR_ERIC\""

new "A.3.3.2 Cursor using the 'next' value (cursor=eric, limit=2) -> eric, joe"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A332" "" "$(membersreply_cursor 1 "$CURSOR_BOB" "$CURSOR_LIN" eric joe)"

new "A.3.3.2 previous metadata points to bob"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A332" "lpg:previous=\"$CURSOR_BOB\""

new "A.3.3.2 next metadata points to lin"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A332" "lpg:next=\"$CURSOR_LIN\""

new "A.3.3.2 remaining metadata is 1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A332" 'lpg:remaining="1"'

new "A.3.3.3 Cursor using another 'next' value (cursor=lin, limit=2) -> lin (only one left)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A333" "" "$(membersreply_cursor "" "$CURSOR_JOE" "" lin)"

new "A.3.3.3 previous metadata points to joe"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A333" "lpg:previous=\"$CURSOR_JOE\""

new "A.3.3.3 next and remaining metadata are absent (last page)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$REQ_A333" "" "" --not-- "lpg:next" "lpg:remaining"

new "A.3.3.4 Cursor using an invalid value -> error-app-tag cursor-not-found"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><cursor>$CURSOR_INVALID</cursor></list-pagination></get-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-app-tag>cursor-not-found</error-app-tag><error-severity>error</error-severity>"

# Note: the draft's expects error-app-tag "cursor-with-exclude-error", but clixon rejects it earlier with YANG validation
new "A.3.3.5 Cursor used together with offset -> rejected by the offset leaf's own when-constraint"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><cursor>$CURSOR_ALICE</cursor><offset>1</offset><limit>10</limit></list-pagination></get-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>WHEN condition failed"

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

rm -rf $dir

new "endtest"
endtest
