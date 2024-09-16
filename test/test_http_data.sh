#!/usr/bin/env bash
# Simple http data test
# Create an html and css file
# Get them via http and https
# Send options and head request
# Errors: not found, post, 
# See RFC 7230

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
rm -rf $dir/www
mkdir $dir/www
mkdir $dir/www/data

# Does not work with fcgi
if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    echo "...skipped: Must run with --with-restconf=native"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Data file
cat <<EOF > $dir/www/data/index.html
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

cat <<EOF > $dir/www/data/example.css
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

# Outside wwwdir, should not be able to access this
cat <<EOF > $dir/outside.html
<!DOCTYPE html>
<html>
<head>
<title>Dont access this</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Dont access this!</h1>
<p>If you see this page, you accessed a file outside the root domain</p>
</body>
</html>
EOF

# Create a soft link from inside to outside
ln -s $dir/outside.html $dir/www/data/inside.html

# Disable read access
cat <<EOF > $dir/www/data/noread.html
<!DOCTYPE html>
<html>
<head>
<title>No read</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>No read!</h1>
<p>If you see this page, you have read access to root</p>
</body>
</html>
EOF

# remove read access
chmod 660 $dir/www/data/noread.html

# bitmap
cp ./clixon.png  $dir/www/data/

# Http test routine with arguments:
# 1. proto:http/https
function testrun()
{
    proto=$1  # http/https
    enable=$2 # true/false
    
    RESTCONFIG=$(restconf_config none false $proto $enable)
    if [ $? -ne 0 ]; then
        err1 "Error when generating certs"
    fi

    if true; then
        # Proper test setup
        datapath=/data
        wdir=$dir/www
    else
        # Experiments with local host
        datapath=/
        wdir=/var/www/html
    fi
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
  <CLICON_HTTP_DATA_PATH>$datapath</CLICON_HTTP_DATA_PATH>
  <CLICON_HTTP_DATA_ROOT>$wdir</CLICON_HTTP_DATA_ROOT>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_RESTCONF_HTTP2_PLAIN>true</CLICON_RESTCONF_HTTP2_PLAIN>
  $RESTCONFIG
</clixon-config>
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
    wait_restconf $proto

#    echo "curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data/index.html"

    if ! $enable; then
        # XXX or bad request?
        new "WWW get html, not enabled, expect not found"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data/index.html)" 0 "HTTP/$HVER 404"
    else
        new "WWW get root expect 404 without body"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/)" 0 "HTTP/$HVER 404" --not-- "Content-Type"
        
        new "WWW get index.html"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data/index.html)" 0 "HTTP/$HVER 200" "Content-Type: text/html" "<title>Welcome to Clixon!</title>"

        new "List of medias"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html,*/*' $proto://localhost/data/index.html)" 0 "HTTP/$HVER 200" "Content-Type: text/html" "<title>Welcome to Clixon!</title>"

        new "List of medias2"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: wrong/media,*/*' $proto://localhost/data/index.html)" 0 "HT
TP/$HVER 200" "Content-Type: text/html" "<title>Welcome to Clixon!</title>"

        new "Server does not support list of medias Expect 406"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: wrong/media' $proto://localhost/data/index.html)" 0 "HTTP/$HVER 406" "content-type: text/html" "<error-message>Unacceptable output encoding</error-message>"

        new "WWW get dir -> expect index.html"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data)" 0 "HTTP/$HVER 200" "Content-Type: text/html" "<title>Welcome to Clixon!</title>"

        # remove index
        mv $dir/www/data/index.html $dir/www/data/tmp.index.html

        new "WWW get dir -> no indirection expect 404"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data)" 0 "HTTP/$HVER 404" "Content-Type: text/html" "<title>404 Not Found</title>"

        # move index back
        mv $dir/www/data/tmp.index.html $dir/www/data/index.html 
        
        new "WWW get css"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/css' $proto://localhost/data/example.css)" 0 "HTTP/$HVER 200" "Content-Type: text/css" "display: inline;" --not-- "Content-Type: text/html"

        new "WWW get css accept *"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html,*/*' $proto://localhost/data/example.css)" 0 "HTTP/$HVER 200" "Content-Type: text/css" "display: inline;" --not-- "Content-Type: text/html"

        new "WWW get css, operation-not-supported"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data/example.css)" 0 "HTTP/$HVER 406" "operation-not-supported"

        new "WWW head"
        expectpart "$(curl $CURLOPTS --head -H 'Accept: text/html' $proto://localhost/data/index.html)" 0 "HTTP/$HVER 200" "Content-Type: text/html" --not-- "<title>Welcome to Clixon!</title>"

        new "WWW options"
        expectpart "$(curl $CURLOPTS -X OPTIONS $proto://localhost/data/index.html)" 0 "HTTP/$HVER 200" "allow: OPTIONS,HEAD,GET" 

        # Remove -i option for binary transfer
        CURLOPTS2=$(echo $CURLOPTS | sed 's/i//')
        new "WWW binary bitmap"
        curl $CURLOPTS2 -X GET $proto://localhost/data/clixon.png -o $dir/foo.png
        cmp $dir/foo.png $dir/www/data/clixon.png
        if [ $? -ne 0 ]; then
            err1 "$dir/foo.png $dir/www/data/example.css should be equal" "Not equal"
        fi

        # negative errors
        new "WWW get http not found"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data/notfound.html)" 0 "HTTP/$HVER 404" "Content-Type: text/html" "<title>404 Not Found</title>"

        new "WWW get http soft link"
        expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data/inside.html)" 0 "HTTP/$HVER 403" "Content-Type: text/html" "<title>403 Forbidden</title>" --not-- "<title>Dont access this</title>"
        
        # Two cases where the privileges test is not run:
        # 1) Docker in alpine for some reason
        # 2) Restconf run explicitly as root (eg coverage)
        if [ ! -f /.dockerenv ] ; then  
            if [[ "$clixon_restconf" != *"-r"* ]]; then
                new "WWW get http not read access"
                expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $proto://localhost/data/noread.html)" 0 "HTTP/$HVER 403" "Content-Type: text/html" "<title>403 Forbidden</title>"
            fi
        fi

        # Try .. Cannot get .. in path to work in curl (it seems to remove it)
        if [ "$proto" = http -a -n "$netcat" ]; then    
            new "WWW get outside using .. netcat"
            expectpart "$(${netcat} 127.0.0.1 80 <<EOF
GET /data/../../outside.html HTTP/1.1
Host: localhost
Accept: text/html

EOF
)" 0 "HTTP/1.1 403" "Forbidden"
        fi

        new "WWW post not allowed"
        expectpart "$(curl $CURLOPTS -X POST -H 'Accept: text/html' -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' $proto://localhost/data/notfound.html)" 0 "HTTP/$HVER 405" "Content-Type: text/html" "<title>405 Method Not Allowed</title>"

    fi 

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
}

protos=
# Go thru all combinations of IPv4/IPv6, http/https, local/backend config
if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    protos="http"
elif ${HAVE_HTTP1}; then
    protos="http"    # No plain http for http/2 only
fi
if [ "${WITH_RESTCONF}" = "native" ]; then
    # https only relevant for internal (for fcgi: need nginx config)
    protos="$protos https"
fi

for proto in $protos; do
    for enable in true false; do    # false
        new "http-data proto:$proto enabled:$enable"
        testrun $proto $enable
    done
done

rm -rf $dir

new "endtest"
endtest
