[![Build Status](https://travis-ci.org/clicon/clixon.png)](https://travis-ci.org/clicon/clixon) [![Documentation Status](https://readthedocs.org/projects/clixon-docs/badge/?version=latest)](https://clixon-docs.readthedocs.io/en/latest/?badge=latest)

# Clixon

Clixon is a YANG-based configuration manager, with interactive CLI,
NETCONF and RESTCONF interfaces, an embedded database and transaction
mechanism.

  * [Background](#background)
  * [Frequently asked questions (FAQ)](doc/FAQ.md)
  * [Hello world](example/hello/README.md)
  * [Changelog](CHANGELOG.md)
  * [Installation](doc/INSTALL.md)
  * [Licenses](#licenses)
  * [Support](#support)
  * [Dependencies](#dependencies)
  * [Extending](#extending)
  * [Yang](#yang)
  * [CLI](doc/CLI.md)
  * [XML and XPATH](#xml-and-xpath)
  * [Netconf](#netconf)
  * [Restconf](#restconf)
  * [Datastore](datastore/README.md)
  * [Authentication](#auth)
  * [NACM Access control](#nacm)
  * [Example](example/README.md)
  * [Runtime](#runtime)
  * [Clixon project page](http://www.clicon.org)
  * [Tests and CI](test/README.md)
  * [Scaling: large lists](doc/scaling/large-lists.md)
  * [Containers](docker/README.md)
  * [Roadmap](doc/ROADMAP.md)
  * [Standard compliance](#standard-compliance)
  * [Reference manual](#reference) 
  
## Background

Clixon was implemented to provide an open-source generic configuration
tool. The existing [CLIgen](http://www.cligen.se) tool was for command-lines only, while Clixon is a system with configuration database, XML and REST interfaces all defined by Yang. Most of the projects using Clixon are for embedded network and measuring devices. But Clixon can be used for other systems as well due to its modular and pluggable architecture.

Users of Clixon currently include:
  * [Netgate](https://www.netgate.com) in particular the [Tnsr product](https://www.tnsr.com/product#architecture)
  * [CloudMon360](http://cloudmon360.com)
  * [Grideye](http://hagsand.se/grideye)	
  * [Netclean](https://www.netclean.com/solutions/whitebox) # only CLIgen
  * [Prosilient's PTAnalyzer](https://prosilient.com) # only CLIgen

See also [Clicon project page](http://clicon.org).

## Licenses

Clixon is open-source and dual licensed. Either Apache License, Version 2.0 or GNU
General Public License Version 2; you choose.

See [LICENSE.md](LICENSE.md) for the license.

## Dependencies

Clixon depends on the following software packages, which need to exist on the target machine.
- [CLIgen](http://github.com/olofhagsand/cligen) If you need to build and install CLIgen: 
```
    git clone https://github.com/olofhagsand/cligen.git
    cd cligen; configure; make; make install
```
- Yacc/bison
- Lex/Flex
- Fcgi (if restconf is enabled)

## Support

Clixon interaction is best done posting issues, pull requests, or joining the
[slack channel](https://clixondev.slack.com).
[Slack invite](https://join.slack.com/t/clixondev/shared_invite/enQtMzI3OTM4MzA3Nzk3LTA3NWM4OWYwYWMxZDhiYTNhNjRkNjQ1NWI1Zjk5M2JjMDk4MTUzMTljYTZiYmNhODkwMDI2ZTkyNWU3ZWMyN2U). 

## Extending

Clixon provides a core system and can be used as-is using available
Yang specifications.  However, an application very quickly needs to
specialize functions.  Clixon is extended by writing
plugins for cli, backend, netconf and restconf.

Plugins are written in C and easiest is to look at
[example](example/README.md) or consulting the [FAQ](doc/FAQ.md).

## Yang

YANG and XML is the heart of Clixon.  Yang modules are used as a
specification for handling XML configuration data. The YANG spec is
used to generate an interactive CLI, netconf and restconf clients. It
also manages an XML datastore.

Clixon follows:
- [YANG 1.0 RFC 6020](https://www.rfc-editor.org/rfc/rfc6020.txt)
- [YANG 1.1 RFC 7950](https://www.rfc-editor.org/rfc/rfc7950.txt).
- [RFC 7895: YANG module library](http://www.rfc-base.org/txt/rfc-7895.txt)

However, the following YANG syntax modules are not implemented (reference to RFC7950 in parenthesis):
- deviation (7.20.3)
- action (7.15)
- augment in a uses sub-clause (7.17) (module-level augment is implemented)
- require-instance
- instance-identifier type (9.13)
- status (7.21.2)
- YIN (13)
- Yang extended Xpath functions: re-match(), deref)(), derived-from(), derived-from-or-self(), enum-value(), bit-is-set() (10.2-10.6)
- Default values on leaf-lists are not supported (7.7.2)
- Lists without keys (non-config lists may lack keys)

### Yang patterns
Yang type patterns use regexps defined in [W3C XML XSD](http://www.w3.org/TR/2004/REC-xmlschema-2-20041028). XSD regexp:s are
slightly different from POSIX regexp.

Clixon supports two regular expressions engines:
  * "Posix" which is the default method, which _translates_ XSD regexp:s to posix before matching with the standard Linux regex engine. This translation is not complete but can be considered "good-enough" for most yang use-cases. For reference, all standard Yang models in [https://github.com/YangModels/yang] have been tested.
  * "Libxml2" which uses the XSD regex engine in Libxml2. This is a complete XSD engine but you need to compile and link with libxml2 which may add overhead.

To use libxml2 in clixon you need enable libxml2 in both cligen and clixon:
```
> ./configure --with-libxml2 # both cligen and clixon
```
You then need to set the following configure option:
```
  <CLICON_YANG_REGEXP>libxml2</CLICON_YANG_REGEXP>
```

## XML and XPATH

Clixon has its own implementation of XML and XPATH implementation.

The standards covered include:
- [XML 1.0](https://www.w3.org/TR/2008/REC-xml-20081126)
- [Namespaces in XML 1.0](https://www.w3.org/TR/2009/REC-xml-names-20091208)
- [XPATH 1.0](https://www.w3.org/TR/xpath-10)

Not supported in the XML:
- !DOCTYPE (ie DTD)

The following XPATH axes are supported:
- child, descendant, descendant_or_self, self, and parent

The following xpath axes are _not_ supported:
- preceeding, preceeding_sibling, namespace, following_sibling, following, ancestor,ancestor_or_self, and attribute 

Note that base netconf namespace syntax is not enforced but recommended, which means that the following two expressions are treated equivalently:
```
     <rpc>
        <my-own-method xmlns="urn:example:my-own"/>
     </rpc> 
     <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
        <my-own-method xmlns="urn:example:my-own"/>
     </rpc> 
```
All other namespaces are enforced.

### XPATH and Namespaces

XPATHs may contain prefixes. Example: `/if:a/if:b`. The prefixes have
associated namespaces. For example, `if` may be bound to
`urn:ietf:params:xml:ns:yang:ietf-interfaces`. The prefix to namespace binding is called a _namespace context_ (nsc).

In yang, the xpath and xml prefixes may not be well-known. For example, the import statement specifies a prefix to an imported module that is local in scope. Other modules may use another prefix. The module name and namespace however are unique.

In the Clixon API, there are two variants on namespace contexts: _implicit_ (given by the XML); or _explicit_ given by an external mapping.

#### 1. Implicit namespace mapping

Implicit mapping is typical for basic known XML, where the context is
given implicitly by the XML being evaluated. In node comparisons (eg
of `if:a`) only name and prefixes are compared.

Example:
```
   XML: <if:a xmlns:if="urn:example:if" xmlns:ip="urn:example:ip"><ip:b/></if>
   XPATH: /if:a/ip:b
```
When you call an xpath API function, call it with nsc set to NULL, or use an API function without an nsc parameter.
This is the default and normal case.

#### 2. Explicit namespace mapping

Explicit binding is typical if the namespace context is independent
from the XML. Examples include NETCONF GET using :xpath when the XML
is not known so that xpath and XML may use different prefixes for the
same namespace.  In that case you cannot rely on the prefix but must
compare namespaces.  The namespace context of the XML is given (by the
XML), but the xpath nsc must then be explicitly given in the xpath
call.  Example:
```
XML: <if:a xmlns:if="urn:example:if" xmlns:ip="urn:example:ip"><ip:b/></if>
NETCONF:<get-config><filter select="/x:a/y:b" xmlns:x="urn:example:if" xmlns:y="urn:example:ip/>
```
Here, x,y are prefixes used for two namespaces that are given by `if,ip`
in the xml. In this case, the namespaces (eg `urn:example:if`) must be
compared instead.

Another case is Yang path expressions.

#### How to create namespace contexts

You can create namespace in three ways:
* `xml_nsctx_init()` by explicitly giving a default namespace
* `xml_nsctx_node()` by copying an XML namespace context from an existing XML node.
* `xml_nsctx_yang()` by computing an XML namespace context a yang module import statements.

## Netconf

Clixon relates to the following NETCONF proposals or standards:
- [RFC 6241: NETCONF Configuration Protocol](http://www.rfc-base.org/txt/rfc-6241.txt)
- [RFC 6242: Using the NETCONF Configuration Protocol over Secure Shell (SSH)](http://www.rfc-base.org/txt/rfc-6242.txt)
- [RFC 6243: With-defaults Capability for NETCONF](http://www.rfc-base.org/txt/rfc-6243.txt). Clixon implements "explicit" default handling, but does not implement the RFC.
- [RFC 5277: NETCONF Event Notifications](http://www.rfc-base.org/txt/rfc-5277.txt)
- [RFC 8341: Network Configuration Access Control Model](http://www.rfc-base.org/txt/rfc-8341.txt)

The following RFC6241 capabilities/features are hardcoded in Clixon:
- :candidate (RFC6241 8.3)
- :validate (RFC6241 8.6)
- :xpath (RFC6241 8.9)
- :notification: (RFC5277)

The following features are optional and can be enabled by setting CLICON_FEATURE:
- :startup (RFC6241 8.7)

Clixon does not support the following netconf features:

- :url capability
- copy-config source config
- edit-config testopts 
- edit-config erropts
- edit-config config-text
- edit-config operation

## Restconf

Clixon Restconf is a daemon based on FastCGI C-API. Instructions are available to
run with NGINX.
The implementatation is based on [RFC 8040: RESTCONF Protocol](https://tools.ietf.org/html/rfc8040).

The following features of RFC8040 are supported:
- OPTIONS, HEAD, GET, POST, PUT, DELETE, PATCH
- stream notifications (Sec 6)
- query parameters: "insert", "point", "content", "depth", "start-time" and "stop-time".
- Monitoring (Sec 9)

The following features are not implemented:
- ETag/Last-Modified
- Query parameters: "fields", "filter", "with-defaults"

See [more detailed instructions](apps/restconf/README.md).

## Datastore

The Clixon datastore is a stand-alone XML based datastore. The idea is
to be able to use different datastores backends with the same
API. Currently only an XML plain text datastore is supported.

The datastore is primarily designed to be used by Clixon but can be used
separately.

See [more detailed instructions](datastore/README.md).

## Auth

Authentication is managed outside Clixon using SSH, SSL, Oauth2, etc.

For CLI, login is typically made via SSH. For netconf, SSH netconf
subsystem can be used. 
  
Restconf however needs credentials.  This is done by writing a credentials callback in a restconf plugin. See:
  * [FAQ](doc/FAQ.md#how-do-i-write-an-authentication-callback).
  * [Example](example/README.md) has an example how to do this with HTTP basic auth.
  * It has been done for other projects using Oauth2 or (https://github.com/CESNET/Netopeer2/tree/master/server/configuration)

The clients send the ID of the user using a "username" attribute with
the RPC calls to the backend. Note that the backend trusts the clients
so the clients can in principle fake a username.

## NACM

Clixon includes an experimental Network Configuration Access Control Model (NACM) according to [RFC8341(NACM)](https://tools.ietf.org/html/rfc8341).

To enable NACM:

* The `CLICON_NACM_MODE` config variable is by default `disabled`.
* If the mode is internal`, NACM configurations are expected to be in the regular configuration, managed by regular candidate/runing/commit procedures. This mode may have some problems with bootstrapping.
* If the mode is `external`, the `CLICON_NACM_FILE` yang config variable contains the name of a separate configuration file containing the NACM configurations. After changes in this file, the backend needs to be restarted.

The [example](example/README.md) contains a http basic auth and a NACM backend callback for mandatory state variables.

NACM is implemented in the backend with incoming RPC and data node access control points.

The functionality is as follows (references to sections in [RFC8341](https://tools.ietf.org/html/rfc8341)):
* Access control point support:
  * Incoming RPC Message validation is supported (3.4.4)
  * Data Node Access validation is supported (3.4.5), except:
    * rule-type data-node path is not supported
  * Outgoing noitification aithorization is _not_ supported (3.4.6)
* RPC:s are supported _except_:
  * `copy-config`for other src/target combinations than running/startup (3.2.6)
  * `commit` - NACM is applied to candidate and running operations only (3.2.8)
* Client-side RPC:s are _not_ supported.

## Runtime

<img src="doc/clixon_example_sdk.png" alt="clixon sdk" style="width: 180px;"/>

The figure shows the SDK runtime of Clixon.

## Standard Compliance

Standards Clixon partially supports:
- [RFC5277](http://www.rfc-base.org/txt/rfc-5277.txt) NETCONF Event Notifications
- [RFC6020](https://www.rfc-editor.org/rfc/rfc6020.txt) YANG - A Data Modeling Language for the Network Configuration Protocol (NETCONF)
- [RFC6241](http://www.rfc-base.org/txt/rfc-6241.txt) NETCONF Configuration Protocol
- [RFC6242](http://www.rfc-base.org/txt/rfc-6242.txt) Using the NETCONF Configuration Protocol over Secure Shell (SSH)
- [RFC7895](http://www.rfc-base.org/txt/rfc-7895.txt) YANG Module Library
* [RFC7950](http://www.rfc-base.org/txt/rfc-7950.txt) The YANG 1.1 Data Modeling Language
* [RFC7951](http://www.rfc-base.org/txt/rfc-7951.txt) JSON Encoding of Data Modeled with YANG
- [RFC8040](https://tools.ietf.org/html/rfc8040) RESTCONF Protocol
- [RFC8341](http://www.rfc-base.org/txt/rfc-8341.txt) Network Configuration Access Control Model
- [XML 1.0](https://www.w3.org/TR/2008/REC-xml-20081126)
- [Namespaces in XML 1.0](https://www.w3.org/TR/2009/REC-xml-names-20091208)
- [XPATH 1.0](https://www.w3.org/TR/xpath-10)
- [W3C XML XSD](http://www.w3.org/TR/2004/REC-xmlschema-2-20041028)

## Reference

Clixon uses [Doxygen](http://www.doxygen.nl/index.html) for reference documentation.
You need to install doxygen and graphviz on your system.
Build it in the doc directory and point the browser to `.../clixon/doc/html/index.html` as follows:
```
> cd doc
> make doc
> make graphs # detailed callgraphs
```