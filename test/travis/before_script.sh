#!/bin/sh
# Run this as before_script in the travis file
apt-get update && apt-get install -y \
  libfcgi-dev 

git clone https://github.com/olofhagsand/cligen.git
(cd cligen && ./configure && make && sudo make install)
