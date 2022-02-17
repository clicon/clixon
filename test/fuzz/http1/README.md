# Clixon http1 fuzzing

This dir contains code for fuzzing the clixon http1 parser. This is normally inside the
native restconf app and need some special compiling to run stand-alone.

Install AFL, see [..](..)

Enable `RESTCONF_HTTP1_UNITTEST` in `include/clixon_custom.h`.


Build and install clixon libraries and restconf statically
```
  ./configure --disable-nghttp2 LINKAGE=static INSTALLFLAGS="" CC=/usr/bin/afl-clang-fast CFLAGS="-g"
  make clean
  make
  sudo make install
  ./runfuzz.sh
```


To view crashes
```
sudo chmod o+x output/crashes
sudo chmod -R o+r output/crashes
```
