#!/bin/sh

# Name of container
: ${NAME:=clixon-example}

# Kill all controller containers (optionally do `make clean`)
sudo docker kill $NAME 2> /dev/null # ignore errors
