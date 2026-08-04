# Clixon NETCONF libfuzzer target

Fuzz target for the clixon NETCONF receive pipeline:
- `netconf_input_msg2()` — EOM (`]]>]]>`) and chunked (RFC 6242) framing
- `netconf_input_frame2()` — XML parse and single-message validation

The first byte of each input selects framing type: `0x00` = EOM, anything else = chunked.

## Prerequisites

Build the clixon lib according to instructions in `..`

## Build the fuzzer

From this directory (`fuzz/libfuzzer/netconf/`):

```
./build.sh
```

This compiles `fuzz_netconf`, seeds `corpus_netconf/`, and creates `artifacts_netconf/`.

## Run

```
make run
```

Or directly:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_netconf corpus_netconf -dict=../xml.dict
```

Monitor progress:

```
tail -f netconf.log
```

A healthy run shows thousands of inline counters (not 28) and `cov:` growing over time.

## Reproducing a finding

libFuzzer writes crashes to `artifacts_netconf/crash-<sha1>`. Reproduce with:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_netconf artifacts_netconf/crash-<sha1>
```

Minimize:

```
LD_LIBRARY_PATH=/usr/local/lib ./fuzz_netconf -minimize_crash=1 -runs=10000 artifacts_netconf/crash-<sha1>
```
