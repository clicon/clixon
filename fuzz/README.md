# Fuzzing with AFL

Clixon can be fuzzed with [american fuzzy lop](https://github.com/google/AFL/releases) but not without pain.

So far the backend and cli can be fuzzed.

Some issues are as follows:
- Static linking. Fuzzing requires static linking. You can statically link clixon using: `LINKAGE=static ./configure` but that does not work with Clixon plugins (at least yet). Therefore fuzzing has been made with no plugins using the hello example only.
- Multiple processes. Only the backend can run stand-alone, cli/netconf/restconf requires a backend. When you fuzz eg clixon_cli, the backend must be running and it will be slow due to IPC. Possibly one could link them together and run as a monolith by making a threaded image.
- Internal protocol 1: The internal protocol uses XML but deviates from netconf by using a (binary) header where the length is encoded, instead of ']]>]]>' as a terminating string. AFL does not like that. By setting CLIXON_PROTO_PLAIN the internal protocol uses pure netconf (with some limitations).
- Internal protocol 2: The internal protocol uses TCP unix sockets while AFL requires stdio. One can use a package called "preeny" to translate stdio into sockets. But it is slow.

Restconf also has the extra problem of running TSL sockets.