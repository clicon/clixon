CICD scripts
============
Manual scripts for running committed code on a set of hosts.

The script then uses a Makefile and logs in to each host, pulls from
git, configure, makes and runs through the tests. Make is used to get
concurrency - non-trivial with bash, eg with `make -j 10`

Note there are other cicd scripts than this, such as the the "travis" scrips.

The Makefile contains a configurable HOSTS variable, which ius defined
in a "hosts" file. You must add such a file, eg:
```
   HOSTS += vandal.hagsand.com # i86_32 ubuntu
```

Logs appear in : <hostname>.log.

