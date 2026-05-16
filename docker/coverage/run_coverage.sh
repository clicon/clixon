#!/usr/bin/env bash
#
# ***** BEGIN LICENSE BLOCK *****
#
# Copyright (C) 2026 Olof Hagsand
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
#
# Run script for the Clixon coverage Docker container.
# Executed as CMD inside the container. Sets up the test environment,
# runs all tests, and generates /coverage.info via lcov.

set -ux

# Generate SSH host keys (needed by some tests)
ssh-keygen -A

# Workaround for: sudo: setrlimit(RLIMIT_CORE): Operation not permitted
echo "Set disable_coredump false" > /etc/sudo.conf

# Site configuration: skip tests that require special environment
cat <<EOF > /usr/local/bin/test/site.sh
# Tests that cannot run in this container environment
SKIPLIST="test_api.sh test_client.sh test_c++.sh test_install.sh test_privileges.sh"
EOF
chmod 775 /usr/local/bin/test/site.sh

# Override YANG_INSTALLDIR so tests find the installed YANG models
cat <<EOF >> /usr/local/bin/test/config.sh
YANG_INSTALLDIR=/usr/local/share/clixon
EOF

# Fix known syntax error in IEEE YANG model
sed -i s/=\ olt\'/=\ \'olt\'/g \
    /usr/local/share/yang/standard/ieee/published/802.3/ieee802-ethernet-pon.yang \
    2>/dev/null || true

# Generate self-signed server certificates used by RESTCONF TLS tests
cat > /tmp/ca.cnf <<EOF
[ req ]
default_bits           = 2048
distinguished_name     = req_distinguished_name
attributes             = req_attributes
prompt                 = no

[ req_distinguished_name ]
C                      = SE
L                      = Stockholm
O                      = Clixon
CN                     = localhost
emailAddress           = olof@hagsand.se

[ req_attributes ]
challengePassword      = test
EOF

openssl req -x509 -config /tmp/ca.cnf -nodes -newkey rsa:2048 \
    -keyout /etc/ssl/private/clixon-server-key.pem \
    -out /etc/ssl/certs/clixon-server-crt.pem \
    -days 365 2>/dev/null

# Run the full test suite; continue-on-error so we always generate coverage
cd /usr/local/bin/test
detail=true ./sum.sh || true

# Generate lcov coverage report from instrumented build tree
cd /build/clixon
lcov --capture \
    --directory . \
    --output-file /coverage.info \
    --ignore-errors empty,unused 2>/dev/null || \
lcov --capture \
    --directory . \
    --output-file /coverage.info

# Strip system headers from the report
lcov --remove /coverage.info '/usr/*' \
    --output-file /coverage.info \
    --ignore-errors unused 2>/dev/null || \
lcov --remove /coverage.info '/usr/*' \
    --output-file /coverage.info

# Print a brief summary to the container log
lcov --list /coverage.info | tail -5

echo "Coverage report written to /coverage.info"
