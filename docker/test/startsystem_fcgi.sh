#!/usr/bin/env bash
# ***** BEGIN LICENSE BLOCK *****
# 
# Copyright (C) 2017-2019 Olof Hagsand
# Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)
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

# If set, enable debugging (of backend and restconf daemons)
: ${DBG:=0}

# Initiate clixon configuration (env variable)
echo "$CONFIG" > /usr/local/etc/clixon.xml

# Initiate running db (env variable)
echo "$STORE" > /usr/local/var/example/running_db

>&2 echo "Write nginx config files"
# nginx site config file
# Note alpine has switched between /etc/nginx/conf.d/ and /etc/nginx/http.d/
cat <<EOF > /etc/nginx/http.d/default.conf
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
# Note use only http, for https you need to reconfig nginx
cat <<EOF > /usr/local/bin/test/site.sh
# Add your local site specific env variables (or tests) here.
SKIPLIST="test_api.sh test_client.sh test_c++.sh test_install.sh test_privileges.sh"
RCPROTO=http # Because nginx
# Parse yangmodels from https://github.com/YangModels/yang
EOF

# Patch to override YANG_INSTALLDIRS
cat <<EOF >> /usr/local/bin/test/config.sh
YANG_INSTALLDIR=/usr/local/share/clixon
OPENCONFIG=/usr/local/share/openconfig/public
EOF

# Patch yang syntax errors
sed -i s/=\ olt\'/=\ \'olt\'/g /usr/local/share/yang/standard/ieee/published/802.3/ieee802-ethernet-pon.yang

# Generate ssh host keys
ssh-keygen -A

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

# Start snmpd, we need this for the SNMP tests and the app clixon_snmp. Log to stdout, then we can
# use Docker logs to see what's happening.
snmpd -Lo -p /var/run/snmpd.pid -I -ifXTable -I -ifTable -I -system_mib -I -sysORTable -I -snmpNotifyFilterTable -I -snmpNotifyTable -I -snmpNotifyFilterProfileTable

# Alt: let backend be in foreground, but test scripts may
# want to restart backend
/bin/sleep 100000000
