# Clixon http1 fuzzing

This dir contains code for fuzzing the clixon http1 parser. This is normally inside the
native restconf app and need some special compiling to run stand-alone.

Install AFL, see [..](..)

Edit `apps/restconf/restconf_main_native.c` by disabling the regular
main function and replacing it with the unit testing `main`:
```
--- a/apps/restconf/restconf_main_native.c
+++ b/apps/restconf/restconf_main_native.c
@@ -1403,7 +1403,7 @@ usage(clicon_handle h,
 /* Enable for normal use
  * Disable for unit testing, fuzzing, etc
  */
-#if 1
+#if 0
```

Build and install clixon libraries and restconf statically
```
  ./configure LINKAGE=static INSTALLFLAGS="" CC=/usr/bin/afl-clang-fast
  make clean
  make
  sudo make install
  ./runfuzz.sh
```

