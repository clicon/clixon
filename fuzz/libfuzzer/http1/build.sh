#!/usr/bin/env bash
#
# Build the clixon HTTP/1 libFuzzer target with AddressSanitizer +
# UndefinedBehaviorSanitizer.
#
# Requirements:
#   - clang with libFuzzer (clang >= 6)
#   - clixon built and installed (libclixon, libcligen in /usr/local/lib)
#   - clixon_config.h generated (run ./configure in the repo root)
#   - the restconf HTTP/1 parser sources generated (run make in apps/restconf/)
#
# Usage (from this directory):
#   ./build.sh          # build fuzz_http1
#
# Run:
#   ./fuzz_http1 corpus_http1
#
set -euo pipefail

CC=${CC:-clang}
FUZZDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "${FUZZDIR}/../../.." && pwd)
RESTCONF="${ROOT}/apps/restconf"

SAN="-fsanitize=fuzzer-no-link,address,undefined -fno-omit-frame-pointer"
CFLAGS="-g -O1 ${SAN} \
  -I${RESTCONF} \
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

# The generated parser sources must exist (built by make in apps/restconf/)
for f in clixon_http1_parse.tab.c lex.clixon_http1_parse.c; do
  if [ ! -f "${RESTCONF}/${f}" ]; then
    echo "Error: ${RESTCONF}/${f} not found; run 'make' in apps/restconf/ first" >&2
    exit 1
  fi
done

echo "== Building fuzz_http1 =="
# shellcheck disable=SC2086
${CC} ${CFLAGS} ${LDFLAGS} \
  "${FUZZDIR}/fuzz_http1.c" \
  "${RESTCONF}/clixon_http1_parse.tab.c" \
  "${RESTCONF}/lex.clixon_http1_parse.c" \
  -o "${FUZZDIR}/fuzz_http1"

echo "== Seeding corpus =="
mkdir -p "${FUZZDIR}/corpus_http1" "${FUZZDIR}/artifacts_http1"

printf 'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n' \
  > "${FUZZDIR}/corpus_http1/get.http"
printf 'GET /restconf/data/ietf-interfaces:interfaces HTTP/1.1\r\nHost: localhost\r\nAccept: application/yang-data+json\r\n\r\n' \
  > "${FUZZDIR}/corpus_http1/get-data.http"
printf 'POST /restconf/data HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/yang-data+json\r\nContent-Length: 2\r\n\r\n{}' \
  > "${FUZZDIR}/corpus_http1/post.http"
printf 'PUT /restconf/data/x HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n' \
  > "${FUZZDIR}/corpus_http1/put.http"
printf 'DELETE /restconf/data/x HTTP/1.1\r\nHost: localhost\r\n\r\n' \
  > "${FUZZDIR}/corpus_http1/delete.http"
printf 'OPTIONS /restconf HTTP/1.1\r\nHost: localhost\r\n\r\n' \
  > "${FUZZDIR}/corpus_http1/options.http"
printf 'HEAD /restconf/data HTTP/1.1\r\nHost: localhost\r\n\r\n' \
  > "${FUZZDIR}/corpus_http1/head.http"

echo "Done."
echo "Run: LD_LIBRARY_PATH=/usr/local/lib ./fuzz_http1 corpus_http1"
