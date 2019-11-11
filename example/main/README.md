# Clixon main example

  * [Content](#content)
  * [Compile and run](#compile)
  * [Using the CLI](#using-the-cli)
  * [Using netconf](#using-netconf)
  * [Streams](#streams)
  * [RPC Operations](#rpc-operations)
  * [State data](#state-data)
  * [Extensions](#extension)
  * [Authentication and NACM](#authentication-and-nacm)
  * [Systemd](#systemd)
  * [Docker](#docker)
  * [Plugins](#plugins)
  
## Content

This directory contains a Clixon example used primarily for testing. It can be used as a basis for making new Clixon applications. But please consider also the minimal [hello](../hello) example as well. It contains the following files:
* `example.xml`       The configuration file. See [yang/clixon-config@<date>.yang](../../yang/clixon-config@2019-03-05.yang) for the documentation of all available fields.
* `clixon-example@2019-01-13.yang`      The yang spec of the example.
* `example_cli.cli`   CLIgen specification.
* `example_cli.c`     CLI callback plugin containing functions called in the cli file above: a generic callback (`mycallback`) and an example RPC call (`example_client_rpc`).
* `example_backend.c` Backend callback plugin including example of:
  * transaction callbacks (validate/commit),
  * notification,
  * rpc handler
  * state-data handler, ie non-config data
* `example_backend_nacm.c` Secondary backend plugin. Plugins are loaded alphabetically.
* `example_restconf.c` Restconf callback plugin containing an HTTP basic authentication callback
* `example_netconf.c` Netconf callback plugin
* `Makefile.in`       Example makefile where plugins are built and installed


## Compile and run

Before you start,
* Make [group setup](../../doc/FAQ.md#do-i-need-to-setup-anything-important)
* Setup [restconf](../../doc/FAQ.md#how-do-i-use-restconf)

```
    cd example
    make && sudo make install
```
Start backend:
```
    sudo clixon_backend -f /usr/local/etc/example.xml -s init
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
    sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/example.xml " -s /bin/sh www-data
```
Send restconf command
```
    curl -G http://127.0.0.1/restconf/data
```

## Using the CLI

The example CLI allows you to modify and view the data model using `set`, `delete` and `show` via generated code.
There are also many other commands available as examples. View the source file (example_cli.cli)[example_cli.cli] for more details.

The following example shows how to add an interface in candidate, validate and commit it to running, then look at it (as xml) and finally delete it.
```
clixon_cli -f /usr/local/etc/example.xml 
cli> set interfaces interface eth9 ?
 description               enabled                   ipv4                     
 ipv6                      link-up-down-trap-enable  type                     
cli> set interfaces interface eth9 type ex:eth
cli> validate 
cli> commit 
cli> show configuration xml 
<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
   <interface>
      <name>eth9</name>
      <type>ex:eth</type>
      <enabled>true</enabled>
   </interface>
</interfaces>
cli> delete interfaces interface eth9
```

## Using Netconf

The following example shows how to set data using netconf:
```
<rpc><edit-config><target><candidate/></target><config>
      <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
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

### Getting data using netconf
```
<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter/></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="xpath"/></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="subtree"><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth9</name><type>ex:eth</type></interface></interfaces></data></filter></get-config></rpc>]]>]]>
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface"/></get-config></rpc>]]>]]>
<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>
```
## Restconf

Setup a web/reverse-proxy server.
For example, using nginx, install, and edit config file: /etc/nginx/sites-available/default:
```
server {
        ...
	location / {
	    root /usr/share/nginx/html/restconf;
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
        }
	location /restconf {
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
        }
	location /streams {
	    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
	    include fastcgi_params;
 	    proxy_http_version 1.1;
	    proxy_set_header Connection "";
        }
}
```
Start nginx daemon
```
   sudo /etc/init.d/nginx start
   sudo systemctl start nginx.service # alternative using systemd
```
Start the clixon restconf daemon
```
   sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/example.xml " -s /bin/sh www-data
```
then access using curl or wget:
```
   curl -X GET http://127.0.0.1/restconf/data/ietf-interfaces:interfaces/interface=eth1/type
```

More info: (restconf)[../../apps/restconf/README.md].

## Streams

The example has an EXAMPLE stream notification triggering every 5s. To start a notification 
stream in the session using netconf, create a subscription:
```
<rpc><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"><stream>EXAMPLE</stream></create-subscription></rpc>]]>]]>
<rpc-reply><ok/></rpc-reply>]]>]]>
<notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>2019-01-02T10:20:05.929272</eventTime><event><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event></notification>]]>]]>
...
```
This can also be triggered via the CLI:
```
clixon_cli -f /usr/local/etc/example.xml
cli> notify
cli> event-class fault;
reportingEntity {
    card Ethernet0;
}
severity major;
...
cli> no notify
cli>
```

Restconf support is also supported, see (restconf)[../../apps/restconf/README.md].


## RPC Operations

Clixon implements Yang RPC operations by a mechanism that enables you
to add application-specific operations.  It works by adding
user-defined callbacks for added netconf operations. It is possible to
use the extension mechanism independent of the yang rpc construct, but
not recommended . The example includes an example:

Example using CLI:
```
clixon_cli -f /usr/local/etc/example.xml
cli> rpc ipv4
<rpc-reply><x xmlns="urn:example:clixon">ipv4</x><y xmlns="urn:example:clixon">42</y></rpc-reply>
```
Example using Netconf:
```
clixon_netconf -qf /usr/local/etc/example.xml
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><example xmlns="urn:example:clixon"><x>ipv4</x></example></rpc>]]>]]>
<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><x xmlns="urn:example:clixon">ipv4</x><y xmlns="urn:example:clixon">42</y></rpc-reply>]]>]]>
```
Restconf (assuming nginx started):
```
sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/example.xml " -s /bin/sh www-data&
curl -X POST  http://localhost/restconf/operations/clixon-example:example -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":"ipv4"}}'
{
  "clixon-example:output": {
    "x": "ipv4",
    "y": "42"
  }
}
```

### Details

The example works by defining an RPC in clixon-example.yang:
```
    rpc example {
	description "Some example input/output for testing RFC7950 7.14.
                     RPC simply echoes the input for debugging.";
    	input {
	    leaf x {
        ...
```

In the CLI a netconf rpc call is constructed and sent to the backend: See `example_client_rpc()` in [example_cli.c] CLI plugin.

The clixon backend  plugin [example_backend.c] reveives the netconf call and replies. This is made byregistering a callback handling handling the RPC:
```
static int 
example_rpc(clicon_handle h, 
	    cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	    cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	    void         *arg,          /* Client session */
	    void         *regarg)       /* Argument given at register */
{
    /* code that echoes the request */
    return 0;
}
int
clixon_plugin_init(clicon_handle h)
{
...
   rpc_callback_register(h, example_rpc, NULL, "example");
...
}
```

## State data

Netconf <get> and restconf GET also returns state data(not only configuration data).

In YANG state data is specified with `config false;`. In the example,
`state` is state data, see (example.yang)[example.yang]

To return state data, you need to write a backend state data callback
with the name "plugin_statedata" where you return an XML tree with
state. This is then merged with config data by the system.

A static example of returning state data is in the example. Note that
a real example would poll or get the interface counters via a system
call, as well as use the "xpath" argument to identify the requested
state data.

The state data is enabled by starting the backend with: `-- -s`.

## Authentication and NACM
The example contains some stubs for authorization according to [RFC8341(NACM)](https://tools.ietf.org/html/rfc8341):
* A basic auth HTTP callback, see: example_restconf_credentials() containing three example users: andy, wilma, and guest, according to the examples in Appendix A in [RFC8341](https://tools.ietf.org/html/rfc8341).
* A NACM backend plugin reporting the mandatory NACM state variables.

## Extensions

Clixon supports Yang extensions by writing plugin callback code.
The example backend implements an "example:e4" Yang extension, as follows:
```
    extension e4 {
       description
	   "The first child of the ex:e4 (unknown) statement is inserted into 
	    the module as a regular data statement. This means that 'uses bar;'
	    in the ex:e4 statement below is a valid data node";
       argument arg;
    }
    ex:e4 arg1{
      uses bar;
    }
```

The backend plugin code registers an extension callback in the init struct:
```
    .ca_extension=example_extension,        /* yang extensions */
```

The callback then receives a callback on all "unknown" Yang statements
during yang parsing. If the extension matches "example:e4", it applies
the extension. In the example, it copies the child of the "ex:e4" statement and
inserts in as a proper yang statement in the example module.

## Systemd

Example systemd files for backend and restconf daemons are found under the systemd directory. Install them under /etc/systemd/system for example.

## Docker

See [../../docker/system] for instructions on how to build this example
as a docker container.

## Plugins

The example includes a restonf, netconf, CLI and two backend plugins.
Each plugin is initiated with an API struct followed by a plugin init function.
The content of the API struct is different depending on what kind of plugin it is.
The plugin init function may also include registering RPC functions, see below is for a backend.
```
static clixon_plugin_api api = {
    "example",          /* name */
    clixon_plugin_init, 
    plugin_start,       
    plugin_exit,        
    .ca_reset=plugin_reset,/* reset for extra XML at startup*/          
    .ca_statedata=plugin_statedata, /* statedata */
    .ca_upgrade=example_upgrade,            /* upgrade configuration */
    .ca_trans_begin=NULL, /* trans begin */
    .ca_trans_validate=transaction_validate,/* trans validate */
    .ca_trans_complete=NULL,                /* trans complete */
    .ca_trans_commit=transaction_commit,    /* trans commit */
    .ca_trans_end=NULL,                     /* trans end */
    .ca_trans_abort=NULL                    /* trans abort */
};

clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    /* Optional callback registration for RPC calls */
    rpc_callback_register(h, example_rpc, NULL, "example");
    /* Return plugin API */
    return &api; /* Return NULL on error */
}
```

Here is a corresponding example for a CLI plugin:
```
static clixon_plugin_api api = {
    "example",          /* name */
    clixon_plugin_init, /* init */
    NULL,               /* start */
    NULL,               /* exit */
    .ca_prompt=NULL,    /* cli_prompthook_t */
    .ca_suspend=NULL,   /* cligen_susp_cb_t */
    .ca_interrupt=NULL, /* cligen_interrupt_cb_t */
};
```
