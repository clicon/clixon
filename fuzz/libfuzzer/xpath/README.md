

# Clixon XPath libfuzzer target

Fuzz target for the clixon XPath 1.0 parse pipeline:
- `xpath_parse()` — XPath lexer and grammar, producing an `xpath_tree`
- Exercises all XPath 1.0 constructs: location paths, axes, node tests, predicates, function calls, operators, and string literals

No XML tree evaluation is performed — the fuzzer focuses purely on the
parser's memory safety: leaks, bad frees, and use-after-free on malformed
or truncated XPath expressions.

## Prerequisites

Build the clixon lib according to instructions in `..`

## Build the fuzzer

From this directory (`fuzz/libfuzzer/xpath/`):

```
./build.sh
```

This compiles `fuzz_xpath`, seeds `corpus_xpath/` with representative XPath
expressions, and creates `artifacts_xpath/`.

## Run

```
make run
```

Or directly:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_xpath corpus_xpath -dict=../xpath.dict
```

Monitor progress:

```
tail -f xpath.log
```

A healthy run shows thousands of inline counters and `cov:` growing over time.

## Reproducing a finding

libFuzzer writes crashes and leak reports to `artifacts_xpath/crash-<sha1>`.
Reproduce with:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_xpath artifacts_xpath/crash-<sha1>
```

Minimize:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_xpath -minimize_crash=1 -runs=10000 \
    artifacts_xpath/crash-<sha1>
```

For leak detection run in single-process mode (leaks are only reported on exit):

```
LD_LIBRARY_PATH=/usr/local/lib LSAN_OPTIONS=detect_leaks=1 \
    ./fuzz_xpath artifacts_xpath/crash-<sha1> -runs=1
```
