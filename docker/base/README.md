# Clixon base docker image

This directory contains code for building and pushing the clixon base docker
container. By default it is pushed to docker hub clixon/clixon, but you can change
the IMAGE in Makefile.in and push it to another name.

The clixon docker base image can be used to build clixon
applications. It has all the whole code for a clixon release which it
downloads from git.

See [clixon-system](../main/README.md) for a more complete clixon image.

## Build and push

Perform the build by `make docker`. This copies the latest _committed_ clixon code into the container.

You may also do `make push` if you want to push the image, but you may then consider changing the image name (in the makefile:s).

(You may have to login for push with sudo docker login -u <username>)

## Example run

The base container is a minimal and primitive example. Look at the [clixon-system](../main) for a more stream-lined application.

The following shows a simple example of how to run the example
application. First, the container is started with the backend running:
```
  $ sudo docker run --rm --name clixon-base -d clixon/clixon clixon_backend -Fs init
```
Then a CLI is started, and finally the container is removed:
```
  $ sudo docker exec -it clixon-base clixon_cli 
  > set interfaces interface e
  > show configuration 
  interfaces {
    interface {
        name e;
        enabled true;
    }
  }
  > q
  $ sudo docker kill clixon-base
```

Note that the clixon example application is a special case since the example is
already a part of the installation. If you want to add your own
application, such as plugins, cli syntax files, yang models, etc, you
need to extend the base container with your own additions.
