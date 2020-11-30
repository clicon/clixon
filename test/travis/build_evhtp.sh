#!/usr/bin/env bash
# Travis pre-config script.
# build libevhtp
git clone https://github.com/criticalstack/libevhtp.git
(cd libevhtp/build && cmake -DEVHTP_DISABLE_REGEX=ON -DEVHTP_DISABLE_EVTHR=ON .. && make && sudo make install)
