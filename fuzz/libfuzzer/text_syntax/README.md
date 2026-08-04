# Clixon text_syntax libfuzzer target

Fuzz target for the clixon text/curly-brace syntax parse pipeline:
- `clixon_text_syntax_parse_string()` — text_syntax lexer, grammar, and XML tree construction
- Exercises curly-brace CLI configuration syntax including `prefix:name` node identifiers,
  quoted string values, nested containers, and list entries

No YANG binding is used (`YB_NONE`), so any parse error returns gracefully and
the fuzzer focuses on memory safety: leaks, bad frees, and use-after-free.

## Prerequisites

Build the clixon lib according to instructions in `..`

## Build the fuzzer

From this directory (`fuzz/libfuzzer/text_syntax/`):

```
./build.sh
```

This compiles `fuzz_text_syntax`, seeds `corpus_text_syntax/` with representative
text_syntax inputs, and creates `artifacts_text_syntax/`.

## Run

```
make run
```

Or directly:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_text_syntax corpus_text_syntax -dict=../text_syntax.dict
```

Monitor progress:

```
tail -f text_syntax.log
```

A healthy run shows thousands of inline counters and `cov:` growing over time.

## Reproducing a finding

libFuzzer writes crashes and leak reports to `artifacts_text_syntax/crash-<sha1>`.
Reproduce with:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_text_syntax artifacts_text_syntax/crash-<sha1>
```

Minimize:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_text_syntax -minimize_crash=1 -runs=10000 \
    artifacts_text_syntax/crash-<sha1>
```

For leak detection run in single-process mode (leaks are only reported on exit):

```
LD_LIBRARY_PATH=/usr/local/lib LSAN_OPTIONS=detect_leaks=1 \
    ./fuzz_text_syntax artifacts_text_syntax/crash-<sha1> -runs=1
```
