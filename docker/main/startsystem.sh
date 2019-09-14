#!/bin/sh
# This script is copied into the container on build time and runs
# _inside_ the container at start in runtime. It gets environment variables
# from the start.sh script.
# It starts a backend, a restconf daemon and a nginx daemon and exposes ports
# for restconf.
# See also Dockerfile of the example
# Log msg, see with docker logs

>&2 echo "$0"

DBG=${DBG:-0}

WWWUSER=${WWWUSER:-www-data}

# Initiate clixon configuration (env variable)
echo "$CONFIG" > /usr/local/etc/clixon.xml

# Initiate running db (env variable)
echo "$STORE" > /usr/local/var/example/running_db

>&2 echo "Write nginx config files"
# nginx site config file
cat <<EOF > /etc/nginx/conf.d/default.conf
#
server {
        listen 80 default_server;
        listen localhost:80 default_server;
        listen [::]:80 default_server;
	server_name localhost;
	server_name _;
	location / {
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
        }
	location /restconf {
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
        }
	location /streams {
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
 	    proxy_http_version 1.1;
	    proxy_set_header Connection "";
        }
}
EOF

# This is a clixon site test file. 
# Add to skiplist:
# - all 3rd party model testing (you need to download the repos)
# - test_install.sh since you dont have the make environment
# - test_order.sh XXX this is a bug need debugging
cat <<EOF > /usr/local/bin/test/site.sh
# Add your local site specific env variables (or tests) here.
SKIPLIST="test_yangmodels.sh test_openconfig.sh test_install.sh test_privileges.sh"
#IETFRFC=
EOF

chmod 775 /usr/local/bin/test/site.sh 

if [ ! -d /run/nginx ]; then
    mkdir /run/nginx
fi

# Start nginx
#/usr/sbin/nginx -g 'daemon off;' -c /etc/nginx/nginx.conf
/usr/sbin/nginx -c /etc/nginx/nginx.conf
>&2 echo "nginx started"

# Start clixon_restconf
su -c "/www-data/clixon_restconf -l f/www-data/restconf.log -D $DBG" -s /bin/sh $WWWUSER &
>&2 echo "clixon_restconf started"

# Set grp write XXX do this when creating
chmod g+w /www-data/fastcgi_restconf.sock

# Start clixon backend
>&2 echo "start clixon_backend:"
/usr/local/sbin/clixon_backend -FD $DBG -s running -l e # logs on docker logs

# Alt: let backend be in foreground, but test scripts may
# want to restart backend
/bin/sleep 100000000
