#!/bin/sh

# Kill all controller containers (optionally do `make clean`)
sudo docker kill clixon-test 2> /dev/null # ignore errors
