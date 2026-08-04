#!/usr/bin/env bash
#
# Build the clixon api-path / instance-id libFuzzer target with
# AddressSanitizer + UndefinedBehaviorSanitizer.
#
# Requirements:
#   - clang with libFuzzer (clang >= 6)
#   - clixon built and installed (libclixon, libcligen in /usr/local/lib)
#   - clixon_config.h generated (run ./configure in the repo root)
#
# Usage (from this directory):
#   ./build.sh          # build fuzz_api_path
#
# Run:
#   ./fuzz_api_path corpus_api_path
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

echo "== Building fuzz_api_path =="
# shellcheck disable=SC2086
${CC} ${CFLAGS} ${LDFLAGS} \
  "${FUZZDIR}/fuzz_api_path.c" \
  -o "${FUZZDIR}/fuzz_api_path"

echo "== Seeding corpus =="
mkdir -p "${FUZZDIR}/corpus_api_path" "${FUZZDIR}/artifacts_api_path"

# api-path corpus
printf '\x01/interfaces/interface[name="eth0"]' \
  > "${FUZZDIR}/corpus_api_path/ap_list.bin"
printf '\x01/system/hostname' \
  > "${FUZZDIR}/corpus_api_path/ap_leaf.bin"
printf '\x01/routing/ribs/rib[name="default"]/routes/route[dest-prefix="0.0.0.0/0"]' \
  > "${FUZZDIR}/corpus_api_path/ap_two_keys.bin"
printf '\x01/' \
  > "${FUZZDIR}/corpus_api_path/ap_root.bin"
printf '\x01/ex:foo/ex:bar' \
  > "${FUZZDIR}/corpus_api_path/ap_ns.bin"

# instance-id corpus (same inputs, exercised by both parsers)
printf '\x00/interfaces/interface[name="eth0"]/enabled' \
  > "${FUZZDIR}/corpus_api_path/ii_leaf.bin"
printf '\x00/routing/ribs/rib[name="ipv4"]/routes/route[dest-prefix="10.0.0.0/8"]' \
  > "${FUZZDIR}/corpus_api_path/ii_two_keys.bin"
printf '\x00/ex:system/ex:ntp/ex:server[ex:name="ntp1.example.com"]' \
  > "${FUZZDIR}/corpus_api_path/ii_ns.bin"

echo "Done."
echo "Run: LD_LIBRARY_PATH=/usr/local/lib ./fuzz_api_path corpus_api_path"
