# Fuzzing with AFL

Clixon can be fuzzed with [american fuzzy lop](https://github.com/google/AFL/releases) but not without pain.

Some issues are as follows:
- Static linking. Fuzzing requires static linking. You can statically link clixon using: `LINKAGE=static ./configure` but that does not work with Clixon plugins (at least yet). Therefore fuzzing has been made with no plugins using the hello example only.
- Multiple processes. Only the backend can run stand-alone, cli/netconf/restconf requires a backend. When you fuzz eg clixon_cli, the backend must be running and it will be slow due to IPC. Possibly one could link them together and run as a monolith by making a threaded image.

Restconf also has the extra problem of running TLS sockets.

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

### backend/restconf

Backend and restconf requires the preeny package to change sockets to stdio. 

Preeny has a "desocketizing" module necessary to map stdio to the internal sockets that the backend uses. Install preeny example:
```
  sudo apt install libini-config-dev # debian/ubuntu
  sudo apt install libseccomp-dev # debian/ubuntu
  git clone https://github.com/zardus/preeny.git
  cd preeny
  make
  sudo cp x86_64-linux-gnu/desock.so /usr/local/lib/ # install
```

