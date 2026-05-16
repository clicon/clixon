#!/usr/bin/env bash
# Script to get yangmodels, either from local installation, or from remote
# This is an optimization from always getting it from github inside the dockerfile
if [ -d yang ]; then
    rm -rf yang
fi
mkdir -p yang/standard
if [ -d /usr/local/share/yang/standard ]; then
    cp -R /usr/local/share/yang/standard yang/    
else
   cd yang
   git init
   git remote add -f origin https://github.com/YangModels/yang
   git config core.sparseCheckout true
   echo "standard/" >> .git/info/sparse-checkout
   echo "experimental/" >> .git/info/sparse-checkout
   git pull origin main
fi

