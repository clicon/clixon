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

The current vagrant boxes are verified continuously:
* ubuntu/bionic64
* generic/centos8
* freebsd/FreeBSD-12.1-STABLE

For other vagrant boxes, see [search vagrant boxes](https://vagrantcloud.com/search)

