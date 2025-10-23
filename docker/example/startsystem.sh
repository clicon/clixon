#!/usr/bin/env sh
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

# Clixon startscript for native restconf and https
# This script is copied into the container on build time and runs
# _inside_ the container at start in runtime. It gets environment variables
# from the start.sh script.
# It starts a backend, a restconf daemon and exposes ports for restconf, and the sleeps
# See also Dockerfile of the example
# Log msg, see with docker logs

set -ux # e but clixon_backend may fail if test is run in parallell

>&2 echo "$0"

# If set, enable debugging (of backend and restconf daemons)
: ${DBG:=0}

# Start sshd
touch /run/openrc/softlevel
/etc/init.d/sshd start

# But dont use -s exposing local ports since there is problem with self-signed certs?
#/usr/local/bin/clixon_restconf -l f/var/log/restconf.log -D $DBG &
#>&2 echo "clixon_restconf started"

# Start clixon backend
/usr/local/sbin/clixon_backend -D $DBG -s startup -l e -f /usr/local/etc/clixon/example.xml
>&2 echo "clixon_backend started"

# Alt: let backend be in foreground, but test scripts may
# want to restart backend
/bin/sleep 100000000
