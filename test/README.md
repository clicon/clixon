# Clixon tests

This directory contains testing code for clixon and the example
routing application:
- clixon    A top-level script clones clixon in /tmp and starts all.sh. You can copy this file (review it first) and place as cron script
- all.sh    Run through all tests named 'test*.sh' in this directory. Therefore, if you place a test in this directory matching 'test*.sh' it will be run automatically. 
- test1.sh  CLI tests
- test2.sh  Netconf tests
- test3.sh  Restconf tests
- test4.sh  Yang tests
- test5.sh  Datastore tests
