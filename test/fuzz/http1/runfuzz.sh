#!/usr/bin/env bash
# Run a fuzzing test using american fuzzy lop
# Add input strings in input
set -eux

if [ $# -ne 0 ]; then 
    echo "usage: $0"
    exit 255
fi

MEGS=500 # memory limit for child process (50 MB)

# remove input and input dirs
#test ! -d input || rm -rf input
test ! -d output || sudo rm -rf output

# create if dirs dont exists
#test -d input || mkdir input
test -d output || mkdir output

# Run script 
#  CC=/usr/bin/afl-clang 
sudo afl-fuzz -i input -o output -d -m $MEGS -- /usr/local/sbin/clixon_restconf


