#!/usr/bin/env bash
#
# Build the clixon JSON libFuzzer target with AddressSanitizer +
# UndefinedBehaviorSanitizer.
#
# Requirements:
#   - clang with libFuzzer (clang >= 6)
#   - clixon built and installed (libclixon, libcligen in /usr/local/lib)
#   - clixon_config.h generated (run ./configure in the repo root)
#
# Usage (from this directory):
#   ./build.sh          # build fuzz_json
#
# Run:
#   ./fuzz_json corpus_json -dict=../json.dict
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

echo "== Building fuzz_json =="
# shellcheck disable=SC2086
${CC} ${CFLAGS} ${LDFLAGS} \
  "${FUZZDIR}/fuzz_json.c" \
  -o "${FUZZDIR}/fuzz_json"

echo "== Seeding corpus =="
mkdir -p "${FUZZDIR}/corpus_json" "${FUZZDIR}/artifacts_json"

printf '{"ietf-interfaces:interfaces":{"interface":[{"name":"eth0","type":"iana-if-type:ethernetCsmacd","enabled":true}]}}' \
  > "${FUZZDIR}/corpus_json/interfaces.json"
printf '{"ietf-interfaces:interfaces-state":{"interface":[{"name":"lo","statistics":{"in-octets":0}}]}}' \
  > "${FUZZDIR}/corpus_json/state.json"
printf '{}' \
  > "${FUZZDIR}/corpus_json/empty.json"
printf '{"a":{"b":{"c":"value"}}}' \
  > "${FUZZDIR}/corpus_json/nested.json"
printf '{"list":[{"key":"a","val":1},{"key":"b","val":2}]}' \
  > "${FUZZDIR}/corpus_json/list.json"
printf 'null' \
  > "${FUZZDIR}/corpus_json/null.json"
printf '"string"' \
  > "${FUZZDIR}/corpus_json/string.json"
printf '42' \
  > "${FUZZDIR}/corpus_json/number.json"

echo "Done."
echo "Run: LD_LIBRARY_PATH=/usr/local/lib ./fuzz_json corpus_json -dict=../json.dict"
