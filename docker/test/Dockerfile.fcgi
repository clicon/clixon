#
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
#
# Clixon dockerfile with fcgi restconf

FROM alpine
LABEL maintainer="Olof Hagsand <olof@hagsand.se>"

# For clixon and cligen
RUN apk add --update git make build-base gcc flex bison curl-dev

# For fcgi
RUN apk add --update fcgi-dev

# For netsnmp
RUN apk add --update net-snmp net-snmp-dev

# For groupadd/groupdel
RUN apk add --update shadow

# Test-specific (for test scripts)
RUN apk add --update openssh

# Checkout standard YANG models for tests (note >1G for full repo)
RUN mkdir -p /usr/local/share/yang
WORKDIR /usr/local/share/yang
COPY yang .

# Checkout OPENCONFIG YANG models for tests
RUN mkdir -p /usr/local/share/openconfig
WORKDIR /usr/local/share/openconfig
COPY openconfig .

# Create a directory to hold source-code, dependencies etc
RUN mkdir -p /clixon/build
WORKDIR /clixon

# Clone cligen
RUN git clone https://github.com/clicon/cligen.git

# Build cligen
WORKDIR /clixon/cligen
RUN ./configure --prefix=/usr/local --sysconfdir=/etc
RUN make
RUN make DESTDIR=/clixon/build install

# Copy Clixon from local dir
RUN mkdir -p /clixon/clixon
WORKDIR /clixon/clixon
COPY clixon .

# Need to add www user manually, but group www-data already exists on Alpine
RUN adduser -D -H -G www-data www-data
# nginx adds group www-data
RUN apk add --update nginx

# Configure, build and install clixon
RUN ./configure --prefix=/usr/local --sysconfdir=/etc --with-cligen=/clixon/build/usr/local --with-yang-standard-dir=/usr/local/share/yang/standard --enable-netsnmp --with-mib-generated-yang-dir=/usr/local/share/mib-yangs/ --with-restconf=fcgi
RUN make
RUN make DESTDIR=/clixon/build install

# Configure, build and install clixon utilities (for tests)
WORKDIR /clixon
RUN git clone https://github.com/clicon/clixon-util.git
WORKDIR /clixon/clixon-util
RUN ./configure --prefix=/usr/local --with-cligen=/clixon/build/usr/local --with-clixon=/clixon/build/usr/local
RUN make
RUN make DESTDIR=/clixon/build install

# Build and install the clixon example
WORKDIR /clixon/clixon/example/main
RUN make
RUN make DESTDIR=/clixon/build install
RUN mkdir -p /clixon/build/etc
RUN install example.xml /clixon/build/etc/clixon.xml

# Copy tests
WORKDIR /clixon/clixon/test
RUN install -d /clixon/build/usr/local/bin/test
RUN install *.sh /clixon/build/usr/local/bin/test
RUN install *.exp /clixon/build/usr/local/bin/test
RUN install clixon.png /clixon/build/usr/local/bin/test
RUN install *.supp /clixon/build/usr/local/bin/test

RUN install -d /clixon/build/mibs
RUN install mibs/* /clixon/build/mibs

# Copy startscript
WORKDIR /clixon
COPY startsystem_fcgi.sh startsystem.sh 
RUN install startsystem.sh /clixon/build/usr/local/bin/

# Add our generated YANG files
RUN git clone https://github.com/clicon/mib-yangs.git /usr/local/share/mib-yangs

#
# Stage 2
# The second step skips the development environment and builds a runtime system
FROM alpine
LABEL maintainer="Olof Hagsand <olof@hagsand.se>"

# For clixon and cligen
RUN apk add --update flex bison fcgi-dev

# For SNMP
RUN apk add --update net-snmp net-snmp-tools

# Some custom configuration for SNMP
RUN echo "master  agentx" > /etc/snmp/snmpd.conf
RUN echo "agentaddress  127.0.0.1" >> /etc/snmp/snmpd.conf
RUN echo "rwcommunity   public  localhost" >> /etc/snmp/snmpd.conf
RUN echo "agentXSocket  unix:/var/run/snmp.sock" >> /etc/snmp/snmpd.conf
RUN echo "agentxperms   777 777" >> /etc/snmp/snmpd.conf
RUN echo "trap2sink     localhost public 162" >> /etc/snmp/snmpd.conf
RUN echo "disableAuthorization yes" >> /etc/snmp/snmptrapd.conf

# Need to add www user manually, but group www-data already exists on Alpine
RUN adduser -D -H -G www-data www-data
# nginx adds group www-data
RUN apk add --update nginx

# Test-specific (for test scripts)
RUN apk add --update sudo curl procps grep make bash expect openssh coreutils

# Dont need to expose restconf ports for internal tests
#EXPOSE 80/tcp

# Create clicon user and group
RUN adduser -D -H clicon
RUN adduser nginx clicon
RUN adduser www-data clicon

COPY --from=0 /clixon/build/ /
COPY --from=0 /usr/local/share/yang/ /usr/local/share/yang/
COPY --from=0 /usr/local/share/openconfig/* /usr/local/share/openconfig/
COPY --from=0 /usr/local/share/mib-yangs/* /usr/local/share/mib-yangs/
COPY --from=0 /clixon/build/mibs/* /usr/share/snmp/mibs/

# Manually created
RUN mkdir /www-data
RUN chown www-data /www-data
RUN chgrp www-data /www-data

# Log to stderr.
CMD /usr/local/bin/startsystem.sh
