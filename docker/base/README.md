# Clixon base docker image

This directory contains code for building and pushing the clixon base docker
container. By default it is pushed to docker hub clixon/clixon, but you can change
the IMAGE in Makefile.in and push it to another name.

This clixon base container uses libevhtp, native http.

The clixon docker base image can be used to build clixon
applications. It has the whole code for a clixon release which it
downloads from git.

See [clixon-system](../main/README.md) for a more complete clixon image.

## Build and push

Perform the build by `make docker`. This copies the latest _committed_ clixon code into the container.

You may also do `make push` if you want to push the image, but you may then consider changing the image name (in the makefile:s).

(You may have to login for push with sudo docker login -u <username>)

