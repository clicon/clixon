#
# ***** BEGIN LICENSE BLOCK *****
# 
# Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren
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

# This application could use the base image, but it does not at this point.
FROM debian
MAINTAINER Olof Hagsand <olof@hagsand.se>

# Clixon dependenies (not needed if build from base)
RUN apt-get update && apt-get install -y \
  git make gcc flex bison \
  libfcgi-dev \
  libcurl4-openssl-dev

# Application-specific
RUN apt-get update && apt-get install -y nginx

# Test-specific (for test scripts)
RUN apt-get update && apt-get install -y sudo curl procps time 

# The example uses "clicon" group
RUN groupadd clicon
RUN usermod -a -G clicon www-data

# Create a directory to hold source-code, dependencies etc
RUN mkdir /clixon
WORKDIR /clixon

# Clone and build cligen (not necessary if use base image)
RUN git clone https://github.com/olofhagsand/cligen.git
WORKDIR /clixon/cligen
RUN ./configure
RUN make
RUN make install

# Copy Clixon from local dir
RUN mkdir /clixon/clixon
WORKDIR /clixon/clixon
COPY clixon .

RUN ./configure
RUN make
RUN make install
RUN make install-include

WORKDIR /clixon/clixon/example
RUN make
RUN make install
RUN install example.xml /usr/local/etc/clixon.xml

RUN ldconfig

# Copy startscript
WORKDIR /clixon
COPY startsystem.sh startsystem.sh 
RUN install startsystem.sh /usr/local/bin/

# Expose nginx port for restconf
EXPOSE 80

# Log to stderr.
CMD /usr/local/bin/startsystem.sh





