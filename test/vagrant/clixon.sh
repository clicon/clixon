#!/usr/bin/env bash
# Setup cligen and clixon
set -eux

if [ $# -ne 3 ]; then 
    echo "usage: $0 <release> <wwwuser> <with_restconf>"
    exit -1
fi
release=$1
wwwuser=$2
with_restconf=$3

# create user & group
if [ ! $(id -u clicon) ]; then 
   if [ $release = "freebsd" -o $release = "dragonfly" ]; then
      sudo pw useradd clicon -d /nonexistent -s /usr/sbin/nologin;
      sudo pw group mod clicon -m vagrant;  # start clixon tests as this users
      sudo pw group mod clicon -m $wwwuser;
   elif [ $release = "alpine" ]; then
      sudo adduser -D -H clicon
      sudo adduser $wwwuser clicon
  else  
      sudo useradd -M -U clicon;
      sudo usermod -a -G clicon vagrant; # start clixon tests as this users
      sudo usermod -a -G clicon $wwwuser;
   fi
fi

# Fcgi restconf requires /www-data directory for fcgi socket
if [ ${with_restconf} = fcgi ]; then
    if [ ! -d /www-data ]; then
        sudo mkdir /www-data
    fi
    sudo chown $wwwuser /www-data 
    sudo chgrp $wwwuser /www-data
fi

# cligen
test -d src || mkdir src
test -d src/cligen || (cd src;git clone https://github.com/clicon/cligen.git)
cd src/cligen
git pull origin master

./configure

if [ $release = "freebsd" -o $release = "dragonfly" ]; then
    MAKE=$(which gmake)
elif [ $release = "arch" ]; then
    MAKE=/usr/bin/make
else
    MAKE=$(which make)
fi
echo "MAKE:$MAKE"
$MAKE clean
$MAKE -j10
sudo $MAKE install

# Clixon
cd
test -d src/clixon || (cd src;git clone https://github.com/clicon/clixon.git)
cd src/clixon
git pull origin master

if [ $release = "freebsd" -o $release = "dragonfly" ]; then
    LDFLAGS="-L/usr/local/lib" CPPFLAGS="-I/usr/local/include" ./configure
else
   # Problems with su not having "sbin" in path on centos when when we run tests later
    LDFLAGS="-L/usr/local/lib" CPPFLAGS="-I/usr/local/include" ./configure --sbindir=/usr/sbin --libdir=/usr/lib --with-restconf=${with_restconf}
fi
$MAKE clean
$MAKE -j10
sudo $MAKE install
(cd example; $MAKE)
(cd example; sudo $MAKE install)
sudo ldconfig

# Clixon-util
cd
test -d src/clixon-util || (cd src;git clone https://github.com/clicon/clixon-util.git)
cd src/clixon-util
git pull origin main
LDFLAGS="-L/usr/local/lib" CPPFLAGS="-I/usr/local/include" ./configure
$MAKE clean
$MAKE -j10
sudo $MAKE install

cd
cd src/clixon/test
echo "#!/usr/bin/env bash" > ./site.sh
echo "IPv6=true" >> ./site.sh
if [ $release = "freebsd" -o $release = "dragonfly" ]; then
  echo "make=gmake" >> ./site.sh
fi
echo "OPENCONFIG=/usr/local/share/openconfig/public" >> ./site.sh

