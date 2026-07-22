# Clixon xpath fuzzing

This dir contains code for fuzzing clixon xpaths. 

## Prereqs

Install AFL, see [..](..)

## Build

Build clixon clixon_util_xpath statically with the afl-clang compiler:

```
  CC=/usr/bin/afl-clang-fast LINKAGE=static INSTALLFLAGS="" ./configure
  make clean
  cd lib
  make
  sudo make install
  cd ../util
  make clixon_util_xpath
  sudo install clixon_util_xpath /usr/local/bin/ # some utils have complex dependencies
```

## Run tests

Run the script `runfuzz.sh` to run one test with a yang spec and an input string, eg:
```
  ./runfuzz.sh
```

After (or during) the test, investigate results in the output dir.
