# Clixon example test container

This directory show how to build a "monolithic" clixon docker
container exporting port 80 and contains the example application with
both restconf, netconf, cli and backend. It also includes packages to be able to run the [Clixon tests](../../test).

The directory contains the following files:
	 cleanup.sh     kill containers
	 Dockerfile     Docker build instructions
	 Makefile.in    "make docker" builds the container
	 README.md	This file
	 start.sh       Start containers
	 startsystem.sh Internal start script copied to inside the container (dont run from shell)

How to build and start the container (called clixon-system):
```
  $ make docker
  $ ./start.sh 
```

The start.sh has a number of environment variables to alter the default behaviour:
* PORT - Nginx exposes port 80 per default. Set `PORT=8080` for example to access restconf using 8080.
* DBG - Set debug. The clixon_backend will be shown on docker logs.
* CONFIG - Set XML configuration file other than the default example.
* STORE - Set running datastore content to other than default.

Example:
```
  $ DBG=1 PORT=8080 ./start.sh
```

Once running you can access it in different ways as follows:
As CLI:
```
  $ sudo docker exec -it clixon-system clixon_cli
```
As netconf via stdin/stdout:
```
  $ sudo docker exec -it clixon-system clixon_netconf
```
As restconf using curl on exposed port 80:
```
  $ curl -G http://localhost/restconf
```
Or run tests:
```
  $ sudo docker exec -it clixon-system bash -c 'cd /usr/local/bin/test && ./all.sh'
```

To check status and then kill it:
```
  $ sudo docker ps --all
  $ ./cleanup.sh 
```

You trigger the test scripts inside the container using `make test`.

## Changing code

If you want to edit clixon code so it runs in the container?
You either
(1) "persistent": make your changes in the actual clixon code and commit; make clean to remove the local clone;  make test again
(2) "volatile" edit the local clone; make test.