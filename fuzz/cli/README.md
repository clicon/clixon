# Clixon fuzzing

This dir contains code for fuzzing clixon cli. 

Note: cli plugins do not work.

## Prereqs

See [AFL docs](https://afl-1.readthedocs.io/en/latest) for installing afl.
On ubuntu this may be enough:
```
  sudo apt install afl
```

You may have to change cpu frequency:
```
  cd /sys/devices/system/cpu
  echo performance | tee cpu?/cpufreq/scaling_governor
```

And possibly change core behaviour:
```
  echo core >/proc/sys/kernel/core_pattern
```

## Build

Build clixon statically with the afl-clang compiler:
```
  CC=/usr/bin/afl-clang-fast LINKAGE=static ./configure
  make clean
  cd apps/cli
  make clixon_cli
  sudo make install
```

## Run tests

Start the backend and Use the script `runfuzz.sh` to run one test with a cli spec and an input string, eg:
```
  ./runfuzz.sh /usr/local/etc/hello.xml "set table parameter a value 23"
```

After (or during) the test, investigate results in the output dir.

