# Clixon

Clixon is an automatic configuration manager where you from a YANG
specification generate interactive CLI, NETCONF, RESTCONF and embedded
databases with transaction support.

Presentations and tutorial is found on the [CLICON project page](http://www.clicon.org)

## 1. Installation

A typical installation is as follows:
```
     configure	       	        # Configure clixon to platform
     make                      # Compile
     sudo make install         # Install libs, binaries, and config-files
     sudo make install-include # Install include files (for compiling)
```
One example applications is provided, a IETF IP YANG datamodel with generated CLI and configuration interface. 

## 2. Documentation

- [Frequently asked questions](http://www.clicon.org/FAQ.html)
- [Reference manual(http://www.clicon.org/doxygen/index.html) (may not be 100%% synched)

## 3. Dependencies

Clixon is dependend on the following packages
- [CLIgen](http://www.cligen.se) is required for building CLIXON. If you need 
to build and install CLIgen: 
```
    git clone https://github.com/olofhagsand/cligen.git
    cd cligen; configure; make; make install
```
- Yacc/bison
- Lex/Flex
- Fcgi (if restconf is enabled)
- Qdbm key-value store (if keyvalue datastore is enabled)

## 4. Licenses

CLIXON is dual license. Either Apache License, Version 2.0 or GNU
General Public License Version 2. You choose.

See LICENSE.md for license, CHANGELOG for recent changes.

## 5. History

CLIXON is a fork of CLICON where legacy key specification has been
replaced completely by YANG. This means that legacy CLICON
applications such as CLICON/ROST does not run on CLIXON.

Clixon origins from work at [KTH](http://www.csc.kth.se/~olofh/10G_OSR)

## 6. Clixon Datastore
The Clixon datastore is a stand-alone XML based datastore used by
Clixon. The idea is to be able to use different datastores. There is
currently a key-value plugin based on qdbm and a plain text-file
datastore.

The datastore is primarily designed to be used by Clixon but can be used
separately.  

A datastore is a dynamic plugin that is loaded at runtime with a
well-defined API. This means it is possible to create your own
datastore and plug it in a Clixon backend at runtime. 

### The functional API
```
int xmldb_plugin_load(clicon_handle h, char *filename);
int xmldb_plugin_unload(clicon_handle h);
int xmldb_connect(clicon_handle h);
int xmldb_disconnect(clicon_handle h);
int xmldb_getopt(clicon_handle h, char *optname, void **value);
int xmldb_setopt(clicon_handle h, char *optname, void *value);
int xmldb_get(clicon_handle h, char *db, char *xpath,
	      cxobj **xtop, cxobj ***xvec, size_t *xlen);
int xmldb_put(clicon_handle h, char *db, enum operation_type op, 
	      char *api_path,  cxobj *xt);
int xmldb_copy(clicon_handle h, char *from, char *to);
int xmldb_lock(clicon_handle h, char *db, int pid);
int xmldb_unlock(clicon_handle h, char *db);
int xmldb_unlock_all(clicon_handle h, int pid);
int xmldb_islocked(clicon_handle h, char *db);
int xmldb_exists(clicon_handle h, char *db);
int xmldb_delete(clicon_handle h, char *db);
int xmldb_create(clicon_handle h, char *db);
```

### Using the API

To use the API, a client needs the following:
- A clicon handle. 
- A datastore plugin, such as a text.so or keyvalue.so. These are normally built and installed at Clixon make.
- A directory where to store databases
- A yang specification. This needs to be parsed using the Clixon yang_parse() method.

A client calling the API needs to (1)load a plugin and (2)connect to a
datastore. You can connect to several datastores, even concurrently,
but in practice in Clixon, you connect to a single store. 

After connecting to a datastore, you can create and modify databases
within the datastore, and set and get options of the datastore itself.

When done, you disconnect from the datastore and unload the plugin.

Within a datastore, the following four databases may exist:
- running
- candidate
- startup
- tmp

Initially, a database does not exist but is created by
xmldb_create(). It is deleted by xmldb_delete(). You may check for
existence with xmldb_exists(). You need to create a database before
you can perform any data access on it.

You may lock a database for exclusive modification according to
Netconf semantics. You may also unlock a single dabase, unlock all frm
a specific session.

You can read a database with xmldb_get() and modify a database with
xmldb_put(), and xmldb_copy().

A typical datastore session can be as follows, see the source code of
datastore_client.c for a more elaborate example.

```
  h = clicon_handle_init();
  xmldb_plugin_load(h, plugin);
  xmldb_connect(h);
  xmldb_setopt(h, "dbdir", dbdir);
  xmldb_setopt(h, "yangspec", yspec);
  /* From here databases in the datastore may be accessed */
  xmldb_create(h, "candidate");
  xmldb_copy(h, "running", "candidate");
  xmldb_lock(h, "candidate", 7878);
  xmldb_put(h, "candidate", OP_CREATE, "/interfaces/interface=eth0", xml);
  xmldb_unlock(h, "candidate");
  xmldb_get(h, "candidate", "/", &xml, &xvec, &xlen);
  xmldb_disconnect(h)
  xmdlb_plugin_unload(h);
```

## 7. YANG

Clixon implements YANG RFC 6020. Clixon generates an interactive CLI
for YANG specifications. It also provides Restconf and Netconf clients.

Clixon YANG currently does not provide the following support:
- type object-references
- if-feature
- unique
- rpc

## 8. Netconf

Clixon Netconf implements the following NETCONF standards:
- RFC 4741 (NETCONF Configuration Protocol)
- RFC 4742 (Using the NETCONF Configuration Protocol over Secure SHell (SSH))
- RFC 5277 (NETCONF Event Notifications)

It needs to be updated to RFC6241 and RFC 6242. 

Clixon NETCONF currently does not support the following Netconf features:

- :url capability
- copy-config source config
- edit-config testopts 
- edit-config erropts
- edit-config config-text

## 9. Restconf

### Features

Clixon restconf is a daemon based on FASTCGI. Instructions are available to
run with NGINX. 
The implementatation supports plain OPTIONS, HEAD, GET, POST, PUT, PATCH, DELETE.
and is based on draft-ietf-netconf-restconf-13. 
There is currently (2017) a RFC 8040, many of those features are _not_ implemented,
including:
- query parameters (section 4.9)
- notifications (sec 6)
- only rudimentary error reporting exists (sec 7)

### Installation using Nginx

Define nginx config file/etc/nginx/sites-available/default
```
server {
  ...
  location /restconf {
    root /usr/share/nginx/html/restconf;
    fastcgi_pass unix:/www-data/fastcgi_restconf.sock;
    include fastcgi_params;
  }
}
```
Start nginx daemon
```
sudo /etc/init.d nginx start
```

Start clixon restconf daemon
```
olof@vandal> sudo su -c "/www-data/clixon_restconf -f /usr/local/etc/routing.conf " -s /bin/sh www-data
```

Make restconf calls with curl
```
olof@vandal> curl -G http://127.0.0.1/restconf/data/interfaces
[
  {
    "interfaces": {
      "interface":[
        {
          "name": "eth0",
          "type": "eth",
          "enabled": "true",
          "name": "eth9",
          "type": "eth",
          "enabled": "true"
         }
      ]
    }
  }
]
olof@vandal> curl -G http://127.0.0.1/restconf/data/interfaces/interface/name=eth9/type
[
  {
    "type": "eth" 
  }
]

curl -sX POST -d '{"clicon":{"interfaces":{"interface":{"name":"eth1","type":"eth","enabled":"true"}}}}' http://localhost/restconf/data
```

### Debugging

Start the restconf fastcgi program with debug flag:
```
sudo su -c "/www-data/clixon_restconf -Df /usr/local/etc/routing.conf" -s /bin/sh www-
data
```
Look at syslog:
```
tail -f /var/log/syslog | grep clixon_restconf
```

Send command:
```
curl -G http://127.0.0.1/restconf/data/*
```

