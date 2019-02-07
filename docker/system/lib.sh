#!/bin/sh
# Lib functions like err(), stat() and others

# Error function
# usage: err $msg
err(){
    echo  "\e[31m\n[Error $1]"
    echo  "\e[0m"
    exit 1
}

#json field XXX notused?
jf(){
  sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep key | awk -F : '{gsub(/"/,"",$3); print $3}'
}

# Status function
# usage: stat $name
stat(){
    name=$1
    ps=$(sudo docker ps -f ancestor=$name|tail -n +2|grep $name|awk '{print $1}')
    if [ -n "$ps" ]; then
	ip=$(sudo docker inspect -f '{{.NetworkSettings.IPAddress }}' $ps)
	echo "$name \t$ps $ip"
    else
	err "$name failed"
    fi
}

# Kill function
kill1(){
    name=$1
    ps=$(sudo docker ps -f ancestor=$name|tail -n +2|grep $name|awk '{print $1}')
    if [ -n "$ps" ]; then
	echo -n "$name\t" && sudo docker kill $ps
    fi
}

