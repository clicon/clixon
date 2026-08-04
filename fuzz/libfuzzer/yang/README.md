# Clixon YANG libfuzzer target

Fuzz target for the clixon YANG parse pipeline:
- `yang_spec_parse_file()` — YANG lexer, grammar, and full post-parse processing
- Exercises RFC 7950 YANG constructs: modules, typedefs, groupings, augments, deviations, extensions, leafrefs, XPath `when`/`must` expressions, and more

Each fuzzer iteration writes the input to a temporary file, calls the full
parse+validate stack, then prunes the added module so the YANG spec is clean
for the next iteration.

## Prerequisites

Build the clixon lib according to instructions in `..`

## Build the fuzzer

From this directory (`fuzz/libfuzzer/yang/`):

```
./build.sh
```

This compiles `fuzz_yang`, seeds `corpus_yang/` with representative YANG module
inputs, and creates `artifacts_yang/`.

## Run

```
make run
```

Or directly:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_yang corpus_yang -dict=../yang.dict
```

Monitor progress:

```
tail -f yang.log
```

A healthy run shows thousands of inline counters and `cov:` growing over time.

## Reproducing a finding

libFuzzer writes crashes and leak reports to `artifacts_yang/crash-<sha1>`.
Reproduce with:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_yang artifacts_yang/crash-<sha1>
```

Minimize:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_yang -minimize_crash=1 -runs=10000 \
    artifacts_yang/crash-<sha1>
```

For leak detection run in single-process mode (leaks are only reported on exit):

```
LD_LIBRARY_PATH=/usr/local/lib LSAN_OPTIONS=detect_leaks=1 \
    ./fuzz_yang artifacts_yang/crash-<sha1> -runs=1
```
