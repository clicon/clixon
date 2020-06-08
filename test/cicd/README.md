Hosts scripts
=============
Manual scripts for running committed code on a set of remote hosts accessible with ssh.

The script then uses a Makefile and logs in to each host, pulls from
git, configure, makes and runs through the tests. Make is used to get
concurrency, eg with `make -j 10`

The Makefile contains a configurable HOSTS variable, which is defined
in a "site.mk" file. You must add such a file, eg:
```
   HOSTS += vandal.hagsand.com # i86_32 ubuntu
```

Logs appear in : <hostname>.log.

