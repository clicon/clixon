# Fuzzing with LLVM libfuzzer

## Prerequisites

- clang with libFuzzer support (clang >= 6)
- clixon built and installed with fuzzer instrumentation (see below)

## Build libclixon with instrumentation

libclixon must be compiled and linked with `-fsanitize=fuzzer-no-link,address`
so that libFuzzer can observe coverage inside the library. Without this the
fuzzer only sees 28 counters (just the harness) and makes no progress.

```
cd /path/to/clixon
./configure CC=clang \
  CFLAGS="-g -O1 -fsanitize=fuzzer-no-link,address -fno-omit-frame-pointer" \
  LDFLAGS="-fsanitize=fuzzer-no-link,address"
cd lib
make clean
make
sudo make install
sudo ldconfig
```

## Restoring a normal build

After fuzzing, restore a normal clixon build:

```
cd /path/to/clixon
./configure
cd lib
make clean
make lib
sudo make install
sudo ldconfig
```

## Remaining parsers
yang_schemanode, yang_sub
