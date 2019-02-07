# Clixon base docker image

This directory contains code for building and pushing the clixon base docker
container. By default it is pushed to olofhagsand/clixon, but you can change
the IMAGE in Makefile.in and push it to another name.

There are also sub-directories with examples og other clixon example systems.

The clixon docker image is a base image that can be used to build
clixon applications. It has all the whole code for a clixon release
which it downloads from git - it does not use local code (note it may even use develop branch).

See [system/README.md] for how to build the clixon example application using the base image.

## Build and push

Perform the build by 'make docker'. 
You may also do 'make push' if you want to push the image, but you may then consider changing the image name (in the makefile:s).

You may run the container directly by going directly to example and
the docker runtime scripts there

(You may have to login for push with sudo docker login -u <username>)

