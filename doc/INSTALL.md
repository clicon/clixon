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
    git clone https://github.com/olofhagsand/cligen.git
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
     configure	       	       # Configure clixon to platform
     make                      # Compile
     sudo make install         # Install libs, binaries, and config-files
     sudo make install-include # Install include files (for compiling)
```

## Alpine Linux
Docker is used to build Alpine Linux 
### Build docker image

## FreeBSD
### Package install
### Build from source

