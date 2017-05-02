# Clixon datastore

The Clixon datastore is a stand-alone XML based datastore used by
Clixon. The idea is to be able to use different datastores. There is
currently a Key-value plugin based on qdbm and a plain text-file
datastore.

The datastore is primarily designed to be used by Clixon but can be used
separately.  See datastore_client.c for an example of how to use a
datastore plugin for other applications

## The functional API
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
int xmldb_init(clicon_handle h, char *db);
```

## Using the API

This section described how the API is used. Please refer to datastore/datastore_client.c for an example of an actual implementation.

### Prerequisities
To use the API, a client needs the following:
- A clicon handle. 
- A datastore plugin, such as a text.so or keyvalue.so. These are normally built and installed at Clixon make.
- A directory where to store the datastores
- A yang specification. This needs to be parsed using the Clixon yang_parse() method.

### Dynamics

A client calling the API needs to load a plugin and connect to a
datastore. In principle, you cannot connect to several datastores,
even concurrently, but in practice in Clixon, you connect to a single
store.

Within a datastore, there may be 

```
  h = clicon_handle_init();
  xmldb_plugin_load(h, plugin);
```
The plugin is the complete path-name of a file.

Thereafter, a connection is made to a specific plugin, such as a text plugin. It is possible to connect to several datastore at once, although this is not supported by CLixon:
```
xmldb_connect(h);
xmldb_setopt(h, "dbdir", dbdir);
xmldb_setopt(h, "yangspec", yspec);
```


