#!/bin/sh
git clone https://github.com/olofhagsand/cligen.git
(cd cligen && ./configure && make && sudo make install)
