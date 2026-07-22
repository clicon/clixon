#!/usr/bin/env bash
#
# Build the clixon NETCONF libFuzzer target with AddressSanitizer +
# UndefinedBehaviorSanitizer.
#
# Requirements:
#   - clang with libFuzzer (clang >= 6)
#   - clixon built and installed (libclixon, libcligen in /usr/local/lib)
#   - clixon_config.h generated (run ./configure in the repo root)
#
# Usage (from this directory):
#   ./build.sh          # build fuzz_netconf
#
# Run:
#   ./fuzz_netconf corpus_netconf -dict=../xml.dict
#
set -euo pipefail

CC=${CC:-clang}
FUZZDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "${FUZZDIR}/../../.." && pwd)

SAN="-fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer"
CFLAGS="-g -O1 ${SAN} \
  -I${ROOT}/include \
  -I${ROOT} \
  -I${ROOT}/lib/clixon \
  -I${ROOT}/lib/src \
  -DHAVE_CONFIG_H"

LDFLAGS="-fsanitize=fuzzer -L/usr/local/lib -lclixon -lcligen"

# libFuzzer needs the C++ runtime; find libstdc++ dir if needed
STDCPPDIR=$(dirname "$(gcc -print-file-name=libstdc++.so 2>/dev/null)" 2>/dev/null || true)
if [ -n "${STDCPPDIR}" ] && [ -d "${STDCPPDIR}" ]; then
  LDFLAGS="${LDFLAGS} -L${STDCPPDIR}"
fi

echo "== Building fuzz_netconf =="
# shellcheck disable=SC2086
${CC} ${CFLAGS} ${LDFLAGS} \
  "${FUZZDIR}/fuzz_netconf.c" \
  -o "${FUZZDIR}/fuzz_netconf"

echo "== Seeding corpus =="
mkdir -p "${FUZZDIR}/corpus_netconf" "${FUZZDIR}/artifacts_netconf"

# EOM-framed seeds (first byte 0x00 = NETCONF_SSH_EOM)
printf '\x00<rpc message-id="1" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><get/></rpc>]]>]]>' \
  > "${FUZZDIR}/corpus_netconf/get.eom"
printf '\x00<rpc message-id="2" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><get-config><source><running/></source></get-config></rpc>]]>]]>' \
  > "${FUZZDIR}/corpus_netconf/get-config.eom"
printf '\x00<rpc message-id="3" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><commit/></rpc>]]>]]>' \
  > "${FUZZDIR}/corpus_netconf/commit.eom"
printf '\x00<rpc message-id="4" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><default-operation>merge</default-operation><config/></edit-config></rpc>]]>]]>' \
  > "${FUZZDIR}/corpus_netconf/edit-config.eom"
printf '\x00<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability></capabilities></hello>]]>]]>' \
  > "${FUZZDIR}/corpus_netconf/hello.eom"

# Chunked-framed seeds (first byte 0x01 = NETCONF_SSH_CHUNKED)
printf '\x01\n#41\n<rpc message-id="5" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><get/></rpc>\n##\n' \
  > "${FUZZDIR}/corpus_netconf/get.chunked"

echo "Done."
echo "Run: LD_LIBRARY_PATH=/usr/local/lib ./fuzz_netconf corpus_netconf -dict=../xml.dict"
