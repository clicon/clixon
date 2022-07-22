# Clixon Test and CI

## Overview

This directory contains Clixon test suites. Files directly under this
directory called `test_*.sh` are part of the regression CI tests.

There are also sub-directories for various other tests:
- cicd - Test scripts for running on remote hosts
- fuzz - Fuzzing with [american fuzzy lop](https://github.com/google/AFL/releases)
- vagrant - Scripts for booting local vagrant hosts, installing clixon and running clixon tests

automatically run as part of the all.sh, sum.sh tests etc. The scripts
need to follow some rules to work properly, please look at one or two
to get the idea.

Most scripts are bash scripts using standard awk/sed etc. There is
also (at least one) expect script.

Note that some IETF yangs need to be available, by default these are in `/usr/local//share/yang/standard`. You can change this location with configure option `--with-yang-standard-dir=DIR`

See also the [site.sh](#site-sh) for example for skipping tests or setting some site-specific variables.

## Openconfig and Yang

To download the openconfig and yang models required for the tests:
```
   cd /usr/local/share/openconfig
   git clone https://github.com/openconfig/public
   cd /usr/local/share/yang
   git init
   git remote add -f origin https://github.com/YangModels/yang
   git config core.sparseCheckout true
   echo "standard/" >> .git/info/sparse-checkout
   echo "experimental/" >> .git/info/sparse-checkout
   git pull origin main
```

## Continuous Integration

CI is done via github actions.

In the CI process, the system is built and configured and then the
[clixon test container](../docker/system) is built and the tests in
this directory is executed.

There are also [manual cicd scripts here](cicd/README.md)

## Getting started

You need to build and install the clixon utility programs before running the tests as some of the tests rely on them:
```
  cd util
  make
  sudo make install
```

You need to configure and start nginx for the restconf tests:
* The [example](../example/main/README.md) has instructions on how to edit your nginx config files
* If you run systemd: `sudo systemctl start nginx.service`

You may need to install the `time` utility (`/usr/bin/time`). 

## Prefix variable

You can prefix a test with `BE=0` if you want to run your own backend.

You can prefix a test with `RC=0` if you want to run your own restconf process.

You can prefix a test with `SN=0` if you want to run your own SNMP process (in combination with `BE=0`)

To run with debug flags, use the `DBG=<number>` environment variable.

Other variables include:
* DEMWAIT Number of seconds to sleep after daemons have started

## Run all tests

You can run an individual test by itself, or run through all tests matching 'test_*.sh' in the directory. Prints test output and stops on first error:
```
  all.sh
```

Run all tests but continue after errors and only print a summary test output identifying which tests succeeded and which failed:
```
  sum.sh
```

Add a detailed error print of the first test that failed, if any:
```
  detail=true sum.sh
```

## Memory leak test
The `mem.sh` runs memory checks using valgrind. Start it with no arguments to test all components (backend, restconf, cli, netconf), or specify which components to run:
```
  mem.sh    2>&1 | tee mylog        # All components
  mem.sh restconf backend           # Only backend and cli
```

## Run pattern of tests

The above scripts work with the `pattern` variable to limit the scope of which tests run, eg:
```
  pattern="test_c*.sh" mem.sh
```

## TLS and http/2

With default configure options, most tests run http/2 and TLS by
default. To pin tests to override this use the `HVER` and `RCPROTO` variables. Example:
```
HVER=1.1 RCPROTO=http ./test_restconf_plain_patch.sh
```

Some tests are pinned to certain settings and overriding will not will not work.

## Performance plots

The script `plot_perf.sh` produces gnuplots for some testcases.

## Site.sh
You may add your site-specific modifications in a `site.sh` file. Example:
```
  # Add your local site specific env variables (or tests) here.
  # Add test to this list that you dont want run
  SKIPLIST="test_openconfig.sh test_yangmodels.sh"
  # Parse yang openconfig models from https://github.com/openconfig/public
  OPENCONFIG=/usr/local/share/openconfig/public
```

For example, in FreeBSD, add:
```
  wwwuser=www
  make=gmake
```

## https

For fcgi/nginx you need to setup https in the nginx config file, independently of clixon.

If you use native with `configure --with-restconf=http1`, you can prepend the tests with RCPROTO=https which will run all restconf tests with SSL https and server certs.

Ensure the server keys are in order, as follows.

If you already have server certs, ensure the RESTCONF variable in lib.sh points to them, by default the config is
```
  <server-cert-path>/etc/ssl/certs/clixon-server-crt.pem</server-cert-path>
  <server-key-path>/etc/ssl/private/clixon-server-key.pem</server-key-path>
  <server-ca-cert-path>/etc/ssl/certs/clixon-ca-crt.pem</server-ca-cert-path>
```

If you do not have them, generate self-signed certs, eg as follows:
```
  openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/clixon-server-key.pem -out /etc/ssl/certs/clixon-server-crt.pem -days 365
```

There are also client-cert tests, eg `test_ssl_certs.sh`

## SNMP

Clixon snmp frontend tests require a running netsnmpd and converted YANG files from MIB.

Netsnmpd is 5.9 or later and can be started via systemd. For the tests
to run, the systems IFMIB should be disabled: `-I -ifTable,ifNumber,ifXTable,`, etc.

One way to start snmpd on Ubuntu, known to be working for the tests are: snmpd -Lo -p /var/run/snmpd.pid -I -ifXTable -I -ifTable -I -system_mib -I -sysORTable -I -snmpNotifyFilterTable -I -snmpNotifyTable -I -snmpNotifyFilterProfileTable

Converted YANG files are available at `https://github.com/clicon/mib-yangs` or alternatively use `smidump` version 0.5 or later. Clixon expects them to be at `/usr/local/share/mib-yangs/` by default, or configured by `--with-mib-generated-yang-dir=DIR`.

You also need to configure a unix socket for agent. Example of /etc/snmp/snmpd.conf:
```
master  agentx
agentaddress  127.0.0.1,[::1]
rwcommunity     public  localhost
agentXSocket    unix:/var/run/snmp.sock
agentxperms     777 777
```

## Known issues

[Workaround: Unicode double-quote in iana-if-type@2022-03-07.yang](https://github.com/clicon/clixon/issues/315)
