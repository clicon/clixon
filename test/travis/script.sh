#!/usr/bin/env bash
set -eux
./configure --with-restconf=fcgi
make
sudo make install
(cd example; make; sudo make install)
(cd util; make; sudo make install)
sudo ldconfig
ps aux|grep clixon
cd test;
./test_api_path.sh
ps aux|grep clixon
./test_augment.sh
ps aux|grep clixon
./all.sh
