# Clixon tests

This directory contains testing code for clixon and the example
application. Assumes setup of http daemon as describe under apps/restonf
- jenkins           Directory w Jenkins specific stuff
- travis            Directory w Travis specific stuff
- all.sh            Run through all tests with detailed output, and stop on first error.
- sum.sh            Run though all tests and print summary
- mem.sh            Make valgrind 
- site.sh           Add your site-specific modifications here (see example below)
- test_nacm.sh      Auth tests using internal NACM
- test_nacm_ext.sh  Auth tests using external NACM (separate file)
- test_nacm_protocol.sh  Auth tests for incoming RPC:s
- test_nacm_module_read.sh  Auth tests for data node read operations
- test_nacm_module_write.sh  Auth tests for data node write operations
- test_cli.sh       CLI tests
- test_netconf.sh   Netconf tests
- test_restconf.sh  Restconf tests
- test_yang.sh      Yang tests for constructs not in the example.
- test_leafref.sh   Yang leafref tests
- test_datastore.sh Datastore tests
- and many more...

Tests called 'test_*.sh' and placed in this directory will be
automatically run as part of the all.sh, sum.sh tests etc. The scripts need to follow some rules to work properly, such as add this magic line as the first command line in the script, which ensures it works well when started from `all.sh`:
```
  s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi
```

You need to build and install the clixon utility programs before running the tests as some of the tests rely on them:
```
  cd util
  make
  sudo make install
```

You need to start nginx for some of the text. There are instructions in 
* If you run systemd: `sudo systemctl start nginx.service`
* The [example](../example/README.md) has instructions

You can prefix a test with `BE=0` if you want to run your own backend.

To run with debug flags, use the `DBG=<number>` environment variable.

You can run an individual test by itself, or run through all tests matching 'test_*.sh' in the directory. Prints test output and stops on first error:
```
  all.sh
```

Run all tests but continue after errors and only print a summary test output identifying which tests succeeded and which failed:
```
  all.sh summary
```

Example site.sh file:
```
  # Add your local site specific env variables (or tests) here.
  # Add test to this list that you dont want run
  SKIPLIST="test_openconfig.sh test_yangmodels.sh"
  # Parse yang openconfig models from https://github.com/openconfig/public
  OPENCONFIG=/home/olof/src/clixon/test/public
  # Parse yangmodels from https://github.com/YangModels/yang
  YANGMODELS=/usr/local/share/yangmodels
  # Standard IETF RFC yang files. 
  IETFRFC=$YANGMODELS/standard/ietf/RFC
```

