# Clixon main example docker image

This directory contains code for building a clixon main example docker container.

This clixon example container uses native http.

## Build

Perform the build by:
```
  $ make docker
```
This copies the latest _committed_ clixon code into the container.

## Start

Start the container:
```
  $ ./start.sh 
```

If you want to install your pre-existing pub rsa key in the container, and change the name:

```
  $ SSHKEY=/home/user/.ssh/id_rsa.pub NAME=clixon-example22 ./start.sh 
```

You can combine make and start by:
```
  $ make start
```

## Run

The CLI directly
```
  $ sudo docker exec -it clixon-example clixon_cli
```

The CLI via ssh (if keys setup correctly) where 172.x.x.x is the addresss of eth0
```
  $ ssh -t root@172.x.x.x clixon_cli
```

Netconf via ssh:
```
  $ ssh root@172.x.x.x -s netconf
```

## Push

You may also do `make push` if you want to push the image, but you may then consider changing the image name (in the makefile:s).

(You may have to login for push with sudo docker login -u <username>)

## Other YANGs

You can add other YANGs for experimentation by:
```
  $ sudo docker cp myyangs.tgz clixon-example:/usr/local/share/clixon/example
```
then untar it an restart the backend
