# Clixon Changelog

## 3.9.0 (Preliminary Target: Mid-January 2019)

### Planned new features
* [Roadmap](ROADMAP.md)

### Major New features
* Correct XML namespace handling
  * XML multiple modules was based on non-strict semantics so that yang modules were found by iterating thorugh namespaces until a match was made. This did not adhere to proper [XML namespace handling](https://www.w3.org/TR/2009/REC-xml-names-20091208) as well as strict Netconf and Restconf namespace handling, which causes problems with overlapping names and false positives, and most importantly, with standard conformance.
  * There are still the following non-strict namespace handling:
    * Everything in ietf-netconf base syntax with namespace `urn:ietf:params:xml:ns:netconf:base:1.0` is default and need not be explicitly given
    * edit-config xpath select statement does not support namespaces
    * notifications do not support namespaces.
  * Below see netconf old (but wrong) netconf RPC:
  ```
     <rpc>
       <my-own-method/>
     </rpc> 
     <rpc-reply>
       <route>
         <address-family>ipv4</address-family>
       </route>
     </rpc-reply>
  ```
  This is the currently correct Netconf RPC:
  ```
     <rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"> # xmlns may be ommitted
       <my-own-method xmlns="urn:example:my-own">
     </rpc>
     <rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
       <route xmlns="urn:ietf:params:xml:ns:yang:ietf-routing">
         <address-family>ipv4</address-family>
       </route>
     </rpc-reply>
  ```
  * Another example for restconf rpc with new correct syntax. Note that while Netconf uses xmlns attribute syntax, Restconf uses module name prefix. First the request:
  ```
    POST http://localhost/restconf/operations/example:example)
    Content-Type: application/yang-data+json
    {
      "example:input":{
        "x":0
      }
    }
  ```
  then the reply:
  ```
    HTTP/1.1 200 OK
    {
      "example:output": {
        "x": "0",
        "y": "42"
      }
    }
  ```
  * To keep previous non-strict namespace handling (backwards compatible), set CLICON_XML_NS_STRICT to false.
  * See https://github.com/clicon/clixon/issues/49
* Yang code upgrade (RFC7950)
  * YANG parser cardinality checked (https://github.com/clicon/clixon/issues/48)
    * See https://github.com/clicon/clixon/issues/84
  * RPC method input parameters validated
    * see https://github.com/clicon/clixon/issues/47
  * Support of submodule, include and belongs-to.
  * Parsing of standard yang files supported, such as:
    * https://github.com/openconfig/public - except [https://github.com/clicon/clixon/issues/60].
      * See [test/test_openconfig.sh]
    * https://github.com/YangModels/yang - except vendor-specific specs
      * See [test/test_yangmodels.sh]
  * Improved "unknown" handling
  * More precise Yang validation and better error messages
    * Example: adding bad-, missing-, or unknown-element error messages, instead of operation-failed.
    * Validation of mandatory choice and recursive mandatory containers
  * Yang load file configure options changed
    * `CLICON_YANG_DIR` is changed from a single directory to a path of directories
      * Note CLIXON_DATADIR (=/usr/local/share/clixon) need to be in the list
    * CLICON_YANG_MAIN_FILE Provides a filename with a single module filename.
    * CLICON_YANG_MAIN_DIR Provides a directory where all yang modules should be loaded.
* NACM (RFC8341)
  * Experimental support, no performance enhancements and need further testing
  * Incoming RPC Message validation is supported (3.4.4)
  * Data Node Access validation is supported (3.4.5), except:
    * rule-type data-node path is not supported
  * Outgoing noitification aithorization is _not_ supported (3.4.6)
  * RPC:s are supported _except_:
    * `copy-config`for other src/target combinations than running/startup (3.2.6)
    * `commit` - NACM is applied to candidate and running operations only (3.2.8)
  * Client-side RPC:s are _not_ supported.
  * Recovery user "_nacm_recovery" added.
	
### API changes on existing features (you may need to change your code)
* Added `username` argument on `xmldb_put()` datastore function for NACM data-node write checks
* Rearranged yang files
  * Moved and updated all standard ietf and iana yang files from example and yang/ to `yang/standard`.
  * Moved clixon yang files from yang to `yang/clixon`
  * New configure option to disable standard yang files: `./configure --disable-stdyangs`
    * This is to make it easier to use standard IETF/IANA yang files in separate directory
  * Renamed example yang from example.yang -> clixon-example.yang
* clixon_cli -p (printspec) changed semantics to add new yang path dir (see minor changes).
* Date-and-time type now properly uses ISO 8601 UTC timezone designators.
  * Eg 2008-09-21T18:57:21.003456 is changed to 2008-09-21T18:57:21.003456Z
* Renamed yang file `ietf-netconf-notification@2008-07-01.yang` to `clixon-rfc5277`.
  * Fixed validation problems, see [https://github.com/clicon/clixon/issues/62]
  * Name confusion, the file is manually constructed from the rfc.
  * Changed prefix to `ncevent`
* Stricter YANG choice validation leads to enforcement of structures like: `choice c{ mandatory true; leaf x` statements. `x` was not previously enforced.
* Many hand-crafted validation messages have been removed and replaced with generic validations, which may lead to changed rpc-error messages.
* CLICON_XML_SORT option (in clixon-config.yang) has been removed and set to true permanently. Unsorted XML lists leads to slower performance and old obsolete code can be removed.
* Strict namespace setting can be a problem when upgrading existing database files, such as startup-db or persistent running-db, or any other saved XML file.
* Removed `delete-config` support for candidate db since it is not supported in RFC6241.
* Switched the order of `error-type` and `error-tag` in all netconf and restconf error messages to comply to RFC order.
* Yang parser is stricter (see above) which may break parsing of existing yang specs.
* XML namespace handling is corrected (see above)
  * For backward compatibility set config option  CLICON_XML_NS_LOOSE
* Yang parser functions have changed signatures. Please check the source if you call these functions.
* Add `<CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>` to your configuration file, or corresponding CLICON_DATADIR directory for Clixon system yang files.
* Change all @datamodel:tree to @datamodel in all CLI specification files
  * If you generate CLI code from the model (CLIXON_CLI_GENMODEL).
  * For backward compatibility, define CLICON_CLI_MODEL_TREENAME_PATCH in clixon_custom.h

### Minor changes
* Added make test from top-level
* Added `xml_rootchild_node()` lib function as variant of `xml_rootchild()`
* Added -o "<option>=<value>" command-line option to all programs: backend, cli, netconf, restconf.
  * Any config option from file can be overrided by giving them on command-line.
* Added -p <dir> command-line option to all programs: backend, cli, netconf, restconf.
  * -p adds a new dir to the yang path dir. (same as -o CLICON_YAN_DIR=<dir>)
* Cligen uses posix regex while yang uses XSD. It differs in some aspects. A translator function has been added for `\d` -> `[0-9]` translation, there may be more.
* Added new clixon-lib yang module for internal netconf protocol. Currently only extends the standard with a debug RPC.
* Added three-valued return values for several validate functions where -1 is fatal error, 0 is validation failed and 1 is validation OK.
  * This includes: `xmldb_put`, `xml_yang_validate_all`, `xml_yang_validate_add`, `xml_yang_validate_rpc`, `api_path2xml`, `api_path2xpath`
* Added new xml functions for specific types: `xml_child_nr_notype`, `xml_child_nr_notype`, `xml_child_i_type`, `xml_find_type`.
* Added example_rpc RPC to example backend
* Renamed xml_namespace[_set]() to xml_prefix[_set]()
* Changed all make tags --> make TAGS
* Keyvalue datastore removed (it has been disabled since 3.3.3)
* Removed return value ymodp from yang parse functions (eg yang_parse()).
* New config option: CLICON_CLI_MODEL_TREENAME defining name of generated syntax tree if CLIXON_CLI_GENMODEL is set.
* XML parser conformance to W3 spec
  * Names lexically correct (NCName)
  * Syntactically Correct handling of '<?' (processing instructions) and '<?xml' (XML declaration)
  * XML prolog syntax for 'well-formed' XML
  * <!DOCTYPE (ie DTD) is not supported.

### Corrected Bugs
* Partially corrected: [yang type range statement does not support multiple values](https://github.com/clicon/clixon/issues/59).
  * Should work for netconf and restconf, but not for CLI.
* Fixed again: [Range parsing is not RFC 7950 compliant](https://github.com/clicon/clixon/issues/71)
* xml_cmp() compares numeric nodes based on string value [https://github.com/clicon/clixon/issues/64]
* xml_cmp() respects 'ordered-by user' for state nodes, which violates RFC 7950 [https://github.com/clicon/clixon/issues/63]. (Thanks JDL)
* XML<>JSON conversion problems [https://github.com/clicon/clixon/issues/66]
  * CDATA sections stripped from XML when converted to JSON
* Restconf returns error when RPC generates "ok" reply [https://github.com/clicon/clixon/issues/69]
* xsd regular expression support for character classes [https://github.com/clicon/clixon/issues/68]
  * added support for \c, \d, \w, \W, \s, \S.
* Removing newlines from XML data [https://github.com/clicon/clixon/issues/65]
* [ietf-netconf-notification@2008-07-01.yang validation problem #62](https://github.com/clicon/clixon/issues/62)
* Ignore CR(\r) in yang files for DOS files
* Keyword "min" (not only "max") can be used in built-in types "range" and "length" statements.
* Support for empty yang string added, eg `default "";`
* Removed CLI generation for yang notifications (and other non-data yang nodes)
* Some restconf error messages contained "rpc-reply" or "rpc-error" which have now been removed.
* getopt return value changed from char to int (https://github.com/clicon/clixon/issues/58)
* Netconf/Restconf RPC extra input arguments are ignored (https://github.com/clicon/clixon/issues/47)
	
### Known issues
* debug rpc added in example application (should be in clixon-config).

## 3.8.0 (6 Nov 2018)

### Major New features
* YANG Features
  * Yang 1.1 feature and if-feature according to RFC 7950 7.20.1 and 7.20.2.
  * See https://github.com/clicon/clixon/issues/41
  * Features are declared via CLICON_FEATURE in the configuration file. Example below shows enabling (1) a specific feature; (2) all features in a module; (3) all features in all modules:
   ```
      <CLICON_FEATURE>ietf-routing:router-id</CLICON_FEATURE>
      <CLICON_FEATURE>ietf-routing:*</CLICON_FEATURE>
      <CLICON_FEATURE>*:*</CLICON_FEATURE>
   ```
  * logical combination of features not implemented, eg if-feature "not foo or bar and baz";
  * ietf-netconf yang module added with candidate, validate, startup and xpath features enabled.
* YANG module library 
  * YANG modules according to RFC 7895 and implemented by ietf-yang-library.yang
  * Enabled by configuration option CLICON_MODULE_LIBRARY_RFC7895 - enabled by default
  * RFC 7895 defines a module-set-id. Configure option CLICON_MODULE_SET_ID is set and changed when modules change.
* Yang 1.1 notification support (RFC 7950: Sec 7.16)
* New event streams implementation with replay
  * Generic stream support (both CLI, Netconf and Restconf)
  * Added stream discovery according to RFC 5277 for netconf and RFC 8040 for restconf
    * Enabled by configure options CLICON_STREAM_DISCOVERY_RFC5277 and CLICON_STREAM_DISCOVERY_RFC8040
  * Configure option CLICON_STREAM_RETENTION is default number of seconds before dropping replay buffers
  * See clicon_stream.[ch] for details
  * Restconf stream notification support according to RFC8040
    * start-time and stop-time query parameters

    * Fork fcgi handler for multiple concurrent streams
    * Set access/subscribe base URL with: CLICON_STREAM_URL (default "https://localhost") and CLICON_STREAM_PATH (default "streams")
    * Replay support: start-time and stop-time query parameter support
    * See [apps/restconf/README.md] for more details.
  * Alternative restconf streams using pub/sub enabled by ./configure --enable-publish
    * Set publish URL base with: CLICON_STREAM_PUB (default http://localhost/pub)
  * RFC5277 Netconf replay supported
  * Replay support is only in-memory and not persistent. External time-series DB could be added.

### API changes on existing features (you may need to change your code)
* Netconf hello capability updated to YANG 1.1 RFC7950 Sec 5.6.4
  * Added urn:ietf:params:netconf:capability:yang-library:1.0
  * Thanks @SCadilhac for helping out, see https://github.com/clicon/clixon/issues/39
* Major rewrite of event streams (as described above)
  * If you used old event callbacks API, you need to switch to the streams API
    * See clixon_stream.[ch]
  * Old streams API which needs to be modified:
    * clicon_log_register_callback() removed
    * subscription_add() --> stream_add()
    * stream_cb_add() --> stream_ss_add()	
    * stream_cb_delete() --> stream_ss_delete()
    * backend_notify() and backend_notify_xml() - use stream_notify() instead
  * Example uses "NETCONF" stream instead of "ROUTING"
* clixon_restconf and clixon_netconf changed command-line option from -D to -D `<level>`  aligning with cli and backend

* Unified log handling for all clicon applications using command-line option: `-l e|o|s|f<file>`.
  * The options stand for e:stderr, o:stdout, s: syslog, f:file
  * Added file logging (`-l f` or `-l f<file>`) for cases where neither syslog nor stderr is usefpul.
  * clixon_netconf -S is obsolete. Use `clixon_netconf -l s` instead.
* Comply to RFC 8040 3.5.3.1 rule: api-identifier = [module-name ":"] identifier
  * The "module-name" was a no-op before.
  * This means that there was no difference between eg: GET /restconf/data/ietf-yang-library:modules-state and GET /restconf/data/foobar:modules-state 
* Generilized top-level yang parsing functions
  * Clarified semantics of main yang module:
    * Command-line option -y MUST specify a filename
    * Configure option CLICON_YANG_MODULE_MAIN MUST specify a module name
    * yang_parse() changed to take either filename or module name and revision. 
  * Removed clicon_dbspec_name() and clicon_dbspec_name_set().
  * Replace calls to yang_spec_main() with yang_spec_parse_module(). See for
    example backend_main() and others if you need details.

### Minor changes
* Renamed test/test_auth*.sh tests to test/test_nacm*.sh
* YANG keywords "action" and "belongs-to" implemented by syntactically by parser (but not proper semantics).
* clixon-config YAML file has new revision: 2018-10-21.
* Allow new lines in CLI prompts 
* uri_percent_encode() and xml_chardata_encode() changed to use stdarg parameters
* Added Configure option CLIXON_DEFAULT_CONFIG=/usr/local/etc/clixon.xml as option and in example (so you dont need to provide -f command-line option).
* New function: clicon_conf_xml() returns configuration tree
* Obsoleted COMPAT_CLIV and COMPAT_XSL that were optional in 3.7
* Added command-line option `-t <timeout>` for clixon_netconf - quit after max time.

### Corrected Bugs
* No space after ampersand escaped characters in XML https://github.com/clicon/clixon/issues/52
  * Thanks @SCadilhac
* Single quotes for XML attributes https://github.com/clicon/clixon/issues/51
  * Thanks @SCadilhac
* Fixed https://github.com/clicon/clixon/issues/46 Issue with empty values in leaf-list
  * Thanks @achernavin22 
* Identity without any identityref:s caused SEGV
* Memory error in backend transaction revert
* Set dir /www-data with www-data as owner, see https://github.com/clicon/clixon/issues/37
	
### Known issues
* Netconf/Restconf RPC extra input arguments are ignored
  * https://github.com/clicon/clixon/issues/47
* Yang sub-command cardinality not checked.
  * https://github.com/clicon/clixon/issues/48
* Issue with bare axis names (XPath 1.0) 
  * https://github.com/clicon/clixon/issues/54
* Top-level Yang symbol cannot be called "config" in any imported yang file.
  * datastore uses "config" as reserved keyword for storing any XML whoich collides with code for detecting Yang sanity.
* Namespace name relabeling is not supported.
  * Eg: if "des" is defined as prefix for an imported module, then a relabeling using xmlns is not supported, such as:
```
    <crypto xmlns:x="urn:example:des">x:des3</crypto>
```

## 3.7.0 (22 July 2018)

### Major New features

* YANG "must" and "when" Xpath-basedconstraints according to RFC 7950 Sec 7.5.3 and 7.21.5.
  * Must and when Xpath constrained checked at validation/commit.
* YANG "identity" and "identityref", according to RFC 7950 Sec 7.18 and 9.10.
  * Identities checked at validation/commit.
  * CLI completion support of identity values.
  * Example extended with iana-if-type RFC 7224 interface identities.
* Improved support for XPATH 1.0 according to https://www.w3.org/TR/xpath-10 using yacc/lex,
  * Full suport of boolean constraints for "when"/"must", not only nodesets.
  * See also API changes below.
* CDATA XML support (patch by David Cornejo, Netgate)
  * Encode and decode (parsing) support 
* Added cligen variable translation. Useful for processing input such as hashing, encryption.
  * More info in example and FAQ.
  * Example:
```
cli> translate value HAL
cli> show configuration
translate {
    value IBM;
}
```
### API changes on existing features (you may need to change your code)

* YANG identity, identityref, must, and when validation support may cause applications that had not strictly enforced identities and constraints before.
* Restconf operations changed from prefix to module name.
  * Proper specification for an operation is POST /restconf/operations/<module_name>:<rpc_procedure> HTTP/1.1
  * See https://github.com/clicon/clixon/issues/31, https://github.com/clicon/clixon/pull/32 and https://github.com/clicon/clixon/issues/30
  * Thanks David Cornejo and Dmitry Vakhrushev of Netgate for pointing this out.
* New XPATH 1.0 leads to some API changes and corrections
  * Due to an error in the previous implementation, all XPATH calls on the form `x[a=str]` where `str` is a string (not a number or XML symbol), must be changed to: `x[a='str'] or x[a="str"]`
  * This includes all calls to `xpath_vec, xpath_first`, etc.
  * In CLI specs, calls to cli_copy_config() must change 2nd argument from `x[%s=%s]` to `x[%s='%s']`
  * In CLI specs, calls to cli_show_config() may need to change third argument, eg
    * `cli_show_config("running","text","/profile[name=%s]","name")` to `cli_show_config("running","text","/profile[name='%s']","name")`
  * xpath_each() is removed
  * The old API can be enabled by setting COMPAT_XSL in include/clixon_custom.h and recompile.

* Makefile change: Removed the make include file: clixon.mk and clixon.mk.in
  * These generated the Makefile variables: clixon_DBSPECDIR, clixon_SYSCONFDIR, clixon_LOCALSTATEDIR, clixon_LIBDIR, clixon_DATADIR which have been replaced by generic autoconf variables instead.

* Removed cli callback vector functions. Set COMPAT_CLIV if you need to keep these functions in include/clixon_custom.h.
  * Replace functions as follows in CLI SPEC files:
  * cli_setv --> cli_set
  * cli_mergev --> cli_merge
  * cli_delv --> cli_del
  * cli_debug_cliv --> cli_debug_cli
  * cli_debug_backendv --> cli_debug_backend
  * cli_set_modev --> cli_set_mode
  * cli_start_shellv --> cli_start_shell
  * cli_quitv --> cli_quit
  * cli_commitv --> cli_commit
  * cli_validatev --> cli_validate
  * compare_dbsv --> compare_dbs
  * load_config_filev --> load_config_file
  * save_config_filev --> save_config_file
  * delete_allv --> delete_all
  * discard_changesv --> discard_changes
  * cli_notifyv --> cli_notify
  * show_yangv --> show_yang
  * show_confv_xpath --> show_conf_xpath

* Changed `plugin_init()` backend return semantics: If returns NULL, _without_ calling clicon_err(), the module is disabled.

### Minor changes

* Clixon docker upgrade
  * Updated the docker image build and example to a single clixon docker image.
  * Example pushed to https://hub.docker.com/r/olofhagsand/clixon_example/
* Added systemd example files under example/systemd
* Added util subdir, with dedicated standalone xml, json, yang and xpath parser utility test programs.
* Validation of yang bits type space-separated list value
* Added -U <user> command line to clixon_cli and clixon_netconf for changing user.
  * This is primarily for NACM pseudo-user tests
* Added a generated CLI show command that works on the generated parse tree with auto completion.
  * A typical call is: 	show @datamodel:example, cli_show_auto("candidate", "json");
  * The example contains a more elaborate example.
  * Thanks ngashok for request, see https://github.com/clicon/clixon/issues/24
* Added XML namespace (xmlns) validation
  * for eg <a xmlns:x="uri"><x:b/></a> 
* ./configure extended with --enable-debug flag
  * CFLAGS=-g ./configure deprecated

### Corrected Bugs
* Prefix of rpc was ignored (thanks Dmitri at netgate)
  * https://github.com/clicon/clixon/issues/30
* Added cli return value also for single commands (eg -1)
* Fixed JSON unbalanced braces resulting in assert.

### Known issues
* Namespace name relabeling is not supported.
  * Eg: if "des" is defined as prefix for an imported module, then a relabeling using xmlns is not supported, such as:
```
  <crypto xmlns:x="urn:example:des">x:des3</crypto>
```

## 3.6.1 (29 May 2018)

### Corrected Bugs
* https://github.com/clicon/clixon/issues/23 clixon_cli failing with error
  * The example included a reference to nacm yang file which did not exist and was not used
* Added clixon-config@2018-04-30.yang

## 3.6.0 (30 April 2018)

### Major changes:
* Experimental NACM RFC8341 Network Configuration Access Control Model, see [NACM](README_NACM.md).
  * New CLICON_NACM_MODE config option, default is disabled.
  * New CLICON_NACM_FILE config option, if CLICON_NACM_MODE is "external"
  * Added username attribute to all internal RPC:s from frontend to backend
  * Added NACM backend module in example
* Restructure and more generic plugin API for cli, backend, restconf, and netconf. See example further down and the [example](example/README.md)
  * Changed `plugin_init()` to `clixon_plugin_init()` returning an api struct with function pointers. There are no other hardcoded plugin functions.
  * Master plugins have been removed. Plugins are loaded alphabetically. You can ensure plugin load order by prefixing them with an ordering number, for example.
  * Plugin RPC callback interface have been unified between backend, netconf and restconf.
    * Backend RPC register callback function (Netconf RPC or restconf operation POST) has been changed from:
           `backend_rpc_cb_register()` to `rpc_callback_register()`
    * Backend RPC callback signature has been changed from:
           `int cb(clicon_handle h, cxobj *xe, struct client_entry *ce, cbuf *cbret, void *arg)`
       to:
            `int cb(clicon_handle h, cxobj *xe, struct client_entry *ce, cbuf *cbret, void *arg)`
    * Frontend netconf and restconf plugins can register callbacks as well with same API as backends.
  * Moved specific plugin functions from apps/ to generic functions in lib/
  * New config option CLICON_BACKEND_REGEXP to match backend plugins (if you do not want to load all).
  * Added authentication plugin callback (ca_auth)
    * Added clicon_username_get() / clicon_username_set()
  * Removed some obscure plugin code that seem not to be used (please report if needed!)
    * CLI parse hook
    * CLICON_FIND_PLUGIN
    * clicon_valcb()
    * CLIXON_BACKEND_SYSDIR
    * CLIXON_CLI_SYSDIR	
    * CLICON_MASTER_PLUGIN config variable
  * Example of migrating a backend plugin module:
    * Add all callbacks in a clixon_plugin_api struct
    * Rename plugin_init() -> clixon_plugin_init() and return api as function value
    * Rename backend_rpc_cb_register() -> rpc_callback_register() for any RPC/restconf operation POST calls
```
/* This is old style with hardcoded function names (eg plugin_start) */
int plugin_start(clicon_handle h, int argc, char **argv)
{
    return 0;
}
int
plugin_init(clicon_handle h)
{
   return 0;
}

/* This is new style with all function names in api struct */
clixon_plugin_api *clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api = {
    "example",           /* name */
    clixon_plugin_init,  /* init */
    NULL,                /* start */
    NULL,                /* exit */
    .ca_auth=plugin_credentials   /* restconf specific: auth */
};

clixon_plugin_api *clixon_plugin_init(clicon_handle h)
{
    return &api; /* Return NULL on error */
}
```

* Builds and installs a new restconf library: `libclixon_restconf.so` and clixon_restconf.h
  * The restconf library can be included by a restconf plugin.
  * Example code in example/Makefile.in and example/restconf_lib.c
* Restconf error handling for get, put and post. (thanks Stephen Jones, Netgate)
  * Available both as xml and json (set accept header).
* Proper RFC 6241 Netconf error handling
  * New functions added in clixon_netconf_lib.[ch]
  * Datastore code modified for RFC 6241

### Minor changes:

* INSTALLFLAGS added with default value -s(strip).
  * For debug do: CFLAGS=-g INSTALLFLAGS= ./configure
* plugin_start() callbacks added for restconf
* Authentication
  * Example extended with http basic authentication for restconf
  * Documentation in FAQ.md
* Updated ietf-netconf-acm to ietf-netconf-acm@2018-02-14.yang from RFC 8341
* The Clixon example has changed name from "routing" to "example" affecting all config files, plugins, tests, etc.
  * Secondary backend plugin added
* Removed username to rpc calls (added below)
* README.md extended with new yang, netconf, restconf, datastore, and auth sections.
* The key-value datastore is no longer supported. Use the default text datastore.
* Added username to rpc calls to prepare for authorization for backend:
  * clicon_rpc_config_get(h, db, xpath, xt) --> clicon_rpc_config_get(h, db, xpath, username, xt)
  * clicon_rpc_get(h, xpath, xt) --> clicon_rpc_get(h, xpath, username, xt)
* Experimental: Added CLICON_TRANSACTION_MOD configuration option. If set,
  modifications in validation and commit callbacks are written back
  into the datastore. Requested by Stephen Jones, Netgate.
* Invalid key to api_path2xml gives warning instead of error and quit.	
* Added restconf/operations get, see RFC8040 Sec 3.3.2:
* yang_find_topnode() and api_path2xml() schemanode parameter replaced with yang_class. Replace as follows: 0 -> YC_DATANODE, 1 -> YC_SCHEMANODE

* xml2json: include prefix in translation, so <a:b> is translated to {"a:b" ..}
* Use `<config>` instead of `<data>` when save/load configuration to file. This
enables saved files to be used as datastore without any editing. Thanks Matt, Netgate.

* Added Yang "extension" statement. This includes parsing unknown
  statements and identifying them as extensions or not. However,
  semantics for specific extensions must still be added.

* Renamed ytype_id and ytype_prefix to yarg_id and yarg_prefix, respectively

* Added cli_show_version()

### Corrected Bugs
* Showing syntax using CLI commands was broekn and is fixed.
* Fixed issue https://github.com/clicon/clixon/issues/18 RPC response issues reported by Stephen Jones at Netgate
* Fixed issue https://github.com/clicon/clixon/issues/17 special character in strings can break RPCs reported by David Cornejo at Netgate.
  * This was a large rewrite of XML parsing and output due to CharData not correctly encoded according to https://www.w3.org/TR/2008/REC-xml-20081126. 
* Fixed three-key list entry problem (reported by jdl@netgate)
* Translate xml->json \n correctly
* Fix issue: https://github.com/clicon/clixon/issues/15 Replace whole config

## 3.5.0 (12 February 2018)

### Major changes:
* Major Restconf feature update to comply to RFC 8040. Thanks Stephen Jones of Netgate for getting right.
  * GET: Always return object referenced (and nothing else). ie, GET /restconf/data/X returns X. 
  * GET Added support for the following resources: Well-known, top-level resource, and yang library version,
  * GET Single element JSON lists use {list:[element]}, not {list:element}.
  * PUT Whole datastore
  
### Minor changes:

* Changed signature of plugin_credentials() restconf callback. Added a "user" parameter. To enable authentication and in preparation for access control a la RFC 6536.
* Added RFC 6536 ietf-netconf-acm@2012-02-22.yang access control (but not implemented).
* The following backward compatible options to configure have been _obsoleted_. If you havent already migrated this code you must do this now.
  * `configure --with-startup-compat`. Configure option CLICON_USE_STARTUP_CONFIG is also obsoleted.
  * `configure --with-config-compat`. The template clicon.conf.cpp files are also removed.
  * `configure --with-xml-compat`
  
* New configuration option: CLICON_RESTCONF_PRETTY. Default true. Set to false to get more compact Restconf output.


* Default configure file handling generalized by Renato Botelho/Matt Smith. Config file FILE is selected in the following priority order:
  * Provide -f FILE option when starting a program (eg clixon_backend -f FILE)
  * Provide --with-configfile=FILE when configuring
  * Provide --with-sysconfig=<dir> when configuring, then FILE is <dir>/clixon.xml
  * Provide --sysconfig=<dir> when configuring then FILE is <dir>/etc/clixon.xml
  * FILE is /usr/local/etc/clixon.xml
	
### Corrected Bugs
* yang max keyword was not supported for string type. Corrected by setting "max" to MAXPATHLEN
* Corrected "No yang spec" printed on tty when using leafref in CLI.
* Fixed error in xml2cvec. If a (for example) int8 value has range error (eg 1000), it was treated as an error and the program terminated. Now this is just logged and skipped. Reported by Fredrik Pettai.
	
### Known issues

## 3.4.0 (1 January 2018)

### Major changes:
* Optimized search performance for large lists by sorting and binary search.
  * New CLICON_XML_SORT configuration option. Default is true. Disable by setting to false.
  * Added yang ordered-by user. The default (ordered-by system) will now sort lists and leaf-lists alphabetically to increase search performance. Note that this may change outputs.
  * If you need legacy order, either set CLICON_XML_SORT to false, or set that list to "ordered-by user".
  * This replaces XML hash experimental code, ie xml_child_hash variables and all xmlv_hash_ functions have been removed.
  * Implementation detail: Cached keys are stored in in yang Y_LIST nodes as cligen vector, see ys_populate_list()  

* Datastore cache introduced: cache XML tree in memory for faster get access.
  * Reads are cached. Writes are written to disk.
  * New CLICON_XMLDB_CACHE configuration option. Default is true. To disable set to false.
  * With cache, you cannot have multiple backends (with single datastore). You need to have a single backend.
  * Thanks netgate for proposing this.

* Changed C functional API for XML creation and parsing for better coherency and closer YANG/XML integration. This may require your action.
  * New yang spec parameter has been added to most functions (default NULL) and functions have been removed and renamed. You may need to change the XML calls as follows.
  * xml_new(name, parent) --> xml_new(name, xn_parent, yspec)
  * xml_new_spec(name, parent, spec) --> xml_new(name, parent, spec)
  * clicon_xml_parse(&xt, format, ...) --> xml_parse_va(&xt, yspec, format, ...)
  * clicon_xml_parse_file(fd, &xt, endtag) --> xml_parse_file(fd, endtag, yspec, &xt)
  * clicon_xml_parse_string(&str, &xt) --> xml_parse_string(str, yspec, &xt)
  * clicon_xml_parse_str(str, &xt) --> xml_parse_string(str, yspec, &xt)
  * xml_parse(str, xt) --> xml_parse_string(str, yspec, &xt)
  * Backward compatibility is enabled by (will be removed in 3.5.0:
  ```
      configure --with-xml-compat
  ```
  
### Minor changes:
* Better semantic versioning, eg MAJOR/MINOR/PATCH, where increment in PATCH does not change API.
* Added CLICON_XMLDB_PRETTY option. If set to false, XML database files will be more compact.
* Added CLICON_XMLDB_FORMAT option. Default is "xml". If set to "json", XML database files uses JSON format.
* Clixon_backend now returns -1/255 on error instead of 0. Useful for systemd restarts, for example.
* Experimental: netconf yang rpc. That is, using ietf-netconf@2011-06-01.yang
  formal specification instead of hardcoded C-code.

### Corrected Bugs
* Fixed bug that deletes running on startup if backup started with -m running.
  When clixon starts again, running is lost.
  The error was that the running (or startup) configuration may fail when
  clixon backend starts. 
  The fix now makes a copy of running and copies it back on failure.
* datastore/keyvalue/Makefile was left behind on make distclean. Fixed by conditional configure. Thanks renato@netgate.com.
* Escape " in JSON names and strings and values
  
### Known issues
* Please use text datastore, key-value datastore no up-to-date

## 3.3.3 (25 November 2017)

Thanks to Matthew Smith, Joe Loeliger at Netgate; Fredrik Pettai at
SUNET for support, requests, debugging, bugfixes and proposed solutions.

### Major changes:
* Performance improvements
  * Added xml hash lookup instead of linear search for better performance of large lists. To disable, undefine XML_CHILD_HASH in clixon_custom.h
  * Netconf client was limited to 8K byte messages. New limit is 2^32 bytes.

* XML and YANG-based configuration file.
  * New configuration files have .xml suffix, old have .conf.
  * The yang model is yang/clixon-config.yang.
  * You can run backward compatible mode using `configure --with-config-compat`
  * In backward compatible mode both .xml and .conf works
  * For migration from old to new, a utility is clixon_cli -x to print new format. Run the command and save in configuration file with .xml suffix instead.
  ```
    > clixon_cli -f /usr/local/etc/example.conf -1x
    <config>
        <CLICON_CONFIGFILE>/usr/local/etc/example.xml</CLICON_CONFIGFILE>
        <CLICON_YANG_DIR>/usr/local/share/example/yang</CLICON_YANG_DIR>
        <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
	...
   </config>
  ```
  
* Simplified backend daemon startup modes.
  * The flags -IRCr are replaced with command-line option -s <mode>
  * You use the -s to select the mode. Example: `clixon_backend -s running`
  * You may also add a default method in the configuration file: `<CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>`
  * The configuration option CLICON_USE_STARTUP_CONFIG is obsolete
  * Command-ine option `-I` is replaced with `-s init` 
  * `-CIr` is replaced with `-s running`
  * Use `-s none` if you request no action on startu
  * Backward compatibility is enabled by:
  ```
      configure --with-startup-compat
  ```
  * You can run in backward compatible mode where both -IRCr and -s options works. But if -s is given, -IRCr options willbe ignored.

* Extra XML has been added along with the new startup modes. Requested by Netgate.
  * You can add extra XML with the -c option to the backend daemon on startup:
  ```
      clixon_backend ... -c extra.xml
   ```
  * You can also add extra XML by programming the plugin_reset() in the backend
plugin. The example application shows how.

* Clixon can now be compiled and run on Apple Darwin. Thanks SUNET.

### Minor changes:
* Fixed DESTDIR make install/uninstall and break immediately on errors
* Disabled key-value datastore. Enable with --with-keyvalue
* Removed mandatory requirements for BACKEND, NETCONF, RESTCONF and CLI dirs in the configuration file. If these are not given, no plugins will be loaded of that type.

* Restconf: http cookie sent as attribute in rpc restconf_post operations to backend as "id" XML attribute.
* Added option CLICON_CLISPEC_FILE as complement to CLICON_CLISPEC_DIR to
  specify single CLI specification file, not only directory containing files.
	
* Replaced the following cli_ functions with their original cligen_functions:
	cli_exiting, cli_set_exiting, cli_comment,
	cli_set_comment, cli_tree_add, cli_tree_active,
	cli_tree_active_set, cli_tree.

* Added a format parameter to clicon_rpc_generate_error() and changed error
  printouts for backend errors, such as commit and validate. (Thanks netgate).
  Example of the new format:

```
  > commit
  Sep 27 18:11:58: Commit failed. Edit and try again or discard changes:
  protocol invalid-value Missing mandatory variable: type
```

* Added event_poll() function to check if data is available on specific file descriptor.

* Support for non-line scrolling in CLI, eg wrap lines. Thanks to Jon Loeliger for proposed solution. Set in configuration file with:
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>

### Corrected Bugs
* Added floating point and negative number support to JSON
* When user callbacks such as statedata() call returns -1, clixon_backend no
  longer silently exits. Instead a log is printed and an RPC error is returned.
  Cred to Matt, netgate for pointing this out.

## 3.3.2 (Aug 27 2017)

### Known issues
* Please use text datastore, key-value datastore no up-to-date
* leafref occuring within lists: cli expansion does not work

### Major changes:
* Added support for YANG anyxml. 

* Changed top-level netconf get-config and get to return `<data>` instead of `<data><config>` to comply to the RFC.
  * If you use direct netconf get or get-config calls, you may need to handle the return XML differently.
  * RESTCONF and CLI is not affected.
  * Example: 

```
  Query: 
    <rpc><get/></rpc>  
  New reply: 
    <rpc-reply>
       <data>
          <a/> # Example data model
       </data>
    </rpc-reply>

  Old reply: 
    <rpc-reply>
       <data>
          <config>  # Removed
             <a/>
          </config> # Removed
       </data>
    </rpc-reply>
```

* Added support for yang presence and no-presence containers. Previous default was "presence".
  * Empty containers will be removed unless you have used the "presence" yang declaration.
  * Example YANG without presence: 

```
     container 
        nopresence { 
          leaf j { 
             type string; 
          } 
     }
```

If you submit "nopresence" without a leaf, it will automatically be removed:

```
     <nopresence/> # removed
     <nopresence>  # not removed
        <j>hello</j>
     </nopresence>
```

* Added YANG RPC support for netconf, restconf and CLI. With example rpc documentation and testcase. This replaces the previous "downcall" mechanism.
  * This means you can make netconf/restconf rpc calls
  * However you need to register an RPC backend callback using the backend_rpc_cb_register() function. See documentation and example for more details.
  * Example, the following YANG RPC definition enables you to run a netconf rpc.
```
    YANG:
      rpc myrpc {
         input {
	   leaf name {
	      type string;
           }
         }
      }
    NETCONF:
      <rpc><myrpc><name>hello</name><rpc>
    RESTCONF:
      curl -sS -X POST -d {"input":{"name":"hello"}} http://localhost/restconf/operations/myroute'
```

* Enhanced leafref functionality: 
  * Validation for leafref forward and backward references; 
  * CLI completion for generated cli leafrefs for both absolute and relative paths.
  * Example, relative path:

```
         leaf ifname {
             type leafref {
                 path "../../interface/name";
             }
         }
```
	
* Added state data: Netconf `<get>` operation, new backend plugin callback: "plugin_statedata()" for retreiving state data.
  * You can use netconf: `<rpc><get/></rpc>` and it will return both config and state data.
  * Restconf GET will return state data also, if defined.
  * You need to define state data in a backend callback. See the example and documentation for more details.

### Minor Changes
* Added xpath support for predicate: current(), eg /interface[name=current()/../name]
* Added prefix parsing of xpath, allowing eg /p:x/p:y, but prefix ignored.
* Corrected Yang union CLI generation and type validation. Recursive unions did not work.
* Corrected Yang pattern type escaping problem, ie '\.' did not work properly. This requires update of cligen as well.
* Compliance with RFC: Rename yang xpath to schema_nodeid and syntaxnode to datanode.
* Main yang module (CLICON_YANG_MODULE_MAIN or -y) can be an absolute file name.
* Removed 'margin' parameter of yang_print().
* Extended example with ietf-routing (not only ietf-ip) for rpc operations.
* Added yang dir with ietf-netconf and clixon-config yang specs for internal usage.
* Fixed bug where cli set of leaf-list were doubled, eg cli set foo -> foofoo
* Restricted yang (sub)module file match to match RFC6020 exactly
* Generic map_str2int generic mapping tables
* Removed vector return values from xmldb_get()
* Generalized yang type resolution to all included (sub)modules not just the topmost
	
## 3.3.1 (June 7 2017)

* Fixed yang leafref cli completion for absolute paths.

* Removed non-standard api_path extension from the internal netconf protocol so that the internal netconf is now fully standard.

* Strings in xmldb_put not properly encoded, eg eth/0 became eth.00000
	
## 3.3.0 (May 2017)
	
* Datastore text module is now default.

* Refined netconf "none" semantics in tests and text datastore

* Moved apps/dbctrl to datastore/

* Added connect/disconnect/getopt/setopt and handle to xmldb API

* Added datastore 'text'

* Configure (autoconf) changes
  Removed libcurl dependency
  Disable restconf (and fastcgi) with configure --disable-restconf
  Disable keyvalue datastore (and qdbm) with configure --disable-keyvalue

* Created xmldb plugin api
  Moved qdbm, chunk and  xmldb to datastore keyvalue directories
  Removed all other clixon dependency on chunk code
	
* cli_copy_config added as generic cli command
* cli_show_config added as generic cli command
  Replace all show_confv*() and show_conf*() with cli_show_config()
  Example: replace:
     show_confv_as_json("candidate","/sender");
  with:
     cli_show_config("candidate","json","/sender");
* Alternative yang spec option -y added to all applications
* Many clicon special string functions have been removed
* The netconf support has been extended with lock/unlock
* clicon_rpc_call() has been removed and should be replaced by extending the
  internal netconf protocol. 
  See downcall() function in example/routing_cli.c and 
  routing_downcall() in example/routing_backend.c
* Replace clicon_rpc_xmlput with clicon_rpc_edit_config
* Removed xmldb daemon. All xmldb acceses is made backend daemon. 
  No direct accesses by clients to xmldb API.
  Instead use the rpc calls in clixon_proto_client.[ch]
  In clients (eg cli/netconf) replace xmldb_get() in client code with 
  clicon_rpc_get_config().
  If you use the vector arguments of xmldb_get(), replace as follows:
    xmldb_get(h, db, api_path, &xt, &xvec, &xlen);
  with
    clicon_rpc_get_config(h, dbstr, api_path, &xt);
    xpath_vec(xt, api_path, &xvec, &xlen)

* clicon_rpc_change() is replaced with clicon_rpc_edit_config().
  Note modify argument 5:
     clicon_rpc_change(h, db, op, apipath, "value") 
  to:
     clicon_rpc_edit_config(h, db, op, apipath, `"<config>value</config>"`) 

* xmdlb_put_xkey() and xmldb_put_tree() have been folded into xmldb_put()
  Replace xmldb_put_xkey with xmldb_put as follows:
     xmldb_put_xkey(h, "candidate", cbuf_get(cb), str, OP_REPLACE);
  with
     clicon_xml_parse(&xml, `"<config>%s</config>"`, str);
     xmldb_put(h, "candidate", OP_REPLACE, cbuf_get(cb), xml);
     xml_free(xml);

* Change internal protocol from clicon_proto.h to netconf.
  This means that the internal protocol defined in clixon_proto.[ch] is removed

* Netconf startup configuration support. Set CLICON_USE_STARTUP_CONFIG to 1 to
  enable. Eg, if backend_main is started with -CIr startup will be copied to
  running.

* Added ".." as valid step in xpath

* Use restconf format for internal xmldb keys. Eg /a/b=3,4

* List keys with special characters RFC 3986 encoded.	

* Replaced cli expand functions with single to multiple args
  This change is _not_ backward compatible
  This effects all calls to expand_dbvar() or user-defined
  expand callbacks

* Replaced cli callback functions with single arg to multiple args
  This change is _not_ backward compatible.
  You are affected if you 
  (1) use system callbacks (i.e. in clixon_cli_api.h)
  (2) write your own cli callbacks

  If you use cli callbacks, you need to rewrite cli callbacks from eg:
     `load("Comment") <filename:string>,load_config_file("filename replace");`
  to:
     `load("Comment") <filename:string>,load_config_file("filename", "replace");`

  If you write your own, you need to change the callback signature from;
```
    int cli_callback(clicon_handle h, cvec *vars, cg_var *arg)
```
  to:
```
    int cli_callback(clicon_handle h, cvec *vars, cvec *argv)
```
  and rewrite the code to handle argv instead of arg.
  These are the system functions affected:
  cli_set, cli_merge, cli_del, cli_debug_backend, cli_set_mode, 
  cli_start_shell, cli_quit, cli_commit, cli_validate, compare_dbs, 
  load_config_file, save_config_file, delete_all, discard_changes, cli_notify,
  show_yang, show_conf_xpath

* Added --with-cligen and --with-qdbm configure options
* Added union type check for non-cli (eg xml) input 
* Empty yang type. Relaxed yang types for unions, eg two strings with different length.
	
## (Dec 2016)
* Dual license: both GPLv3 and APLv2
	
## (Feb 2016)
* Forked new clixon repository from clicon

