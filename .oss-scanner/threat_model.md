# Threat model

## What this project does and where untrusted input enters
Clixon is a YANG-based configuration management framework: a backend daemon
holding the datastore and transaction engine, plus CLI, NETCONF, RESTCONF,
gRPC/gNMI and SNMP frontends that all talk to it over an internal
NETCONF-over-IPC protocol. Untrusted input enters through every frontend:
NETCONF XML over SSH/stdio (`apps/netconf/`), RESTCONF HTTP/JSON or XML
bodies (`apps/restconf/`), gRPC/gNMI protobuf messages (`apps/grpc/`), SNMP
PDUs (`apps/snmp/`), and CLI command-line text (`apps/cli/`, parsed via
CLIgen). YANG models themselves (`lib/src/clixon_yang_parse.y` and friends)
are also parsed as input -- a hostile or malformed YANG file
(`CLICON_YANG_DIR` / `CLICON_YANG_MAIN_FILE`) is a second, separate
untrusted-input surface from runtime protocol traffic.

## Components that matter most / least
- Most critical: the XML parser/encoder (`lib/src/clixon_xml_parse.y`,
  `clixon_xml*.c`), the YANG parser (`lib/src/clixon_yang_parse.y`), the
  datastore/transaction/validation engine (`apps/backend/backend_commit.c`,
  `lib/src/clixon_validate.c`, `lib/src/clixon_datastore*.c`), and the
  NETCONF/RESTCONF/gRPC/SNMP frontends that feed them (`apps/netconf/`,
  `apps/restconf/`, `apps/grpc/`, `apps/snmp/`). These see attacker-controlled
  bytes directly.
- Also in scope, lower priority: the CLI (`apps/cli/`) and CLIgen-based
  tab-completion -- normally local/trusted input, but still worth checking as
  a parser.
- Out of scope: vendored/third-party code, build scripts (`configure`,
  `config-aux/`, `Makefile.in`), and the test/fuzz harnesses themselves
  (`test/`, `docker/`, `fuzz/`) -- these aren't part of a running Clixon
  deployment's attack surface.

## How to exercise it
- `example/` (built and installed by `.oss-scanner/Dockerfile`) wires up a
  complete YANG module with CLI/NETCONF/RESTCONF frontends -- the easiest way
  to drive real input through the stack.
- `test/` has ~1000 shell-based regression tests (`test_*.sh`) covering
  NETCONF, RESTCONF, CLI and YANG edge cases. Most start a backend under
  `sudo` and aren't run in the scan image, but they're a good source of
  realistic inputs and fixtures.
- `fuzz/` already has AFL and libFuzzer harnesses for several parsers
  (`fuzz/afl/`, `fuzz/libfuzzer/`), pointing at the specific entry points
  considered most exposed (e.g. API-path and XML parsing).

## How you rate severity
- Any memory-safety bug (overflow, use-after-free, double free, OOB
  read/write) reachable from NETCONF/RESTCONF/gRPC/SNMP input, or from
  YANG/XML parsing, is high at a minimum; critical if it plausibly corrupts
  control data or could lead to RCE.
- An unauthenticated crash (NULL deref, assert, abort) reachable from any
  frontend is medium-high, more so if it takes down the whole backend
  (shared across all clients) rather than a single frontend process.
- A validation bypass -- eg a mandatory leaf, "must" or "when" constraint
  silently not enforced (`lib/src/clixon_validate.c`,
  `apps/backend/backend_commit.c`) -- is medium: a correctness/integrity
  issue, not memory-unsafe, but it lets invalid or policy-violating
  configuration reach production state.
- An RPC error silently swallowed or replaced by an unrelated message (a
  caller reading an RPC reply before checking for `<rpc-error>`) is
  low-medium: confusing and can mask a real failure, but isn't itself a
  privilege or memory-safety violation.

## Anything to leave alone
- Don't report findings in vendored/bundled code -- if a vulnerability is in
  a dependency, it should go to that project upstream.
- The CLI frontend trusts its local operator by design, similar to a shell.
  Don't report "CLI command X can change config Y" as a vulnerability unless
  it crosses a privilege boundary Clixon itself claims to enforce (eg NACM
  access control, `lib/src/clixon_nacm.c`).
- Build-time code and the test/fuzz harnesses are not part of the runtime
  attack surface.
