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
   if [ $release = "freebsd" ]; then
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

# cligen
test -d src || mkdir src
test -d src/cligen || (cd src;git clone https://github.com/clicon/cligen.git)
cd src/cligen
git pull

if [ $release = "freebsd" ]; then
    ./configure
    MAKE=$(which gmake)
elif [ $release = "arch" ]; then
    ./configure --prefix=/usr
    MAKE=/usr/bin/make
else
    ./configure --prefix=/usr
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
git pull

if [ $release = "freebsd" ]; then
    LDFLAGS=-L/usr/local/lib ./configure --with-cligen=/usr/local --enable-optyangs --with-restconf=${with_restconf}
else
   # Problems with su not having "sbin" in path on centos when when we run tests later
    ./configure --sbindir=/usr/sbin --libdir=/usr/lib --enable-optyangs --with-restconf=${with_restconf}
fi
$MAKE clean
$MAKE -j10
sudo $MAKE install
(cd example; $MAKE)
(cd util; $MAKE)
(cd example; sudo $MAKE install)
(cd util; sudo $MAKE install)
sudo ldconfig
cd test
echo "#!/usr/bin/env bash" > ./site.sh
if [ $release = "freebsd" ]; then
  echo "make=gmake" >> ./site.sh
fi
