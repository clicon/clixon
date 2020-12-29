# Clixon fuzzing

This dir contains code for fuzzing clixon backend. 

It requires the preeny package to change sockets to stdio. 

Plugins do not work

## Prereqs

Preeny has a "desocketizing" module necessary to map stdio to the internal sockets that the backend uses. Install preeny example:
```
  sudo apt install libini-config-dev # debian/ubuntu
  sudo apt install libseccomp-dev # debian/ubuntu
  git clone https://github.com/zardus/preeny.git
  cd preeny
  make
  sudo cp x86_64-linux-gnu/desock.so /usr/local/lib/ # install
```

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

Make a modification to how Clixon sends internal messages in `include/clixon_custom.h`:
```
  #define CLIXON_PROTO_PLAIN
```

Build clixon statically with the afl-clang compiler:
```
  CC=/usr/bin/afl-clang-fast LINKAGE=static ./configure --with-restconf=evhtp
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
