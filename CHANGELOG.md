# Clixon Changelog

## 3.6.0 (Upcoming)
### Major changes:
### Minor changes:
### Corrected Bugs
* Translate xml->json \n correctly

### Major changes:
### Minor changes:

* Use <config> instead of <data> when save/load configuration to file. This
enables saved files to be used as datastore without any editing. Thanks Matt.

* Added Yang "extension" statement. This includes parsing unknown
  statements and identifying them as extensions or not. However,
  semantics for specific extensions must still be added.

* Renamed ytype_id and ytype_prefix to yarg_id and yarg_prefix, respectively

* Added cli_show_version()

### Corrected Bugs


## 3.5.0 (12 February 2018)

### Major changes:
* Major Restconf feature update to compy to RFC 8040. Thanks Stephen Jones for getting right.
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
  * This replaces XML hash experimental code, ie xml_child_hash variables and all xml_hash_ functions have been removed.
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
    > clixon_cli -f /usr/local/etc/routing.conf -1x
    <config>
        <CLICON_CONFIGFILE>/usr/local/etc/routing.xml</CLICON_CONFIGFILE>
        <CLICON_YANG_DIR>/usr/local/share/routing/yang</CLICON_YANG_DIR>
        <CLICON_BACKEND_DIR>/usr/local/lib/routing/backend</CLICON_BACKEND_DIR>
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
  pIf you use the vector arguments of xmldb_get(), replace as follows:
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

