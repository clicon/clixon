Vagrant scripts
===============
Scripts for booting local vagrant hosts, installing clixon and running clixon tests

The script then uses a Makefile and logs in to each host, pulls from
git, configure, makes and runs through the tests. Make is used to get
concurrency - eg with `make -j 10`

The Makefile contains a configurable VAGRANTS variable, which is defined
in a `site.mk` file. You can add such a file, eg:
```
  VAGRANTS += freebsd/FreeBSD-12.1-STABLE
  VAGRANTS += generic/centos8
```

Beware memory exhaustion if you run too many simultaneously.

Logs appear in : `<dir>/<hostname>.log.`

You can also run a single vagrant test as follows:
```
  vagrant.sh freebsd/FreeBSD-12.1-STABLE
```

The current status is as follows
* freebsd/FreeBSD-12.1-STABLE - OK
* ubuntu/xenial64 - OK
* generic/opensuse42 - nginx: [emerg] getgrnam("www-data") failed in /etc/nginx/nginx.conf:2

* generic/centos8 - Error in test_perf_state.sh errcode=255
* 

For other vagrant boxes, see [search vagrant boxes](https://vagrantcloud.com/search)

