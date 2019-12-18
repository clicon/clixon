# Clixon hello world example

  * [Content](#content)
  * [Compile and run](#compile)
  * [Using the CLI](#using-the-cli)
  * [Netconf](#netconf)	
  * [Restconf](#restconf)
  * [Next steps](#next-steps)
  
## Content

This directory contains a Clixon example which includes a simple example. It contains the following files:
* `hello.xml`       The configuration file. See [yang/clixon-config@<date>.yang](../../yang/clixon-config@2019-03-05.yang) for the documentation of all available fields.
* `clixon-hello@2019-04-17.yang` The yang spec of the example.
* `hello_cli.cli`                CLIgen specification.
* `Makefile.in`                  Example makefile where plugins are built and installed
* `README.md`                    This file


## Compile and run

Before you start,
* Make [group setup](../../doc/FAQ.md#do-i-need-to-setup-anything-important)

```
    make && sudo make install
```
Start backend in the background:
```
    sudo clixon_backend
```
Start cli:
```
    clixon_cli
```

## Using the CLI

The example CLI allows you to modify and view the data model using `set`, `delete` and `show` via generated code.

The following example shows how to add a very simple configuration `hello world` using the generated CLI. The config is added to the candidate database, shown, committed to running, and then deleted.
```
   olof@vandal> clixon_cli
   cli> set <?>
     hello                 
   cli> set hello world 
   cli> show configuration 
   hello world;
   cli> commit 
   cli> delete <?>
     all                   Delete whole candidate configuration
     hello                 
   cli> delete hello 
   cli> show configuration 
   cli> commit 
   cli> quit
   olof@vandal> 
```

## Netconf

Clixon also provides a Netconf interface. The following example starts a netconf client form the shell, adds the hello world config, commits it, and shows it:
```
   olof@vandal> clixon_netconf -q
   <rpc><edit-config><target><candidate/></target><config><hello xmlns="urn:example:hello"><world/></hello></config></edit-config></rpc>]]>]]>
   <rpc-reply><ok/></rpc-reply>]]>]]>
   <rpc><commit/></rpc>]]>]]>
   <rpc-reply><ok/></rpc-reply>]]>]]>
   <rpc><get-config><source><running/></source></get-config></rpc>]]>]]>
   <rpc-reply><data><hello xmlns="urn:example:hello"><world/></hello></data></rpc-reply>]]>]]>
olof@vandal> 
```

## Restconf

Clixon also provides a Restconf interface. A reverse proxy needs to be configured. There are [instructions how to setup Nginx](../../doc/FAQ.md#how-do-i-use-restconf) for Clixon.

Start restconf daemon
```
   sudo su -c "/www-data/clixon_restconf" -s /bin/sh www-data &
```

Start sending restconf commands (using Curl):
```
   olof@vandal> curl -X POST http://localhost/restconf/data -H "Content-Type: application/yang-data+json" -d '{"clixon-hello:hello":{"world":null}}'
   olof@vandal> curl -X GET http://localhost/restconf/data 
   {
     "data": {
       "clixon-hello:hello": {
         "world": null
       }
     }
   }
```

## Next steps

The hello world example only has a Yang spec and a template CLI
spec. For more advanced applications, customized backend, cli, netconf
and restconf code callbacks becomes necessary.

Further, you may want to add upgrade, RPC:s, state data, notification
streams, authentication and authorization. The [main example](../main)
contains examples for such capabilities.

There are also [container examples](../../docker) and lots more.





