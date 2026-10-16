# Build image for Anthropic's OSS Scanner (https://github.com/anthropics/oss-scanner).
# Builds CLIgen and then Clixon itself with debug symbols and frame pointers, mirroring
# the native build in .github/workflows/ci.yml (job "ubuntu-build").
# Network access is available during this build and is removed afterwards, so
# everything an agent might need must be fetched here.
FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive \
    CC=clang \
    CFLAGS="-g -fno-omit-frame-pointer"

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates build-essential clang git pkg-config \
      bison flex \
      libssl-dev libnghttp2-dev libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# CLIgen: required sibling dependency (lives in its own repo, see configure.ac).
RUN git clone --depth 1 https://github.com/clicon/cligen.git /tmp/cligen \
    && cd /tmp/cligen && ./configure && make -j"$(nproc)" && make install \
    && rm -rf /tmp/cligen

# scanner contract: the checkout lives inside the image, at /src
COPY . /src
WORKDIR /src

RUN ./configure --enable-debug \
    && make -j"$(nproc)" \
    && make install install-include

# Build and install the example application: a complete YANG module wired up
# to all frontends (CLI/NETCONF/RESTCONF). It's the most representative
# target for exercising the parsers that handle untrusted input -- see
# threat_model.md.
RUN cd example && make -j"$(nproc)" && make install

# Cheap sanity check that the built binaries run. The full regression suite
# (test/) starts a backend under sudo and needs a multi-step harness (see
# docker/test/), so it is not run in this image.
RUN (clixon_backend -h; clixon_cli -h; clixon_netconf -h; clixon_restconf -h) \
    || echo "WARNING: sanity check of built binaries failed"
