# Clixon main example

  * [Background](#background)
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
  

## Background

The aim of the main clixon example is to illustrate common features
and for internal testing.  See the simpler [hello world](https://github.com/clicon/clixon-examples/tree/master/hello) if you want to start from the simplest possible example.

See also other examples in: [clixon-examples](https://github.com/clicon/clixon-examples).

## Content

This directory contains a Clixon example used primarily as a part of the Clixon test suites. It can be used as a basis for making new Clixon applications.  It contains the following files:
* `clixon-example@2020-12-20.yang`      The yang spec of the example.
* `example_backend.c`      Backend callback plugin including example of:
* `example_backend_nacm.c` Secondary backend plugin. Plugins are loaded alphabetically.
* `example_cli.c`          CLI callback plugin containing functions called in the .cli file
* `example_cli.cli`        CLIgen specification of example CLI commands
* `example_netconf.c`      Netconf callback plugin
* `example_restconf.c`     Restconf callback plugin containing HTTP basic authentication
* `example.xml`            Main configuration file.
* `Makefile.in`            Example makefile where plugins are built and installed

See [yang/clixon-config@<date>.yang](https://github.com/clicon/clixon/blob/master/yang/clixon/clixon-config%402021-05-20.yang) for documentation of all available fields in `example.xml`.

## Compile and run

Before you start,
* You must configure with: `--enable-optyangs` to install all yang files required for the example. This is not necessary for the base colixon system
* Setup clicon [groups](https://github.com/clicon/clixon/blob/master/doc/FAQ.md#do-i-need-to-setup-anything)

```
    cd example/main
    make && sudo make install
```

Start backend:
```
    sudo clixon_backend -f /usr/local/etc/example.xml -s init
```
Start cli:
```
    clixon_cli -f /usr/local/etc/example.xml
```
Send netconf command:
```
    clixon_netconf -f /usr/local/etc/example.xml
```
Start clixon restconf daemon (default config listens on http IPv4 0.0.0.0 on port 8080):
```
    sudo clixon_restconf -f /usr/local/etc/example.xml
```
Send restconf command
```
    curl -X GET http://127.0.0.1:8080/restconf/data
```

## Using the CLI

The example CLI allows you to modify and view the data model using `set`, `delete` and `show` via generated code.
There are also many other commands available as examples. View the source file (example_cli.cli)[example_cli.cli] for more details.

The following example shows how to add an interface in candidate, validate and commit it to running, then look at it (as xml) and finally delete it.
```
clixon_cli -f /usr/local/etc/example.xml 
cli> set interfaces interface eth1 ?
  <cr>
  description           A textual description of the interface.
  enabled               This leaf contains the configured, desired state of the
                        interface.
  ipv4                  Parameters for the IPv4 address family.
  ipv6                  Parameters for the IPv6 address family.
  type                  The type of the interface.
cli> set interfaces interface eth1 type ianaift:ip
cli> set interfaces interface eth1 enabled true
cli> set interfaces interface eth1 ipv4 address 1.2.3.4 prefix-length 24
cli> validate 
cli> commit 
cli> show configuration xml 
<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
   <interface>
      <name>eth1</name>
      <type>ianaift:ip</type>
      <enabled>true</enabled>
      <ip:ipv4 xmlns:ip="urn:ietf:params:xml:ns:yang:ietf-ip">
         <ip:enabled>true</ip:enabled>
         <ip:forwarding>false</ip:forwarding>
         <ip:address>
            <ip:ip>1.2.3.4</ip:ip>
            <ip:prefix-length>24</ip:prefix-length>
         </ip:address>
      </ip:ipv4>
   </interface>
</interfaces>
cli> delete interfaces interface eth1
cli> commit
```

## Using Netconf

The following example shows how to set data using netconf:
```
sh> clixon_netconf -qf /usr/local/etc/example.xml
<?xml version="1.0" encoding="UTF-8"?>
<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="0">
   <edit-config>
      <target><candidate/></target>
      <config>
         <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
            <interface>
               <name>eth1</name>
	       <type>ianaift:ip</type>
               <enabled>true</enabled>
               <ipv4 xmlns="urn:ietf:params:xml:ns:yang:ietf-ip">
                  <address>
                     <ip>1.2.3.4</ip>
                     <prefix-length>24</prefix-length>
                  </address>
               </ipv4>
            </interface>
         </interfaces>
      </config>
   </edit-config>
</rpc>]]>]]>
# Reply: <rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="0"><ok/></rpc-reply>]]>]]>
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1">
   <commit/>
</rpc>]]>]]>
```

Getting data:
```
# Reply: <rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1"><ok/></rpc-reply>]]>]]>
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="2">
   <get-config>
      <source><candidate/></source>
   </get-config>
</rpc>]]>]]>
# Reply: <rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="2"><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth1</name><type>ianaift:ip</type><enabled>true</enabled><ip:ipv4 xmlns:ip="urn:ietf:params:xml:ns:yang:ietf-ip"><ip:enabled>true</ip:enabled><ip:forwarding>false</ip:forwarding><ip:address><ip:ip>1.2.3.4</ip:ip><ip:prefix-length>24</ip:prefix-length></ip:address></ip:ipv4></interface></interfaces></data></rpc-reply>]]>]]>
```

Examples of a filtered GET statement:
```
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1"><get-config><source><candidate/></source><filter type="xpath" select="/if:interfaces/if:interface[if:name='eth1']" xmlns:if="urn:ietf:params:xml:ns:yang:ietf-interfaces"/></get-config></rpc>]]>]]>
```

## Restconf 

By default clixon from release 5.3 uses "native" restconf, see next
section for an alternative. General clixon [restconf
documentation](https://clixon-docs.readthedocs.io/en/latest/restconf.html). By
default restconf supports http/1.1 and http/2 with the standard way
(ALPN vs switch protocol) of selecting and upgrading from 1.1 to 2.

In the example, a restconf config is included in the [config file](example.xml):
```
  <restconf>
     <enable>true</enable>
     <auth-type>none</auth-type>
     <socket>
        <namespace>default</namespace>
	<address>0.0.0.0</address>
	<port>80</port>
	<ssl>false</ssl>
     </socket>
  </restconf>
```

In this example, a listening socket is opened using http on port 80. You can extend the restconf config by modifying the entry or add multiple `<socket>` entries, such as IPv6, TLS and another network namespace, for example:
```
   <socket>
      <namespace>dataplane</namespace>
      <address>::</address>
      <port>443</port>
      <ssl>true</ssl>
   </socket>
```

For TLS, cert files need to be given, such as follows:
```
<restconf>
   ...
   <server-cert-path>/path/to/server/cert</server-cert-path>
   <server-key-path>/path/to/server/key</server-key-path>
   <server-ca-cert-path>/path/to/ca/cert</server-ca-cert-path>
```

For more info, such as client-certs, authentication, etc, see: [restconf documentation](https://clixon-docs.readthedocs.io/en/latest/restconf.html)

## Restconf using nginx

Alternatively, restconf can use a reverse-proxy such as nginx.

Configure:
```
  ./configure --with-restconf=fcgi
```

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
   sudo /usr/local/sbin/clixon_restconf -f /usr/local/etc/example.xml
```
then access using curl or wget:
```
   curl -X GET http://127.0.0.1/restconf/data/ietf-interfaces:interfaces/interface=eth1/type
```

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
sudo /usr/local/sbin/clixon_restconf -f /usr/local/etc/example.xml
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

Example systemd files for backend and restconf daemons are found under the [systemd](systemd) directory. Install them under /etc/systemd/system for example.

## Docker

See [clixon docker main example](../../docker/main) for instructions on how to build this example as a docker container.

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
