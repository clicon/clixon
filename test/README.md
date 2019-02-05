# Clixon tests

This directory contains testing code for clixon and the example
application. Assumes setup of http daemon as describe under apps/restonf
- Jenkinsfile       Makefile for Jenkins tests. Build clixon and run tests.
- all.sh            Run through all tests with detailed output, and stop on first error.
- sum.sh            Run though all tests and print summary
- mem.sh            Make valgrind 
- site.sh           Add your site-specific modifications here
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

Tests called 'test*.sh' and placed in this directory will be automatically run as part of the all.sh, sum.sh tests etc. 

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


