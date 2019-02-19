# Clixon tests

## Overview

Tests called 'test_*.sh' and placed in this directory will be
automatically run as part of the all.sh, sum.sh tests etc. The scripts
need to follow some rules to work properly, please look at one or two
to get the idea.

See also the [site.sh](#site.sh) for example for skipping tests or setting some site-specific variables.

## Getting started

You need to build and install the clixon utility programs before running the tests as some of the tests rely on them:
```
  cd util
  make
  sudo make install
```

You need to start nginx for some of the text. There are instructions in 
* If you run systemd: `sudo systemctl start nginx.service`
* The [example](../example/README.md) has instructions
* See also the [clixon test container](../docker/system) where all test are encapsulated.

## Prefix variable

You can prefix a test with `BE=0` if you want to run your own backend.

To run with debug flags, use the `DBG=<number>` environment variable.

Other variables include:
* RCWAIT Number of seconds to sleep after daemons have started

## Run all tests

You can run an individual test by itself, or run through all tests matching 'test_*.sh' in the directory. Prints test output and stops on first error:
```
  all.sh
```

Run all tests but continue after errors and only print a summary test output identifying which tests succeeded and which failed:
```
  sum.sh
```

## Memory leak test
These tests use valgrind to check for memory leaks:
```
  mem.sh cli
  mem.sh netconf
  mem.sh backend
#  mem.sh restconf # NYI
```

## Site.sh
You may add your site-specific modifications in a `site.sh` file. Example:
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

