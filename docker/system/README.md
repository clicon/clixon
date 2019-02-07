# Clixon example container

This directory show how to build a "monolithic" clixon docker
container containing the example application with both restconf,
netconf, cli and backend.
The directory contains the following files:
	 cleanup.sh     kill containers
	 Dockerfile     Docker build instructions
	 lib.sh         script library functions
	 Makefile.in    "make docker" builds the container
	 README.md	This file
	 start.sh       Start containers
	 startsystem.sh Internal start script copied to inside the container
	 stat.sh        Shows container status

How to build and start the container:
```
  $ make docker
  $ ./start.sh 
```

Once running you can access it as follows:
* CLI: `sudo docker exec -it ef62ccfe1782 clixon_cli`
* Netconf: `sudo docker exec -it ef62ccfe1782 clixon_netconf`
* Restconf: `curl -G http://localhost/restconf`

To check status and then kill it:
```
  $ ./stat.sh
  $ ./cleanup.sh 
```