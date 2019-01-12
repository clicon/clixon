# Clixon roadmap

## High prio
- NACM (RFC 8341) 
  - Module rules (done)
  - Data node rules (read/create/delete/update/execute)
- Special handling of the initial startup transaction to avoid exit at startup
  - Possibly - draft-wu-netconf-restconf-factory-restore-03
- Handle revisions to data model.
  - Possibly draft-wang-netmod-module-revision-management-01
- XML [Namespace handling](https://github.com/clicon/clixon/issues/49)

## Medium prio:
- Input validation on custom RPCs/ (done)
  - [Sanity checks](https://github.com/clicon/clixon/issues/47)
- Support for XML regex's.
  - Currently Posix extended regular expressions
- Support a plugin callback that is invoked when copy-config is called.
- Preserve CLI command history across sessions. The up/down arrows

## Low prio:
- Provide a client library to access netconf APIs provided by system services.
  - Netconf backend (Clixon acts as netconf controller)
- Support for restconf call-home (RFC 8071)

Not prioritized:
- Support for restconf PATCH method
- NETCONF
  - Support for additional Netconf [edit-config modes](https://github.com/clicon/clixon/issues/53)
  - Netconf [framing](https://github.com/clicon/clixon/issues/50)
  - [Child ordering](https://github.com/clicon/clixon/issues/22)
- Restconf
  - Query parameters
- Streams (netconf and restconf)
  - Extend native stream mode with external persistent timeseries database, eg influxdb.
- Jenkins CI/CD and webhooks
- YANG
  - RFC 6022 [NETCONF monitoring](https://github.com/clicon/clixon/issues/39)
  - Deviation, min/max-elements, action, unique
- Containers
  - [Docker improvements](https://github.com/clicon/clixon/issues/44)
  - Kubernetes Helm chart definition
- [gRPC](https://github.com/clicon/clixon/issues/43)



