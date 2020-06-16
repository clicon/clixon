#!/usr/bin/env bash
# Script for running cligen and clixon test scripts on local vagrant virtual hosts
# 1. Create a vagrant host based on "box" argument
# 2. setup host for clixon
# 3. Compile and install clixon
# 4. Run tests
# Example run:  ./vagrant.sh generic/centos8 2>&1 | tee cilog

set -eux # x

if [ $# -ne 1 -a $# -ne 2 ]; then 
    echo "usage: $0 <box> [destroy]\n <box> as defined in https://vagrantcloud.com/search"
    exit -1
fi

box=$1 # As defined in https://vagrantcloud.com/search
if  [ $# -eq 2 ]; then
    destroy=true
else
    destroy=false
fi

host=$(echo "$box"|awk -F'/' '{print $2}')
dir=$box
# XXX: ad-hoc to get (linux) release from boxname
# using lsb_release is too heavyweight in many cases
release=$(echo "$host" | grep -io "[a-z]*" | head -1 | tr '[:upper:]' '[:lower:]')
wwwuser=www-data

# example box="freebsd/FreeBSD-12.1-STABLE"
test -d $dir || mkdir -p $dir

# Write a freebsd vagrant file
cat<<EOF > $dir/Vagrantfile
Vagrant.configure("2") do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "$box"
  config.ssh.shell = "sh" # freebsd
  config.vm.define "$host"
  config.vm.hostname = "$host"
end
EOF

# Start vagrant
if $destroy; then
    (cd $dir; vagrant destroy -f)
fi
(cd $dir; vagrant up)

# Get ssh config to make proper ssh/scp calls to local vagrant host
cfg=$(cd $dir; vagrant ssh-config $host)
idfile=$(echo "$cfg" |grep "IdentityFile"|awk '{print $2}')
port=$(echo "$cfg" |grep "Port"|awk '{print $2}')
# make ssh and scp shorthand commands using vagrant-generated keys
sshcmd="ssh -o StrictHostKeyChecking=no -i $idfile -p $port vagrant@127.0.0.1"
scpcmd="scp -p -o StrictHostKeyChecking=no -i $idfile -P $port"
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[127.0.0.1]:$port"
echo "$sshcmd"

system=$($sshcmd uname)

buildfcgi=false
case $system in
    FreeBSD)
	# packages for building
	$sshcmd sudo pkg install -y git gmake bash
	# cligen
	$sshcmd sudo pkg install -y bison flex
	# Add www user for nginx
	if [ ! $($sshcmd id -u $wwwuser) ]; then
	    $sshcmd sudo pw useradd $wwwuser -d /nonexistent -s /usr/sbin/nologin 
	fi
	$sshcmd sudo pkg install -y fcgi-devkit nginx
	;;
    Linux)
	# nginx restconf user: $wwwuser
	if [ ! $($sshcmd id -u $wwwuser) ]; then
	    $sshcmd sudo useradd -M $wwwuser    
	fi
	case $release in
	    centos) # centos 8
		# packages for building
		$sshcmd sudo yum install -y git
		# cligen
		$sshcmd sudo yum install -y bison flex
		# clixon
		$sshcmd sudo yum install -y fcgi-devel nginx
		# clixon utilities
		$sshcmd sudo yum install -y libcurl-devel
		;;
	    opensuse) # opensuse42
		# packages for building
		$sshcmd sudo zypper install -y git
		# cligen
		$sshcmd sudo zypper install -y bison flex
		# clixon 
		$sshcmd sudo zypper install -y nginx
		buildfcgi=true # build fcgi from source
		# clixon utilities
		$sshcmd sudo zypper install -y libcurl-devel
		# packages for building fcgi
		$sshcmd sudo zypper install -y autoconf automake libtool
		;;
	    *) # ubuntu/apt based
		# cligen
		$sshcmd sudo apt install -y bison flex
		# clixon 
		$sshcmd sudo apt install -y libfcgi-dev nginx
		# clixon utilities
		$sshcmd sudo apt install -y libcurl4-openssl-dev
		;;
	esac
	;;
    *)
	echo "Unknown system: $system"
	;;
esac

# Some platforms dont have fcgi, build the source (should all?)
if $buildfcgi; then
    $sshcmd "test -d fcgi2 || git clone https://github.com/FastCGI-Archives/fcgi2"
    $sshcmd "(cd fcgi2; ./autogen.sh; ./configure; make; sudo make install)"
fi

# Hide all complex nginx config in sub-script
. ./nginx.sh $dir $idfile $port $wwwuser

# Setup cligen and clixon
# This is a script generated at the original host, then copied to the target and run there.
# 'EOF' means dont expand $
cat<<'EOF' > $dir/setup.sh
#!/usr/bin/env bash
set -eux # x

if [ $# -ne 2 ]; then 
    echo "usage: $0 <release> <wwwuser>"
    exit -1
fi
release=$1
wwwuser=$2
# create user & group
if [ ! $(id -u clicon) ]; then 
   if [ $release = "freebsd" ]; then
      sudo pw useradd clicon -d /nonexistent -s /usr/sbin/nologin;
      sudo pw group mod clicon -m vagrant;  # start clixon tests as this users
      sudo pw group mod clicon -m $wwwuser;
   else  
      sudo useradd -M -U clicon;
      sudo usermod -a -G clicon vagrant; # start clixon tests as this users
      sudo usermod -a -G clicon $wwwuser;
   fi
fi

# cligen
test -d src || mkdir src
test -d src/cligen || (cd src;git clone https://github.com/olofhagsand/cligen.git)
cd src/cligen
git pull

if [ $release = "freebsd" ]; then
    ./configure
    MAKE=$(which gmake)
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
    LDFLAGS=-L/usr/local/lib ./configure --with-cligen=/usr/local --enable-optyangs
else
   # Problems with su not having "sbin" in path on centos when when we run tests later
    ./configure --sbindir=/usr/sbin --libdir=/usr/lib --enable-optyangs
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
  echo 'SKIPLIST="test_api.sh"' >> ./site.sh
fi
EOF
chmod a+x $dir/setup.sh

# config and setup cligen and clixon
$scpcmd $dir/setup.sh vagrant@127.0.0.1:
$sshcmd ./setup.sh $release $wwwuser

# Run tests
$sshcmd "(cd src/cligen/test; ./sum.sh)"
$sshcmd "(cd src/clixon/test; ./sum.sh)"

# destroy vm
if $destroy; then
    (cd $dir; vagrant destroy -f)
fi
