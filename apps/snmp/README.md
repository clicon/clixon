SNMP
====

The SNMP frontend acts as an intermediate daemon between the Net-SNMP
daemon (snmpd) and the Clixon backend. Clixon-snmp communicates over the AgentX
protocol to snmpd typically via a UNIX socket, and over the internal IPC protocol to the Clixon
backend.

Use Net-SNMP version 5.9 or later

To set up AgentX communication between ``clixon_snmp`` and ``snmpd`` a
Unix or TCP socket is configured. This socket is also configured in
Clixon (see below). An example `/etc/snmpd/snmpd.conf` is as follows::

   master       agentx
   agentaddress 127.0.0.1,[::1]
   rwcommunity  public localhost
   agentXSocket unix:/var/run/snmp.sock
   agentxperms  777 777

It is necessary to ensure snmpd does `not` to load modules
implemented by Clixon. For example, if Clixon implements the IF-MIB and
system MIBs, snmpd should not load those modules. This can be done
using the "-I" flag and prepending a "-" before each module::
   
   -I -ifTable -I -system_mib -I -sysORTable

Net-snmp must be started via systemd or some other external mechanism before clixon_snmp is started.

To build the snmp support, netsnmp is enabled at configure time.  Two configure  options are added for SNMP:
* ``--enable-netsnmp`` Enable SNMP support.
* ``--with-mib-generated-yang-dir`` For tests: Directory of generated YANG specs (default: $prefix/share/mibyang)
