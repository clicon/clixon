# Clixon datastore

The Clixon datastore is a stand-alone XML based datastore. The idea is
to be able to use different datastores backends with the same
API. There is currently only a plain text-file datastore.

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
- A datastore plugin, such as a text.so. These are normally built and installed at Clixon make.
- A directory where to store databases
- A yang specification. This needs to be parsed using the Clixon yang_parse() method.

A client calling the API needs to: 
1. Load a plugin and 
2. Connect to a datastore. 
You can connect to several datastores, even concurrently,
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
[datastore_client.c](datastore_client.c) for a more elaborate example.

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


