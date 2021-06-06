# Clixon fuzzing

This dir contains code for fuzzing clixon cli. 

Note: cli plugins do not work.

## Prereqs

Install AFL, see [..](..)

Build and install a clixon system (in particular the backend, the CLI will be replaced)

## Build

Build clixon cli statically with the afl-clang compiler:
```
  CC=/usr/bin/afl-clang-fast LINKAGE=static ./configure # Dont care about restconf
  make clean
  cd apps/cli
  make clixon_cli
  sudo make install
```

## Run tests

Run the script `runfuzz.sh` to run one test with a cli spec and an input string, eg:
```
  ./runfuzz.sh
```

After (or during) the test, investigate results in the output dir.

