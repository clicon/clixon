#!/usr/bin/env bash
#
# Build the clixon XPath libFuzzer target with AddressSanitizer +
# UndefinedBehaviorSanitizer.
#
# Requirements:
#   - clang with libFuzzer (clang >= 6)
#   - clixon built and installed (libclixon, libcligen in /usr/local/lib)
#   - clixon_config.h generated (run ./configure in the repo root)
#
# Usage (from this directory):
#   ./build.sh          # build fuzz_xpath
#
# Run:
#   ./fuzz_xpath corpus_xpath -dict=../xpath.dict
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

echo "== Building fuzz_xpath =="
# shellcheck disable=SC2086
${CC} ${CFLAGS} ${LDFLAGS} \
  "${FUZZDIR}/fuzz_xpath.c" \
  -o "${FUZZDIR}/fuzz_xpath"

echo "== Seeding corpus =="
mkdir -p "${FUZZDIR}/corpus_xpath" "${FUZZDIR}/artifacts_xpath"

printf '/interfaces/interface[name="eth0"]' \
  > "${FUZZDIR}/corpus_xpath/path.xpath"
printf '/a/b/c' \
  > "${FUZZDIR}/corpus_xpath/simple.xpath"
printf '//interface[enabled="true"]' \
  > "${FUZZDIR}/corpus_xpath/filter.xpath"
printf 'count(/a/b)' \
  > "${FUZZDIR}/corpus_xpath/function.xpath"
printf '/a[@type="x" and @name="y"]' \
  > "${FUZZDIR}/corpus_xpath/and.xpath"
printf '/a/b | /c/d' \
  > "${FUZZDIR}/corpus_xpath/union.xpath"
printf 'not(/a) or /b' \
  > "${FUZZDIR}/corpus_xpath/not.xpath"
printf 'string-length(../name) > 0' \
  > "${FUZZDIR}/corpus_xpath/comparison.xpath"
printf '/ns:a/ns:b' \
  > "${FUZZDIR}/corpus_xpath/namespace.xpath"
printf 'descendant-or-self::node()' \
  > "${FUZZDIR}/corpus_xpath/axis.xpath"

echo "Done."
echo "Run: LD_LIBRARY_PATH=/usr/local/lib ./fuzz_xpath corpus_xpath -dict=../xpath.dict"
