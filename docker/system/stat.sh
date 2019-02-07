#!/bin/sh
# Show stats (IP address etc) about the clixon containers
# include err(), stat() and other functions
. ./lib.sh

stat clixon/clixon-system

name=clixon/clixon-system
ps=$(sudo docker ps -f ancestor=$name|tail -n +2|grep $name|awk '{print $1}')
echo "sudo docker exec -it $ps clixon_cli # example command"
