# Security Policy

## Supported Versions

Clixon's `master` branch is continuously tested by CI. Releases are cut from
`master` roughly every third month (see [CHANGELOG.md](CHANGELOG.md) and
[Releases](https://github.com/clicon/clixon/releases)). Security fixes are
made against `master` and included in the next release; only the latest
release and `master` are supported.

## Reporting a Vulnerability

Please report security vulnerabilities privately by email to
**info@clicon.org**, rather than filing a public GitHub issue.

Include, if possible:
- A description of the vulnerability and its potential impact.
- Steps to reproduce, or a minimal example (eg a NETCONF/RESTCONF request, CLI
  command, or YANG model) that triggers it.
- The affected component (CLI, NETCONF, RESTCONF, gRPC/gNMI, SNMP, backend,
  datastore, etc.) and version or commit.

We will acknowledge your report, investigate, and work with you on a fix and
disclosure timeline before any public announcement.
