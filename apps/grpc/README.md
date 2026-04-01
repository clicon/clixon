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
- Subscribe RPC (ONCE)
- Module qualified names, unqualified node fallback
- Bool, double, ascii typed values
- Leaf-list Get

Remaining:
- TLS
- Leaf-list Set
- Subscribe RPC (STREAM/POLL)
- Notifications
- Mount-point support
