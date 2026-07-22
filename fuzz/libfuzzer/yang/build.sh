#!/usr/bin/env bash
#
# Build the clixon YANG libFuzzer target with AddressSanitizer +
# UndefinedBehaviorSanitizer.
#
# Requirements:
#   - clang with libFuzzer (clang >= 6)
#   - clixon built and installed (libclixon, libcligen in /usr/local/lib)
#   - clixon_config.h generated (run ./configure in the repo root)
#
# Usage (from this directory):
#   ./build.sh          # build fuzz_yang
#
# Run:
#   ./fuzz_yang corpus_yang -dict=../yang.dict
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

echo "== Building fuzz_yang =="
# shellcheck disable=SC2086
${CC} ${CFLAGS} ${LDFLAGS} \
  "${FUZZDIR}/fuzz_yang.c" \
  -o "${FUZZDIR}/fuzz_yang"

echo "== Seeding corpus =="
mkdir -p "${FUZZDIR}/corpus_yang" "${FUZZDIR}/artifacts_yang"

cat > "${FUZZDIR}/corpus_yang/interfaces.yang" << 'EOF'
module interfaces {
  namespace "urn:example:interfaces";
  prefix "if";
  description "Example interfaces YANG module";
  revision 2024-01-01 { description "Initial"; }
  container interfaces {
    list interface {
      key "name";
      leaf name { type string; }
      leaf enabled { type boolean; default true; }
      leaf mtu { type uint16 { range "64..9000"; } }
    }
  }
}
EOF

cat > "${FUZZDIR}/corpus_yang/types.yang" << 'EOF'
module types {
  namespace "urn:example:types";
  prefix "ty";
  revision 2024-01-01 { description "Initial"; }
  typedef my-string { type string { length "1..64"; pattern '[a-z]+'; } }
  typedef my-int { type int32 { range "-100..100"; } }
  leaf a { type my-string; }
  leaf b { type union { type my-int; type string; } }
}
EOF

cat > "${FUZZDIR}/corpus_yang/grouping.yang" << 'EOF'
module grouping {
  namespace "urn:example:grouping";
  prefix "gr";
  revision 2024-01-01 { description "Initial"; }
  grouping address {
    leaf ip { type string; }
    leaf port { type uint16; }
  }
  container server { uses address; }
}
EOF

cat > "${FUZZDIR}/corpus_yang/leafref.yang" << 'EOF'
module leafref {
  namespace "urn:example:leafref";
  prefix "lr";
  revision 2024-01-01 { description "Initial"; }
  list items {
    key "name";
    leaf name { type string; }
  }
  leaf ref { type leafref { path "../items/name"; } }
}
EOF

cat > "${FUZZDIR}/corpus_yang/submodule.yang" << 'EOF'
module submod-parent {
  namespace "urn:example:submod";
  prefix "sp";
  revision 2024-01-01 { description "Initial"; }
  leaf x { type string; }
}
EOF

echo "Done."
echo "Run: LD_LIBRARY_PATH=/usr/local/lib ./fuzz_yang corpus_yang -dict=../yang.dict"
