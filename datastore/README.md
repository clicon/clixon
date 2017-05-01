# Clixon datastore

The Clixon datastore is a stand-alone XML based datastore used by
Clixon. The idea is to be able to use different datastores. There is
currently a Key-value plugin based on qdbm and a plain text-file
datastore.

The datastore is primarily designed to be used by Clixon but can be used
separately.  See datastore_client.c for an example of how to use a
datastore plugin for other applications

Can we equate a file that does not exist with an empty file?
Or is empty file same as <config/>?
Three states:
NULL <---> "" <---> "<config/>"
which are valid?
