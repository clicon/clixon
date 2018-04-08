# Clixon example

This directory contains a Clixon example which includes a simple
routing example. It contains the following files:
* example.xml       The configuration file. See yang/clixon-config@<date>.yang for all available fields.
* example.yang      The yang spec of the example. It mainly includes ietf routing and IP modules.
* example_cli.cli   CLIgen specification.
* example_cli.c     CLI callback plugin containing functions called in the cli file above: a generic callback (`mycallback`) and an RPC (`fib_route_rpc`).
* example_backend.c Backend callback plugin including example of:
  * transaction callbacks (validate/commit),
  * notification,
  * rpc handler
  * state-data handler, ie non-config data
* example_backend_secondary.c Secondary backend plugin. Plugins are loaded alphabetically.
* example_restconf.c Restconf callback plugin containing an HTTP basic authentication callback
* example_netconf.c Netconf callback plugin
* Makefile.in       Example makefile where plugins are built and installed

## Compile and run
```
    cd example
    make && sudo make install
```
Start backend:
```
    clixon_backend -f /usr/local/etc/example.xml -I
```
Edit cli:
```
    clixon_cli -f /usr/local/etc/example.xml
```
Send netconf command:
```
    clixon_netconf -f /usr/local/etc/example.xml
```
Start clixon restconf daemon
```
> sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/example.xml " -s /bin/sh www-data
```
Send restconf command
```
    curl -G http://127.0.0.1/restconf/data
```

## Setting data example using netconf
```
<rpc><edit-config><target><candidate/></target><config>
      <interfaces>
         <interface>
            <name>eth1</name>
            <enabled>true</enabled>
            <ipv4>
               <address>
                  <ip>9.2.3.4</ip>
                  <prefix-length>24</prefix-length>
               </address>
            </ipv4>
         </interface>
      </interfaces>
</config></edit-config></rpc>]]>]]>
```

## Getting data using netconf
```
<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter/></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="xpath"/></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="subtree"><configuration><interfaces><interface><ipv4/></interface></interfaces></configuration></filter></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface/ipv4"/></get-config></rpc>]]>]]>
<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>
```

## Creating notification

The example has an example notification triggering every 10s. To start a notification 
stream in the session, create a subscription:
```
<rpc><create-subscription><stream>ROUTING</stream></create-subscription></rpc>]]>]]>
<rpc-reply><ok/></rpc-reply>]]>]]>
<notification><event>Routing notification</event></notification>]]>]]>
<notification><event>Routing notification</event></notification>]]>]]>
...
```
This can also be triggered via the CLI:
```
cli> notify 
cli> Routing notification
Routing notification
...
```

## Initializing a plugin

The example includes a restonf, netconf, CLI and two backend plugins.
Each plugin is initiated with an API struct followed by a plugin init function.
The content of the API struct is different depending on what kind of plugin it is. Some fields are
meaningful only for some plugins.
The plugin init function may also include registering RPC functions.
```
static clixon_plugin_api api = {
    "example",          /* name */
    clixon_plugin_init, 
    plugin_start,       
    plugin_exit,        
    NULL,               /* cli prompt N/A for backend */
    NULL,               /* cli suspend N/A for backend */
    NULL,               /* cli interrupt N/A for backend */
    NULL,               /* auth N/A for backend */
    plugin_reset,       
    plugin_statedata,   
    transaction_begin,  
    transaction_validate,
    transaction_complete,
    transaction_commit,
    transaction_end,  
    transaction_abort
};

clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    /* Optional callback registration for RPC calls */
    rpc_callback_register(h, fib_route, NULL, "fib-route");
    /* Return plugin API */
    return &api; /* Return NULL on error */
}
```

## Operation data

Clixon implements Yang RPC operations by an extension mechanism. The
extension mechanism enables you to add application-specific
operations. It works by adding user-defined callbacks for added
netconf operations. It is possible to use the extension mechanism
independent of the yang rpc construct, but it is recommended. The example includes an example:

Example:
```
cli> rpc ipv4
<rpc-reply>
   <ok/>
</rpc-reply>
```

The example works by creating a netconf rpc call and sending it to the backend: (see the fib_route_rpc() function).
```
  <rpc>
    <fib-route>
      <routing-instance-name>ipv4</routing-instance-name>
    </fib-route>
   </rpc>
```

In the backend, a callback is registered (fib_route()) which handles the RPC.
```
static int 
fib_route(clicon_handle h, 
	  cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	  cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	  void         *arg,          /* Client session */
	  void         *regarg)       /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply><ok/></rpc-reply>");    
    return 0;
}
int
clixon_plugin_init(clicon_handle h)
{
...
   rpc_callback_register(h, fib_route, NULL, "fib-route");
...
}
```
## State data

Netconf <get> and restconf GET also returns state data, in contrast to
config data. 
p
In YANG state data is specified with "config false;". In the example, interface-state is state data.

To return state data, you need to write a backend state data callback
with the name "plugin_statedata" where you return an XML tree with
state. This is then merged with config data by the system.

A static example of returning state data is in the example. Note that
a real example would poll or get the interface counters via a system
call, as well as use the "xpath" argument to identify the requested
state data.


## Run as docker container
```
cd docker
# look in README
```



