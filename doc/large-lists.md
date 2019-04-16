# Large lists in Clixon

  * [Background](#background)
  * [Overview](#overview)
  * [Test descriptions]#test-descriptions)

## Background

Clixon is a configuration management tool.  In this paper the case of
a large number of "flat" list and leaf-list entries are investigated.
There may be other scaling usecases, such as large configuratin
"depth", large number of requesting clients, etc. However, these are
not investigated here.

## Overview
The basic case is a large list, according to the following Yang specification:
```
   list y {
      key "a";
      leaf a {
         type int32;
      }
      leaf b {
         type string;
      }
   }
```
where `a` is a unique key and `b` is a payload, useful in replace operations.

There is also a leaf-list as follows:
```
    leaf-list c {
       type string;
    }
```

XML lists with `N` elements are generated based on
this configuration, eg for `N=10`:
```
   <y><a>0</a><b>0</b></y>
   <y><a>1</a><b>1</b></y>
   <y><a>2</a><b>2</b></y>
   <y><a>3</a><b>3</b></y>
   <y><a>4</a><b>4</b></y>
   <y><a>5</a><b>5</b></y>
   <y><a>6</a><b>6</b></y>
   <y><a>7</a><b>7</b></y>
   <y><a>8</a><b>8</b></y>
   <y><a>9</a><b>9</b></y>
```

Requests are made using a random function, a request on the list above will on the form:
```
   curl -G http://localhost/restconf/data/y=(rnd%$N)
```

## Test descriptions

### Limitations

Test were not made using CLI interaction.

### Setup

The setup consisted of the following components running on the same machine:
* A clixon backend daemon
* A clixon restconf daemon
* An nginx daemon daemon
* A netconf client program
* curl client
* A bash terminal and test script [plot_perf.sh](../test/plot_perf.sh)
* Gnuplot for generating plots

### Config file
The following Clixon config file was used:
```   
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>scaling</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/example/example.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/example.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
</clixon-config>
```
where `$dir` and `$cfg`are local files. For more info see [plot_perf.sh].

### Testcases

All tests measure the "real" time of a command on a lightly loaded
machine using the Linux command `time(1)`.

The following tests were made (for each architecture and protocol):
* Write `N` entries in one single operation. (With an empty datastore)
* Read `N` entries in one single operation. (With a datastore of `N` entries)
* Commit `N` entries (With a candidate of `N` entries and empty running)
* Read 1 entry (In a datastore of `N` entries)
* Write/Replace 1 entry (In a datastore of `N` entries)
* Delete 1 entry (In a datastore of `N` entries)

### Protocols

The tests are made using:
* Netconf[RFC6241] and
* Restconf[RFC8040].
Notably, CLI tests are for future study.

### Architectures

The tests were made on the following hardware, all running Ubuntu Linux:
* [i686] dual Intel Core Duo processor (IBM Thinkpad X60), 3GB memory
* arm 32-bit (Raspberry PI 3)
* x86 64-bit (Intel NUC)

### Operating systems

On i686:
```
Linux version 4.4.0-143-generic (buildd@lgw01-amd64-037) (gcc version 5.4.0 20160609 (Ubuntu 5.4.0-6ubuntu1~16.04.10) ) #169-Ubuntu SMP Thu Feb 7 07:56:51 UTC 2019
```

## Results

## References

[RFC6241](https://tools.ietf.org/html/rfc6241) "Network Configuration Protocol (NETCONF)"
[RFC8040](https://tools.ietf.org/html/rfc8040) "RESTCONF Protocol"
[i686](https://ark.intel.com/content/www/us/en/ark/products/27235/intel-core-duo-processor-t2400-2m-cache-1-83-ghz-667-mhz-fsb.html)
[plot_perf.sh](../test/plot_perf.sh) Test script


