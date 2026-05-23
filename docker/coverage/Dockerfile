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
# Single-pass Ubuntu Dockerfile for Clixon code coverage.
# Builds Clixon with --coverage, runs all tests, generates coverage.info.
# Output: /coverage.info inside the container.

FROM ubuntu:latest
LABEL maintainer="Olof Hagsand <olof@hagsand.se>"

# Build and test dependencies
RUN apt-get update && apt-get install -y \
    git make gcc flex bison \
    libssl-dev libnghttp2-dev libcurl4-openssl-dev \
    lcov \
    sudo curl procps expect openssh-server openssh-client openssl \
    && rm -rf /var/lib/apt/lists/*

# Standard YANG models (sparse-checked-out on host, copied here)
RUN mkdir -p /usr/local/share/yang
WORKDIR /usr/local/share/yang
COPY yang .

# Build root
RUN mkdir -p /build
WORKDIR /build

# Clone and install CLIgen with coverage flags so libcligen.so emits .gcda data
# both when CLIgen's own tests run and when Clixon tests exercise the library.
RUN git clone https://github.com/clicon/cligen.git
WORKDIR /build/cligen
RUN ./configure CFLAGS="--coverage" LDFLAGS="--coverage" && make && make install

# Copy Clixon source (inline-cloned on host)
RUN mkdir -p /build/clixon
WORKDIR /build/clixon
COPY clixon .

# Configure with coverage flags. Use native restconf (http1 + http2).
RUN ./configure \
    --with-restconf=native \
    --enable-nghttp2 \
    --enable-http1 \
    --with-yang-standard-dir=/usr/local/share/yang/standard \
    CFLAGS="--coverage" LDFLAGS="--coverage"
RUN make -j$(nproc)
RUN make install
RUN ldconfig

# Build and install example application (required by test suite)
WORKDIR /build/clixon/example/main
RUN make && make install

# Clone and install clixon-util (test helper tools)
WORKDIR /build
RUN git clone https://github.com/clicon/clixon-util.git
WORKDIR /build/clixon-util
RUN ./configure && make && make install

# Install test scripts to expected location
WORKDIR /build/clixon/test
RUN install -d /usr/local/bin/test
RUN install *.sh /usr/local/bin/test
RUN install *.exp /usr/local/bin/test
RUN install clixon.png /usr/local/bin/test
RUN install *.supp /usr/local/bin/test

# Create the clicon system user (backend drops privileges to this user)
#RUN useradd -r -M -s /usr/sbin/nologin clicon

# Allow all users to write gcda files into the build tree.
# This is the key step: the backend process (running as clicon after privilege
# drop) must be able to write coverage data back to the source directory.
# /build/ is 755 (traversable), /build/clixon/ and /build/cligen/ are made
# fully writable so both CLIgen and Clixon .gcda files accumulate correctly.
RUN chmod -R 777 /build/clixon /build/cligen

# Allow passwordless sudo for test scripts (tests use sudo to start the backend)
RUN echo "ALL ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd

COPY run_coverage.sh /run_coverage.sh
RUN chmod +x /run_coverage.sh

CMD ["/run_coverage.sh"]
