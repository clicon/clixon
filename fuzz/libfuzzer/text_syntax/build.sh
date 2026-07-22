#!/usr/bin/env bash
#
# Build the clixon text_syntax libFuzzer target with AddressSanitizer +
# UndefinedBehaviorSanitizer.
#
# Requirements:
#   - clang with libFuzzer (clang >= 6)
#   - clixon built and installed (libclixon, libcligen in /usr/local/lib)
#   - clixon_config.h generated (run ./configure in the repo root)
#
# Usage (from this directory):
#   ./build.sh          # build fuzz_text_syntax
#
# Run:
#   ./fuzz_text_syntax corpus_text_syntax -dict=../text_syntax.dict
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

echo "== Building fuzz_text_syntax =="
# shellcheck disable=SC2086
${CC} ${CFLAGS} ${LDFLAGS} \
  "${FUZZDIR}/fuzz_text_syntax.c" \
  -o "${FUZZDIR}/fuzz_text_syntax"

echo "== Seeding corpus =="
mkdir -p "${FUZZDIR}/corpus_text_syntax" "${FUZZDIR}/artifacts_text_syntax"

# Basic leaf value
printf 'interface eth0 {\n  type ethernet;\n  enabled true;\n}\n' \
  > "${FUZZDIR}/corpus_text_syntax/interface.txt"

# Nested containers
printf 'system {\n  hostname router1;\n  ntp {\n    server 192.0.2.1;\n  }\n}\n' \
  > "${FUZZDIR}/corpus_text_syntax/system.txt"

# List with key
printf 'route 10.0.0.0/8 {\n  nexthop 192.168.1.1;\n  metric 100;\n}\n' \
  > "${FUZZDIR}/corpus_text_syntax/route.txt"

# Quoted string value
printf 'description "This is a test description";\n' \
  > "${FUZZDIR}/corpus_text_syntax/quoted.txt"

# Multiple top-level statements
printf 'a 1;\nb 2;\nc 3;\n' \
  > "${FUZZDIR}/corpus_text_syntax/multi.txt"

# Empty container
printf 'container {\n}\n' \
  > "${FUZZDIR}/corpus_text_syntax/empty_container.txt"

# Deeply nested
printf 'a {\n  b {\n    c {\n      d value;\n    }\n  }\n}\n' \
  > "${FUZZDIR}/corpus_text_syntax/deep.txt"

# Namespaced node-id (prefix:name)
printf 'ietf-interfaces:interfaces {\n  interface eth0 {\n    type iana-if-type:ethernetCsmacd;\n  }\n}\n' \
  > "${FUZZDIR}/corpus_text_syntax/namespaced.txt"

echo "Done."
echo "Run: LD_LIBRARY_PATH=/usr/local/lib ./fuzz_text_syntax corpus_text_syntax -dict=../text_syntax.dict"
