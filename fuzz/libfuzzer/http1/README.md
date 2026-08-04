# Clixon HTTP/1 libfuzzer target

Fuzz target for the clixon HTTP/1.1 flex/bison parser (`clixon_http1_parseparse`).
Drives the parser directly with no network, no backend, and no restconf_conn.

## Prerequisites

- Build the clixon lib according to instructions in `..`
- The restconf parser sources built (requires `make` in `apps/restconf/`)

## Build

From this directory (`fuzz/libfuzzer/http1/`):

```
  build.sh
```

## Run

```
make run
```

To suppress expected per-iteration leak reports from tokens abandoned on parse
errors and focus on heap-overflows/use-after-free:

```
ASAN_OPTIONS=detect_leaks=0 LD_LIBRARY_PATH=/usr/local/lib ./fuzz_http1 corpus/
```

## Corpus

Seed inputs go in the `corpus/` subdirectory (create if absent).
Any saved crashes are written to the current directory by libFuzzer.

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
