gRPC/gNMI Server for Clixon
===========================

Add gRPC server-side support to Clixon, primarily targeting gNMI (gRPC
Network Management Interface) as the service definition. This enables
modern network automation tools to manage Clixon-based devices.

To configure::

   ./configure --enable-grpc

Extra requirement: protobuf (libprotobuf-c-dev and protobuf-c-compiler)
proto/gNMI proto specifications imported from openconfig/gnmi
Also assume google well-known .proto types

nghttp2 and openssl were already present for the RESTCONF native implementation

See: https://openconfig.net/docs/gnmi/gnmi-specification

Status:
- nghttp2 server, gRPC framing, trailers
- Capabilities, returns loaded YANG modules + encodings (JSON_IETF, JSON, ASCII)
- Get (XPath build, namespace handling)
- Set (update/replace/delete)
- Subscribe RPC (ONCE, STREAM with SAMPLE/TARGET_DEFINED, POLL)
- Module qualified names, unqualified node fallback
- Bool, double, ascii typed values
- Leaf-list Get (works via JSON subtree serialization, not special-cased)

Remaining:
- TLS
- Authentication
- NACM
- Leaf-list Set
- Subscribe ON_CHANGE
- Mount-point support
- Prefix field (GetRequest/SetRequest, silently ignored)
- Path wildcards (*, ...)
- union_replace
- use_models
