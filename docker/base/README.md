# Clixon base docker image

This directory contains code for building and pushing the clixon base docker
container. By default it is pushed to docker hub clixon/clixon, but you can change
the IMAGE in Makefile.in and push it to another name.

The clixon docker base image can be used to build clixon
applications. It has all the whole code for a clixon release which it
downloads from git.

See [clixon-system](../system/README.md) for a more complete clixon image.

## Build and push

Perform the build by `make docker`. 
You may also do `make push` if you want to push the image, but you may then consider changing the image name (in the makefile:s).

You may run the container directly by going directly to example and
the docker runtime scripts there

(You may have to login for push with sudo docker login -u <username>)

## Example run

The following shows a simple example of how to run the example
application. First,the container is started, then the backend is startend in the background inside the container, and finally the CLI is started in the foreground.

```
  $ sudo docker run --name clixon --rm -td clixon/clixon
  $ sudo docker exec -it clixon clixon_backend -s init -f /usr/local/etc/example.xml
  $ sudo docker exec -it clixon clixon_cli -f /usr/local/etc/example.xml
  > set interfaces interface e
  > show configuration 
  interfaces {
    interface {
        name e;
        enabled true;
    }
  }
  > q
  $ sudo docker kill clixon
```

Note that this is a special case since the example is
already a part of the installation. If you want to add your own
application, such as plugins, cli syntax files, yang models, etc, you
need to extend the base container with your own additions.
