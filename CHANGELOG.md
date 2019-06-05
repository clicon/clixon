# Clixon Changelog

## 4.0.0 (Upcoming)

### Major New features
* Regexp improvements: Libxml2 XSD, multiple patterns, optimization
  * Support for multiple patterns as described in RFC7950 Section 9.4.7
  * Support for inverted patterns as described in RFC7950 Section 9.4.6
  * Libxml2 support for full XSD matching as alternative to Posix translation
    * Configure with: `./configure --with-libxml2`	
    * Set `CLICON_YANG_REGEXP` to libxml2 (default is posix)
    * Note you need to configure cligen as well with `--with-libxml2`
  * Better compliance with XSD regexps in the default Posix translation regex mode
    * Added `\p{L}` and `\p{N}`
    * Added escaping of `$`
  * Added clixon_util_regexp utility function
  * Added extensive regexp test [test/test_pattern.sh] for both posix and libxml2
  * Added regex cache to type resolution
* Yang "refine" feature supported
  * According to RFC 7950 7.13.2
* Yang "min-element" and "max-element" feature supported
  * According to RFC 7950 7.7.4 and 7.7.5
  * See (tests)[test/test_minmax.sh]
  * The following cornercases are not supported:
    * Check for min-elements>0 for empty lists on top-level
    * Check for min-elements>0 for empty lists in choice/case
* Yang "unique" feature supported
  * According to RFC 7950 7.8.3
  * See (tests)[test/test_unique.sh]
* Persistent CLI history: [Preserve CLI command history across sessions. The up/down arrows](https://github.com/clicon/clixon/issues/79)
  * The design is similar to bash history:
      * The CLI loads/saves its complete history to a file on entry and exit, respectively
      * The size (number of lines) of the file is the same as the history in memory
      * Only the latest session dumping its history will survive (bash merges multiple session history).
      * Tilde-expansion is supported
      * Files not found or without appropriate access will not cause an exit but will be logged at debug level
  * New config options: CLICON_CLI_HIST_FILE with default value `~/.clixon_cli_history`
  * New config options: CLICON_CLI_HIST_SIZE with default value 300.
* New backend startup and upgrade support, see [doc/startup.md] for details
  * Enable with CLICON_XMLDB_MODSTATE config option
  * Check modules-state tags when loading a datastore at startup
    * Check which modules match, and which do not.
  * Loading of "extra" XML, such as from a file.
  * Detection of in-compatible XML and Yang models in the startup configuration.
  * A user can register upgrade callbacks per module/revision when in-compatible XML is encountered (`update_callback_register`).
    * See the [example](example/example_backend.c) and [test](test/test_upgrade_interfaces.sh].
  * A "failsafe" mode allowing a user to repair the startup on errors or failed validation.
  * Major rewrite of `backend_main.c` and a new module `backend_startup.c`
* Datastore files contain RFC7895 module-state information
  * Added modules-state diff parameter to xmldb_get datastore function
  * Set config option `CLICON_XMLDB_MODSTATE` to true
    * Enable this if you wish to use the upgrade feature in the new startup functionality.
  * Note that this adds bytes to your configs
* New xml changelog experimental feature for automatic upgrade
  * Yang module clixon-xml-changelog@2019-03-21.yang based on draft-wang-netmod-module-revision-management-01
  * Two config options control:
    * CLICON_XML_CHANGELOG enables the yang changelog feature
    * CLICON_XML_CHANGELOG_FILE where the changelog resides
* Optimization work
  * Removed O(n^2) in cli expand/completion code
  * Improved performance of validation of (large) lists
  * A scaling of [large lists](doc/scaling) report is added
  * New xmldb_get1() returning actual cache - not a copy. This has lead to some householding instead of just deleting the copy
  * xml_diff rewritten to work linearly instead of O(2)
  * New xml_insert function using tree search. The new code uses this in insertion xmldb_put and defaults. (Note previous xml_insert renamed to xml_wrap_all)
  * A yang type regex cache added, this helps the performance by avoiding re-running the `regcomp` command on every iteration.
  * An XML namespace cache added (see `xml2ns()`)
  * Better performance of XML whitespace parsing/scanning.
	
### API changes on existing features (you may need to change your code)

* Replaced `CLIXON_DATADIR` with two configurable options defining where Clixon installs Yang files.
  * use `--with-yang-installdir=DIR` to install Clixon yang files in DIR
  * use `--with-std-yang-installdir=DIR` to install standard yang files that Clixon may use in DIR 
  * Default is (as before) `/usr/local/share/clixon`
* New clixon-config@2019-06-05.yang revision
  * Added: `CLICON_YANG_REGEXP, CLICON_CLI_TAB_MODE, CLICON_CLI_HIST_FILE, CLICON_CLI_HIST_SIZE, CLICON_XML_CHANGELOG, CLICON_XML_CHANGELOG_FILE`.
  * Renamed: `CLICON_XMLDB_CACHE` to `CLICON_DATASTORE_CACHE` and type changed.
  * Deleted: `CLICON_XMLDB_PLUGIN, CLICON_USE_STARTUP_CONFIG`;
* New clixon-lib@2019-06-05.yang revision
  * Added: ping rpc added (for liveness)
* Added compiled regexp parameter as part of internal yang type resolution functions
  * `yang_type_resolve()`, `yang_type_get()`
* All internal `ys_populate_*()` functions (except ys_populate()) have switched parameters: `clicon_handle, yang_stmt *)`
* Added clicon_handle as parameter to all validate functions
  * Just add `clixon_handle h` to all calls.
* Clixon transaction mechanism has changed which may affect your backend plugin callbacks:
  * Validate-only transactions are terminated by an `end` or `abort` callback. Now all started transactions are terminated either by an `end` or `abort` without exceptions
    * Validate-only transactions used to be terminated by `complete`
  * If a commit user callback fails, a new `revert` callback will be made to plugins that have made a succesful commit. 
    * Clixon used to play the (already made) commit callbacks in reverse order
* Datastore cache and xmldb_get() changes:
  * You need to remove `msd` (last) parameter of `xmldb_get()`:
    * `xmldb_get(h, "running", "/", &xt, NULL)` --> `xmldb_get(h, "running", "/", &xt)`
  * New suite of API functions enabling zero-copy: `xmldb_get0`. You can still use `xmldb_get()`. The call sequence of zero-copy is (see reference for more info):
```
   xmldb_get0(xh, "running", "/interfaces/interface[name="eth"]", 0, &xt, NULL);
   xmldb_get0_clear(h, xt);     # Clear tree from default values and flags 
   xmldb_get0_free(h, &xt);     # Free tree 
```
  * Clixon config option `CLICON_XMLDB_CACHE` renamed to `CLICON_DATASTORE_CACHE` and changed type from `boolean` to `datastore_cache`
  * Type `datastore_cache` have values: nocache, cache, or cache-zerocopy
  * Change code from: `clicon_option_bool(h, "CLICON_XMLDB_CACHE")` to `clicon_datastore_cache(h) == DATASTORE_CACHE`
  * `xmldb_get1` removed (functionality merged with `xmldb_get`)
* Non-key list now not accepted in edit-config (before only on validation)
* Changed return values in internal functions
  * These functions are affected: `netconf_trymerge`, `startup_module_state`, `yang_modules_state_get`
  * They now comply to Clixon validation: Error: -1; Invalid: 0; OK: 1.
* New Clixon Yang RPC: ping. To check if backup is running.
  * Try with `<rpc xmlns="http://clicon.org/lib"><ping/></rpc>]]>]]>`
* Restconf with startup feature will now copy all edit changes to startup db (as it should according to RFC 8040)
* Netconf Startup feature is no longer hardcoded, you need to explicitly enable it (See RFC 6241, Section 8.7)
  * Enable in config file with: `<CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>`, or use `*:*`
* The directory `docker/system` has been moved to `docker/main`, to reflect that it runs the main example.
* xmldb_get() removed "config" parameter:
  * Change all calls to dbget from: `xmldb_get(h, db, xpath, 0|1, &xret, msd)` to `xmldb_get(h, db, xpath, &xret, msd)`
* Structural change: removed datastore plugin and directory, and merged into regular clixon lib code.
  * The CLICON_XMLDB_PLUGIN config option is obsolete, you should remove it from your config file
  * All references to plugin "text.so" should be removed.
  * The datastore directory is removed, code is moved to lib/src/clixon_datastore*.c
  * Removed clixon_backend -x <plugin> command-line options
* Structural C-code change of yang statements:
  * Merged yang_spec and yang_node types into yang_stmt
    * Change all references to types yang_node/yang_spec to yang_stmt
    * Change all yang struct field accesses yn_* and yp_* to ys_* (but see next item for access functions).
  * Added yang access functions
    * Change all y->ys_parent to yang_parent_get(y)
    * Change all y->ys_keyword to yang_keyword_get(y)
    * Change all y->ys_argument to yang_argument_get(y)
    * Change all y->ys_cv to yang_cv_get(y)
    * Change all y->ys_cvec to yang_cvec_get(y) or yang_cvec_set(y, cvv)
  * Removed external direct access to the yang_stmt struct.
* xmldb_get() removed unnecessary config option:
  * Change all calls to dbget from: `xmldb_get(h, db, xpath, 0|1, &xret, msd)` to `xmldb_get(h, db, xpath, &xret, msd)`

* Moved out code from clixon_options.[ch] into a new file: clixon_data.[ch] where non-option data resides.
* Directory change: Moved example to example/main to make room for other examples.
* Removed argc/argv parameters from ca_start plugin API function:
  * You may need to change signatures of your startup in your plugins, eg from:
  ```
    int xxx_start(clicon_handle h, int argc, char **argv)
    {
	return 0;
    }
    static clixon_plugin_api xxx_api = {
        ...
	.ca_start = xxx_start,
  ```
    to:
  ```
    int xxx_start(clicon_handle h)
    {
	return 0;
    }
    static clixon_plugin_api xxx_api = {
        ...
	.ca_start = xxx_start,
  ```
    * If you use argv/argc use `clicon_argv_get()` in the init function instead.
* Changed hash API for better error handling
  * hash_dump, hash_keys, clicon_option_dump have new signatures
* Renamed `xml_insert` to `xml_wrap_all`.
* Added modules-state diff parameter to xmldb_get datastore function for startup scenarios. Set this to NULL in normal cases.
* `rpc_callback_register` added a namespace parameter. Example:
   ```
     rpc_callback_register(h, empty_rpc, NULL, "urn:example:clixon", "empty");
   ```
* Clixon configuration file top-level symbols has changed to `clixon-config`and namespace check is enforced. This means all Clixon configuration files must change from:
  ```
    <config>...</config>
  to:
    <clixon-config xmlns="http://clicon.org/config">...</clixon-config>
  ```
* Strict XML prefixed namespace check. This means all XML namespaces must always be declared by default or prefixed attribute name. There were some cases where this was not enforced. Example, `y` must be declared:
```
  <a><y:b/></a> -->    <a xmlns:y="urn:example:y"><y:b/></a>
```

### Minor changes

* JSON parse and print improvements
  * Integrated parsing with namespace translation and yang spec lookup
* Added CLIgen tab-modes in config option CLICON_CLI_TAB_MODE, which means you can control the behaviour of `<tab>` in the CLI.
* Yang state get improvements
  * Integrated state and config into same tree on retrieval, not separate trees
  * Added cli functions `cli_show_config_state()` and `cli_show_auto_state()` for showing combined config and state info.
  * Added integrated state in the main example: `interface/oper-state`.
  * Added performance tests for getting state, see [test/test_perf_state.sh].
* Improved submodule implementation (as part of [Yang submodule import prefix restrictions #60](https://github.com/clicon/clixon/issues/60)).
  * Submodules share same namespace as modules, which means that functions looking for symbols under a module were extended to also look in that module's included submodules, also recursively (submodules can include submodules in Yang 1.0).
  * Submodules are no longer merged with modules in the code. This is necessary to have separate local import prefixes, for example.
  * New function `ys_real_module()` complements `ys_module()`. The latter gets the top module or submodule, whereas the former gets the ultimate module that a submodule belongs to. 
  * See [test/test_submodule.sh]
* New XMLDB_FORMAT added: `tree`. An experimental record-based tree database for
 direct access of records. 
* Netconf error handling modified
  * New option -e added. If set, the netconf client returns -1 on error.
* A new minimal "hello world" example has been added
* Experimental customized error output strings, see [lib/clixon/clixon_err_string.h]
* Empty leaf values, eg <a></a> are now checked at validation.
  * Empty values were skipped in validation.
  * They are now checked and invalid for ints, dec64, etc, but are treated as empty string "" for string types.
* Added syntactic check for yang status: current, deprecated or obsolete.
* Added `xml_wrap` function that adds an XML node above a node as a wrapper
  * also renamed `xml_insert` to `xml_wrap_all`.
* Added `clicon_argv_get()` function to get the user command-line options, ie the args in `-- <args>`. This is an alternative to using them passed to `plugin_start()`.
* Made Makefile concurrent so that it can be compiled with -jN
* Added flags to example backend to control its behaviour:
  * Start with `-- -r` to run the reset plugin
  * Start with `-- -s` to run the state callback
* Rewrote yang dir load algorithm to follow the algorithm in [FAQ](FAQ(doc/FAQ.md#how-are-yang-files-found) with more precise timestamp checks, etc.
* Ensured you can add multiple callbacks for any RPC, including basic ones.
  * Extra RPC:s will be called _after_ the basic ones.
  * One specific usecase is hook for `copy-config` (see [doc/ROADMAP.md](doc/ROADMAP.md) that can be implemented this way.
* Added "base" as CLI default mode and "cli> " as default prompt.
* clixon-config YAML file has new revision: 2019-03-05.
  * New URN and changed top-level symbol to `clixon-config`
* Removed obsolete `_CLICON_XML_NS_STRICT` variable and `CLICON_XML_NS_STRICT` config option.
* Removed obsolete `CLICON_CLI_MODEL_TREENAME_PATCH` constant
* Added specific clixon_suberrno code: XMLPARSE_ERRNO to identify XML parse errors.
* Removed all dependency on strverscmp
* Added libgen.h for baseline()
	
### Corrected Bugs

* Check cligen tab mode, dont start if CLICON_CLI_TAB_MODE is undefined
* Startup transactions did not mark added tree with XML_FLAG_ADD as it should.
* Restconf PUT different keys detected (thanks @dcornejo) and fixed
  * This was accepted but shouldn't be: `PUT http://restconf/data/A=hello/B -d '{"B":"goodbye"}'`
  * See RFC 8040 Sec 4.5
* Yang Enumeration including space did not generate working CLIgen code, see [Choice with space is not working in CLIgen code](https://github.com/olofhagsand/cligen/issues/24)
* Fixed: [Yang submodule import prefix restrictions #60](https://github.com/clicon/clixon/issues/60)
* Fixed support for multiple datanodes in a choice/case statement. Only single datanode was supported.
* Fixed an ordering problem showing up in validate/commit callbacks. If two new items following each order (yang-wise), only the first showed up in the new-list. Thanks achernavin!
* Fixed a problem caused by recent sorting patches that made "ordered-by user" lists fail in some cases, causing multiple list entries with same keys. NACM being one example. Thanks vratnikov!
* [Restconf does not handle startup datastore according to the RFC](https://github.com/clicon/clixon/issues/74)
* Failure in startup with -m startup or running left running_db cleared.
  * Running-db should not be changed on failure. Unless failure-db defined. Or if SEGV, etc. In those cases, tmp_db should include the original running-db.
* Backend plugin returning NULL was still installed - is now logged and skipped.
* [Parent list key is not validated if not provided via RESTCONF #83](https://github.com/clicon/clixon/issues/83), thanks achernavin22.
* [Invalid JSON if GET /operations via RESTCONF #82](https://github.com/clicon/clixon/issues/82), thanks achernavin22
* List ordering bug - lists with ints as keys behaved wrongly and slow.
* NACM read default rule did not work properly if nacm was enabled AND no groups were defined 
* Re-inserted `cli_output_reset` for what was erroneuos thought to be an obsolete function
  * See in 3.9.0 minro changes: Replaced all calls to (obsolete) `cli_output` with `fprintf`
* Allowed Yang extended Xpath functions (syntax only):
  * re-match, deref, derived-from, derived-from-or-self, enum-value, bit-is-set
* XSD regular expression handling of dash(`-`)
  *: Translate XDS `[xxx\-yyy]` to POSIX `[xxxyyy-]`.
* YANG Anydata treated same as Anyxml 
* Bugfix: [Nodes from more than one of the choice's branches exist at the same time](https://github.com/clicon/clixon/issues/81)
  * Note it may still be possible to load a file with multiple choice elements via netconf, but it will not pass validate.
* Bugfix: Default NACM policies applied even if NACM is disabled
* [Identityref inside augment statement](https://github.com/clicon/clixon/issues/77)
  * Yang-stmt enhanced with "shortcut" to original module
* Yang augment created multiple augmented children (no side-effect)
* XML prefixed attribute names were not copied into the datastore
* [yang type range statement does not support multiple values](https://github.com/clicon/clixon/issues/59)
  * Remaining problem was mainly CLIgen feature. Strengthened test cases in [test/test_type.sh].
  * Also in: [Multiple ranges support](https://github.com/clicon/clixon/issues/78)
* Fixed numeric ordering of lists (again) [https://github.com/clicon/clixon/issues/64] It was previously just fixed for leaf-lists.
* There was a problem with ordered-by-user for XML children that appeared in some circumstances and difficult to trigger. Entries entered by the user did not appear in the order they were entered. This should now be fixed.

## 3.9.0 (21 Feb 2019)

Thanks for all bug reports, feature requests and support! Thanks to [Netgate](https://www.netgate.com) and other sponsors for making Clixon a better tool!

### Major New features
* Correct [W3C XML 1.0 names spec](https://www.w3.org/TR/2009/REC-xml-names-20091208) namespace handling in Restconf and Netconf.
  * See [https://github.com/clicon/clixon/issues/49]
  * The following features are exceptions and still do not support namespaces:
    * Netconf `edit-config xpath select` statement, and all xpath statements
    * Notifications
    * CLI syntax (ie generated commands)
  * The default namespace is ietf-netconf base syntax with uri: `urn:ietf:params:xml:ns:netconf:base:1.0` and need not be explicitly given. 
  * The following example shows changes in netconf and restconf:
    * Accepted pre 3.9 (now not valid):
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
    * Correct 3.9 Netconf RPC:
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
    * Correct 3.9 Restconf request/ reply
    ```
    POST http://localhost/restconf/operations/example:example)
    Content-Type: application/yang-data+json
    {
      "example:input":{
        "x":0
      }
    }
    HTTP/1.1 200 OK
    {
      "example:output": {
        "x": "0",
        "y": "42"
      }
    }
    ```
  * To keep previous non-strict namespace handling (backwards compatible), set CLICON_XML_NS_STRICT to false. Note that this option will be removed asap after 3.9.0.

* An uplift of Yang to conform to RFC7950
  * YANG parser cardinality checked (https://github.com/clicon/clixon/issues/48)
  * More precise Yang validation and better error messages
    * RPC method input parameters validated (https://github.com/clicon/clixon/issues/47)
    * Added bad-, missing-, or unknown-element error messages, instead of operation-failed.
    * Validation of mandatory choice and recursive mandatory containers
  * Support of YANG `submodule, include and belongs-to` and improved `unknown` handling
  * Parsing of standard yang files supported, such as:
    * https://github.com/openconfig/public - except [https://github.com/clicon/clixon/issues/60]. See [test/test_openconfig.sh]
    * https://github.com/YangModels/yang - except vendor-specific specs. See [test/test_yangmodels.sh].
  * Yang load file configure options changed
    * `CLICON_YANG_DIR` is changed from a single directory to a path of directories
      * Note `CLIXON_DATADIR` (=/usr/local/share/clixon) need to be in the list
    * `CLICON_YANG_MAIN_FILE` Provides a filename with a single module filename.
    * `CLICON_YANG_MAIN_DIR` Provides a directory where all yang modules should be loaded.
* NACM (RFC8341)
  * Incoming RPC Message validation is supported (See sec 3.4.4 in RFC8341)
  * Data Node Access validation is supported (3.4.5), _except_:
    * rule-type data-node `path` statements
  * Outgoing notification authorization is _not_ supported (3.4.6)
  * RPC:s are supported _except_:
    * `copy-config`for other src/target combinations than running/startup (3.2.6)
    * `commit` - NACM is applied to candidate and running operations only (3.2.8)
  * Client-side RPC:s are _not_ supported. That is, RPC code that runs in Netconf, Restconf or CLI clients.
  * Recovery user `_nacm_recovery` added.
  * The NACM support is ongoing work and needs performance enhancements and further testing.
* Change GIT branch handling to a single working master branch
  * Develop branched abandoned
  * [Clixon Travis CI]([https://travis-ci.org/clicon/clixon]) continuous integration is now supported.
* Clixon Alpine-based containers
  * [Clixon base container](docker/base).
  * [Clixon system and test container](docker/system) used in Travis CI.
  * See also: [Clixon docker hub](https://hub.docker.com/u/clixon)
	
### API changes on existing features (you may need to change your code)
* XML namespace handling is corrected (see [#major-changes])
  * For backward compatibility set config option  CLICON_XML_NS_LOOSE
  * You may have to manually upgrade existing database files, such as startup-db or persistent running-db, or any other saved XML file.
* Stricter Yang validation (see (#major-changes)):
  * Many hand-crafted validation messages have been removed and replaced with generic validations, which may lead to changed rpc-error messages.
  * Choice validation. Example: In `choice c{ mandatory true; leaf x; }`, `x` was not previously enforced but is now.
* Change all `@datamodel:tree` to `@datamodel` in all CLI specification files
  * More specifically, to the string in new config option: CLICON_CLI_MODEL_TREENAME which has `datamodel` as default.
  * Only applies if CLI code is generated, ie, `CLIXON_CLI_GENMODEL` is true.
* Add `<CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>` to your configuration file, or corresponding CLICON_DATADIR directory for Clixon system yang files.
* Date-and-time type now properly uses ISO 8601 UTC timezone designators.
  * Eg `2008-09-21T18:57:21.003456` is changed to `2008-09-21T18:57:21.003456Z`
* CLICON_XML_SORT option (in clixon-config.yang) has been removed and set to true permanently. Unsorted XML lists leads to slower performance and old obsolete code can be removed.
* Added `username` argument to `xmldb_put()` datastore function for NACM data-node write checks
* Rearranged yang files
  * Moved and updated all standard ietf and iana yang files from example and yang/ to `yang/standard`.
  * Moved clixon yang files from yang to `yang/clixon`
  * New configure option to disable standard yang files: `./configure --disable-stdyangs`
    * This is to make it easier to use standard IETF/IANA yang files in separate directory
  * Renamed example yang from example.yang -> clixon-example.yang
* Switched the order of `error-type` and `error-tag` in all netconf and restconf error messages to comply to RFC order.
* Removed `delete-config` support for candidate db since it is not supported in RFC6241.
* Renamed yang file `ietf-netconf-notification.yang` to `clixon-rfc5277.yang`.
  * Fixed validation problems, see [https://github.com/clicon/clixon/issues/62]
  * Name confusion, the file is manually constructed from the rfc.
  * Changed prefix to `ncevent`
* Yang parser functions have changed signatures. Please check the source if you call these functions.

### Minor changes
* Better XML parser conformance to W3 spec
  * Names lexically correct (NCName)
  * Syntactically Correct handling of '<?' (processing instructions) and '<?xml' (XML declaration)
  * XML prolog syntax for 'well-formed' XML
  * `<!DOCTYPE` (ie DTD) is not supported.
* Command-line options:
  * Added -o "<option>=<value>" command-line option to all programs: backend, cli, netconf, restconf. Any config option from file can be overrided by giving them on command-line.
  * Added -p <dir> command-line option to all programs: backend, cli, netconf, restconf. Adds a new dir to the yang path dir. (same as -o CLICON_YANG_DIR=<dir>)
    * `clixon_cli -p` (printspec) obsolete and replaced
  * `clixon_cli -x` is obsolete and removed.
* Added experimental config option `CLICON_CLI_UTF8` default set to 0. Does not work with scrolling and control editing, see (https://github.com/olofhagsand/cligen/issues/21)
* Added valgrind memory leak tests in testmem.sh for cli, netconf, restconf and backend
  * To run with backend for example: `mem.sh backend`
* Keyvalue datastore removed (it has been disabled since 3.3.3)
* Added clicon_socket_set() and clicon_socket_get() functions for cleaning up backend server and restconf FCGI socket on termination.
* clixon-config YAML file has new revision: 2019-02-06.
* Added new log function: `clicon_log_xml()` for logging XML tree to syslog
* Replaced all calls to (obsolete) `cli_output` with `fprintf`
* Added `make test` from top-level Makefile
* Added `xml_rootchild_node()` lib function as variant of `xml_rootchild()`
* Added new clixon-lib yang module for internal netconf protocol. Currently only extends the standard with a debug RPC.
* Added three-valued return values for several validate functions where -1 is fatal error, 0 is validation failed and 1 is validation OK.
  * This includes: `xmldb_put`, `xml_yang_validate_all`, `xml_yang_validate_add`, `xml_yang_validate_rpc`, `api_path2xml`, `api_path2xpath`
* Added new xml functions for specific types: `xml_child_nr_notype`, `xml_child_nr_notype`, `xml_child_i_type`, `xml_find_type`.
* Added `example_rpc` RPC to example backend
* Renamed `xml_namespace()` and `xml_namespace_set()` to `xml_prefix()` and `xml_prefix_set()`, respectively.
* Changed all make tags --> make TAGS

### Corrected Bugs
* [Issue with bare axis names](https://github.com/clicon/clixon/issues/54)
* Did not check for missing keys in validate. [Key of a list isn't mandatory](https://github.com/clicon/clixon/issues/73)
  * Problem here is that you can still add keys via netconf - since validation is a separate step, but in cli or restconf it should not be possible.
* Partially corrected: [yang type range statement does not support multiple values](https://github.com/clicon/clixon/issues/59).
  * Should work for netconf and restconf, but not for CLI.
* [Range parsing is not RFC 7950 compliant](https://github.com/clicon/clixon/issues/71)
* `xml_cmp()` compares numeric nodes based on string value [https://github.com/clicon/clixon/issues/64]
* `xml_cmp()` respects 'ordered-by user' for state nodes, which violates RFC 7950 [https://github.com/clicon/clixon/issues/63]. (Thanks JDL)
* XML<>JSON conversion problems [https://github.com/clicon/clixon/issues/66]
  * CDATA sections stripped from XML when converted to JSON
* Restconf returns error when RPC generates "ok" reply [https://github.com/clicon/clixon/issues/69]
* XSD regular expression support for character classes [https://github.com/clicon/clixon/issues/68]
  * Added support for \c, \d, \w, \W, \s, \S.
* Removing newlines from XML data [https://github.com/clicon/clixon/issues/65]
* Fixed [ietf-netconf-notification@2008-07-01.yang validation problem #62](https://github.com/clicon/clixon/issues/62)
* Ignore CR(\r) in yang files for DOS files
* Keyword "min" (not only "max") can be used in built-in types "range" and "length" statements.
* Support for empty yang string added, eg `default "";`
* Removed CLI generation for yang notifications (and other non-data yang nodes)
* Some restconf error messages contained `rpc-reply` or `rpc-error` which have now been removed.
* getopt return value changed from char to int (https://github.com/clicon/clixon/issues/58)
* Netconf/Restconf RPC extra input arguments are ignored (https://github.com/clicon/clixon/issues/47)
	
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
* Added cache for modules-state RFC7895 to avoid building new XML every get call
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

