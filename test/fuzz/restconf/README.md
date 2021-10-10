# Clixon fuzzing

This dir contains code for fuzzing clixon restconf 

It requires the preeny package to change sockets to stdio. 

## Prereqs

Install AFL and preeny, see [..](..)

Build and install a clixon system (in particular the backend, RESTCONF binary will be replaced)

## Build

Build clixon restconf statically with the afl-clang compiler:
```
  CC=/usr/bin/afl-clang-fast LINKAGE=static ./configure --with-restconf=native
  make clean
  cd apps/restconf
  make clixon_restconf
  sudo make install
```

## Run tests

Use the script `runfuzz.sh` to run one test:
```
  ./runfuzz.sh
```

After (or during) the test, investigate results in the output dir.
