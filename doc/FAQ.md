# Clixon FAQ

This FAQ may be outdated. Main [Clixon documentation](clixon-docs.readthedocs.io/) contains more detailed information.

  * [What is Clixon?](#what-is-clixon)
  * [Why should I use Clixon?](#why-should-i-use-clixon)
  * [What license is available?](#what-license-is-available)
  * [Is Clixon extendible?](#is-clixon-extendible)
  * [Which programming language is used?](#which-programming-language-is-used)
  * [How to best understand Clixon?](#how-to-best-understand-clixon)
  * [Hello world?](#hello-world)
  * [How do you build and install Clixon (and the example)?](how-do-you-build-and-install-clixon)
  * [How do I run Clixon example commands?](#how-do-i-run-clixon-example-commands)
  * [Do I need to setup anything? (IMPORTANT)](#do-i-need-to-setup-anything))
  * [How do I use the CLI?](#how-do-i-use-the-cli)
  * [How do I use netconf?](#how-do-i-use-netconf)
  * [How do I use restconf?](#how-do-i-use-restconf)
  * [What about reference documentation?](#what-about-reference-documentation)
  * [How is configuration data stored?](#how-is-configuration-data-stored)
  * [What is validate and commit?](#what-is-validate-and-commi)t
  * [Does Clixon support transactions?](#does-clixon-support-transactions)
  * [What is a Clixon configuration file?](#what-is-a-clixon-configuration-file)
  * [How are Clixon configuration files found?](#how-are-clixon-configuration-files-found)
  * [Can I modify clixon options at runtime?](#can-i-modify-clixon-options-at-runtime)
  * [How are Yang files found?](#how-are-yang-files-found)
  * [How do I enable Yang features?](#how-do-i-enable-yang-features)
  * [Can I run Clixon as a container?](#can-i-run-clixon-as-a-container)
  * [Does Clixon support event streams?](#does-clixon-support-event-streams)
  * [How should I start the backend daemon?](#how-should-i-start-the-backend-daemon)
  * [Can I use systemd with Clixon?](#can-i-use-systemd-with-clixon)
  * [How can I add extra XML?](#how-can-i-add-extra-xml)
  * [I want to program. How do I extend the example?](#i-want-to-program-how-do-i-extend-the-example)
  * [How is a plugin initiated?](#how-is-a-plugin-initiated)
  * [How do I write a commit function?](#how-do-i-write-a-commit-function)
  * [How do I check what has changed on commit?](#how-do-i-check-what-has-changed-on-commit)
  * [How do I access the XML tree?](#how-do-i-access-the-xml-tree)
  * [How do I write a CLI callback function?](#how-do-i-write-a-cli-callback-function)
  * [How do I write a validation function?](#how-do-i-write-a-validation-function)
  * [How do I write a state data callback function?](#how-do-i-write-a-state-data-callback-function)
  * [How do I write an RPC function?](#how-do-i-write-an-rpc-function)
  * [I want to add a hook to an existing operation, can I do that?](#i-want-to-add-a-hook-to-an-existing-operation-can-i-do-that)
  * [How do I write an authentication callback?](#how-do-i-write-an-authentication-callback)
  * [What about access control?](#what-about-access-control)
  * [Does Clixon support upgrade?](#does-clixon-support-upgrade)
  * [How do I write a CLI translator function?](#how-do-i-write-a-cli-translator-function)

## What is Clixon?

Clixon is a YANG-based configuration manager, with interactive CLI,
NETCONF and RESTCONF interfaces, an embedded database and transaction
support.

## Why should I use Clixon?

If you want an easy-to-use configuration toolkit based on yang with an
open-source license.  Typically for embedded devices requiring a
config interface such as routers and switches. 

## What license is available?
Clixon is dual license. Either Apache License, Version 2.0 or GNU
General Public License Version 2. 

## Is Clixon extendible?
Yes. All application semantics is defined in plugins with well-defined
APIs. There are currently plugins for: CLI, Netconf,  Restconf, the datastore and the backend.
Clixon also supports Yang extensions, see main example.

## Which programming language is used?
Clixon is written in C. The plugins are written in C. The CLI
specification uses [CLIgen](http://github.com/clicon/cligen)

## How to best understand Clixon?
Run the Clixon main example, in the [example](../example) directory or [examples repo](https://github.com/clicon/clixon-examples), or [main documentation](https://clixon-docs.readthedocs.io)

## Hello world?

One of the examples is [a hello world example](https://github.com/clicon/clixon-examples/tree/master/hello). Please start with that.

## How do you build and install Clixon?
Clixon: 
```
        ./configure
        make; 
        sudo make install; 
```

The main example:
```
         cd example; 
         make; 
         sudo make install
```

## How do I run Clixon example commands?

- Start a backend server: `sudo clixon_backend -s init -f /usr/local/etc/example.xml`
- Start a cli session: `clixon_cli -f /usr/local/etc/example.xml`
- Start a netconf session: `clixon_netconf -f /usr/local/etc/example.xml`
- Start a restconf daemon: `sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/example.xml " -s /bin/sh www-data`
- Send a restconf command: `curl -X GET http://127.0.0.1/restconf/data`

More info in the [example](../example) directory.

## Do I need to setup anything?

The config demon requires a valid group to create a server UNIX domain socket.
Define a valid CLICON_SOCK_GROUP in the config file or via the -g option
or create the group and add the user to it. The default group is 'clicon'.
Add yourself and www-data, if you intend to use restconf.

Using useradd and usermod:
```
  sudo useradd clicon # 
  sudo usermod -a -G clicon $(whoami)
  sudo usermod -a -G clicon www-data
```
Using adduser (eg on busybox):
```
  sudo adduser -D -H clicon
  sudo adduser $(whoami) clicon
```
(you may have to restart shell)

Verify:
```
grep clicon /etc/group
clicon:x:1001:<user>,www-data
```

## How do I use the CLI?

The easiest way to use Clixon is via the CLI. In the main example, once the backend is started you can start the auto-cli. Example:
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

## How do I use netconf?

As an alternative to cli configuration, you can use netconf. Easiest is to just pipe netconf commands to the clixon_netconf application.
Example:
```
clixon_netconf -qf /usr/local/etc/example.xml
<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>
<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth9</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>
```

However, more useful is to run clixon_netconf as an SSH
subsystem. Register the subsystem in /etc/sshd_config:
```
        Subsystem netconf /usr/local/bin/clixon_netconf -f /usr/local/etc/example.xml
```
and then invoke it from a client using
```
        ssh -s <host> netconf
```

## How do I use restconf?

You can access clixon via REST API using restconf, such as using
curl. GET, PUT, POST are supported.

You need a web-server, such as nginx, and start a restconf fcgi
daemon, clixon_restconf.

For example, using nginx, install, and edit config file: /etc/nginx/sites-available/default:
```
server {
  ...
  location /restconf {
    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
    include fastcgi_params;
  }
}
```
Start nginx daemon
```
sudo /etc/init.d/nginx start
```
Start the clixon restconf daemon
```
sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/example.xml " -s /bin/sh www-data
```

Then access:
```
   curl -X GET http://127.0.0.1/restconf/data/ietf-interfaces:interfaces/interface=eth0/type
   [
     {
       "ietf-interfaces:type": "clixon-example:eth" 
     }
   ]
```
Read more in the [restconf](../apps/restconf) docs.

## What about reference documentation?
Clixon uses [Doxygen](http://www.doxygen.nl/index.html) for reference documentation.
You need to install doxygen and graphviz on your system.
Build it in the doc directory and point the browser to `.../clixon/doc/html/index.html` as follows:
```
> cd doc
> make doc
> make graphs # detailed callgraphs
```

## How is configuration data stored?
Configuration data is stored in an XML datastore. In the example the
datastore are regular files found in /usr/local/var/example/.

## What is validate and commit?
Clixon follows netconf in its validate and commit semantics.
In short, you edit a 'candidate' configuration, which is first
'validated' for consistency and then 'committed' to the 'running' 
configuration.

A clixon developer writes commit functions to incrementaly upgrade a
system state based on configuration changes. Writing commit callbacks
is the core functionality of a clixon system.

## Does Clixon support transactions?

Yes. The netconf validation and commit operation is implemented in
Clixon by a transaction mechanism, which ensures that user-written
plugin callbacks are invoked atomically and revert on error.  If you
have two plugins, for example, a transaction sequence looks like the
following:
```
Backend   Plugin1    Plugin2
  |          |          |
  +--------->+--------->+ begin
  |          |          |
  +--------->+--------->+ validate
  |          |          |
  +--------->+--------->+ commit
  |          |          |
  +--------->+--------->+ end
```

If an error occurs in the commit call of Plugin2, for example,
the transaction is aborted and the commit reverted:
```
Backend   Plugin1    Plugin2
  |          |          |
  +--------->+--------->+ begin
  |          |          |
  +--------->+--------->+ validate
  |          |          |
  +--------->+---->X    + commit error
  |          |          |
  +--------->+          + revert
  |          |          |
  +--------->+--------->+ abort
```


## What is a Clixon configuration file?

Clixon options are stored in an XML configuration file. The default
configuration file is /usr/local/etc/clixon.xml. The example
configuration file is installed at /usr/local/etc/example.xml. The
YANG specification for the configuration file is clixon-config.yang.

See the [example config file](../example/main/example.xml).

## How are Clixon configuration files found?

Clixon by default finds its configuration file at `/usr/local/etc/clixon.xml`. However, you can modify this location as follows:
  - Provide -f FILE option when starting a program (eg clixon_backend -f FILE)
  - Provide --with-configfile=FILE when configuring
  - Provide --with-sysconfig=<dir> when configuring. Then FILE is <dir>/clixon.xml
  - Provide --sysconfig=<dir> when configuring. Then FILE is <dir>/etc/clixon.xml
  - FILE is /usr/local/etc/clixon.xml

## Can I modify clixon options at runtime?

Yes, when you start a clixon program, you can supply the `-o` option to modify the configuration specified in the configuration file. Options that are leafs are overriden, whereas options that are leaf-lists are added to.

Example, add the "/usr/local/share/ietf" directory to the list of directories where yang files are searched for:
```
  clixon_cli -o CLICON_YANG_DIR=/usr/local/share/ietf
```

## How are Yang files found?

Yang files contain the configuration specification. A Clixon
application loads yang files and clixon itself loads system yang
files. When Yang files are loaded modules are imported and submodules
are included.

The following configuration file options control the loading of Yang files:
- `CLICON_YANG_DIR` -  A list of directories (yang dir path) where Clixon searches for module and submodules.
- `CLICON_YANG_MAIN_FILE` - Load a specific Yang module given by a file. 
- `CLICON_YANG_MODULE_MAIN` - Specifies a single module to load. The module is searched for in the yang dir path.
- `CLICON_YANG_MODULE_REVISION` : Specifies a revision to the main module. 
- `CLICON_YANG_MAIN_DIR` - Load all yang modules in this directory.

Note that the special `YANG_INSTALLDIR`, by default `/usr/local/share/clixon` should be included in the yang dir path for Clixon system files to be found.

You can combine the options, however, if there are different variants
of the same module, more specific options override less
specific. The precedence of the options are as follows:
- `CLICON_YANG_MAIN_FILE`
- `CLICON_YANG_MODULE_MAIN`
- `CLICON_YANG_MAIN_DIR`

Note that using `CLICON_YANG_MAIN_DIR` Clixon may find several files
containing the same Yang module. Clixon will prefer the one without a
revision date if such a file exists. If no file has a revision date,
Clixon will prefer the newest.

## How do I download standard YANGs?

Some clixon tests rely on standard IETF YANG modules which you need to download. By default, these are in `/usr/local/share/yang/standard`. You can change this location with configure option `--with-yang-standard-dir=DIR`

To download the yang models required for some tests:
```
   cd /usr/local/share/yang
   git clone https://github.com/YangModels/yang
```

## How do I enable Yang features?

Yang models have features, and parts of a specification can be
conditional using the if-feature statement. In Clixon, features are
enabled in the configuration file using <CLICON_FEATURE>.

The example below shows enabling a specific feature; enabling all features in module; and enabling all features in all modules, respectively:
```
      <CLICON_FEATURE>ietf-routing:router-id</CLICON_FEATURE>
      <CLICON_FEATURE>ietf-routing:*</CLICON_FEATURE>
      <CLICON_FEATURE>*:*</CLICON_FEATURE>
```

Features can be probed by using RFC 7895 Yang module library which provides
information on all modules and which features are enabled.

Clixon have three hardcoded features:
- :candidate (RFC6241 8.3)
- :validate (RFC6241 8.6)
- :xpath (RFC6241 8.9)

You can select the startup feature by including it in the config file:
```
      <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
```
(or just `ietf-netconf:*`).

## Can I run Clixon as a container?

Yes, Clixon has two examples on how to build docker containers. A [base](../docker/base) image and a complete [example system](../docker/system).

The base image can only be used as a boilerplate for building clixon
applications (it has no applications semantics); whereas the system is
a complete example applications with CLI/Netconf/Restconf, and
testing.

For example, the clixon-system container can be used as follows:
* CLI: `sudo docker exec -it clixon-system clixon_cli`
* Netconf: `sudo docker exec -it clixon-system clixon_netconf`
* Restconf: `curl -G http://localhost/restconf`
* Run tests: `sudo docker exec -it clixon-system bash -c 'cd /clixon/clixon/test; ./all.sh'`

See [../docker](../docker) for more info.

## Does Clixon support event streams? 

Yes, Clixon supports event notification streams in the CLI, Netconf and Restconf API:s.

The example has a prebuilt notification stream called "EXAMPLE" that triggers every 5s.
You enable the notification via the CLI:
```
cli> notify 
cli>
event-class fault;
reportingEntity {
    card Ethernet0;
}
severity major;
...
```
or via NETCONF:
```
clixon_netconf -qf /usr/local/etc/example.xml 
<rpc><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"><stream>EXAMPLE</stream></create-subscription></rpc>]]>]]>
<rpc-reply><ok/></rpc-reply>]]>]]>
<notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>2018-09-30T12:44:59.657276</eventTime><event xmlns="http://example.com/event/1.0"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event></notification>]]>]]>
...
```
or via restconf:
```
   curl -H "Accept: text/event-stream" -s -X GET http://localhost/streams/EXAMPLE
```
Consult [clixon restconf](../apps/restconf/README.md) on more information on how to setup a reverse proxy for restconf streams. It is also possible to configure a pub/sub system such as [Nginx Nchan](https://nchan.io). 

## How should I start the backend daemon?

There are four different backend startup modes. There is differences in running state treatment, ie what state the machine is when you start the daemon and how loading the configuration affects it:
- none - Do not touch running state. Typically after crash when running state and db are synched.
- init - Initialize running state. Start with a completely clean running state.
- running - Commit running db configuration into running state. Typically after reboot if a persistent running db exists.
- startup - Commit startup configuration into running state. After reboot when no persistent running db exists.

You use the -s to select the mode:
```
clixon_backend ... -s running
```

You may also add a default method in the configuration file:
```
<clixon-config xmlns="http://clicon.org/config">
   ...
   <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE
</clixon-config>
```

## Can I use systemd with Clixon?

Yes. Systemd example files are provide for the backend and the
restconf daemon as part of the [example](../example/main/systemd).


## How can I add extra XML?

There are two ways to add extra XML to running database after start. Note that this XML is not "committed" into running.

The first way is via a file. Assume you want to add this xml (the config tag is a necessary top-level tag):
```
   <config>
      <x xmlns="urn:example:clixon">extra</x>
   </config>
```
You add this via the -c option:
```
   clixon_backend ... -c extra.xml
```

The second way is by programming the plugin_reset() in the backend
plugin. The example code contains an example on how to do this (see plugin_reset() in example_backend.c).


## I want to program. How do I extend the example?
See [../example/main](../example/main)
- example.xml - Change the configuration file
- The yang specifications - This is the central part. It changes the XML, database and the config cli.
- example_cli.cli - Change the fixed part of the CLI commands 
- example_cli.c - Cli C-commands are placed here.
- example_backend.c - Commit and validate functions.
- example_backend_nacm.c - Secondary example plugin (for authorization)
- example_netconf.c - Netconf plugin
- example_restconf.c - Add restconf authentication, etc.

## How is a plugin initiated?
Each plugin is initiated with an API struct followed by a plugin init function as follows:
```
   static clixon_plugin_api api = {
      "example",          /* name */
      clixon_plugin_init, 
      plugin_start,
      ... /* more functions here */
   }
   clixon_plugin_api *
   clixon_plugin_init(clicon_handle h)
   {
      ...
      return &api; /* Return NULL on error */
   }
```
For more info see [the main example](../example/main/README.md)

## How do I write a commit function?
In the example, you write a commit function in example_backend.c.
Every time a commit is made, transaction_commit() is called in the
backend.  It has a 'transaction_data td' argument which is used to fetch
information on added, deleted and changed entries. You access this
information using access functions as defined in clixon_backend_transaction.h

## How do I check what has changed on commit?
You use XPATHs on the XML trees in the transaction commit callback.
Suppose you want to print all added interfaces:
```
        cxobj *target = transaction_target(td); # wanted XML tree
        vec = xpath_vec_flag(target, NULL, "//interface", &len, XML_FLAG_ADD); /* Get added i/fs */
        for (i=0; i<len; i++)             /* Loop over added i/fs */
          clicon_xml2file(stdout, vec[i], 0, 1); /* Print the added interface */
```
You can look for added, deleted and changed entries in this way.

## How do I access the XML tree?
Using XPATH, find and iteration functions defined in the XML library. Example library functions:
```
      xml_child_each(), 
      xml_find(), 
      xml_body(), 
      xml_print(), 
      xml_apply()
```
More are found in the doxygen reference.

## How do I write a CLI callback function?

1. You add an entry in example_cli.cli
>   example("This is a comment") <var:int32>("This is a variable"), mycallback("myarg");
2. Then define a function in example_cli.c
>   mycallback(clicon_handle h, cvec *cvv, cvec *arv)
where 'cvv' contains the value of the variable 'var' and 'argv' contains the string "myarg".

The 'cvv' datatype is a 'CLIgen variable vector'.
They are documented in [CLIgen tutorial](https://github.com/clicon/cligen/blob/master/cligen_tutorial.pdf)

## How do I write a validation function?
Similar to a commit function, but instead write the transaction_validate() function.
Check for inconsistencies in the XML trees and if they fail, make an clicon_err() call.
```
    clicon_err(OE_PLUGIN, 0, "Route %s lacks ipv4 addr", name);
    return -1;
```
The validation or commit will then be aborted.

## How do I write a state data callback function?

Netconf <get> and restconf GET also returns state data, in contrast to
config data. In YANG state data is specified with "config false;".

To return state data, you need to write a backend state data callback
with the name "plugin_statedata()" where you return an XML tree.

Please look at the example for an example on how to write a state data callback.

## How do I write an RPC function?

A YANG RPC is an application specific operation. Example:
```
   rpc example-rpc {
      input {
         leaf inarg { type string; }
      }
      output {
         leaf outarg { type string; }
      }
   }
```
which defines the example-rpc operation present in the example (the arguments have been changed).

Clixon automatically relays the RPC to the clixon backend. To
implement the RFC, you need to register an RPC callback in the backend plugin:
Example:
```
int
clixon_plugin_init(clicon_handle h)
{
...
   rpc_callback_register(h, example_rpc, NULL, "urn:example:my", "example-rpc");
...
}
```
And then define the callback itself:
```
static int 
example_rpc(clicon_handle h,            /* Clicon handle */
            cxobj        *xe,           /* Request: <rpc><xn></rpc> */
            cbuf         *cbret,        /* Reply eg <rpc-reply>... */
            void         *arg,          /* Client session */
            void         *regarg)       /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply><ok/></rpc-reply>");    
    return 0;
}
```
Here, the callback is over-simplified.

## I want to add a hook to an existing operation, can I do that?

Yes, by registering an [RPC callback](how-do-i-write-an-rpc-function)
on an existing function, your function will be called immediately
_after_ the original.

The following example shows how `my_copy` can be called right after the system (RFC6241) `copy-config` RPC. You can perform some side-effect or even alter
the original operation:
```
static int 
my_copy(clicon_handle h,            /* Clicon handle */
        cxobj        *xe,           /* Request: <rpc><xn></rpc> */
        cbuf         *cbret,        /* Reply eg <rpc-reply>... */
        void         *arg,          /* Client session */
        void         *regarg)       /* Argument given at register */
{
    /* Do something */
    return 0;
}
int
clixon_plugin_init(clicon_handle h)
{
...
   rpc_callback_register(h, my_copy, NULL, "urn:ietf:params:xml:ns:netconf:base:1.0", "copy-config");
...
}
```

## How do I write an authentication callback?

A restconf call may need to be authenticated. 
You can specify an authentication callback for restconf as follows:
```
int
plugin_credentials(clicon_handle h,     
                   void         *arg)
{
    FCGX_Request *r = (FCGX_Request *)arg;
    ...
    clicon_username_set(h, user);
```

To authenticate, the callback needs to return the value 1 and supply a username.

See [../example/main/example_restconf.c] example_restconf_credentials() for
an example of HTTP basic auth.

## What about access control?

Clixon has experimental support of the Network Configuration Access
Control Model defined in [RFC8341](https://tools.ietf.org/html/rfc8341)

Incoming RPC and data node access points are supported with some
limitations. See the (README)(../README.md) for more information.

## Does Clixon support upgrade?

Yes. Clixon provides a callback interface where datastores can be
upgraded. This is described in [the startup doc](startup.md).

## How do I write a CLI translator function?

The CLI can perform variable translation. This is useful if you want to
process the input, such as hashing, encrypting or in other way
translate the input.

Yang example:
```
list translate{
    leaf value{
        type string;
    }
}
```

CLI specification:
```
translate value (<value:string translate:incstr()>),cli_set("/translate/value");
```

If you run this example using the `incstr()` function which increments the characters in the input, you get this result:
```
cli> translate value HAL
cli> show configuration
translate {
    value IBM;
}
```
You can perform translation on any type, not only strings.
