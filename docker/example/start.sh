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
set -eux
# Usage: ./startup.sh
# Debug: DBG=1 ./startup.sh
# See also cleanup.sh

# Name of container
: ${NAME:=clixon-example}

# If set to filename also install your users pubkey
: ${SSHKEY:=}

>&2 echo "Running script: $0"

sudo docker kill $NAME || true 2> /dev/null # ignore errors

# Start clixon-example backend
sudo docker run --name ${NAME} --rm -td clixon/clixon-example #|| err "Error starting clixon-example"

# Copy rsa pubkey 
if [ -n "$SSHKEY" ]; then
    # install user pub key 
    sudo docker exec -it $NAME mkdir -m 700 /root/.ssh
    sudo docker cp $SSHKEY $NAME:/root/.ssh/authorized_keys
    sudo docker exec -it $NAME chown root /root/.ssh/authorized_keys
    sudo docker exec -it $NAME chgrp root /root/.ssh/authorized_keys
fi

>&2 echo "$NAME started"
