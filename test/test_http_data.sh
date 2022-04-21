#!/usr/bin/env bash
# Simple web data

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
wdir=$dir/www
rm -rf $wdir
mkdir $wdir

# Does not work with fcgi
if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    echo "...skipped: Must run with --with-restconf=native"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

RESTCONFIG=$(restconf_config none false)


# Clixon config
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_FEATURE>clixon-restconf:http-data</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_HTTP_DATA_PATH>/data</CLICON_HTTP_DATA_PATH>
  <CLICON_HTTP_DATA_ROOT>$wdir</CLICON_HTTP_DATA_ROOT>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_RESTCONF_HTTP2_PLAIN>true</CLICON_RESTCONF_HTTP2_PLAIN>
  $RESTCONFIG
</clixon-config>
EOF

# Host setup:
#  <CLICON_HTTP_DATA_PATH>/</CLICON_HTTP_DATA_PATH>
#  <CLICON_HTTP_DATA_ROOT>/var/www/html</CLICON_HTTP_DATA_ROOT>

# Data file
cat <<EOF > $wdir/index.html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to Clixon!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to Clixon!</h1>
<p>If you see this page, the clixon web server is successfully installed and
working. Further configuration is required.</p>
</body>
</html>
EOF

cat <<EOF > $wdir/example.css
img { 
    display: inline; 
    border: 
    0 none;
}
body { 
    font-family: verdana, arial, helvetica, sans-serif; 
    text-align: left; 
    position: relative;
}
table { 
    border-collapse: collapse; 
    text-align: left;
}
div, span {
    text-align:left;
}

h1,h2,h3,h4,h5,h6 {
    color: white;
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

new "WWW get html"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $RCPROTO://localhost/data/index.html)" 0 "HTTP/$HVER 200" "Content-Type: text/html" "<title>Welcome to Clixon!</title>"

new "WWW get css"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $RCPROTO://localhost/data/example.css)" 0 "HTTP/$HVER 200" "Content-Type: text/css" "display: inline;" --not-- "Content-Type: text/html"

new "WWW head"
expectpart "$(curl $CURLOPTS --head -H 'Accept: text/html' $RCPROTO://localhost/data/index.html)" 0 "HTTP/$HVER 200" "Content-Type: text/html" --not-- "<title>Welcome to Clixon!</title>"

new "WWW options"
expectpart "$(curl $CURLOPTS -X OPTIONS $RCPROTO://localhost/data/index.html)" 0 "HTTP/$HVER 200" "allow: OPTIONS,HEAD,GET" 

new "WWW get http not found"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $RCPROTO://localhost/data/notfound.html)" 0 "HTTP/$HVER 404" "Content-Type: text/html" "<title>404 Not Found</title>"

new "WWW post not allowed"
expectpart "$(curl $CURLOPTS -X POST -H 'Accept: text/html' -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' $RCPROTO://localhost/data/notfound.html)" 0 "HTTP/$HVER 405" "Content-Type: text/html" "<title>405 Method Not Allowed</title>"

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
