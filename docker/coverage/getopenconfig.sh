#!/usr/bin/env bash
# Script to get openconfig, either from local installation, or from remote
# This is an optimization from always getting it from github inside the dockerfile
if [ -d openconfig ]; then
    rm -rf openconfig
fi
mkdir -p openconfig

if [ -d /usr/local/share/openconfig ]; then
    cp -R /usr/local/share/openconfig openconfig/    
else
    (cd openconfig && git clone https://github.com/openconfig/public)
fi

