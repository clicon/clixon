# Clixon base development docker image

This directory contains code for building a clixon base development
docker container that can be used as a stage 1 builder for clixon appplications

This clixon base container uses native http.

The clixon docker base image can be used to build clixon
applications. It has the whole code for a clixon release which it
downloads from git.

## Build

Perform the build by `make docker`. This copies the latest _committed_ clixon code into the container.

## Push

You may also do `make push` if you want to push the image, but you may then consider changing the image name (in the makefile:s).

(You may have to login for push with sudo docker login -u <username>)

