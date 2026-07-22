# Clixon JSON libfuzzer target

Fuzz target for the clixon JSON parse pipeline:
- `clixon_json_parse_string()` — JSON lexer, grammar, and XML tree construction
- Exercises RFC 7951 JSON encoding including `prefix:name` node identifiers

No YANG binding is used (`YB_NONE`), so any parse error returns gracefully and
the fuzzer focuses on memory safety: leaks, bad frees, and use-after-free.

## Prerequisites

Build the clixon lib according to instructions in `..`

## Build the fuzzer

From this directory (`fuzz/libfuzzer/json/`):

```
./build.sh
```

This compiles `fuzz_json`, seeds `corpus_json/` with representative JSON inputs,
and creates `artifacts_json/`.

## Run

```
make run
```

Or directly:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_json corpus_json -dict=../json.dict
```

Monitor progress:

```
tail -f json.log
```

A healthy run shows thousands of inline counters and `cov:` growing over time.

## Reproducing a finding

libFuzzer writes crashes and leak reports to `artifacts_json/crash-<sha1>`.
Reproduce with:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_json artifacts_json/crash-<sha1>
```

Minimize:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_json -minimize_crash=1 -runs=10000 \
    artifacts_json/crash-<sha1>
```

For leak detection run in single-process mode (leaks are only reported on exit):

```
LD_LIBRARY_PATH=/usr/local/lib LSAN_OPTIONS=detect_leaks=1 \
    ./fuzz_json artifacts_json/crash-<sha1> -runs=1
```

## Restoring a normal build

After fuzzing, restore a normal clixon build:

```
cd /path/to/clixon
./configure
make -C lib clean
make -C lib
sudo make -C lib install
sudo ldconfig
```
