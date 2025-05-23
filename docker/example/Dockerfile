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

FROM alpine:latest
LABEL maintainer="Olof Hagsand <olof@hagsand.se>"

# For clixon and cligen
RUN apk add --update git make build-base gcc flex bison curl-dev

# nghttp2 dependencies
RUN apk add --update nghttp2

# For netsnmp
RUN apk add --update net-snmp net-snmp-dev

# For groupadd/groupdel
RUN apk add --update shadow

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

# Need to add www user manually
RUN adduser -D -H -G www-data www-data

# Copy Clixon from local dir
RUN mkdir -p /clixon/clixon
WORKDIR /clixon/clixon
COPY clixon .

# Configure, build and install clixon
RUN ./configure --prefix=/usr/local --sysconfdir=/etc --with-cligen=/clixon/build/usr/local --with-restconf=native --enable-nghttp2 --enable-http1 --enable-netsnmp

RUN make
RUN make DESTDIR=/clixon/build install
RUN make DESTDIR=/clixon/build install-include

# Build and install the clixon example
WORKDIR /clixon/clixon/example/main
RUN make
RUN make DESTDIR=/clixon/build install
RUN mkdir -p /clixon/build/etc
RUN install example.xml /clixon/build/etc/clixon.xml

# Copy startscript
WORKDIR /clixon
COPY startsystem.sh startsystem.sh 
RUN install startsystem.sh /clixon/build/usr/local/bin/

#
# Stage 2
# The second step skips the development environment and builds a runtime system
FROM alpine:latest
MAINTAINER Olof Hagsand <olof@hagsand.se>

# For clixon and cligen
RUN apk add --update flex bison openssl

# need to add www user manually
RUN adduser -D -H -G www-data www-data

# nghttp2 dependencies
RUN apk add --update nghttp2

# For SNMP
RUN apk add --update net-snmp net-snmp-tools

# Some custom configuration for SNMP
RUN echo "master  agentx" > /etc/snmp/snmpd.conf
RUN echo "agentaddress  127.0.0.1" >> /etc/snmp/snmpd.conf
RUN echo "rwcommunity   public  localhost" >> /etc/snmp/snmpd.conf
RUN echo "agentxsocket  unix:/var/run/snmp.sock" >> /etc/snmp/snmpd.conf
RUN echo "agentxperms   777 777" >> /etc/snmp/snmpd.conf
RUN echo "trap2sink     localhost public 162" >> /etc/snmp/snmpd.conf
RUN echo "disableAuthorization yes" >> /etc/snmp/snmptrapd.conf

# Expose https port for restconf
EXPOSE 80/tcp
EXPOSE 443/tcp

# Add sshd
RUN apk add --update openrc openssh
RUN rc-update add sshd
RUN rc-status
RUN echo "Subsystem netconf /usr/local/bin/clixon_netconf" >> /etc/ssh/sshd_config

# Create clicon user and group
RUN adduser -D -H clicon

COPY --from=0 /clixon/build/ /

# Overwrite config file since install dirs are wrong
COPY example.xml /usr/local/etc/clixon/example.xml
# Create symlink so you can run clixon without -f arg
RUN ln -s /usr/local/etc/clixon/example.xml /usr/local/etc/clixon.xml 

# Start daemons
CMD /usr/local/bin/startsystem.sh
