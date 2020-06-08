Vagrant scripts
===============
Scripts for booting local vagrant hosts, installing clixon and running clixon tests

The script then uses a Makefile and logs in to each host, pulls from
git, configure, makes and runs through the tests. Make is used to get
concurrency - eg with `make -j 10`

The Makefile contains a configurable VAGRANTS variable, which is defined
in a "site.mk" file. You can add such a file, eg:
```
  VAGRANTS += freebsd/FreeBSD-12.1-STABLE
  VAGRANTS += generic/centos8
```

Logs appear in : <hostname>.log.

You can also run a single vagrant test as follows:
```
  vagrant.sh freebsd/FreeBSD-12.1-STABLE
```

The current status is as follows
* freebsd/FreeBSD-12.1-STABLE
* generic/centos8 - some remaining nginx issue
* generic/opensuse42 - fastcgi is not installed

See more Vagrant boxes at [https://vagrantcloud.com/search]).
