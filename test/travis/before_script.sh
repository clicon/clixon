#!/usr/bin/env bash
# Travis pre-config script.


# Clone and install CLIgen (needed for clixon configure and make)
# Note travis builds and installs, then starts a clixon container where all tests are run from.
git clone https://github.com/clicon/cligen.git
(cd cligen && ./configure && make && sudo make install)

# This is for nginx/restconf
wwwuser=www-data

# Nginx conf file
cat<<EOF > /etc/nginx/nginx.conf
#
user $wwwuser;
error_log  /var/log/nginx/error.log;
worker_processes  1;
events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;
  server {
        listen 80 default_server;
        listen localhost:80 default_server;
        listen [::]:80 default_server;
	server_name localhost;
	server_name _;
      #:well-known is in root, otherwise restconf would be ok
	location / {
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
}
EOF

sudo pkill nginx
sudo nginx -c /etc/nginx/nginx.conf

# Start clixon
sudo useradd -M -U clicon;
sudo usermod -a -G clicon $(whoami); # start clixon tests as this users
sudo usermod -a -G clicon $wwwuser;

# This is a clixon site test file. 
# Add to skiplist:
# - all 3rd party model testing (you need to download the repos)
# - test_install.sh since you dont have the make environment
# - test_order.sh XXX this is a bug need debugging
cat <<EOF > test/site.sh
# Add your local site specific env variables (or tests) here.
SKIPLIST="test_api.sh test_c++.sh test_yangmodels.sh test_openconfig.sh test_install.sh test_privileges.sh"
#IETFRFC=
IPv6=true
NGINXCHECK=false
EOF
