# Clixon fuzzing

This dir contains code for fuzzing clixon backend.

It requires the preeny package to change sockets to stdio. 

Plugins do not work

## Prereqs

Install AFL and preeny, see [..](..)

## Build

Build clixon statically with the afl-clang compiler:
```
  CC=/usr/bin/afl-clang-fast LINKAGE=static ./configure
  make clean
  make
  sudo make install
```

## Run tests

Populate the input/ dir with input usecases, there are two examples already in this dir that can be modified.
Use the script `runfuzz.sh` to run one test:
```
  ./runfuzz.sh
```

After (or during) the test, investigate results in the output dir.
