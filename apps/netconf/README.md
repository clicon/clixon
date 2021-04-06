# Clixon Netconf

Clixon implements NETCONF as external access, and also as an internal protocol between backend and frontent clients.

You can expose ``clixon_netconf`` as an SSH subsystem according to `RFC 6242`. Register the subsystem in ``/etc/sshd_config``::

	Subsystem netconf /usr/local/bin/clixon_netconf

and then invoke it from a client using::

	ssh -s <host> netconf


For more defails see [Clixon docs netconf](https://clixon-docs.readthedocs.io/en/latest/standards.html#netconf)