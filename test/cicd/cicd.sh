#!/usr/bin/env bash
# CI/CD script complementing trevor github
# Login in to a number of hosts and fo the following:
# 0. Create and transfer sub-scripts used in main script: cligen-mk.sh clixon-mk.sh clixon-config.sh
# 1. pull latest version
# 2. Run configure
# 3. Compile and install (assume mk.sh)
# 4. Run tests
# Assume:
# - subscripts SCRIPTS exists locally where this script is executed
# - A test/site.sh file is handmade on each host
# - some commands are passwordless using
#    sudo visudo -f /etc/sudoers.d/clixonci
#       <user> ALL = (root)NOPASSWD : ALL
#       <user> ALL = (www-data)NOPASSWD : ALL
#       <user> ALL = (clicon)NOPASSWD : /usr/local/sbin/clixon_backend
# Experiment in identifying all commands: /usr/bin/make,/usr/local/sbin/clixon_backend,/usr/bin/pkill,/usr/local/bin/clixon_util_socket,/usr/bin/tee,/bin/rm,/usr/bin/touch,/bin/chmod
#
# Typical run:  ./cicd.sh 2>&1 | tee cilog

set -eux # x

if [ $# -ne 1 ]; then 
    echo "usage: $0 <host>"
    exit -1
fi

h=$1

ssh -t $h "test -d src || mkdir src"
ssh -t $h "test -d src/cligen || (cd src;git clone https://github.com/olofhagsand/cligen.git)"
ssh -t $h "(cd src/cligen;git pull)"
ssh -t $h "(cd src/cligen;./configure)"
ssh -t $h "(cd src/cligen; /tmp/cligen-mk.sh)"
ssh -t $h "test -d src/clixon || (cd src;git clone https://github.com/clicon/clixon.git)"
ssh -t $h "(cd src/clixon;git pull)"
ssh -t $h "(cd src/clixon; /tmp/clixon-config.sh)"
ssh -t $h "(cd src/clixon; /tmp/clixon-mk.sh)"
ssh -t $h sudo ldconfig
ssh -t $h "(cd src/clixon/test; ./sum.sh)"
