#!/bin/sh
# ***** BEGIN LICENSE BLOCK *****
# 
# Copyright (C) 2017-2019 Olof Hagsand
# Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)
#
# This file is part of CLIXON
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Alternatively, the contents of this file may be used under the terms of
# the GNU General Public License Version 3 or later (the "GPL"),
# in which case the provisions of the GPL are applicable instead
# of those above. If you wish to allow use of your version of this file only
# under the terms of the GPL, and not to allow others to
# use your version of this file under the terms of Apache License version 2, 
# indicate your decision by deleting the provisions above and replace them with
# the notice and other provisions required by the GPL. If you do not delete
# the provisions above, a recipient may use your version of this file under
# the terms of any one of the Apache License version 2 or the GPL.
#
# ***** END LICENSE BLOCK *****

# Clixon startscript for fcgi/nginx and http
# This script is copied into the container on build time and runs
# _inside_ the container at start in runtime. It gets environment variables
# from the start.sh script.
# It starts a backend, a restconf daemon,  a nginx daemon,  exposes ports and the sleeps
# for restconf.
# See also Dockerfile of the example
# Log msg, see with docker logs

set -ux # e but clixon_backend may fail if test is run in parallell

>&2 echo "$0"

DBG=${DBG:-0}

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
SKIPLIST="test_api.sh test_client.sh test_c++.sh test_install.sh test_privileges.sh"
#IETFRFC=
EOF

# Workaround for this error output:
# sudo: setrlimit(RLIMIT_CORE): Operation not permitted
echo "Set disable_coredump false" > /etc/sudo.conf

chmod 775 /usr/local/bin/test/site.sh 

if [ ! -d /run/nginx ]; then
    mkdir /run/nginx
fi

# Start nginx
#/usr/sbin/nginx -g 'daemon off;' -c /etc/nginx/nginx.conf
/usr/sbin/nginx -c /etc/nginx/nginx.conf
>&2 echo "nginx started"

# Start clixon_restconf (tests will kill this)
/usr/local/sbin/clixon_restconf -l f/var/log/restconf.log -D $DBG &
>&2 echo "clixon_restconf started"

# Set grp write XXX do this when creating
chmod g+w /www-data/fastcgi_restconf.sock

# Start clixon backend (tests will kill this)
# Note if tests start too quickly, a backend may only be running and get error when start here,
# therefore test starts need to be delayed slightly
/usr/local/sbin/clixon_backend -D $DBG -s running -l e # logs on docker logs
>&2 echo "clixon_backend started"

# Alt: let backend be in foreground, but test scripts may
# want to restart backend
/bin/sleep 100000000
