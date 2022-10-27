# Building Clixon

Clixon runs on Linux, [FreeBSD port](https://www.freshports.org/devel/clixon) and Mac/Apple. CPU architecures include x86_64, i686, ARM32.

## Ubuntu Linux

### Installing dependencies

Install packages
```
sudo apt-get update
sudo apt-get install flex bison fcgi-dev curl-dev
```

Install and build CLIgen
```
    git clone https://github.com/clicon/cligen.git
    cd cligen;
    configure;
    make;
    make install
```

Add a user group, using groupadd and usermod:
```
  sudo groupadd clicon # 
  sudo usermod -a -G clicon <user>
  sudo usermod -a -G clicon www-data
```


### Build from source
```
     configure                 # Configure clixon to platform
     make                      # Compile
     sudo make install         # Install libs, binaries, and config-files
     sudo make install-include # Install include files (for compiling)
```

## Alpine Linux
Docker is used to build Alpine Linux 
### Build docker image

## FreeBSD

FreeBSD has ports for both cligen and clixon available.
You can install them as binary packages, or you can build
them in a ports source tree locally.

If you install using binary packages or build from the
ports collection, the installation locations comply
with FreeBSD standards and you have some assurance
that the installed package is correct and functional.

The nginx setup for RESTCONF is altered - the system user
www is used, and the restconf daemon is placed in
/usr/local/sbin.

### Binary package install

To install the pre-built binary package, use the FreeBSD
pkg command.

```
% pkg install clixon
```

This will install clixon and all the dependencies needed.

### Build from source

If you prefer you can also build clixon from the
[FreeBSD ports collection](https://www.freebsd.org/doc/handbook/ports-using.html)

Once you have the Ports Collection installed, you build
clixon like this:

```
% cd /usr/ports/devel/clixon
% make && make install
```

One issue with using the Ports Collection is that it may
not install the latest version from GitHub. The port is
generally updated soon after an official release, but there
is still a lag between it and the master branch. The maintainer
for the port tries to assure that the master branch will
compile always, but no FreeBSD specific functional testing
is done.



