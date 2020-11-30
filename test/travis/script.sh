#!/usr/bin/env bash
./configure --with-restconf=fcgi
make
sudo make install
(cd example; make; sudo make install)
(cd util; make; sudo make install)
sudo ldconfig
which clixon_backend
sudo clixon_backend
sleep 1
ps aux|grep clixon
(cd test; ./all.sh)
