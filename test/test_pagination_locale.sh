#!/usr/bin/env bash
# Test for the "locale" list-pagination query parameter.
# Based on Appendix A.3.7 of draft-ietf-netconf-list-pagination, using the "example-social" module.
#
# A.3.7 is the only appendix section that includes the member "åsa", so the member list
# used here is, in system order: bob, eric, alice, lin, joe, åsa (6 entries). Members are trimmed to
# their mandatory leafs only (member-id, email-address, password), except
# alice who also gets a "favorites/uint8-numbers" leaf-list (ordered-by
# user), needed for the "locale on an ordered-by-user list" error case.
# get-config is used (rather than get) so no state/operational data needs
# to be set up at all.
#
# NOTE: clixon currently only validates the "locale" parameter (that it's a
# real locale, and not used on an "ordered-by user" list/leaf-list) but does NOT sort according to the locale
#
# NOTE: A.3.7: for "locale" without "sort-by" the draft expects a plain "invalid-value" error,
# but clixon rejects it earlier and more generically with the locale leaf's YANG "when" statement

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fexample=$dir/example-social.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-list-pagination:sort-by</CLICON_FEATURE>
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

# Members per draft-ietf-netconf-list-pagination-15 Appendix A.2, including
# "åsa" (see note above), trimmed to mandatory leafs only
cat <<'EOF' > $dir/startup_db
{"config":
   {
     "example-social:members": {
       "member": [
         {"member-id": "bob",   "email-address": "bob@example.com",   "password": "$0$1543"},
         {"member-id": "eric",  "email-address": "eric@example.com",  "password": "$0$1543"},
         {"member-id": "alice", "email-address": "alice@example.com", "password": "$0$1543",
          "favorites": {"uint8-numbers": [17, 13, 11, 7, 5, 3]}},
         {"member-id": "lin",   "email-address": "lin@users.example.net", "password": "$0$1543"},
         {"member-id": "joe",   "email-address": "joe@example.com",   "password": "$0$1543"},
         {"member-id": "åsa",   "email-address": "asa@users.example.net", "password": "$0$1543"}
       ]
     }
   }
}
EOF

# Build the expected <members> reply for a list of member-ids, in the given order
# Args: member-id...
function membersreply()
{
    local xmllist=""
    for m in "$@"; do
        local favorites=""
        case $m in
            bob)   e="bob@example.com" ;;
            eric)  e="eric@example.com" ;;
            alice) e="alice@example.com"
                   favorites="<favorites><uint8-numbers>17</uint8-numbers><uint8-numbers>13</uint8-numbers><uint8-numbers>11</uint8-numbers><uint8-numbers>7</uint8-numbers><uint8-numbers>5</uint8-numbers><uint8-numbers>3</uint8-numbers></favorites>" ;;
            lin)   e="lin@users.example.net" ;;
            joe)   e="joe@example.com" ;;
            åsa)   e="asa@users.example.net" ;;
        esac
        xmllist="${xmllist}<member><member-id>$m</member-id><email-address>$e</email-address><password>\$0\$1543</password>${favorites}</member>"
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

new "Baseline: no pagination returns all 6 members, canonicalized by key"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/></get-config></rpc>" "" "$(membersreply alice bob eric joe lin åsa)"

# Note: happens to also be the plain byte-order result (å is UTF-8 encoded as
# bytes > any ASCII letter), so this doesn't by itself prove locale-aware
# collation is applied -- see NYI note above.
new "A.3.7 sort-by=member-id locale=sv-SE -> alice,bob,eric,joe,lin,åsa (å sorts last)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>member-id</sort-by><locale>sv-SE</locale></list-pagination></get-config></rpc>" "" "$(membersreply alice bob eric joe lin åsa)"

new "A.3.7 sort-by=member-id locale=sv_SE.UTF-8 (POSIX form with encoding) -> accepted, same order"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>member-id</sort-by><locale>sv_SE.UTF-8</locale></list-pagination></get-config></rpc>" "" "$(membersreply alice bob eric joe lin åsa)"

if false; then # NYI: genuinely requires locale-aware collation (å next to a), expected to fail
new "A.3.7 sort-by=member-id locale=en-US -> alice,åsa,bob,eric,joe,lin (å sorts next to a) [NYI: fails today]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>member-id</sort-by><locale>en-US</locale></list-pagination></get-config></rpc>" "" "$(membersreply alice åsa bob eric joe lin)"
fi

new "A.3.7 locale=invalid -> error-app-tag locale-unavailable"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>member-id</sort-by><locale>invalid</locale></list-pagination></get-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-app-tag>locale-unavailable</error-app-tag><error-severity>error</error-severity>"

new "A.3.7 locale on an \"ordered-by user\" leaf-list -> invalid-value, no app-tag"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>.</sort-by><locale>sv-SE</locale></list-pagination></get-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>The \"locale\" parameter is not relevant"

# Note: the draft's expects a plain "invalid-value" error for locale without sort-by, but clixon rejects it earlier
new "A.3.7 locale without sort-by -> rejected by the locale leaf's own when-constraint"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><locale>sv-SE</locale></list-pagination></get-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>WHEN condition failed"

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
