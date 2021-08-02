#!/usr/bin/env bash
# Script for running cligen and clixon test scripts on local vagrant virtual hosts
# 1. Create a vagrant host based on "box" argument
# 2. setup host for clixon
# 3. Compile and install clixon
# 4. Run tests
# Example run:  ./vagrant.sh generic/centos8 2>&1 | tee cilog
# Default runs native (not fcgi)

set -eux #

if [ $# -ne 1 -a $# -ne 2 ]; then 
    echo "usage: $0 <box> [destroy]\n <box> as defined in https://vagrantcloud.com/search"
    exit 255
fi

box=$1 # As defined in https://vagrantcloud.com/search

#with_restconf=fcgi
: ${with_restconf:=native}
echo "with-restconf:${with_restconf}"

VCPUS=1
MEM=1024

# This is a hack just to get the linux release for provisioning
linuxrelease()
{
    box=$1
    release="unknown"
    for r in freebsd openbsd opensuse ubuntu centos coreos alpine debian arch gentoo fedora rhel; do
	# -i ignore case
	if [ -n "$(echo "$box" | grep -io "$r")" ]; then	
	    release=$r
	    break
	fi
    done
    # Special cases
    if [ "$release" = "unknown" ]; then
	if [ -n "$(echo "$box" | grep -io "bionic")" ]; then
	    release=ubuntu
	    break;
	fi
    fi
    echo "$release"
}

if  [ $# -eq 2 ]; then
    destroy=true
else
    destroy=false
fi

# Convert eg centos/8 -> centos-8 and use that as dir and hostname
host=$(echo "$box"|sed -e "s/\//-/")
dir=$host
wwwuser=www-data

# XXX ad.hoc to get release (lsb-release is too heavyweight)
release=$(linuxrelease $box)
echo "release:$release"

if [ "$release" = unknown ]; then
    echo "$box not recognized"
    exit 255
fi

test -d $dir || mkdir -p $dir

# Write a vagrant file
cat<<EOF > $dir/Vagrantfile
Vagrant.configure("2") do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "$box"
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.box_check_update = true
  config.ssh.shell = "sh" # freebsd
  config.vm.define "$host"
  config.vm.hostname = "$host"
  config.vm.provider "virtualbox" do |v|
        v.memory = $MEM
        v.cpus = $VCPUS
  end
end
EOF

# Start vagrant
if $destroy; then
    (cd $dir; vagrant destroy -f)
    exit 0
fi
(cd $dir; vagrant up)
echo "vagrant is up -----------------"
# Get ssh config to make proper ssh/scp calls to local vagrant host
cfg=$(cd $dir; vagrant ssh-config $host)
idfile=$(echo "$cfg" |grep "IdentityFile"|awk '{print $2}')
port=$(echo "$cfg" |grep "Port"|awk '{print $2}')
# make ssh and scp shorthand commands using vagrant-generated keys
sshcmd="ssh -o StrictHostKeyChecking=no -i $idfile -p $port vagrant@127.0.0.1"
scpcmd="scp -p -o StrictHostKeyChecking=no -i $idfile -P $port"
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[127.0.0.1]:$port"
echo "$sshcmd"

system=$($sshcmd uname) # we use the release "hack" instead

# Some release have packages, some need to be built from source
buildfcgi=false
case $release in
    openbsd)
	# packages for building
	$sshcmd sudo pkg install -y git gmake bash
	# cligen
	$sshcmd sudo pkg install -y bison flex
	# Add restconf user
	if [ ! $($sshcmd id -u $wwwuser) ]; then
	    $sshcmd sudo pw useradd $wwwuser -d /nonexistent -s /usr/sbin/nologin 
	fi
	case ${with_restconf} in
	    fcgi)
		$sshcmd sudo pkg install -y fcgi-devkit nginx
		;;
	    native)
		;;
	esac
    ;;
    freebsd)
	# packages for building
	$sshcmd sudo pkg install -y git gmake bash
	# cligen
	$sshcmd sudo pkg install -y bison flex
	# Add restconf user
	if [ ! $($sshcmd id -u $wwwuser) ]; then
	    $sshcmd sudo pw useradd $wwwuser -d /nonexistent -s /usr/sbin/nologin 
	fi
	case ${with_restconf} in
	    fcgi)
		$sshcmd sudo pkg install -y fcgi-devkit nginx
		;;
	    native)
		$sshcmd sudo pkg install -y libevent
		;;
	esac
	;;
    centos)
        # enable ipv6
        $sshcmd sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
	# add restconf user: $wwwuser
	if [ ! $($sshcmd id -u $wwwuser) ]; then
	    $sshcmd sudo useradd -M $wwwuser    
	fi
	# packages for building
	$sshcmd sudo yum install -y git make
	# cligen
	$sshcmd sudo yum install -y bison flex
	# clixon utilities
	$sshcmd sudo yum install -y time libcurl-devel gcc-c++
	# restconf
	case ${with_restconf} in
	    fcgi)
		buildfcgi=true # build fcgi from source
		$sshcmd sudo yum install -y epel-release
		#			$sshcmd sudo yum update
		$sshcmd sudo yum install -y nginx
		;;
	    native)
		$sshcmd sudo yum install -y libevent openssl
		$sshcmd sudo yum install -y libevent-devel openssl-devel
		$sshcmd sudo dnf config-manager --set-enabled powertools
		$sshcmd sudo yum install -y libnghttp2-devel
		;;
	esac
	;;
    opensuse) # opensuse42
	# restconf user: $wwwuser
	if [ ! $($sshcmd id -u $wwwuser) ]; then
	    $sshcmd sudo useradd -M -U $wwwuser    
	fi
	# packages for building
	$sshcmd sudo zypper install -y git
	# cligen
	$sshcmd sudo zypper install -y bison flex
	# clixon utilities
	$sshcmd sudo zypper install -y libcurl-devel gcc-c++
	# restconf
	case ${with_restconf} in
	    fcgi)
		$sshcmd sudo zypper install -y nginx
		buildfcgi=true # build fcgi from source
		;;
	    native)
		;;
	esac
	;;
    ubuntu) # ubuntu/apt based
	$sshcmd sudo apt-get update --fix-missing
	$sshcmd sudo apt install -y git
	# restconf user: $wwwuser
	if [ ! $($sshcmd id -u $wwwuser) ]; then
	    $sshcmd sudo useradd -M $wwwuser    
	fi
	# cligen
	$sshcmd sudo apt install -y bison flex make
	# clixon utilities
	$sshcmd sudo apt install -y libcurl4-openssl-dev
	$sshcmd sudo apt install -y g++
	# restconf
	case ${with_restconf} in
	    fcgi)
		buildfcgi=true # some ubuntu dont have fcgi-dev
		$sshcmd sudo apt install -y nginx
		;;
	    native)
#		$sshcmd sudo apt install -y libevent-2.1
		$sshcmd sudo apt install -y libssl-dev
		$sshcmd sudo apt install -y libevent-dev # evhtp
		$sshcmd sudo apt install -y libnghttp2-dev # nghttp2
		;;
	esac
	;;
    alpine)
	if [ ! $($sshcmd id -u $wwwuser) ]; then
            $sshcmd sudo adduser -D -H $wwwuser
	fi
	$sshcmd sudo apk add --update git make build-base gcc flex bison curl-dev g++
	# restconf
	case ${with_restconf} in
	    fcgi)
		$sshcmd sudo apk add --update nginx fcgi-dev
		;;
	    native)
		;;
	esac
	;;
    arch)
	$sshcmd sudo useradd -M $wwwuser    
	useradd -m -G additional_groups -s login_shell username
	$sshcmd sudo pacman -Syu --noconfirm git
	# cligen
	$sshcmd sudo pacman -Syu --noconfirm bison flex make
	# restconf
	case ${with_restconf} in
	    fcgi)
		$sshcmd	sudo pacman -Syu --noconfirm nginx fcgi
		;;
	    native)
		$sshcmd	sudo pacman -Syu --noconfirm libevent
		;;
	esac
	;;
    *)
	echo "Unknown release: $release"
	;;
esac

# Some platforms dont have fcgi, build the source (should all?)
if $buildfcgi; then
    test -d $dir/fcgi2 || (cd $dir;git clone https://github.com/FastCGI-Archives/fcgi2)
    (cd $dir/fcgi2; ./autogen.sh; rm -rf .git)
    $scpcmd -r $dir/fcgi2 vagrant@127.0.0.1:
    $sshcmd "(cd fcgi2; ./configure --prefix=/usr; make; sudo make install)"
fi

case ${with_restconf} in
    fcgi)
	# Hide all complex nginx config in sub-script
	. ./nginx.sh $dir $idfile $port $wwwuser
	;;
    native)
	$sshcmd << EOF
        test -d src || mkdir src
        cd src
	test -d clixon-libevhtp || git clone https://github.com/clicon/clixon-libevhtp.git
	cd clixon-libevhtp; 
	./configure --libdir=/usr/lib # otherwise in /usr/local/lib where RH dont look
        make
	sudo make install
EOF
	;;
esac

# Setup cligen and clixon
$scpcmd ./clixon.sh vagrant@127.0.0.1:
$sshcmd ./clixon.sh $release $wwwuser ${with_restconf}

# Run tests
$sshcmd "(cd src/cligen/test; ./sum.sh)"
$sshcmd "(cd src/clixon/test; ./sum.sh)"

# destroy vm
#if $destroy; then
#    (cd $dir; vagrant destroy -f)
#fi
