#!/bin/bash
# Start daemon and a cli docker containers .
# Note that they have a common file-system at /data 
#
sudo docker run -td --net host -v $(pwd)/data:/data olofhagsand/clicon_backend
sudo docker run -ti --rm --net host -v $(pwd)/data:/data olofhagsand/clicon_cli


