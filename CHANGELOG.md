# Clixon Changelog

* [7.4.0](#740) Planned: April 2025
* [7.3.0](#730) 30 January 2025
* [7.2.0](#720) 28 October 2024
* [7.1.0](#710) 3 July 2024
* [7.0.1](#701) 3 April 2024
* [7.0.0](#700) 8 March 2024
* [6.5.0](#650) 6 December 2023
* [6.4.0](#640) 30 September 2023
* [6.3.0](#630) 29 July 2023
* [6.2.0](#620) 30 April 2023
* [6.1.0](#610) 19 Feb 2023
* [6.0.0](#600) 29 Nov 2022

## 7.4.0
Planned: April 2025

### Features

* Event handling: replace `select` with `poll`
  * See [Support more than 100 devices](https://github.com/clicon/clixon-controller/issues/174)
* Added new `ca_userdef` callback
* New `clixon-restconf@2025-02-01.yang` revision
  * Added timeout parameter

### Corrected Bugs

* Fixed: [Diff of top-level default values on startup stopped working in 7.3](https://github.com/clicon/clixon/issues/596)
* Fixed: [cli_show_auto don't work](https://github.com/clicon/clixon/issues/595)
* Fixed: [XPath * stopped working in 7.3](https://github.com/clicon/clixon/issues/594)
* Fixed: [Templates with nc:operation "merge" causes bad diffs to be shows](https://github.com/clicon/clixon-controller/issues/187)

## 7.3.0
30 January 2025

Clixon 7.3 features "system-only-config" for secure in-mem handling of selected config data, several cycle optimizations, generic CLI pipe callbacks and lots of bug-fixes.

### Features

* Added support for system-only-config data
  * Store sensitive data in the "system" instead of in datastores
  * New `CLICON_XMLDB_SYSTEM_ONLY_CONFIG` configuration option
  * New `system-only-config` extension
  * New `ca_system_only` backend callback for reading system-only data
* New `clixon-config@2024-11-01.yang` revision
  * Changed: `CLICON_NETCONF_DUPLICATE_ALLOW` to not only check but remove duplicates
  * Added: `CLICON_CLI_PIPE_DIR`
  * Added: `CLICON_XMLDB_SYSTEM_ONLY_CONFIG`
  * Deprecated:  `CLICON_YANG_SCHEMA_MOUNT_SHARE`
* Performance optimization
  * New no-copy `xmldb_get_cache` function for performance, as alternative to `xmldb_get`
  * Optimized duplicate detection of incoming NETCONF requests
* New: CLI generic pipe callbacks
  * Add scripts in `CLICON_CLI_PIPE_DIR`
* New: [feature request: support xpath functions for strings](https://github.com/clicon/clixon/issues/556)
  * Added: `re-match`, `substring`, `string`, `string-length`, `translate`, `substring-before`, `substring-after`, `starts-with`

### C/CLI-API changes on existing features

Developers may need to change their code

* Moved callbacks starting programs from libclixon_cli to example code
  * The functions are: `cli_start_shell` and `cli_start_program`
  * If you need them, add them to your application plugin code instead
* Changed C-API: add `system-only` parameter with default value `0` last:
  * `clixon_json2file()` -> `clixon_json2file(,0)`
  * `clixon_json2cbuf()` -> `clixon_json2cbuf(,0)`

### Corrected Bugs

* Fixed: YANG: added extension/unknown-stmt to rpc/input+output
* Fixed: [Incorrect fields displayed for "show compare" and "commit diff"](https://github.com/clicon/clixon-controller/issues/177)
* Fixed: [Documentation corresponding to specific release](https://github.com/clicon/clixon-controller/issues/178)
  * https://clixon-docs.readthedocs.io/en/stable points to lastest release, starting with 7.2.0
* Fixed: [Backend hangs when doing "process services restart" in the CLI](https://github.com/clicon/clixon-controller/issues/178)
* Fixed: [Autocli: error when empty YANG group and grouping-treeref=true](https://github.com/clicon/clixon/issues/579)
* Fixed: [Mem error when more multiple uses on top level with multiple statements in grouping](https://github.com/clicon/clixon/issues/583)
* Fixed: [Change CLICON_NETCONF_DUPLICATE_ALLOW to remove duplicates](https://github.com/clicon/clixon-controller/issues/160)
* Fixed: Segv in canonical xpath transform
* Fixed: [Error with submodules and feature Interaction](https://github.com/clicon/clixon-controller/issues/158)
* Fixed: [Expansion removes the double quote](https://github.com/clicon/clixon/issues/524)
  *  Add escaping in expand_dbvar instead of automatic in cligen expand
* Fixed: [string length validation doesn't work for the entry "" in case it has default value specified](https://github.com/clicon/clixon/issues/563)
* Fixed: [SNMP: snmpwalk is slow and can timeout](https://github.com/clicon/clixon/issues/404)

## 7.2.0
28 October 2024

The 7.2.0 release features several minor changes and bug-fixes including memory optimizations and package builds.

### Features

* Restconf: Support for list of media in Accept header
* Rearranged YANG top-levels into YANG domains, mounts, and specs
* Deb build script
* Optimize YANG memory
  * Autocli
    * Late evaluation of uses/grouping
  * YANG
    * Added union and extended struct for uncommon fields
    * Removed per-object YANG linenr info
    * Yang-type cache only for original trees (not derived via grouping/augment)
    * Added option `CLICON_YANG_USE_ORIGINAL` to use original yang object in grouping/augment
* New: [CLI simple alias](https://github.com/clicon/cligen/issues/112)
  * See: https://clixon-docs.readthedocs.io/en/latest/cli.html#cli-aliases
* List pagination more ietf-draft compliance
  * Added where, sort-by and direction parameter for configured data
* New `clixon-autocli@2024-08-01.yang` revision
  * Added: disable operation for module rules
* New `clixon-config@2024-08-01.yang` revision
  * Added: `CLICON_YANG_DOMAIN_DIR`
  * Added: `CLICON_YANG_USE_ORIGINAL`

### API changes on existing protocol/config features

Users may have to change how they access the system

* Capability announce urn:ietf:params:netconf:capability:yang-library:1.1 (instead of 1.0)
  * RFC 7950->8526
* New version string on the form: `7.1.0-1+11+g2b25294`
* Restconf: Better RFC compliance with Accept errors: 406 vs 415
* Removed YANG line-number in error-messages for memory optimization
  * Re-enable by setting `YANG_SPEC_LINENR` compile-time option
* NETCONF error returns of failed leafref references, see https://github.com/clicon/clixon/issues/536

### C/CLI-API changes on existing features

Developers may need to change their code

* Added `domain` argument to yang parse functions. Upgrade as follows:
  * `yang_file_find_match(h, m, r, f)` -> `yang_file_find_match(h, m, r, NULL, f)`
  * `yang_parse_module(h, m, r, y, o)` -> `yang_parse_module(h, m, r, y, NULL, o)`
* Replaced `clixon_get_logflags()` with `clixon_logflags_get()`
* New `yn_iter()` yang iterator replaces `yn_each()`
  * Use an integer iterator instead of yang object
  * Replace:
    `y1 = yn_each(y0, y1) { ...`
  * with:
    `int inext = 0;
     y1 = yn_iter(y0, &inext) { ...`
* Add `keyw` argument to `yang_stats()`

### Corrected Bugs

* Fixed: [YANG 'when' does not work in multiple grouping](https://github.com/clicon/clixon/issues/572)
* Fixed: [Error when changing choice/case with different structure](https://github.com/clicon/clixon/issues/568)
* Fixed: [Clixon handle if-feature incorrectly](https://github.com/clicon/clixon/issues/555)
* Fixed: [Clixon fails to load yang with extension](https://github.com/clicon/clixon/issues/554)
* Fixed: Double top-levels in xmldb_get that could occur with xpath containing choice.
* Fixed: [RESTCONF exit on cert error + complex accept](https://github.com/clicon/clixon/issues/551)
* Fixed: [Deletion of leaf in YANG choice removes leaf in a different choice/case](https://github.com/clicon/clixon/issues/542)
* Fixed: Deviated types were resolved in target context, not lexically in deviation context
* Fixed: Signal handling of recv message
   Revert to signal handling in 6.5 that was changed in the netconf uniform handling in 7.0
* Fixed: [NETCONF error reply from failed leafref rquire-instance does not comply to RFC 7950](https://github.com/clicon/clixon/issues/536)

## 7.1.0
3 July 2024

The 7.1.0 release features RESTCONF notifications for native mode,
multi-datastore, and many new configure options.

### Features

* RESTCONF notification for native mode
  * Previously only for FCGI
  * The following does not work: Regular subscription + stop-time
* Optimization of yang schema mount: share yang-specs if all YANGs are equal
  * This reduces memory if many mount-points share YANGs
* Changed datastore modstate to be last in file, as prior to 7.0
* Event priority. Backend socket has higher prio
* Multi-datastore
  * You can split configure datastore into multiple sub-files
  * On edit, only changed sub-files are updated.
  * Curently only implemented for mount-points
* Code for SHA digests.
* Option for automatic lock of datastore on edit-config
  * See [Autolock](https://github.com/clicon/clixon/issues/508)
* Option to set default CLI output format
  * See [Default format should be configurable](https://github.com/clicon/clixon-controller/issues/87)
* CLI support for multiple inline commands separated by semi-colon
* New `clixon-config@2024-04-01.yang` revision
  * Added options:
    - `CLICON_NETCONF_DUPLICATE_ALLOW`: Disable duplicate check in NETCONF messages
    - `CLICON_LOG_DESTINATION`: Default log destination
    - `CLICON_LOG_FILE`: Which file to log to if file logging
    - `CLICON_DEBUG`: Debug flags
    - `CLICON_YANG_SCHEMA_MOUNT_SHARE`: Share same YANGs of several moint-points
    - `CLICON_SOCK_PRIO`: Enable socket event priority
    - `CLICON_XMLDB_MULTI`: Split datastore into multiple sub files
    - `CLICON_CLI_OUTPUT_FORMAT`: Default CLI output format
    - `CLICON_AUTOLOCK`: Implicit locks
* New `clixon-lib@2024-04-01.yang` revision
    - Added: debug bits type
    - Added: xmldb-split extension
    - Added: Default format

### API changes on existing protocol/config features
Users may have to change how they access the system

* Changed intermediate version numbers to be git-style, eg `7.0.0-39` instead of `7.1.0-PRE`
* If `CLICON_XMLDB_MULTI` is set, datastores are stored in a new directory
   * Previously: `CLICON_XMLDB_DIR/<db>_db`
   * New: `CLICON_XMLDB_DIR/<db>d/`
   * In particular, the top-level is moved from `<db>_db` to `<db>.d/0.xml`
   * Backward-compatible:
     * If backend is started with `-s startup` or `-s running` then `<db>_db` is read if `<db>.d/0.xml` is not found
* Autoconf: Openssl mandatory for all configure, not only restconf, due to digest code

### C/CLI-API changes on existing features

Developers may need to change their code

* XML encoding added a `quotes` parameter for attribute encoding, update as follows:
  * `xml_chardata_encode(e, fmt,...)` --> `xml_chardata_encode(e, 0, fmt,...)`
  * `xml_chardata_cbuf_append(cb, str)` --> `xml_chardata_cbuf_append(cb, 0, str)`

### Corrected Bugs

* Fixed: [Invalid api-path errors thrown when displayin qfx family device conf in CLI](https://github.com/clicon/clixon-controller/issues/126)
* Fixed: [Error message from CLI if terminal is modified](https://github.com/clicon/clixon-controller/issues/122)
* Fixed: backend exit when receiving invalid NETCONF get select XPath
  * Added XML encoding to XPaths in `select` attribute
* Fixed: Fail on return errors when reading from datastore
  * Can happen if running is not upgraded for example
* Fixed: [Duplicate config files in configdir causes merge problems -> set ? = NULL](https://github.com/clicon/clixon/issues/510)

## 7.0.1
3 April 2024

Three issues detected in post-testing of 7.0.0 are fixed in the 7.0.1 release

### Corrected Bugs

* Fixed: [NACM create rules do not work properly on objects with default values](https://github.com/clicon/clixon/issues/506)
* Fixed: [CLI: Explicit api-path not encoded correctly](https://github.com/clicon/clixon/issues/504)
* Fixed: [Startup and default of same object causes too-many-elements error](https://github.com/clicon/clixon/issues/503)

## 7.0.0
8 March 2024

Clixon 7.0.0 is a major release with changes to the debug/log/error API, other APIs,
standardized internal framing protocol and many other changes.
It also supports the 1.0 clixon controller release.

### Features

* Changed framing between backend and frontend to RFC6242 "chunked-encoding"
  * Previous a propriatary framing method was used
* Added micro-second resolution to logs via stderr/stdout
* New command-line debug mechanism
  * Separation between subject-area and details
  * Multiple subject-areas
  * Symbolic and combined debug names, example: `-D debug -D detail`
  * See https://clixon-docs.readthedocs.io/en/latest/errors.html#customized-errors for more info
* Made coverity analysis and fixed most of them
  * Some were ignored being for generated code (eg lex) or not applicable
* Feature: [Add support for -V option to give version](https://github.com/clicon/clixon/issues/472)
  * All clixon applications added command-line option `-V` for printing version
  * New ca_version callback for customized version output
* Optimization:
  * Removed reply sanity if `CLICON_VALIDATE_STATE_XML` not set
  * Improved performance of GET and PUT operations
  * Optimized datastore access by ensuring REPORT_ALL in memory and EXPLICIT in file
  * Added mountpoint cache as yang flag `YANG_FLAG_MTPOINT_POTENTIAL`
  * Optimized `yang_find`, especially namespace lookup
  * Filtered state data if not match xpath
* Added reference count for shared yang-specs (schema mounts)
  * Allowed for sharing yspec+modules between several mountpoints
* Added "%k" as extra flag character to api-path-fmt

### API changes on existing protocol/config features
Users may have to change how they access the system

* Changed framing between backend and frontend to RFC6242 "chunked-encoding"
  * Should only affect advanced usage between clixon frontend and backend
  * This should allow standard netconf utilities to be used as frontend (may be some caveats)
* Revert the creators attribute feature introduced in 6.2. It is now obsoleted.
  It is replaced with a configured `creators` and user/application semantics
* New `clixon-lib@2024-01-01.yang` revision
  * Replaced container creators to grouping/uses
* New `clixon-config@2024-01-01.yang` revision
  * Changed semantics:
    * `CLICON_VALIDATE_STATE_XML` - disable return sanity checks if false
  * Marked as obsolete:
    * `CLICON_DATASTORE_CACHE` Replaced with enhanced datastore read API
    * `CLICON_NETCONF_CREATOR_ATTR` reverting 6.5 functionality

### C/CLI-API changes on existing features
Developers may need to change their code

* Rename function `xml_yang_minmax_recurse()` -> `xml_yang_validate_minmax()`
* Modified msg functions for clearer NETCONF 1.0 vs 1.1 API:
  * `clicon_rpc1` --> `clixon_rpc10`
  * `clicon_msg_send1` --> `clixon_msg_send10`
  * `clicon_msg_rcv` and `clicon_msg_decode` --> `clixon_msg_rcv11`
    * Rewrite by calling `clixon_msg_rcv11` and explicit xml parsing
  * `clicon_msg_rcv1` --> `clixon_msg_rcv10`
* Added `yspec` parameter to `api_path_fmt2api_path()`:
  * `api_path_fmt2api_path(af, c, a, c)` --> `api_path_fmt2api_path(af, c, yspec, a, c)`
* Added flags parameter to default functions:
  * `xml_default_recurse(...)` -> `xml_default_recurse(..., 0)`
  * `xml_defaults_nopresence(...)` -> `xml_default_nopresence(..., 0)`
    * Also renamed (_defaults_ -> _default_)
* Changed function name: `choice_case_get()` -> `yang_choice_case_get()`
* New `clixon-lib@2024-01-01.yang` revision
  * Removed container creators, reverted from 6.5
* Changed ca_errmsg callback to a more generic variant
  * Includes all error, log and debug messages
  * See [Customized NETCONF error message](https://github.com/clicon/clixon/issues/454)
  * See https://clixon-docs.readthedocs.io/en/latest/errors.html#customized-errors for more info
* Refactoring basic clixon modules and some API changes
  * Changes marked in code with `COMPAT_6_5`
    * Most common functions have backward compatible macros through the 6.6 release
  * Handle API
    * Renamed `clicon_handle` -> `clixon_handle`
    * `clicon_handle_init()` -> `clixon_handle_init()
    * `clicon_handle_exit()` -> `clixon_handle_exit()
  * Log/Debug API
    * Changed function names. You need to rename as follows:
      * `clicon_log_init()` -> `clixon_log_init(h,)` NOTE added "clixon_handle h"
      * `clicon_log()` -> `clixon_log(h,)`   NOTE added "clixon_handle h"
      * `clixon_debug_init(d, f)` -> `clixon_debug_init(h, )` NOTE h added, f removed
      * `clicon_log_xml()` -> `clixon_debug_xml(h,)` NOTE added "clixon_handle h"
      * `clixon_debug_xml()` -> `clixon_debug_xml(h,)` NOTE added "clixon_handle h"
  * Error API:
    * Added `clixon_err_init(h)` function
    * Renaming, make the following changes:
      * `clicon_err()` -> `clixon_err()`
      * `clicon_err_reset()` -> `clixon_err_reset()`
      * `clicon_strerror(int)` -> `clixon_err_str()`
      * `clicon_netconf_error(h, x, fmt)` -> clixon_err_netconf(h, OE_XML, 0, x, fmt)`
      * `netconf_err2cb(...)` --> `netconf_err2cb(h, ...)`
      * Likewise for some other minor functions: `clicon_err_*` -> `clixon_err_*`
    * Replaced global variables with access functions. Replace variables with functions as follows:
      * `clicon_errno`    -> `clixon_err_category()`
      * `clicon_suberrno` -> `clixon_err_subnr()`
      * `clicon_err_reason`   -> `clixon_err_reason()`
  * Changed process API:
      * `clixon_proc_socket(...)` --> `clixon_proc_socket(h, ..., sockerr)`

### Corrected Bugs

* Fixed: [If services add duplicate entries, controller does not detect this](https://github.com/clicon/clixon-controller/issues/107)
* Fixed: [Problems with diff of YANG lists ordered-by user](https://github.com/clicon/clixon/issues/496)
* Fixed: [show compare does not show correct diff while load merge xml](https://github.com/clicon/clixon-controller/issues/101)
* Fixed: [commit goes 2 times](https://github.com/clicon/clixon/issues/488)
* Fixed: Problem with cl:ignore attribute for show compare
* Fixed: [yang_enum_int_value() fails if no explicit values are assigned to enums](https://github.com/clicon/clixon/issues/483)
  Remaining work: `yang_enum2valstr()`
* Fixed: [show compare/diff problems with sorted-by user](https://github.com/clicon/clixon/issues/482)
* Fixed: [Choice and Leafref](https://github.com/clicon/clixon/issues/469)
* Fixed: [Problem deleting non-last list element if ordered-by user](https://github.com/clicon/clixon/issues/475)
* Fixed: [Tab completion mounted devices with lists](https://github.com/clicon/clixon-controller/issues/72)
* Fixed: kill-session cleanup when client none existant, and for all db:s
* Fixed: [Using the characters '<' and '>' might cause an invalid diff](https://github.com/clicon/clixon-controller/issues/73)

## 6.5.0
6 December 2023

Clixon 6.5 includes bugfixes, moved out utility functions and some API changes.

### API changes on existing protocol/config features
Users may have to change how they access the system

* All clixon test utilities in util/ have been moved to a separate repo: clicon/clixon-util
  * To run tests you need to clone, build and install them separately
* Moved and split install of main example config file
  * From `/usr/local/etc/example.xml` to `/usr/local/etc/clixon/example.xml`
  * Added `/usr/local/etc/clixon/example/autocli.xml` and `/usr/local/etc/clixon/example/restconf.xml`

### C/CLI-API changes on existing features
Developers may need to change their code
p
* Changed return value of `xml_add_attr` from 0/-1 to xa/NULL
  * You need to change eg `if (xml_add_attr < 0)` to if (xml_add_attr == NULL)`
* Changed signature of `clicon_netconf_error()` and `netconf_err2cb()`
  * You need to add the clixon handle as first parameter:
    * `clicon_netconf_error(...)` --> `clixon_netconf_error(h, ...)`
    * `netconf_err2cb(...)` --> `netconf_err2cb(h, ...)`
* Changed function name for `clicon_debug` functions. You need to rename as follows:
  * clicon_debug() -> clixon_debug()
  * clicon_debug_init() -> clixon_debug_init()
  * clicon_debug_get() -> clixon_debug_get()
  * clicon_debug_xml() -> clixon_debug_xml()
  * There are backward compatible macros during a transition period

### Minor features

* New feature: [Customized NETCONF error message](https://github.com/clicon/clixon/issues/454)
  * Added new callback `.ca_errmsg`
  * See https://clixon-docs.readthedocs.io/en/latest/errors.html#customized-errors for more info
* New `clixon-config@2023-11-01.yang` revision
  * Added `CLICON_NETCONF_CREATOR_ATTR` option
* New `clixon-lib@2023-11-01.yang` revision
  * Added ignore-compare extension
  * Added creator meta configuration

### Corrected Bugs

* Fixed: [NACM paths don't work for mounted YANG models](https://github.com/clicon/clixon-controller/issues/62)
* Fixed: [cl:creator attribute must be persistent](https://github.com/clicon/clixon-controller/issues/54)
* Fixed: [Does clixon cli support autocompletion for leafrefs pointed to another module?](https://github.com/clicon/clixon/issues/455)
* Fixed: [commit diff sometimes includes namespace in output](https://github.com/clicon/clixon-controller/issues/44)

## 6.4.0
30 September 2023

This releases is mainly for bugfixes and improvements of existing functionality, such as CLI output pipes.

### Minor features

* New `clixon-autocli@2023-09-01.yang` revision
  * Added argument to alias extension
* CLI show compare example function:
  * Improved diff algorithm for XML and TEXT/curly, replaced UNIX diff with structural in-mem algorithm
* JSON: Added unicode BMP support for unicode strings as part of fixing (https://github.com/clicon/clixon/issues/453)
* Example cli pipe grep command quotes vertical bar for OR function
* Added: [Feature request: node's alias for CLI](https://github.com/clicon/clixon/issues/434)
   * Note: "Skip" is for all nodes, but "Alias" is only for leafs
* New command-line option for dumping configuration options for all clixon applications after load
  * Syntax is `-C <format>`
  * Example: `clixon_backend -1C json`
* Removed sending restconf config inline using -R when CLICON_BACKEND_RESTCONF_PROCESS=true
  * Define RESTCONF_INLINE to revert
* Clarified clixon_cli command-line: `clixon_cli [options] [commands] [-- extra-options]`

### C/CLI-API changes on existing features
Developers may need to change their code

* Renamed `clixon_txt2file()` to `clixon_text2file()`
* Changed parameters of example clispec function `compare_dbs()`
  * New parameters are: `db1`, `db2`, `format`
* Add `fromroot` parameter to `cli_show_common()`
  * `cli_show_common(...xpath...)` --> `cli_show_common(...xpath,0...)`
* Low-level message functions added `descr` argument for better logging
  * In this way, message debugs in level 2 are more descriptive
  * The descr argument can be set to NULL for backward-compability, see the following translations:
    * `clicon_rpc(s, ...)` --> `clicon_rpc(s, NULL, ...)`
    * `clicon_rpc1(s, ...)` --> `clicon_rpc1(s, NULL, ...)`
    * `clicon_msg_send(s, ...)` --> `clicon_msg_send(s, NULL, ...)`
    * `clicon_msg_send1(s, ...)` --> `clicon_msg_send1(s, NULL, ...)`
    * `clicon_msg_rcv(s, ...)` --> `clicon_msg_rcv(s, NULL, ...)`
    * `clicon_msg_rcv1(s, ...)` --> `clicon_msg_rcv1(s, NULL, ...)
    * `clicon_msg_notify_xml(h, s, ...)` --> `clicon_msg_notify_xml(h, s, NULL, ...)`
    * `send_msg_reply(s, ...)` --> `send_msg_reply(s, NULL, ...)`
    * `clixon_client_lock(s, ...)` --> `clixon_client_lock(s, NULL, ...)`
    * `clixon_client_hello(s, ...)` --> `clixon_client_hello(s, NULL, ...)`

* CLI pipe function: added arg to `pipe_tail_fn()`

### Corrected Bugs

* Fixed: ["show compare" and "show compare | display cli" differs #23](https://github.com/clicon/clixon-controller/issues/23)
* Fixed: [JSON backslash string decoding/encoding not correct](https://github.com/clicon/clixon/issues/453)
* Fixed: [CLI show config | display <format> exits over mountpoints with large YANGs](https://github.com/clicon/clixon-controller/issues/39)
  * JSON string fixed according to RFC 8259: encoding/decoding of escape as defined in Section 8
  * No need to bind for xml and json, only cli and text
* Fixed several issues with including multiple configure-files in a config-directory, including overwriting of structured sub-configs.
* Fixed: [YANG error when poking on EOS configuration](https://github.com/clicon/clixon-controller/issues/26)
* Fixed: [CLICON_CONFIGDIR with external subsystems causes endless looping](https://github.com/clicon/clixon/issues/439)
* Fixed: ["show configuration devices" and "show configuration devices | display cli" differs](https://github.com/clicon/clixon-controller/issues/24)
* Fixed: [Configuring Juniper PTX produces CLI errors](https://github.com/clicon/clixon-controller/issues/19)
* Fixed: CLI output pipes: Add `CLICON_PIPETREE` to any cli files, not just the first

## 6.3.0
29 July 2023

Clixon 6.3 introduces CLI output pipes and multiple updates and optimizations, primarily to the CLI.

### New features

* CLI output pipes
  * Building on a new CLIgen feature
  * See https://clixon-docs.readthedocs.io/en/latest/cli.html#output-pipes

### API changes on existing protocol/config features
Users may have to change how they access the system

* New `clixon-config@2023-05-01.yang` revision
  * Added options: `CLICON_CONFIG_EXTEND`
  * Moved datastore-format datastype to clixon-lib
* New `clixon-lib@2023-05-01.yang` revision
  * Restructured and extended stats rpc to schema mountpoints
  * rpc `<stats>` is not backward compatible
* New `clixon-autocli@2023-05-01.yang` revision
  * New `alias` and `skip` extensions (NOTE: just added in YANG, not implemented)
  * New `grouping-treeref` option

### C/CLI-API changes on existing features
Developers may need to change their code

* Added `uid`, `gid` and `fdkeep` parameters to `clixon_process_register()` for drop privs
* Added output function to JSON output:
  * `xml2json_vec(...,skiptop)` --> `xml2json_vec(..., cligen_output, skiptop)`
* `yang2cli_yspec` removed last argument `printgen`.
* Removed obsolete: `cli_auto_show()`

### Minor features

* Autocli optimization feature for generating smaller CLISPECs for large YANGs using treerefs
   * New `grouping-treeref` option added to clixon-autocli.yang
   * Default is disabled, set to true to generate smaller memory footprint of clixon_cli
* Changed YANG uses/grouping to keep uses statement and flag it with YANG_FLAG_USES_EXP
* Removed  extras/ and build-root/ build code since they are not properly maintained
* Refactored cli-syntax code to use cligen pt_head instead (long overdue)
* Modified backend exit strategy so that 2nd ^C actually exits
* Performance: A change in the `merge` code made "co-located" config and non-config get retrieval go considerable faster. This is done by a specialized `xml_child_each_attr()` function.
* CLI: Added `show statistics` example code for backend and CLI memory stats
* [Support yang type union with are same subtypes with SNMP](https://github.com/clicon/clixon/pull/427)
* Removed obsolete compile options introduced in 6.1:
  * `NETCONF_DEFAULT_RETRIEVAL_REPORT_ALL`
  * `AUTOCLI_DEPRECATED_HIDE`

### Corrected Bugs

* Fixed: [xpath // abbreviation does not work other than on the top-level](https://github.com/clicon/clixon/issues/435)
* Fixed: [if-feature always negative if imported from another module](https://github.com/clicon/clixon/issues/429)
* Fixed autocli edit modes for schema mounts

## 6.2.0
30 April 2023

Clixon 6.2.0 brings no new major feature changes, but completes YANG
schema mount and other features required by the clixon controller
project, along with minor improvements and bugfixes.

### API changes on existing protocol/config features
Users may have to change how they access the system

* Changed `configure --with-cligen=dir`
  * <dir> is considered as `DESTDIR` and consider cligen installed under `DESTDIR/PREFIX`
  * Changed from: consider cligen installed under `<dir>`
* New `clixon-config@2023-03-01.yang` revision
  * Added options:
    * `CLICON_RESTCONF_NOALPN_DEFAULT`
    * `CLICON_PLUGIN_DLOPEN_GLOBAL`
  * Extended datastore-format with CLI and text
* New `clixon-lib@2023-03-01.yang` revision
  * Added creator meta-object

### C/CLI-API changes on existing features
Developers may need to change their code

* C-API
  * `clixon_xml2file` and `clixon_xml2cbuf` added `prefix` argument
    * Example application is to add "+"/"-" for diffs
    * Example change:
      * `clixon_xml2file(f,x,p,f,s,a)` -> `clixon_xml2file(f,x,p,NULL,f,s,a)`
      * `clixon_xml2cbuf(c,x,l,p,d,s)` -> `clixon_xml2cbuf(c,x,l,p,NULL,d,s)`
  * `xmldb_validate` is removed. Yang checks should be enough, remnant of time before YANG checks.
  * `xml_diff`: removed 1st `yspec` parameter
  * `xml2xpath()`: Added `int apostrophe` as 4th parameter, default 0
    * This is for being able to choose single or double quote as xpath literal quotes
  * `clicon_msg_rcv`: Added `intr` parameter for interrupting on `^C` (default 0)
  * Renamed include file: `clixon_backend_handle.h`to `clixon_backend_client.h`
  * `candidate_commit()`: validate_level (added in 6.1) marked obsolete

### Minor features

* Adjusted to Openssl 3.0
* Unified netconf input function
  * Three different implementations were used in external, internal and controller code
    * Internal netconf still not moved to unified
  * The new clixon_netconf_input API unifies all three uses
  * Code still experimental controlled by `NETCONF_INPUT_UNIFIED_INTERNAL`
* RFC 8528 YANG schema mount
  * Made cli/autocli mount-point-aware
* Internal NETCONF (client <-> backend)
  * Ensure message-id increments
  * Separated rpc from notification socket in same session
* Restconf: Added fallback mechanism for non-ALPN HTTPS
  * Set `CLICON_RESTCONF_NOALPN_DEFAULT` to `http/2` or `http/1.1`
  * For http/1 or http/2 only, that will be the default if no ALPN is set.
* Fixed: [Add support decimal64 for SNMP](https://github.com/clicon/clixon/pull/422)

### Corrected Bugs

* Fixed RESTCONF race conditions on SSL_shutdown sslerr ZERO_RETURN appears occasionally and exits.
* Fixed: RESTCONF: some client cert failure leads to restconf exit. Instead close and continue

## 6.1.0
19 Feb 2023

The Clixon 6.1 release completes Network monitoring (RFC 6022) and introduces a first version of YANG schema mount (RFC 8528). The main focus has been interoperability and basic support for the ongoing [Clixon controller](https://github.com/clicon/clixon-controller) work.

### New features

* YANG schema mount RFC 8528
  * The primary use-case is the clixon-controller but can be used independently
  * New plugin callback: `ca_yang_mount`
    * To specify which YANG modules should be mounted
  * New plugin callback: `ca_yang_patch`
    * A method to patch a YANG module
  * To enable yang mounts, set new option `CLICON_YANG_SCHEMA_MOUNT` to `true`
  * Restrictions:
    * Only schema-ref=inline, not shared-schema
    * Mount-points must be presence containers, regular containers or lists are not supported.
* Netconf monitoring RFC 6022
  * This is part 2, first part was in 6.0
  * Datastores, sessions and statistics
    * Added clixon-specific transport identities: cli, snmp, netconf, restconf
    * Added source-host from native restonf, but no other transports
    * Hello statistics is based on backend statistics, hellos from RESTCONF, SNMP and CLI clients are included and dropped external NETCONF sessions are not
    * RFC 6022 "YANG Module for NETCONF Monitoring"
  * See [Feature Request: Support RFC 6022 (NETCONF Monitoring)](https://github.com/clicon/clixon/issues/370)

### API changes on existing protocol/config features

Users may have to change how they access the system

* Obsolete config options given in the configuration file are considered an error
* New `clixon-config@2022-12-01.yang` revision
  * Added option: 'CLICON_YANG_SCHEMA_MOUNT`
  * Removed obsolete option: `CLICON_MODULE_LIBRARY_RFC7895`
* clixon-lib,yang
  * Moved all extended internal NETCONF attributes to the clicon-lib namespace
    * These are: content, depth, username, autocommit, copystartup, transport, source-host, objectcreate, objectexisted.
  * The internal attributes are documented in https://clixon-docs.readthedocs.io/en/latest/netconf.html
* With-defaults default retrieval mode has changed from `REPORT-ALL` to `EXPLICIT`
  * This means that all get operations without `with-defaults` parameter do no longer
    return implicit default values, only explicitly set values.
  * Applies to NETCONF `<get>`, `<get-config>` and RESTCONF `GET`
  * To keep backward-compatible behavior, define option `NETCONF_DEFAULT_RETRIEVAL_REPORT_ALL` in `include/clixon_custom.h`
  * Alternatively, change all get operation to include with-defaults parameter `report-all`

### C/CLI-API changes on existing features
Developers may need to change their code

* Changed docker builds
  * `clixon-test` built in `docker/test`
    * Renamed from `clixon-system` built in `docker/main`
  * `clixon-example` built in `docker/example`
    * Added netconf ssh subsystem
    * Renamed from `clixon` built in `docker/base`
* C-API
  * `xml2xpath()`: Added `int spec` as third parameter, default 0
    * This was for making an xpath to a yang-mount point (only for yang-mount)
    * Example change:
      * `xml2xpath(x, n, xp)` -> `xml2xpath(x, n, 0, xp)`
  * `xml_bind_*()` functions: Added `clicon_handle h` as first parameter
    * Example change:
      * `xml_bind_yang(x, y, yp, xe)` -> `xml_bind_yang(h, x, y, yp, xe)` ->
  * `xmldb_get0()`: Added `with-defaults` parameter, default 0
    * Example change:
       * `xmldb_get0(0, db, yb, n, xp, c, x, m, x)` -> `xmldb_get0(0, db, yb, n, xp, c, WITHDEFAULTS_REPORT_ALL, x, m, x)`
  * `candidate_commit()`: Add myid as fourth and validate_level as fifth parameter, default 0
    * Example change:
       * `candidate_commit(h, x, d, c)` -> `candidate_commit(h, x, d, 0, VL_FULL, c)`
  * `xpath_vec_flag()`: Changed type of sixth `veclen` parameter to `size_t *`
  * `clicon_log_xml()`: All calls changed to new function `clicon_debug_xml()`
  * `clixon_proc_socket()`: Added `sock_flags` parameter

### Minor features

* Misc. build fixes encountered when cross-compiling by @troglobit in https://github.com/clicon/clixon/pull/418
* Update FAQ.md hello world example url by @jarrodb in https://github.com/clicon/clixon/pull/419
* Done: [Request to suppress auto-completion for "deprecated" / "obsolete" status and warn the user.](https://github.com/clicon/clixon/issues/410)
  * Implemented by:
    * Not generating any autocli syntax for obsolete YANG statements,
    * Hide statements for deprecated YANG statements.
* New plugin callbacks
  * `ca_yang_mount` - see the RFC 8528 support
  * `ca_yang_patch` - for modifying existing YANG modules
* Changed debug levels in `clicon_debug()` to be based on maskable flags:
  * Added flag names: `CLIXON_DBG_*`
  * Added maskable flags that can be combined when debugging:
    * `DEFAULT` = 1: Basic debug message, espcially initialization
    * `MSG` = 2: Input and output packets, read datastore
    * `DETAIL` = 4: xpath parse trees, etc
    * `EXTRA` = 8: Extra detailed logs, message dump in hex
* Added `ISO/IEC 10646` encodings to XML parser: `&#[0-9]+;` and `&#[0-9a-fA-F]+;`
* Added `CLIXON_CLIENT_SSH` to client API to communicate remotely via SSH netconf sub-system

### Corrected Bugs

* Added translation from Yang type to SNMP type by @StasSt-siklu in https://github.com/clicon/clixon/pull/406
* Fixed: [State XML validation error when CLICON_MODULE_LIBRARY_RFC7895=true and ietf-yang-library@2019-01-04 is loaded](https://github.com/clicon/clixon/issues/408)
* Fixed: [SNMP: snmpwalk is slow and can timeout #404 ](https://github.com/clicon/clixon/issues/404)
* Fixed: [SNMP accepts only u32 & u64 #405](https://github.com/clicon/clixon/issues/405)
* Fixed: [Yang leaves without smiv2:oid directive are not shown well in snmpwalk #398](https://github.com/clicon/clixon/issues/398)
  * Yang leaves without smiv2:oid directive are not shown well in]… by @doron2020 in https://github.com/clicon/clixon/pull/402

* Fixed: [Netconf commit confirm session-id mismatch #407](https://github.com/clicon/clixon/issues/407)
* Fixed: Initialized session-id to 1 instead of 0 following ietf-netconf.yang
* Fixed: [snmpwalk doesn't show properly SNMP boolean values which equal false](https://github.com/clicon/clixon/issues/400)
* Fixed: yang-library: Remove revision if empty instead of sending empty revision
  * This was a change from RFC 7895 to RFC 8525
* Fixed: [locally scoped YANG typedef in grouping does not work #394](https://github.com/clicon/clixon/issues/394)
* Fixed: [leafref in new type no work in union type](https://github.com/clicon/clixon/issues/388)
* Fixed: [must statement check int value failed](https://github.com/clicon/clixon/issues/386)
* Fixed: [Defaults in choice does not work properly](https://github.com/clicon/clixon/issues/390)
* Fixed: [Netconf monitoring](https://github.com/clicon/clixon/issues/370)
  - Announce module capability
  - Return origin Yang file in get-schema

## 6.0.0
29 Nov 2022

The 6.0 release features confirmed-commit and an initial version of
netconf monitoring along with many minor changes and bug fixes.

### New features

* Confirmed-commit capability
  * Standards
    * RFC 4741 "NETCONF Configuration Protocol": Section 8.4
    * RFC 6241 "Network Configuration Protocol (NETCONF)": Section 8.4
  * Features
    * `:confirmed-commit:1.0` capability
    * `:confirmed-commit:1.1` capability
  * Added support for relevant arguments to CLI commit
    * See [example_cli.cli](https://github.com/clicon/clixon/blob/master/example/main/example_cli.cli)
  * See [Netconf Confirmed Commit Capability](https://github.com/clicon/clixon/issues/255)
* Netconf monitoring, part 1
  * Capabilities and schema state and get-schema
  * Remaining: Datastore, sessions and statistics state
  * Standards
    * RFC 6022 "YANG Module for NETCONF Monitoring"
  * See [Feature Request: Support RFC 6022 (NETCONF Monitoring)](https://github.com/clicon/clixon/issues/370)

### API changes on existing protocol/config features

Users may have to change how they access the system

* New `clixon-config@2022-11-01.yang` revision
  * Added option:
    * `CLICON_NETCONF_MONITORING`
    * `CLICON_NETCONF_MONITORING_LOCATION`
* Added `PRETTYPRINT_INDENT` compile-time option controlling indentation level for XML, JSON, TEXT and YANG
  * Default value is `3`
* NETCONF: Removed `message-id` from hello protocol following RFC 6241
  * See [message-id present on netconf app "hello"](https://github.com/clicon/clixon/issues/369)

### C/CLI-API changes on existing features

Developers may need to change their code

* [Code formatting: Change indentation style to space](https://github.com/clicon/clixon/issues/379)
  * Applies to all c/h/y/l/sh files and .editorconfig
* C API changes:
  * Added `expanddefault` parameter to `xml_yang_validate_rpc()`
  * Added `defaults` parameter to `clicon_rpc_get_pageable_list()`
  * `clicon_rpc_commit()` and `cli_commit`
    * Added `confirmed`, `cancel`, `timeout`, `persist-id`, and `persist-id-val` parameters to
  * `clicon_rpc_commit()` and `clicon_rpc_validate`
    * Added three-value return.
    * Code need to be changed from: checking for `<0` to `<1` to keep same semantics
  * Added `skiptop` parameter to `xml2json_vec()`
  * Added two arguments to `candidate_commit`
    * `myid` : Client-id of incoming message
    * `vlev` : validate level
    * Both parameters are default `0` for backward-compatibility

### Minor features

* Removed obsoleted compile-time options since 5.4:
  * `YANG_ORDERING_WHEN_LAST`
    * See https://github.com/clicon/clixon/issues/287
  * `JSON_CDATA_STRIP`
* Added fuzz code for xpath
* List-pagination: Follow ietf-draft 100%: Removed list-pagination "presence"
* Main example: Removed dependency of external IETF RFCs
  * See [Can't initiate clixon_backend](https://github.com/clicon/clixon/issues/382)
* Added warning if modstate is not present in datastore if `CLICON_XMLDB_MODSTATE` is set.

### Corrected Bugs

* Fixed: XPath evaluation of two nodes reverted to strcmp even if both were numbers
* Fixed: [Yang identityref XML encoding is not general](https://github.com/clicon/clixon/issues/90)
  * Revisiting this issue now seems to work, there are no regressions that fail when disabling IDENTITYREF_KLUDGE.
* Fixed several xpath crashes discovered by unit xpath fuzzing
* Fixed: SEGV when using NETCONF get filter xpath and non-existent key
  * eg `select="/ex:table[ex:non-exist='a']`
* Fixed: [CLI Show config JSON with multiple top-level elements is broken](https://github.com/clicon/clixon/issues/381)
* Fixed: [Non-obvious behavior of clixon_snmp after snmpset command when transaction validation returns an error](https://github.com/clicon/clixon/issues/375)
  * Fixed by validating writes on ACTION instead of COMMIT since libnetsnmp seems not to accept commit errors
* Fixed: [YANG when condition evaluated as false combined with a mandatory leaf does not work](https://github.com/clicon/clixon/issues/380)
* Fixed: [Trying to change the "read-only" node through snmpset](https://github.com/clicon/clixon/issues/376)
* Fixed: [Trying to change the "config false" node through snmpset](https://github.com/clicon/clixon/issues/377)
  * Fixed by returning `SNMP_ERR_NOTWRITABLE` when trying to reserve object
* Fixed: [Non-obvious behavior of clixon_snmp after snmpset command when transaction validation returns an error](https://github.com/clicon/clixon/issues/375)
* Fixed: [clixon_snmp module crashes on snmpwalk command](https://github.com/clicon/clixon/issues/378)
* Fixed: [unneeded trailing zero character on SNMP strings](https://github.com/clicon/clixon/issues/367)
* Fixed: [message-id present on netconf app "hello"](https://github.com/clicon/clixon/issues/369)
* Fixed: [SNMP "smiv2" yang extension doesn't work on augmented nodes](https://github.com/clicon/clixon/issues/366)

## 5.9.0
24 September 2022

The 5.9 release features with-defaults (RFC 6243) and RESTCONF Call-home (RFC 8071) along with numerous bugfixes and usability improvements.

### New features

* With-defaults capability
  * Standards
    * RFC 6243 "With-defaults Capability for NETCONF"
    * RFC 8040 "RESTCONF Protocol": Section 4.8.9
  * Features:
    * `:with-defaults` capability
    * `explicit` basic mode
    * Full retrieval modes: `explicit`, `trim`, `report-all`, `report-all-tagged`.
    * RESTCONF with-defaults query for XML and JSON
       * Assigned meta-data for the `ietf-netconf-with-defaults:default` attribute for JSON (RFC8040 Sec 5.3.2)
  * Added `withdefault` option to cli show commands
    * See [User manual](https://clixon-docs.readthedocs.io/en/latest/cli.html#show-commands)
    * See [CLISPEC changes](#api-changes-on-existing-protocolconfig-features)
  * See [Netconf With-defaults Capability](https://github.com/clicon/clixon/issues/262)
* RESTCONF call home
  * Standard: RFC 8071 "NETCONF Call Home and RESTCONF Call Home"
  * clixon-restconf.yang extended with callhome inspired by ietf-restconf-server.yang
    * See e.g., draft-ietf-netconf-restconf-client-server-26.txt
  * The `<socket>` list has been extended with a `call-home` presence container including:
    * reconnect-strategy/max-attempts
    * connection-type: either persistent or periodic
    * idle-timeout for periodic call-homes.
  * An example util client is `clixon_restconf_callhome_client.c` used in test cases
  * See [call-home user guide](https://clixon-docs.readthedocs.io/en/latest/restconf.html#callhome)

### API changes on existing protocol/config features

Users may have to change how they access the system

* NETCONF error handling for `data-not-unique` and `missing-choice` follows standard more closely
  * data-not-unique:
    * Added YANG namespace to `<non-unique>` tag
    * Changed `yang-unique` value to path insytead of  single name
    * See RFC 7950 Sec 15.1
  * missing-choice:
    * Added `<error-path>`
    * Added YANG namespace to `<missing-choice>` tag
    * See RFC 7950 Sec 15.6
* Backend transaction plugins: edit of choice node will always result in a "del/add" event for all edits of change nodes, never a "change" event.
  * Before, some cases were using a "change" event if the "yang ordering" happended to be the same.
  * See more details in: [Clixon backend transactions for choice/case is not logical](https://github.com/clicon/clixon/issues/361)
* Constraints on number of elements have been made stricter (ie unique, min/max-elements)
  * Usecases that passed previously may now return error
  * This includes:
    * Check of incoming RPCs
    * Check of non-presence containers

### C/CLI-API changes on existing features

Developers may need to change their code

* C API changes
  * Added `defaults` parameter to `clicon_rpc_get()` and `clicon_rpc_get_config()`
     * For upgrade, add new sixth parameter and set it to `NULL`.
* CLISPEC changes of cli show functions
  * For details of updated API, see https://clixon-docs.readthedocs.io/en/latest/cli.html#show-commands
  * Changed `cli_show_auto()`
     * Added parameters for pretty-print, state and with-default
     * If the `<prefix>`is used, you need to change the call as follows:
        * `cli_show_auto(<db>, <format>, <prefix>)` -> `cli_show_auto(<db>, <format>, true, false, NULL, <prefix>)`
     * Otherwise the API is backward-compatible
  * Changed `cli_show_config()`
     * Added parameters for pretty-print, state and with-default
     * If the `<prefix>` parameter is used, you need to change the call as follows:
        * `cli_show_config(<db>, <format>, <xpath>, <ns>, <prefix>)` -> `cli_show_auto(<db>, <format>, <xpath>, <ns>, true, false, NULL, <prefix>)`
     * Otherwise the API is backward-compatible
  * Removed `cli_show_auto_state()`, replace with `cli_show_auto` with state set to `true`
  * Removed `cli_show_config_state()`, replace with `cli_auto_show` with state set to `true`
  * Replaced `cli_auto_show()` with `cli_show_auto_mode()`
     * The first argument is removed. You need to change all calls as follows:
       * `cli_show_config(<treename>, <db>, ...` -> `cli_show_auto_menu(<db>, ...)`
     * The `cli_auto_show()` callback remains in 5.9.0 for backward compatible reasons, but will be removed in later releaes.

### Minor features

* Restconf:
  * Openssl 3.0 is supported
  * Refactoring of code closing sockets. Some cornercase bugs have been removed.

### Corrected Bugs

* Fixed: Leak in restconf http/1 data path: when multiple packets in same connection.
* Fixed: [Replace operation](https://github.com/clicon/clixon/issues/350)
* Fixed: [When multiple lists have same key name, need more elaborate error message in case of configuration having duplicate keys](https://github.com/clicon/clixon/issues/362)
  * Solved by implementing RFC7950 Sec 5.1 correctly
* Fixed: [All values in list don't appear when writing "show <list>" in cli](https://github.com/clicon/clixon/issues/359)
* Fixed: [yang regular char \w not include underline char](https://github.com/clicon/clixon/issues/357)
* Fixed: [Clixon backend transactions for choice/case is not logical](https://github.com/clicon/clixon/issues/361)
* Fixed: [Clixon backend transaction callback fails for empty types](https://github.com/clicon/clixon/issues/360)
* Fixed: [with-defaults=trim does not work due to dodgy handling of state data marked as default](https://github.com/clicon/clixon/issues/348)
* Fixed: [YANG ordering fails for nested choice and action](https://github.com/clicon/clixon/issues/356)
* Fixed: [YANG min-elements within non-presence container does not work](https://github.com/clicon/clixon/issues/355)
* Fixed: [Issues with ietf-snmp modules](https://github.com/clicon/clixon/issues/353)
* Fixed: [Missing/no namespace error in YANG augments with default values](https://github.com/clicon/clixon/issues/354)
* Fixed: [Validation of mandatory in choice/case does not work in some cases](https://github.com/clicon/clixon/issues/349)

## 5.8.0
28 July 2022

New features in Clixon 5.8.0 include a new SNMP frontend, YANG action and parseable TEXT syntax.

### New features

* New SNMP frontend
  * Support for SNMP for retreiving and setting values via net-snmp using MIB-YANG mapping defined in RFC6643.
  * For details, see [SNMP section of user manual](https://clixon-docs.readthedocs.io/en/latest/snmp.html)
  * YANG `clixon-config@2022-03-21.yang` changes:
    * Added options:
      * `CLICON_SNMP_AGENT_SOCK`
      * `CLICON_SNMP_MIB`
  * New configure options:
    * `--enable-netsnmp`
    * `--with-mib-generated-yang-dir=DIR` (test only)
  * Thanks: Siklu Communications LTD for sponsoring this work

* YANG Action (RFC 7950 Section 7.15)
  * Register action callback with `action_callback_register()`
    * The main example contains example code
  * Remains: check list keys, validate output
  * See [Support for "action" statement](https://github.com/clicon/clixon/issues/101)

* TEXT syntax is now parseable
  * This means you can save and load TEXT syntax files, as additions to XML/JSON/CLI formats
  * Previously only output was supported.
  * TEXT output format changed (see API changes)
  * FOr more info, see [user manual](https://clixon-docs.readthedocs.io/en/latest/datastore.html#other-formats)
  * See [Support performant load_config_file(...) for TEXT format](https://github.com/clicon/clixon/issues/324)

### API changes on existing protocol/config features

Users may have to change how they access the system

* TEXT file format changed
  * With new parsing of TEXT format, the output is changed
    * Namespace/modulename added to top-level
    * Leaf-list support: `a [ x y z ]`
    * List key support: `a x y { ... }`
    * See compile-time option `TEXT_LIST_KEYS`
  * Keep backward-compatible non-top-level prefix with compile-time option `TEXT_SYNTAX_NOPREFIX`
* Augmented XML uses default namespace
  * Instead of using prefixes for augmented XML, assign the default namespace
  * This does not change the semantics, but changes the way XML prefixes are used
  * Example augmented ipv4 into interface:
    * Previously: `<interface><ip:ipv4 xmlns:ip="urn:...:ietf-ip"><ip:enabled>...`
    * Now: `<interface><ipv4 xmlns="urn:...:ietf-ip"><enabled>...`

### C/CLI-API changes on existing features

Developers may need to change their code

* Changed C-API for xml translation/print the internal `cxobj` tree data structure to other formats.
  * Functions are merged, ie removed and with replaced more generic functions
  * Added `skiptop` parameter, if set only apply to children of a node, skip top node
     * default is 0
  * The new API is as follows:
     * `clixon_xml2file()` / `clixon_xml2cbuf()` - Print internal tree as XML to file or buffer, respectively
     * `clixon_json2file()` / `clixon_json2cbuf()` - Print internal tree as JSON to file or buffer, respectively
     * `clixon_cli2file()` - Print internal tree as CLI format to file
     * `clixon_txt2file()` - Print internal tree as text format to file
  * As developer, you need to replace the old functions to the new API as follows:
     * `clicon_xml2file(f, x, l, p)` -> `clixon_xml2file(f, x, l, p, NULL, 0, 0)`
     * `clicon_xml2file_cb(f, x, l, p, fn)` -> `clixon_xml2file(f, x, l, p, fn, 0, 0)`
     * `cli_xml2file(x, l, p, fn)` -> `clixon_xml2file(stdout, x, l, p, fn, 0, 0)`
     * `clicon_xml2cbuf(c, x, l, p, d)` -> `clixon_xml2cbuf(c, x, l, p, d, 0)`
     * `clicon_xml2str(x)` -> Rewrite using cbufs and `clixon_xml2cbuf()`
     * `xml2json(f, x, p)` -> `clixon_json2file(f, x, p, NULL, 0, 0)`
     * `xml2json_cb(f, x, p, fn)` -> `clixon_json2file(f, x, p, fn, 0, 0)`
     * `xml2json_cbuf(c, x, p)` -> `clixon_json2cbuf(c, x, p, 0, 0)`
     * `xml2cli(h, f, x, p, fn)` -> `clixon_cli2file(h, f, x, p, fn, 0)`
     * `cli_xml2txt(x, fn, l)` -> `clixon_txt2file(stdout, x, l, NULL, 0, 0)`
     * `xml2txt(f, x, l)` -> `clixon_txt2file(f, x, l, NULL, 0, 0)`
     * `xml2txt_cb(f, x, fn)` -> `clixon_txt2file(f, x, 0, NULL, 0, 0)`

### Minor features

* Break-out RFC 7950 Section 6.1 tokenization
  * This enables full string lexical parsing of some rules previously not fully compliant, including:
    * refine, uses-augment, augment, if-feature, type, base.
  * Also fixes some previous tokenization issues
    * [String concatenation in YANG model leads to syntax error ](https://github.com/clicon/clixon/issues/265)
    * [Can't use + symbol in the enum statement without quotes](https://github.com/clicon/clixon/issues/241)
* Full RFC 7950 if-feature-expr support (Section 7.20.2)
  * Previous implementation did not handle nested if-feature expressions
  * As part of fixing: [YANG if-feature does not support nested boolean expression](https://github.com/clicon/clixon/issues/341)
  * Added new yacc/lex parser for if-feature-expr string
* Added XPATH function `boolean()`
  * This caused problem for new NTP YANG in RFC 9249
* [Feature Request: Log SSL events](https://github.com/clicon/clixon/issues/331)
  * Added syslog NOTICE on failed user certs

### Corrected Bugs

* Fixed: [Clixon CLI issue: when I try to print the value of the leaf node nothing appeared](https://github.com/clicon/clixon/issues/345)
* Fixed: [Can't use + symbol in the enum statement without quotes](https://github.com/clicon/clixon/issues/241)
* Fixed: [String concatenation in YANG model leads to syntax error ](https://github.com/clicon/clixon/issues/265)
* Fixed: ["autocli:hide-show" extension cause bug in xmldb_put method #343](https://github.com/clicon/clixon/issues/343)
* Fixed: [Schema Ambiguity Error with openconfig-system re: NTP](https://github.com/clicon/clixon/issues/334)
* Fixed: [YANG mandatory statements within case nodes do not work](https://github.com/clicon/clixon/issues/344)
* Fixed: [Nested YANG choice does not work](https://github.com/clicon/clixon/issues/342)
* Fixed: [YANG if-feature does not support nested boolean expression](https://github.com/clicon/clixon/issues/341)
* Fixed: [RPC edit-config payloads are not fully validated](https://github.com/clicon/clixon/issues/337)

## 5.7.0
17 May 2022

The Clixon 5.7 release introduces (long overdue) NETCONF chunked framing as defined
in RFC 6242. It also introduces a limited http data service and lots of bugfixes.

* Implementation of "chunked framing" according to RFC6242 for Netconf 1.1.
  * First hello is 1.0 EOM framing, then successing rpc is chunked framing
  * See
    * [Netconf framing](https://github.com/clicon/clixon/issues/50), and
    * [Clixon does not switch to chunked framing after NETCONF 1.1 is negotiated](https://github.com/clicon/clixon/issues/314)
* Extended the Restconf implementation with a limited http-data static service
   * Added two new config options to clixon-config.yang:
      * `CLICON_HTTP_DATA_PATH`
      * `CLICON_HTTP_DATA_ROOT`
   * Added feature http-data to restconf-config.yang and the following option that needs to be true
      * `enable-http-data`
   * Added `HTTP_DATA_INTERNAL_REDIRECT` compile-time option for internal redirects to `index.html`
   * For more info, see [user manual documentation](https://clixon-docs.readthedocs.io/en/latest/restconf.html#http-data)

### API changes on existing protocol/config features

Users may have to change how they access the system

* CLI
  * `clixon_cli` reconnects to backend if backend restarts with a warning
    * Note that edits to the candidate database or locks will be lost
    * To force the CLI to exit if backend restarts, undef `PROTO_RESTART_RECONNECT`
    * This is an effect of the fix of [Broken pipe error seen in client (cli) when backend restarts and CLICON_SOCK is recreated](https://github.com/clicon/clixon/issues/312), the CLI behavior on backend restart is changed.
  * Expansion of YANG leafref type default behavior has changed
    * In the autocli and handcrafted CLI:s using `expand_dbvar()` the CLI expansion followed the leafrefs to the sources, ie the origin of the leafrefs
    * Instead leafref expansion now expands according to existing leafrefs by default
    * Example:
       * Assume leafref with leafref pointing to source if values:
          * `<if>a</if><if>b</if><if>c</if>
	     <ifref>b</ifref>`
       * Existing behavior: expand to: `a, b, c`
       * New default behavior: expand to: `b`
    * To keep existing behavior, set `<CLICON_CLI_EXPAND_LEAFREF>true<CLICON_CLI_EXPAND_LEAFREF>`

* Restconf
  * Added 404 return without body if neither restconf, data or streams prefix match
* Netconf:
  * Usage of chunked framing
    * To keep existing end-of-message encoding, set `CLICON_NETCONF_BASE_CAPABILITY` to `0`
    * Added `clixon_netconf` command-line option `-0` and changed `-H` to `-1`
       * `-0` means dont send hello, but fix netconf base version to 0 and use EOM framing
       * `-1` means dont send hello, but fix netconf base version to 1 and use chunked framing
  * Error message `data-not-unique` changed to return schema nodes instead of XML for RFC7950 compliance
* YANG
  * Instead of removing YANG which is disabled by `if-feature`, replace it with an yang `anydata` node.
    * See [Adding feature to top level container doesn't work](https://github.com/clicon/clixon/issues/322)
    * This means XML specified by such YANG is ignored, and it is not an error to access it
    * Note the similarity with `CLICON_YANG_UNKNOWN_ANYDATA`
  * New `clixon-config@2022-03-21.yang` revision
    * Added option:
      * `CLICON_RESTCONF_API_ROOT`
      * `CLICON_NETCONF_BASE_CAPABILITY`
      * `CLICON_HTTP_DATA_PATH`
      * `CLICON_HTTP_DATA_ROOT`
      * `CLICON_CLI_EXPAND_LEAFREF`
  * New `clixon-restconf@2022-03-21.yang` revision
    * Added option:
      * `enable-http-data`
    * Added feature:
      * `http-data`

### C/CLI-API changes on existing features

Developers may need to change their code

* Added `nsc` parameter to `xml2xpath()` and ensured the xpath uses prefixes.
  * Old code: add `NULL` as second parameter
* Added `eof` parameter to `clicon_rpc()` and `clicon_rpc1()` and error handling modified

### Minor features

* Command-line option: Extended `-l` of all clixon commands with `-l n` which directs logging to `/dev/null`
* New: CLI load command for CLI syntax files (not only XML and JSON)
  * See [provide support for load config of cli format along with json and xml format as save config is supported for all 3 formats](https://github.com/clicon/clixon/issues/320)
* New: Do not load clixon-restconf YANG file by default
  * See [prevent clixon-restconf@2021-05-20.yang module from loading](https://github.com/clicon/clixon/issues/318)
  * Instead of always loading it, load it to datastore YANGs only if `CLICON_BACKEND_RESTCONF_PROCESS` is `true`
* YANG unique: added single descendant node ids as special case
  * This means that two variants are supported:
    * unique "a b c", ie multiple direct children
    * unique "a/b/c", ie single descendants
  * RFC 7950 Sec 7.8.3 is somewhat unclear
  * The combination is not supported

### Corrected Bugs

* XPath parser: fixed some lexical issues
  * Some complexities in Section 3.7 Lexical Structure of XPath 1.0 spec as follows
  * There used to be some cornercases where function-names could not be used as nodes
  * For example, `node()` is a nodetest, so `/node/` caused an error.
  * In the grammar these include: axisnames,  nodetests, functionnames
  * The NCNames vs functionnames is now implemented according to the lexical structure section
* Fixed: [Keywords containing '-' hyphen are missing from the auto-completion list](https://github.com/clicon/clixon/issues/330)
  * Fixed by disabling `cligen_preference_mode`. This may have other side effects.
* Fixed: [Returning a string while Querying leaf-list for single entry](https://github.com/clicon/clixon/issues/326)
* Fixed: A long TLS+HTTP/2 request such as by a browser causing block of other requests.
* Fixed: [Error message seen twice in some cases](https://github.com/clicon/clixon/issues/325)
* Fixed: [if choice is declared with multiple elements or leaf-list with in a case scope , addition or updation is not happening as expected](https://github.com/clicon/clixon/issues/327)
  * This includes several choice/case adjustments to follow RFC 7950 Sec 7.9 better
* Fixed: HTTP/1 parse error for '/' path
* Fixed: YANG if-feature in config file of disables feature did not work, was always on
  * This does not apply to the datastore, only the config file itself.
* Fixed: YANG key list check bad performance
  * List key check did unique "xpath" lookup instead of direct child traverse
* Fixed: YANG unique single schema-nodeid required "canonical" namespace
  * E.g., `a/b` did not work even if there was default namespace in XML
* Disabled xpath optimization for hierarchical list
  * When `XPATH_LIST_OPTIMIZE` is set, patterns like `y[k='3']` is optimized
  * But hierarchical lists should not be, ie when `a/y[k='3']` and `a` is a list
* Fixed: Removed warning at startup: `No YANG spec for module-set`
* Fixed: HTTP/1 multiple write requests in single session appended data between writes, eg PUT+PUT.
* Fixed: [Broken pipe error seen in client (cli) when backend restarts and CLICON_SOCK is recreated](https://github.com/clicon/clixon/issues/312)
* Fixed: [Xpath API do not support filter data by wildcard](https://github.com/clicon/clixon/issues/313)
* Fixed: SEGV in cli show yang

## 5.6.0
8 March 2022

Clixon 5.6 removes the dependency of libevhtp and libevent2 for native HTTP/1
RESTCONF, module-state has been upgraded to RFC8525 and a lot of bugs
have been fixed, thanks to the community for all feedback.

### New features

* Yang library upgraded from RFC7895 to [RFC 8525](https://datatracker.ietf.org/doc/html/rfc8525)
  * See [API changes](#API-changes-on-existing-protocol/config-features) for more info
* RESTCONF Internal HTTP/1 native parser
  * Removed dependency of libevhtp/libevent2
  * Replace configure option `--disable-evhtp` with `--disable-http1` for disabling HTTP/1 (default enabled)

### API changes on existing protocol/config features

Users may have to change how they access the system

* Module state upgrade: RFC7895 to RFC8525:
  * To upgrade to RFC8525:
    * Set `CLICON_YANG_LIBRARY` to `true` and `CLICON_MODULE_LIBRARY_RFC7895` to `false`
  * To keep RFC7895:
    * Set both `CLICON_YANG_LIBRARY` and `CLICON_MODULE_LIBRARY_RFC7895` to `true`
  * Following RFC8525, the upgrade means that the state-data returned using GET is changed:
    * Preamble changed from: `<modules-state>...` to: `<yang-library><module-set>...`
    * `module-state-id` changed to `content-id`
    * `conformance-type` removed
  * Note that the datastore feature `CLICON_XMLDB_MODSTATE` is backward compatible with RFC8525.
* New `clixon-config@2022-02-11.yang` revision
  * Added option:
    * `CLICON_LOG_STRING_LIMIT`
    * `CLICON_YANG_LIBRARY`
  * Changed default value:
    * `CLICON_MODULE_LIBRARY_RFC7895` to false
  * Removed (previosly marked) obsolete options:
      * `CLICON_RESTCONF_PATH`
      * `CLICON_RESTCONF_PRETTY`
      * `CLICON_CLI_GENMODEL`
      * `CLICON_CLI_GENMODEL_TYPE`
      * `CLICON_CLI_GENMODEL_COMPLETION`
      * `CLICON_CLI_AUTOCLI_EXCLUDE`
      * `CLICON_CLI_MODEL_TREENAME`
* RESTCONF replies on the form: `{"data":...}` changed to: `{"ietf-restconf:data":...}`
  * See [restconf GET json response does not encode top level node with namespace as per rfc #303](https://github.com/clicon/clixon/issues/303)
* YANG leafref `require-instance` default changed to `true`
  * This makes leafref validation stricter
  * See [statement: require-instance should be true if not present according to rfc7950 Sec 9.9.3](https://github.com/clicon/clixon/issues/302)
* Autotools/configure changes
  * `configure --with-wwwdir=<dir>` is removed
  *  Configure option `--disable-evhtp` with `--disable-http1` for disabling HTTP/1 (default enabled)
* Command field of `clixon-lib:process-control` RPC reply used CDATA encoding but now uses regular XML encoding

### C/CLI-API changes on existing features

* Added RFC7951 parameter to `clixon_json_parse_string()` and `clixon_json_parse_file()`
  * If set, honor RFC 7951: JSON Encoding of Data Modeled with YANG, eg it requires module name prefixes
  * If not set, parse as regular JSON

### Minor features

* Added: [Strict auto completion for CLI argument expansion #163](https://github.com/clicon/clixon/issues/163)
* Added: [Convert int64, uint64 and decimal64 to string in xml to json #310](https://github.com/clicon/clixon/pull/310)
* Backend ignore of `SIGPIPE`. This occurs if client quits unexpectedly over the UNIX socket.
   * This is a timing issue but occurs more frequently in large RESTCONF messages.
* Added option: `CLICON_LOG_STRING_LIMIT` configure option
  * Limit the length of log and debug messages. Some log messages are dependendent on sizes that can be very large, such as packet lengths. This new option constrains the length of all messgaes. By default no limits.

### Corrected Bugs

* Fixed: [Validate error when appending module B grouping to module A item use augment statement #308](https://github.com/clicon/clixon/issues/308)
* Fixed: [Restconf PATCH method request failed on item defined by submodule #306](https://github.com/clicon/clixon/issues/306)
* Fixed: [restconf GET json response does not encode top level node with namespace as per rfc #303](https://github.com/clicon/clixon/issues/303)
* Fixed: [statement: require-instance should be true if not present according to rfc7950 Sec 9.9.3](https://github.com/clicon/clixon/issues/302)
  * See also API changes
* Fixed: input RPC validation of YANG `choice`, more specifically, without `case` keyword
* Fixed: More than one unknown/extension in combination with augment of extension resulted in extension being skipped.

## 5.5.0
20 January 2022

This release introduces a new autocli design with a clixon-autocli YANG file

### New features

* Changed auto-cli design
  * See [autocli documentation](https://clixon-docs.readthedocs.io/en/latest/cli.html#autocli) for overview
  * Added new YANG `clixon-autocli.yang` moving all autocli options there
    * Default rules for module exclusion, list-keywords, edit-modes, treeref-state and completion
    * Specialized rules for module exclusion and compression
  * Replaced separate autocli trees with a single `@basemodel` tree by using filter labels
    * Filter labels are added to the basemodel tree and then filtered out using `@remove:<label>`
    * This method reduces memory usage and is more generic
    * Backward compatible: can continue use the "old" trees.
    * Note: while `@datamodel` etc are backward compatible, the autocli redesign is NOT backward compatible
      * see API changes
  * New autocli edit-mode design
     * Control which modes to use with `edit-mode-default`
       * Default is create edit-mode for all containers and list entries
     * New edit-mode tree: `@datamodelmode`
  * Moved hide extensions from `clixon-lib` to `clixon-autocli`

### API changes on existing protocol/config features

Users may have to change how they access the system

* Auto-cli edit-modes changed
  * CLI-spec variable `CLICON_PROMPT` `%W` changed semantics due to long prompt
    * From "Full Working edit path" to "Last element of working path"
    * Use `%w` if you want to keep "Full working path"
  * Edit modes only for list and container nodes
  * Change cli spec entry to `edit @datamodelmode, cli_auto_edit("basemodel");`
* New `clixon-lib@2021-12-05.yang` revision
  * Extension `autocli-op` obsoleted and no longer supported, use clixon-autocli `hide` and `hide-show` instead as follows:
    * `cl:autocli-op hide` -> `autocli:hide`
    * `cl:autocli-op hide-database` -> `autocli:hide-show`
    * `cl:autocli-op hide-database-auto-completion` -> `autocli:hide; autocli:hide-show`
* New `clixon-config@2021-12-05.yang` revision
  * Removed obsolete options:
    * `CLICON_YANG_LIST_CHECK`
  * Fixed: Configure option `CLICON_RESTCONF_PRETTY` was marked as obsolete but was still used.
    * `CLICON_RESTCONF_PRETTY` is now obsolete for sure
    * Use: `restconf/pretty`
  * Fixed: Configure option `CLICON_RESTCONF_PATH` was marked as obsolete but was still used.
    * `CLICON_RESTCONF_PATH` is now obsolete for sure
    * Instead if you use fgci/nginx:
      * Use `restconf/fcgi-socket`
      * Ensure `<CLICON_FEATURE>clixon-restconf:fcgi</CLICON_FEATURE>` is set
  * Marked as obsolete and moved autocli config options from clixon-config.yang to clixon-autocli.yang
    * Use: `<config><autocli>...` for configuring the autocli
    * For details, see [autocli upgrade documentation](https://clixon-docs.readthedocs.io/en/latest/cli.html#upgrade-from-pre-clixon-5-5)

### C/CLI-API changes on existing features

Developers may need to change their code

* Removed `#ifdef __GNUC__` around printf-like prototypes since both clang and gcc have format/printf macros defined

* Test changes
  * Use `YANG_STANDARD_DIR` from `./configure --with-yang-standard-dir=DIR` instead of `YANGMODELS` from site.sh
  * Remove dependency of IETF YANGs on most tests
  * Remove dependency of example/main in most tests, instead make local copy of example yang
  * Changed `configure --with-yang-standard-installdir` to `configure --with-yang-standard-dir`

### Corrected Bugs

* Fixed: Autocli YANG patterns including `"` were not properly escaped: `\"`
* Ensure auto-cli can be run with config option `CLICON_CLI_VARONLY=1`
* Fixed: SEGV in backend callback for user-defined RFC:
  * rpc_callback_call(): Check if nrp parameter is NULL

## 5.4.0
30 November, 2021

This release features lots of minor updates and bugfixes, an updated list pagination and optimized auto-cli for large yang-specs. Thanks Netgate for providing the dispatcher code used in the new pagination API!

### New features

* Broke out pagination callback API from state data callbacks
  * New pagination callback API uses new dispatcher from netgate, thanks @dcornejo
    * Register callback with: `clixon_pagination_cb_register()`
    * Use accessor functions `pagination_offset()`, `pagination_limit()`, etc
  * Reverted state data callback API to pre-5.3 (see C/CLI API changes below)
  * See https://clixon-docs.readthedocs.io/en/latest/pagination.html
* Added support for XPATH function `bit-is-set()`
* Added: [Recursive search CLIXON_YANG_DIR](https://github.com/clicon/clixon/issues/284)
* Added statistics for YANG: number of objects and memory used
  * See clixon-lib: stats rpc

### API changes on existing protocol/config features

Users may have to change how they access the system

* Optional yangs for testing have been removed from the Clixon repo
  * As a consequence, the following configure options have been removed:
    * `configure --with-opt-yang-installdir=DIR`
    * `configure --enable-optyangs`
* You may need to specify where standard IETFC/IEEE YANGMODELS are
  * Note, this applies to testing and main example only, not core clixon
  * The following configure option has been added
    * `configure --with-yang-standard-dir=DIR`
* RPC replies now verified with YANG
  * Stricter checking of outgoing RPC replies from server
  * See [RPC output not verified by yang](https://github.com/clicon/clixon/issues/283)
* XML to JSON CDATA translation is NOT stripped
  * Example, assume XML: `<s><![CDATA[  z > x  & x < y ]]></s>`
  * Previous bevavior:
    * JSON: {"s":"  z > x  & x < y "}
  * New behavior:
    * JSON: `{"s":"<![CDATA[  z > x  & x < y ]]>"}`
  * To keep old behavior, set `JSON_CDATA_STRIP` in clixon_custom.h
* New `clixon-lib@2021-11-11.yang` revision
  * Modified option: RPC stats extended with YANG stats
* New `clixon-config@2021-11-11.yang` revision
  * Added option:
    * `CLICON_PLUGIN_CALLBACK_CHECK`
    * `CLICON_YANG_AUGMENT_ACCEPT_BROKEN`
  * Modified options:
    * CLICON_CLI_GENMODEL_TYPE: added OC_COMPRESS enum
    * CLICON_YANG_DIR: recursive search
* The behavior of option `CLICON_YANG_DIR` to find the most recent yang file has been changed
  * Instead of searching a flat dir, it now searches recursively in the given dir
  * See [Recursive search CLIXON_YANG_DIR](https://github.com/clicon/clixon/issues/284)
* Pagination is updated to new drafts:
  * [https://datatracker.ietf.org/doc/html/draft-wwlh-netconf-list-pagination-00>]
   * Note removed import of system-capabilities.yang
  * [https://datatracker.ietf.org/doc/html/draft-wwlh-netconf-list-pagination-nc-02]
    * Note added presence to list-pagination container
  * [https://datatracker.ietf.org/doc/html/draft-wwlh-netconf-list-pagination-rc-02]
  * See also updated [https://clixon-docs.readthedocs.io/en/latest/pagination.html]
* NETCONF hello errors, such as wrong session-id, prefix, namespace terminates session
  * Instead of returning an rpc-error reply
  * This conforms to RFC 6241

### C/CLI-API changes on existing features

Developers may need to change their code

* Statedata plugin callbacks are reverted to pre-5.3:
  * This has been done as a consequence of breaking out the pagination state API as a separate API.
  * The reverted state data callback signature is as follows:
  ```
  int statedata(clicon_handle     h,
                cvec             *nsc,
                char             *xpath,
                cxobj            *xstate)
  ```
* Changed signature of `rpc_callback_call()`
   * from: `clicon_handle h, cxobj *xe, cbuf *cbret, void *arg`
   * to: `clicon_handle h, cxobj *xe, void *arg, int *nrp, cbuf *cbret)`
* Changed signature of `yang_extension_value()`
   * from: `yang_stmt *ys, char *name, char *ns, char **value`
   * to:   `yang_stmt *ys, char *name, char *ns, int *exist, char **value`

### Minor features

* Added configure option `--with-yang-standard-dir=DIR`
  * Directory of standard IETF/IEEE YANG specs
* Added option `CLICON_YANG_AUGMENT_ACCEPT_BROKEN` to accept broken yangmodels.
  * This is a debug option for CI testcases where standard YANG models are broken
* Performance improvement
  * Added ancestor config cache indicating wether the node or an ancestor is config false or true
  * Improved performance of yang cardinality lookup
* Added sorting of YANG statements
  * Some openconfig specs seem to have use/when before a "config" which it depends on. This leads to XML encoding being in the "wrong" order.
  * When parsing, clixon now sorts container/list statements so that sub-statements with WHEN are put last.
  * See [Statements given in "load set" are order dependent](https://github.com/clicon/clixon/issues/287)
* Plugin context check before and after all callbacks.
  * Check blocked signals and signal handlers
  * Check termios settings
  * Any changes to context are logged at loglevel WARNING
  * New option: `CLICON_PLUGIN_CALLBACK_CHECK`: set to 1 to get checks, 2, to abort on failure (default 0)
* Added: [OpenConfig Path Compression Support](https://github.com/clicon/clixon/issues/274)
  * PR: [OpenConfig path compression](https://github.com/clicon/clixon/pull/276)
* C API: Added set/get pointer API to clixon_data:
   * Added json/cli support for cli save/load
   * clicon_ptr_get(), clicon_ptr_set(),
* Restconf YANG PATCH according to RFC 8072
  * Changed YANG PATCH enabling:
    * Now: `./configure --enable-yang-patch`
    * Before: set YANG_PATCH constant in `include/clixon_custom.h`
* Refactored Makefile for static linking

### Corrected Bugs

* [JSON leaf-list output single element leaf-list does not use array](https://github.com/clicon/clixon/issues/289)
* [very slow execution of load_set_file #288](https://github.com/clicon/clixon/issues/288)
* [RPC output not verified by yang](https://github.com/clicon/clixon/issues/283)
* [Statements given in "load set" are order dependent](https://github.com/clicon/clixon/issues/287)
  * Modify ordering of XML encoding to put sub-elements with YANG WHEN statements last
* [RPC get-conf method returned some content not specified by select filter](https://github.com/clicon/clixon/issues/281)
  * Bug introduced when upgrading of list pagination
* [type leafref in type union ineffective](https://github.com/clicon/clixon/issues/277)
  * Leafrefs and identityrefs in unions were not validated correctly
* [cl:autocli-op hide has no effect in yang submodule](https://github.com/clicon/clixon/issues/282)
* [Doxygen - Typo in Input #275](https://github.com/clicon/clixon/issues/275)

## 5.3.0
27 September, 2021

The 5.3 release has pagination support, Linkref changes in validation and auto-cli, and lots of bug fixes.

### New features

* List pagination for Netconf and Restconf
  * Loosely based on:
    * draft-wwlh-netconf-list-pagination-00.txt
    * draft-wwlh-netconf-list-pagination-rc-01
    * Note: not a standardized feature
  * Added yangs:
    * ietf-restconf-list-pagination@2015-01-30.yang
    * clixon-netconf-list-pagination@2021-08-27.yang
    * ietf-yang-metadata@2016-08-05.yang
  * Restconf change:
    * New http media: application/yang-collection+xml/json
  * Updated state callback signature containing parameters for pagination
    * See API changes below
  * Work-in-progress
    * Enable remaining attribute with LIST_PAGINATION_REMAINING compile-time option
    * sort/direction/where etc not supported
  * For documentation: [User manual pagination](https://clixon-docs.readthedocs.io/en/latest/misc.html#pagination)
* YANG Leafref feature update
  * Closer adherence to RFC 7950. Some of this is changed behavior, some is new feature.
  * Validation uses referred node
    * Validation changed to use type of referred node, instead of just "string"
    * Essentially instead of looking at the referring leaf, context is referred(target) node
  * Auto-cli
    * Changed to use type of referred node for typecheck
    * Completion uses referred node
  * Required instance / less strict validation
    * New: Leafrefs must refer to existing data leaf ONLY IF YANG `required-instance` is true
    * Previous: All leafrefs must refer to existing data leaf node
* Restconf YANG PATCH according to RFC 8072 (Work in progress)
  * Experimental: enable by setting YANG_PATCH in include/clixon_custom.h
  * Thanks to Alan Yaniger for providing this patch

### API changes on existing protocol/config features

Users may have to change how they access the system

* Looser leafref validation checks
  * Leafref required-instance must be set to make strict data-node check
  * See changes under new feature "YANG leafref feature update" above
* Native Restconf
  * Native restconf is now default, not fcgi/nginx
    * To configure with fcgi, you need to explicitly configure: `--with-restconf=fcgi`
  * SSL client certs failures are returned as http `405` errors, not fail during SSL negotiation
* New `clixon-config@2021-07-11.yang` revision
   * Added: `CLICON_RESTCONF_HTTP2_PLAIN`
   * Removed default of `CLICON_RESTCONF_INSTALLDIR`
     * The default behaviour is changed to use the config `$(sbindir)` to locate `clixon_restconf` when starting restconf internally

### C/CLI-API changes on existing features

Developers may need to change their code

* You need to change all statedata plugin callback for the new pagination feature
  * NOTE THIS CHANGE IS REVERTED IN 5.4
  * If you dont use pagination you can ignore the values of the new parameters
  * The updated callback signature is as follows:
  ```
  int statedata(clicon_handle     h,
                cvec             *nsc,
	        char             *xpath,
	        pagination_mode_t pagmode,   // NEW
	        uint32_t          offset,    // NEW
	        uint32_t          limit,     // NEW
	        uint32_t         *remaining, // NEW
	        cxobj            *xstate)
  ```

### Minor features

* Fuzzing:
  * Added netconf fuzzing
  * Added `CLIXON_STATIC_PLUGINS` and description how to link CLI plugins statically
  * See `fuzz/cli`, `fuzz/netconf`
* Added `-H` option to clixon_netconf: Do not require hello before request
* JSON errors are now labelled with JSON and not XML
* Restconf native HTTP/2:
  * Added option `CLICON_RESTCONF_HTTP2_PLAIN` for non-TLS http
    * Default disabled, set to true to enable HTTP/2 direct and switch/upgrade HTTP/1->HTTP/2
    * Recommendation is to used only TLS HTTP/2
* JSON encoding of YANG metadata according to RFC 7952
  * XML -> JSON translation
  * Note: JSON -> XML metadata is not implemented
* Restconf internal start: fail early if clixon_restconf binary is not found
  * If `CLICON_BACKEND_RESTCONF_PROCESS` is true
* Added linenumbers to all YANG symbols for better debug and errors
  * Improved error messages for YANG identityref:s and leafref:s by adding original line numbers

### Corrected Bugs

* Partly Fixed: [String concatenation in YANG model leads to syntax error](https://github.com/clicon/clixon/issues/265)
  * In this case, eg "uses", single quotes can now be used, but not `qstring + qstring` in this case
* Fixed: [Performance issue when parsing large JSON param](https://github.com/clicon/clixon/issues/266)
* Fixed: [Duplicate lines emitted by cli_show_config (cli output style) when yang list element has composite key](https://github.com/clicon/clixon/issues/258)
* Fixed: Typing 'q' in CLI more scrolling did not properly quit output
  * Output continued but was not shown, for a very large file this could cause considerable delay
* Fixed: Lock was broken in first get access
  * If the first netconf operation to a backend was lock;get;unlock, the lock was broken in the first get access.
* Fixed: [JSON leaf-list output single element leaf-list does not use array](https://github.com/clicon/clixon/issues/261)
* Fixed: Netconf diff callback did not work with choice and same value replace
  * Eg if YANG is `choice c { leaf x; leaf y }` and XML changed from `<x>42</x>` to `<y>42</y>` the datastrore changed, but was not detected by diff algorithms and provided to validate callbacks.
  * Thanks: Alexander Skorichenko, Netgate
* Fixed: [Autocli does not offer completions for leafref to identityref #254](https://github.com/clicon/clixon/issues/254)
  * This is a part of YANG Leafref feature update
* Fixed: [clixon_netconf errors on client XML Declaration with valid encoding spec](https://github.com/clicon/clixon/issues/250)
* Fixed: Yang patterns: `\n` and other non-printable characters were broken
  * Example: Clixon interpereted them as the two characters: `\\` and `n` instead of ascii 10
* Fixed: The auto-cli identityref did not expand identities in grouping/usecases properly.
* Fixed: [OpenConfig BGP afi-safi and when condition issues #249](https://github.com/clicon/clixon/issues/249)
  * YANG "when" was not properly implemented for default values
* Fixed: SEGV in clixon_netconf_lib functions from internal errors including validation.
  * Check `xerr` argument both before and after call on netconf lib functions
* Fixed: Leafs added as augments on NETCONF RPC input/output lacked cv:s causing error in default handling
* Fixed: RFC 8040 yang-data extension allows non-key lists
  * Added `YANG_FLAG_NOKEY` as exception to mandatory key lists
* Fixed: mandatory leaf in a uses statement caused abort
  * Occurence was in `ietf-yang-patch.yang`
* Native RESTCONF fixes for http/1 or http/2 only modes
  * Memleak in http/1-only
  * Exit if http/1 request sent to http/2-only (bad client magic)
  * Hang if http/1 TLS request sent to http/2 only (ALPN accepted http/1.1)
* Fixed: [RESTConf GET for a specific list instance retrieves data from other submodules that have same list name and key value #244](https://github.com/clicon/clixon/issues/244)

## 5.2.0
1 July 2021

The 5.2 release has YANG support for "deviation", "when" and statement ordering. The native restconf mode also supports http/2 using libnghttp2

### New features

* Restconf native HTTP/2 support using nghttp2
  * FCGI/nginx not affected only for `--with-restconf=native`
  * HTTP/1 co-exists, unless `--disable-evhtp` which results in http/2 only
  * For HTTP/2 only: `--disable-nghttp2`
  * Upgrade from HTTP/1.1 to HTTP/2
    * https: ALPN upgrade
    * http: Upgrade header (using: `HTTP/1.1 101 Switching Protocols`)
* Full support of YANG `when` statement in conjunction with grouping/uses/augment
  * The following cases are now supported according to RFC 7950:
    * Do not extend default values if when statements evaluate to false
    * Do not allow edit-config of nodes if when statements evaluate to false (Sec 8.3.2)
    * If a key leaf is defined in a grouping that is used in a list, the "uses" statement MUST NOT have a "when" statement. (See 7.21.5)
  * See [yang uses's substatement when has no effect #218](https://github.com/clicon/clixon/issues/218)
* YANG `deviation` support [deviation statement not yet support #211](https://github.com/clicon/clixon/issues/211)
  * See RFC7950 Sec 5.6.3
* Added ordering sanity check for YANG modules and sub-modules
  * If YANG sub-statements are placed in wrong order, clixon fails with error.
* New utility: clixon_util_validate for stand-alone application that validates or commits datastores

### API changes on existing protocol/config features

Users may have to change how they access the system

* Netconf message-id attribute changed from optional to mandatory
  * Example:
    * Correct: `<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="42">`
    * Wrong: `<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">`
  * Set `CLICON_NETCONF_MESSAGE_ID_OPTIONAL` to `true` to accept omission of message-id attribute
  * See also [need make sure message-id exist in rpc validate #240](https://github.com/clicon/clixon/issues/240)
* Changed config and install options for Restconf
  * clixon_restconf daemon is installed in `/usr/local/sbin` (as clixon_backend), instead of /www-data
    * `configure --with-wwwdir=<dir>` remains but only applies to fcgi socket and log
    * New option `CLICON_RESTCONF_INSTALLDIR` is set to where clixon_restconf is installed, with default `/usr/local/sbin/`
  * Restconf drop privileges user is defined by `CLICON_RESTCONF_USER`
    * `configure --with-wwwuser=<user>` is removed
  * clixon_restconf drop of privileges is defined by `CLICON_RESTCONF_PRIVILEGES` option
* New clixon-config@2021-05-20.yang revision
  * Added: `CLICON_RESTCONF_USER`
  * Added: `CLICON_RESTCONF_PRIVILEGES`
  * Added: `CLICON_RESTCONF_INSTALLDIR`
  * Added: `CLICON_RESTCONF_STARTUP_DONTUPDATE`
  * Added: `CLICON_NETCONF_MESSAGE_ID_OPTIONAL`
* New clixon-restconf@2020-05-20.yang revision
  * Added: restconf `log-destination` (syslog or file:`/var/log/clixon_restconf.log`)
* RESTCONF error replies have changed
  * Added Restconf-style xml/json message bodies everywhere
    * Clixon removed the message body from many errors in the 4.6 version since they used html encoding.
    * However, the RFC Section 7.1 mandates to use RESTCONF-style message bodies.
* RESTCONF in Clixon used empty key as "wildchar". But according to RFC 8040 it should mean the "empty string".
  * Example: `GET restconf/data/x:a=`
  * Previous meaning (wrong): Return all `a` elements.
  * New meaning (correct): Return the `a` instance with empty key string: "".

### C/CLI-API changes on existing features

Developers may need to change their code

* Event exit API changed to a single decrementing counter where 1 means exit.
  * Removed: `clicon_exit_reset()`
  * Changed: `clicon_exit_set()` --> `clixon_exit_set(int nr)`
  * Changed: `clicon_exit_get()` --> `clixon_exit_get()`
* Made backend transaction and commit/validate API available to plugin code.
  * This enables RPC plugin code can call commit and validate via lib
  * The commit/validate API is now: `candidate_validate()` and `candidate_commit()`

### Minor features

* CI testing:
  * Changed default CI to be Ǹative restconf` instead of fcgi using nginx
  * Moved CI from travis to github actions
* Added autotool check for `getresuid` (+ related functions) necessary for lowering of priviliges for backend and restconf
  * If `getresuid` is not available, `CLICON_RESTCONF_PRIVILEGES` must be 'none'
* Added new startup-mode: `running-startup`: First try running db, if it is empty try startup db.
  * See [Can startup mode to be extended to support running-startup mode? #234](https://github.com/clicon/clixon/issues/234)
* Restconf: added inline configuration using `-R <xml>` command line as an alternative to making advanced restconf configuration
* New option `CLICON_RESTCONF_STARTUP_DONTUPDATE` added to disable RFC 8040 mandatory copy of running to startup after commit*
  * See [Need an option to disable restconf mandatory action of overwriting startup_db #230](https://github.com/clicon/clixon/issues/230)
* Add default network namespace constant: `RESTCONF_NETNS_DEFAULT` with default value "default".
* CLI: Two new hide variables added (thanks: shmuelnatan)
  * hide-database : specifies that a command is not visible in database. This can be useful for setting passwords and not exposing them to users.
  * hide-database-auto-completion : specifies that a command is not visible in database and in auto completion. This can be useful for a password that was put in device by super user, not be changed.

### Corrected Bugs

* Fixed: [uses oc-if:interface-ref error with openconfig #233](https://github.com/clicon/clixon/issues/233)
* Fixed: [need make sure message-id exist in rpc validate #240](https://github.com/clicon/clixon/issues/240)
  * Netconf message-id attribute changed from optional to mandatory (see API changes)
* Fixed: [restconf patch method unable to change value to empty string #229](https://github.com/clicon/clixon/issues/229)
* Fixed: [restconf patch method adds redundant namespaces #235](https://github.com/clicon/clixon/issues/235)
* Fixed: Restconf HEAD did not work everywhere GET did, such as well-known and exact root.
* Fixed: [JSON parsing error for a specific input. #236](https://github.com/clicon/clixon/issues/236)
  * JSON empty list parse problems, eg `a:[]`
  * Also fixed: [Json parser not work properly with empty array \[\] #228](https://github.com/clicon/clixon/issues/228)
* Fixed: [restconf patch method unable to chage value to empty string #229](https://github.com/clicon/clixon/issues/229)
* Fixed: [when condition error under augment in restconf #227](https://github.com/clicon/clixon/issues/227)
* Fixed: [Using YANG union with decimal64 and string leads to regexp match fail #226](https://github.com/clicon/clixon/issues/226)
* Fixed: [xpath function count did not work properly #224](https://github.com/clicon/clixon/issues/224)
* Fixed: RESTCONF Native: Failed binding of socket in network namespace caused process zombie
* Fixed  problems with XPATH composite operations and functions in netconf get/get-config operations.
  * See [XPATH issues #219](https://github.com/clicon/clixon/issues/219)
* Fix Union in xpath [XPATH issues #219](https://github.com/clicon/clixon/issues/219)
* Fix: XPath:s used in netconf (eg get-config) did not correctly access default values
* Fixed: [RESTCONF GET request of single-key list with empty string returns all elements #213](https://github.com/clicon/clixon/issues/213)
* Fixed: [RESTCONF GETof lists with empty string keys does not work #214](https://github.com/clicon/clixon/issues/214)
* Fixed: [Multiple http requests in native restconf yields same reply #212](https://github.com/clicon/clixon/issues/212)

## 5.1.0
15 April 2021

The 5.1 release contains more RESTCONF native mode restructuring, new multi-yang support in upgrade scenarios and a stricter NETCONF HELLO handling, and many minor updates and bugfixes.

### New features

* Restructuring of RESTCONF native mode
  * Configure native mode changed to: `configure --with-restconf=native`, NOT `evhtp`
  * Use libevhtp from https://github.com/clixon/clixon-libevhtp.git, NOT from criticalstack
    * Moved out event handling to clixon event handling
    * Moved out all ssl calls to clixon
    * Plan is to remove reliance on libevhtp and libevent altogether
  * Extended status restconf process message with:
  * If `CLICON_BACKEND_RESTCONF_PROCESS` is set, RESTCONF is started as internal process from backend
    * Otherwise restconf daemon must be started externally by user, such as by systemd.
* Netconf HELLO made mandatory
  * See RFC 6241 Sec 8.1
  * A client MUST send a <hello> element.
  * Each peer MUST send at least the base NETCONF capability, "urn:ietf:params:netconf:base:1.1" (or 1.0 for RFC 4741)
  * The netconf client will terminate (close the socket) if the client does not comply
  * Set `CLICON_NETCONF_HELLO_OPTIONAL` to use the old behavior with optional hellos.
* Add multiple yang support also for old/previous versions
  * Files and datastores supporting modstate also look for deleted or updated yang modules.
  * Stricter binding which gives error if loading outdated YANG file does not exist.
  * Keep old behavior: disable `CLICON_XMLDB_UPGRADE_CHECKOLD`.

### API changes on existing protocol/config features

Users may have to change how they access the system

* Native RESTCONF mode
  * Configure native mode changed to: `configure --with-restconf=native`, NOT `evhtp`
  * Use libevhtp from https://github.com/clixon/clixon-libevhtp.git, NOT from criticalstack
* Stricter yang checks: you cannot do get-config on datastores that have obsolete YANG.
* Netconf HELLO is mandatory
  * Set `CLICON_NETCONF_HELLO_OPTIONAL` to use the old behavior with optional hellos.
* New clixon-lib@2020-03-08.yang revision
  * Changed: RPC process-control output to choice with status fields
    * The fields are: active, description, command, status, starttime, pid (or just ok).
* New clixon-config@2020-03-08.yang revision
  * Added: `CLICON_NETCONF_HELLO_OPTIONAL`
  * Added: `CLICON_CLI_AUTOCLI_EXCLUDE`
  * Added: `CLICON_XMLDB_UPGRADE_CHECKOLD`

### C/CLI-API changes on existing features

Developers may need to change their code

* `str2cvec`: Renamed to `uri_str2cvec` and added a decode parameter:
  * To keep existing semantics: `str2cvec(...,cvp) -> str2cvec(...,1, cvp)`
* Removed `cli_debug()`. Use `cli_debug_backend()` or `cli_debug_restconf()` instead.
* Removed `yspec_free()` - replace with `ys_free()`
* `xmldb_get0()`:  Added xerr output parameter to
* `clixon_xml_parse_file()`: Removed `endtag` parameter.
* Restconf authentication callback (ca_auth) signature changed (again)
  * Minor modification to 5.0 change: userp removed.
  * New version is: `int ca_auth(h, req, auth_type, authp)`, where
    * `authp` is NULL for not authenticated, or the returned associated authenticated user
  * For more info see [clixon-docs/restconf](https://clixon-docs.readthedocs.io/en/latest/restconf.html)

### Minor features

* Application specialized error handling for specific error categories
  * See: https://clixon-docs.readthedocs.io/en/latest/misc.html#specialized-error-handling
* Added several fields to process-control status operation: active, description, command, status, starttime, pid, coredump
* Changed signal handling
  * Moved clixon-proc sigchild handling	from handler to clixon_events
* The base capability has been changed to "urn:ietf:params:netconf:base:1.1" following RFC6241.
* Made a separate Clixon datastore XML/JSON top-level symbol
  * Replaces the hardcoded "config" keyword.
  * Implemented by a compile-time option called `DATASTORE_TOP_SYMBOL` option in clixon_custom.h

### Corrected Bugs

* Fixed [clixon_proc can't start new process with PATH env #202](https://github.com/clicon/clixon/issues/202)
* Fixed ["aux" folder issue with Windows. #198](https://github.com/clicon/clixon/issues/198)
* Fixed [changing interface name not support with openconfig module #195](https://github.com/clicon/clixon/issues/195)
* Fixed [making cli_show_options's output more human readable #199](https://github.com/clicon/clixon/issues/199)
* Fixed Yang parsing of comments in (extension) unknown statements, to allow multiple white space
  * this also caused spaces to be printed to stdout after clixon-restconf was terminated
* Fixed: [clixon_restconf not properly configed and started by clixon_backend #193](clixon_restconf not properly configed and started by clixon_backend #193)
* Fixed: [backend start resconf failed due to path string truncated #192](https://github.com/clicon/clixon/issues/192)
* Fixed: [state showing error in cli with CLICON_STREAM_DISCOVERY_RFC8040 #191](https://github.com/clicon/clixon/issues/191)
* Fixed: [yang submodule show error in modules-state #190](yang submodule show error in modules-state #190)
* Fixed: [Backend can not read datastore with container named "config" #147](https://github.com/clicon/clixon/issues/147)
* Fixed: [The config false leaf shouldn't be configed in startup stage #189](https://github.com/clicon/clixon/issues/189)
* Fixed: [CLIXON is not waiting for the hello message #184](https://github.com/clicon/clixon/issues/184)
  * See also API changes
* Fixed: [comma in yang list name will lead to cli setting error #186](https://github.com/clicon/clixon/issues/186)
* Reverted blocked signal behavior introduced in 5.0.

## 5.0.1

10 March 2021

### Minor features

* Introduced a delay before making process start/stop/restart processes for race conditions when configuring eg restconf
* For restconf `CLICON_BACKEND_RESTCONF_PROCESS`, restart restconf if restconf is edited.

### Corrected Bugs

* Reverted blocked signal behavior introduced in 5.0.

## 5.0.0
27 February 2021

The 5.0.0 release is a new major release. The last major release was
4.0.0 in 13 July 2019.  Recently, large changes to RESTCONF
configuration has been made which is the primary reason for a new major version.

Other changes since 4.9 include NETCONF call home, a new client API, and a modified lock behavior.

Thanks Netgate and input from the Clixon community for making this possible!

### Known Issues

* Changed behavior in signal handlers and some race conditions, use 5.0.1 instead

### New features

* RESTCONF configuration is extended and changed for both fcgi and evhtp
  * RESTCONF options is moved from clixon-config.yang to clixon-restconf.yang
  * This applies to both evhtp and fcgi RESTCONF
  * The RESTCONF daemon can be read both from clixon config, as well from backend datastore
    * Controlled by `CLICON_BACKEND_RESTCONF_PROCESS` option
  * Network namespaces implemented for evhtp
  * For more info see [clixon-docs/restconf](https://clixon-docs.readthedocs.io/en/latest/restconf.html)
    * See also API changes section below for details
* NETCONF Call Home RFC 8071
  * See [Netconf/ssh callhome](https://clixon-docs.readthedocs.io/en/latest/netconf.html#callhome)
  * Solution description using openssh and utility functions, no changes to core clixon
  * Example: test/test_netconf_ssh_callhome.sh
  * RESTCONF Call home not yet implemented
* New clixon_client API for external access
  * See [client api docs](https://clixon-docs.readthedocs.io/en/latest/client.html)
  * Many systems using other tools employ such a model, and this API is an effort to make a usage of clixon easier
  * See [client-docs/client-integration](https://clixon-docs.readthedocs.io/en/latest/overview.html#client-integration)
  * This is work-in-progress and is still limiyed in scope
* Add a new process-control API clixon-lib.yang to manage processes
  * See [Example usage for RESTCONF](https://clixon-docs.readthedocs.io/en/latest/restconf.html#internal-start)

### API changes on existing protocol/config features

Users may have to change how they access the system

* Changed Netconf client session handling to make internal IPC socket persistent
  * Follows RFC 6241 7.5 closer
  * Previous behavior:
    * Close socket after each rpc
    * Release lock when socket closes (after each rpc)
  * New behavior
    * Keep socket open until the client terminates, not close after each RPC
    * Release lock until session (not socket) ends
  * Applies to all `cli/netconf/restconf/client-api` code
* RESTCONF configuration is unified and moved from clixon-config.yang to clixon-restconf.yang
  * Except `CLICON_RESTCONF_DIR` which remains in clixon-config.yang due to bootstrapping
    * `-d <dir>` command-line option removed
  * Failed authentication changed error return code from 403 Forbiden to 401 Unauthorized following RFC 8040
  * You may need to move config as follows (from clixon-config.yang to clixon-restconf.yang)
    * `CLICON_RESTCONF_PRETTY` -> restconf/pretty
    * `CLICON_RESTCONF_PATH` -> restconf/fcgi-path
* New clixon-restconf@2020-12-30.yang revision
  * Added: debug field
  * Added 'none' as default value for auth-type
  * Changed http-auth-type enum from 'password' to 'user'
  * Changed namespace from `https://clicon.org/restconf` to `http://clicon.org/restconf`
* Handling empty netconf XML messages "]]>]]>" is changed from being accepted to return an error.
* New clixon-lib@2020-12-30.yang revision
  * Changed: RPC process-control output parameter status to pid
* New clixon-config@2020-12-30.yang revision
  * Added CLICON_ANONYMOUS_USER
    * Only applies to restconf
    * used to be hardcoded as "none", now default value is "anonymous"
  * Removed obsolete RESTCONF and SSL options (CLICON_SSL_* and CLICON_RESTCONF_IP*/HTTP*)
  * Removed obsolete: CLICON_TRANSACTION_MOD option
  * Marked as obsolete: CLICON_RESTCONF_PATH CLICON_RESTCONF_PRETTY

### C/CLI-API changes on existing features

Developers may need to change their code

* Restconf authentication callback (ca_auth) signature changed
  * Not backward compatible: All uses of the ca-auth callback in restconf plugins must be changed
  * New version is: `int ca_auth(h, req, auth_type, authp, userp)`
    * where `auth_type` is the requested authentication-type (none, client-cert or user-defined)
    * `authp` is the returned authentication flag
    * `userp` is the returned associated authenticated user
    * and the return value is three-valued: -1: Error, 0: not handled, 1: OK
  * For more info see [clixon-docs/restconf](https://clixon-docs.readthedocs.io/en/latest/restconf.html)
* RPC msg C API rearranged to separate socket/connect from connect
  * Removed `xsock0` parameter from `clicon_rpc_msg()`, use `clicon_rpc_msg_persistent()` instead
* Added `cvv_i` output parameter to `api_path_fmt2api_path()` to see how many cvv entries were used.
* CLIspec dbxml API: Ability to specify deletion of _any_ vs _specific_ entry.
  * In a cli_del() call, the cvv arg list either exactly matches the api-format-path in which case _any_ deletion is specified, otherwise, if there is an extra element in the cvv list, that is used for a specific delete.

### Minor changes

* If a signal handler runs during `select()` loop in `clixon_event_loop()` and unless the signal handler sets clixon_exit, the select will be restarted.
  * Existing behavior for SIGTERM/SIGINT to exit is maintained
  * This was for supporting SIGCHLD of forked restconf that crashes or being killed externally.
* Look for symbols in plugins using `dlsym(RTLD_DEFAULT)` instead of `dlsym(NULL)` for more portable use
  * Thanks jdl@netgate.com
* Added support for the following XPATH functions:
  * `false()`, `true()`
* Make the yang `augment` target node check stricter,
  * Instead of printing a warning, it will terminate with error.
* Implemented: [Simplifying error messages for regex validations. #174](https://github.com/clicon/clixon/issues/174)
* For backend, also `ca_reset` callback also when the startup-mode is `none`, such as the command-line `-s none`
* Added validation of clixon-restconf.yang: server-key-path and server-cert-path must be present if ssl enabled.
  * Only if `CLICON_BACKEND_RESTCONF_PROCESS` is true
* Use [https://github.com/clicon/libevhtp](https://github.com/clicon/libevhtp) instead of [https://github.com/criticalstack/libevhtp](https://github.com/criticalstack/libevhtp) as a source of the evhtp source
* Limited fuzz by AFL committed,
  * see [fuzz/README.md](fuzz/README.md) for details

### Corrected Bugs

* Fixed: [Recursive calling xml_apply_ancestor is no need #180](https://github.com/clicon/clixon/issues/180)
* Fixed: [Negation operator in 'must' statement makes backend segmentation fault](https://github.com/clicon/clixon/issues/179)
* Fixed YANG extension/unknown problem shown in latest openconfig where other than a single space was used between the unknown identifier and string
* Fixed: [Augment that reference a submodule as target node fails #178](https://github.com/clicon/clixon/issues/178)
* Fixed a memory error that was reported in slack by Pawel Maslanka
  * The crash printout was: `realloc(): invalid next size Aborted`
* Fixed: [Irregular ordering of cli command + help text when integer is a part of command #176](https://github.com/clicon/clixon/issues/176)
  * Enabled by default `cligen_lexicalorder_set()` using strversmp instead of strcmp
* Fixed: [xml bind yang error in xml_bind_yang_rpc_reply #175](https://github.com/clicon/clixon/issues/175)
* Fixed: [Is there an error with plugin's ca_interrupt setting ? #173](https://github.com/clicon/clixon/issues/173)
* Fixed: Unknown nodes (for extensions) did not work when placed directly under a grouping clause
* Fixed: [Behaviour of Empty LIST Input in RESTCONF JSON #166](https://github.com/clicon/clixon/issues/166)
* Netconf split lines input (input fragments) fixed
  * If netconf input is split on several lines, eg using stdin: "<a>\nfoo</a>]]>]]>", then under some circumstances, the string could be split so that the initial string was dropped and only "</a>]]>]]>" was properly processed. This could also happen to a socket receiving a sub-string and then after a delay receive the rest.
* [Presence container configs not displayed in 'show config set' #164 ](https://github.com/clicon/clixon/issues/164)
  * Treat presence container as a leaf: always print a placeholder regardless if it has children or not.

## 4.9.0
18 December 2020

### New features

* New process-control RPC feature in clixon-lib.yang to manage processes
  * This is an alternative to manage a clixon daemon direct via systemd, containerd or other ways to manage processes
  * One important special case is starting the clixon-restconf daemon internally
  * This is how it works:
    * Register a process via `clixon_process_register(h, name, namespace, argv, argc)`
    * Use process-control RPC defined in clixon-lib.yang to start/stop/restart or query status on that process
  * Enable in backend for starting restconf internally using `CLICON_BACKEND_RESTCONF_PROCESS`.
* New YANG extension functionality: mark YANG and use in plugins
  * Documentation: https://clixon-docs.readthedocs.io/en/latest/misc.html#extensions
  * As one usage of this extensions, the `autocli-op` extension has been added to annotate YANG with autocli properties, "hidden" commands being the first function.
  * See [Augment auto-cli for hiding/modifying cli syntax #156](https://github.com/clicon/clixon/issues/156) and [hiding auto-generated CLI entries #153](https://github.com/clicon/clixon/issues/153)
* New restconf configuration model: `clixon-restconf.yang`
  * The new restconf config, including addresses, authentication type, is set either in clixon-config local config or in backend datastore (ie running)
  * This only applies to the evhtp restconf daemon, not fcgi/nginx, where the nginx config is used.
  * The RESTCONF clixon-config options are obsolete
  * Thanks to Dave Cornejo for the idea

### API changes on existing protocol/config features

Users may have to change how they access the system

* New clixon-lib@2020-12-08.yang revision
  * Added: autocli-op extension (see new features)
  * Added: rpc process-control for process/daemon management
* New clixon-config@2020-11-03.yang revision
  * Added `CLICON_BACKEND_RESTCONF_PROCESS`
  * Moved to clixon-restconf.yang, still remains but marked as obsolete:
    - `CLICON_RESTCONF_IPV4_ADDR`
    - `CLICON_RESTCONF_IPV6_ADDR`
    - `CLICON_RESTCONF_HTTP_PORT`
    - `CLICON_RESTCONF_HTTPS_PORT`
    - `CLICON_SSL_SERVER_CERT`
    - `CLICON_SSL_SERVER_KEY`
    - `CLICON_SSL_CA_CERT`
  * Removed obsolete option 'CLICON_TRANSACTION_MOD`;

### C/CLI-API changes on existing features

Developers may need to change their code

* Auto-cli changed signature of `yang2cli()`.
* Added by-ref parameter to `ys_cv_validate()` returning sub-yang spec was validated in a union.
* Changed first parameter from `int fd` to `FILE *f` in the following functions:
  * `clixon_xml_parse_file()`, `clixon_json_parse_file()`, `yang_parse_file()`

### Minor changes

* Initial NBMA functionality (thanks: @benavrhm): "ds" resource
* Support for building static lib: `LINKAGE=static configure`
  * One usecase is coverage and fuzzing
* Change comment character to be active anywhere to beginning of _word_ only.
  * ' # This is a comment', but ' This# is not a comment'
  * See [Change CLIgen comments](https://github.com/clicon/cligen/issues/55)
* Improved performance of parsing files as described in [Bytewise read() of files is slow #146](https://github.com/clicon/clixon/issues/146), thanks: @hjelmeland
* Added new backend plugin: `ca_pre-demon` when backend is daemonized just prior to forking.
* Added XPATH function `position`
* Added new revision of main example yang: `clixon-example@2020-12-01.yang`

### Corrected Bugs

* [Delete and show config are oblivious to the leaf value #157](https://github.com/clicon/clixon/issues/157)
  * Added equality of values necessary condition in edit-config delete/remove of leafs
* Fixed error memory in RESTCONF PATCH/PUT when accessing top-level data node.
* Fixed: [ Calling copy-config RPC from restconf #158](https://github.com/clicon/clixon/issues/158)
* Fixed: [namespace prefix nc is not supported in full #154](https://github.com/clicon/clixon/issues/154)
  * edit-config "config" parameter did not work with prefix other than null
* Fixed [YANG: key statement in rpc/notification list #148](https://github.com/clicon/clixon/issues/148)
  * Do not check uniqueness among lists without keys
* Fixed typo: [False Header Content_type in restconf error #152](https://github.com/clicon/clixon/issues/152)
* Added message-id attributes in error and hello replies
  * See [namespace prefix nc is not supported in full #154](https://github.com/clicon/clixon/issues/154)
* Fixed [Clixon backend generates wrong XML on empty string value #144](https://github.com/clicon/clixon/issues/144)

### New features

* Prototype of collection draft
  * This is prototype work for ietf netconf work
  * See draft-ietf-netconf-restconf-collection-00.txt
  * New yang: ietf-restconf-collection@2020-10-22.yang
  * New http media: application/yang-collection+xml/json

## 4.8.0
18 October 2020

The Clixon 4.8 release features a new auto-cli implementation, a new "conf.d"-style configuration directory and more XPATH functionality.

### New features

* New YANG generated auto-cli feature with syntax modes
  * The existing autocli does not support modes, complete paths must be given, eg: `set a b c d 42`.
  * In the new auto-cli, automatic modes are present at each YANG syntax node level, eg the above can be given as: `edit a b c; set d 4; top`
  * The existing CLI API remains, the new API is as follows: `cli_auto_edit()`, `cli_auto_up()`, `cli_auto_top()`, `cli_auto_show()`, `cli_auto_set()`, `cli_auto_merge()`, `cli_auto_create()`, `cli_auto_del()`.
  * See `test/test_cli_auto.sh` for an example of the new API, and `apps/cli/cli_auto.c` for the source code of the new callback API.
  * See the [auto-cli documentation](https://clixon-docs.readthedocs.io/en/latest/cli.html#the-auto-cli) and main example.
* Added support for the following XPATH functions:
  * `count`, `name`, `contains`, `not`, as defined in [xpath 1.0](https://www.w3.org/TR/xpath-10)
  * `deref`, `derived-from` and `derived-from-or-self` from RFC7950 Section 10.
    * these are in particular used in YANG augment/when statements
  * Improved error handling
    * Verification of XPath functions is done at startup when yang modules are loaded, not when XPaths are evaluated.
    * Separation of "not found" and "not implemented" XPath functions
    * Both give a fatal error (backend does not start).
* Configuration directory
  * A new configuration option `CLICON_CONFIGDIR` has been added for loading of extra config files
  * If not given, only the main configfile is loaded.
  * If given, and if the directory exists, the files in this directory will be loaded alphabetically AFTER the main config file in the following way:
    * leaf values are overwritten
    * leaf-list values are appended
  * You can override file setting with `-E <dir>` command-line option.

### API changes on existing protocol/config features

Users may have to change how they access the system

* New clixon-config@2020-10-01.yang revision
  * Added option for configuration directory: `CLICON_CONFIGDIR`
* Not implemented XPath functions will cause a backend exit on startup, instead of being ignored.
* More explanatory validation error messages for when and augments error messages.
  * Example: error-message: `Mandatory variable` -> `Mandatory variable of edit-config in module ietf-netconf`.

### Minor changes

* Removed string limit on cli prompt and cli mode name
* Added more sanity checks on incoming top-level rpc and hello messages, including verifying top-level namespace
* Added inline state field to clixon-example.yang
* Added stricter check on schema-node identifier checking, such as for augments.
  * These checks are now made at YANG loading time
* Added sanity check that a yang module name matches the filename

### Corrected Bugs

* Fixed: [namespace prefix nc is not supported](https://github.com/clicon/clixon/issues/143)
* Fixed: [Crash seen with startup mode as running with the XML_DB format being set to JSON. [clixon : 4.7.0] #138](https://github.com/clicon/clixon/issues/138)
* Fixed: Performance enhancement of unique list check (of duplicate keys)
* Fixed: Validate/commit error with false positive yang choice changes detected in validation found in ietf-ipfix-psamp.yang.
* Fixed: Accepted added subtrees containing lists with duplicate keys.
* Fixed: [default state data returned with get-config](https://github.com/clicon/clixon/issues/140)
  * Generalized default code for both config and state

## 4.7.0
14 September 2020

This release is primarily a bugfix and usability improvement release, no major new features.

### API changes on existing protocol/config features

Users may have to change how they access the system

* Netconf as default namespace has been disabled by default.
  * Only requests on the form: `<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config>...` are accepted
  * All replies are on the form: `<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">...`
  * Requests such as: `<rpc><edit-config>...` are not accepted.
  * You can revert this behaviour (to clixon pre-4.6 behaviour) by enabling `CLICON_NAMESPACE_NETCONF_DEFAULT`
  * This API change is a consequence of: [copy-config's RPC cxobj parameter does not contain namespace #131](https://github.com/clicon/clixon/issues/131)
* NACM datanode paths fixed to canonical namespace
  * The fix of [Cannot create or modify NACM data node access rule with path using JSON encoding #129](https://github.com/clicon/clixon/issues/129) leads to that data-node paths, eg `<rule>...<path>ex:table/ex:parameter</path></rule>` instance-identifiers are restricted to canonical namespace identifiers for both XML and JSON encoding. That is, if a symbol (such as `table` above) is a symbol in a module with prefix `ex`, another prefix cannot be used, even though defined with a `xmlns:` rule.

* New clixon-config@2020-08-17.yang revision
  * Added options for Restconf evhtp setting default bind socket address and ports:
    * `CLICON_RESTCONF_IPV4_ADDR`, `CLICON_RESTCONF_IPV6_ADDR`, `CLICON_RESTCONF_HTTP_PORT`, `CLICON_RESTCONF_HTTPS_PORT`
  * Added option for using NETCONF default namespace: `CLICON_NAMESPACE_NETCONF_DEFAULT`
  * Added options for better handling of long and multi-line CLI help strings:
    * `CLICON_CLI_HELPSTRING_TRUNCATE`, `CLICON_CLI_HELPSTRING_LINES`
  * Changed semantics of `CLICON_NACM_DISABLED_ON_EMPTY` to "disable NACM if there is no _NACM_ configuration", instead of "disable NACM if there is no _configuration_".

### Minor changes

* Debug messages
  * Added cli command debug printf on debug level 1
  * Moved all parse debug printfs to level 3
* Added `-r` command-line option to restconf daemon to NOT lower privileges to wwwuser if started from root.
* Changed CLI help strings behaviour on query (?) for long and multi-line help strings.
  * If multiple strings (eg "\n" in text), indent before each new line
  * Primarily for auto-cli where long help strings are generated from YANG descriptions, but applies as well for manual long/multi-line help strings
  * New config option: `CLICON_CLI_HELPSTRING_TRUNCATE`: Truncate help string on right margin mode
  * New config option: `CLICON_CLI_HELPSTRING_LINES`: Limit of number of help strings to show

### Corrected Bugs

* Fixed: Restconf failed put/post could leave residue in candidate causing errors in next put/post
* Fixed: [clixon_netconf does not respond to hello #136](https://github.com/clicon/clixon/issues/136)
  * The error showed only when CLICON_MODULE_LIBRARY_RFC7895 was disabled.
* Fixed: Do not check min/max constraints on state data in config validate code
* Fixed: [min-elements attribute prevents from deleting list entries #133](https://github.com/clicon/clixon/issues/133)
* Fixed: [xmldb_get0 returns invalid candidate on startup transaction callbacks #126](https://github.com/clicon/clixon/issues/126). Always clear candidate-db before db initialization.
* Fixed: YANG `uses` statements in sub-modules did not search for `grouping` statements in other submodules of the module it belongs to.
* Fixed: [CLI crash if error-info is empty #134](https://github.com/clicon/clixon/issues/134)
* Fixed: [copy-config's RPC cxobj parameter does not contain namespace #131](https://github.com/clicon/clixon/issues/131)
  * See also "Netconf as default namespace has been disabled by default" above
* Fixed: [Cannot create or modify NACM data node access rule with path using JSON encoding #129](https://github.com/clicon/clixon/issues/129). The evaluation of NACM datanode rule path is assumed to be canonical namespace and cannot be overruled with `xmlns` rules.
* Corrected error message for list min/max-value to comply to RFC 7950: a proper path is now returned, previously only the final list symbol was returned. This error-path is also now exposed in the CLI error message correctly.
  * Example: `<error-path>/c/a1</error-path>`
* Fixed: [Yang modules skipped if the name is a proper prefix of other module name](https://github.com/clicon/clixon/issues/130)
* Fixed an error in global default values. Global default values were not written to datastore after startup, but AFTER an edit/commit.
* Fixed: [Type / Endianism problem in yang_parse_file #128](https://github.com/clicon/clixon/issues/128)
* Fixed: [(CLI) the description of a used grouping is shown instead of the encapsulating container #124](https://github.com/clicon/clixon/issues/124)
  * Uses/group and augments only copies *schemanodes*. This means reference/description/.. etc are not copied, the original is kept. Also, as a side-effect of the bugfix, a final cardinality sanity check is now made after all yang modifications, not only at the time the file is loaded.

## 4.6.0
14 August 2020

The 4.6.0 release introduces a new RESTCONF solution using "native" http. An important API change is top-level default value assignment that may cause a NACM read-only dead-lock. The NACM recovery user handling has been improved for this case. Numerous bugfixes and improvements. Vagrant tests have been added.

Thanks Netgate for making this possible.

### Major New features

* A new restconf configuration where Clixon restconf daemon is integrated with the [libevhtp](https://github.com/criticalstack/libevhtp) embedded web server.
  * The existing FCGI restconf solution will continue to be supported for NGINX and other reverse proxies with a FCGI API and is still the default.
  * The restconf code has been refactored to support both modes. Hopefully, it should be straightforward to add another embedded server, such as GNU microhttpd.
  * The new restconf module is selected using a compile-time autotools configure as follows:
    * `--with-restconf=fcgi    FCGI interface for stand-alone web rev-proxy eg nginx (default)`
    * `--with-restconf=evhtp   Integrate restconf with libevhtp server`
    * `--without-restconf      Disable restconf altogether`
  * SSL server and client certificates are supported.
  * SSE Stream notification is not yet supported.

### API changes on existing protocol/config features

Users may have to change how they access the system

* New clixon-config@2020-06-17.yang revision
  * Added `CLICON_CLI_LINES_DEFAULT` for setting window row size of raw terminals
  * Added  enum HIDE to `CLICON_CLI_GENMODEL` for auto-cli
  * Added SSL cert info for evhtp restconf https:
    * `CLICON_SSL_SERVER_CERT`
    * `CLICON_SSL_SERVER_KEY`
    * `CLICON_SSL_CA_CERT`
  * Added `CLICON_NACM_DISABLED_ON_EMPTY` to mitigate read-only "dead-lock" of empty startup configs.
  * Removed default valude of `CLICON_NACM_RECOVERY_USER`
* Top-level default leafs assigned.
  * Enforcing RFC 7950 Sec 7.6.1 means unassigned top-level leafs (or leafs under non-presence containers) are assigned default values.
  * In this process non-presence containers may be created.
  * See also [default values don't show up in datastores #111](https://github.com/clicon/clixon/issues/111).
  * If a default value is replaced by an actual value, RESTCONF return values have changed from `204 No Content` to `201 Created`
* NACM default behaviour is read-only (empty configs are dead-locked)
  * This applies if NACM is loaded and `CLICON_NACM_MODE` is `internal`
  * Due to the previous bult (top-level default leafs)
  * This means that empty configs or empty NACM configs are not writable (deadlocked).
  * Workarounds:
    1. Access the system with the recovery user, see clixon option `CLICON_NACM_RECOVERY_USER`
    2. Edit the startup-db with a valid NACM config and restart the system
    3. Enable clixon option `CLICON_NACM_DISABLED_ON_EMPTY`: if the config is empty, you can add a NACM config in a first edit.
* NACM recovery user session is improved.
  * If `CLICON_NACM_CREDENTIALS` is `except`, a specific `CLICON_NACM_RECOVERY_USER` can make any edits and bypass NACM rules.
  * Either the recovery user exists as UNIX user and is logged in by the client (eg CLI/NETCONF), or
  * The client is "trusted" (root/wwwuser) and the recovery user is used as a pseudo-user when accessing the backend.
  * One can make the recovery user a proper authenticated (eg SSL client certs) user, or one may define root to be that user using local access.

* Netconf lock/unlock behaviour changed to adhere to RFC 6241
  * Changed commit lock error tag from "lock denied" to "in-use".
  * Changed unlock error message from "lock is already held" to "lock not active" or "lock held by other session".
  * See also related bugfix [lock candidate succeeded even though it is modified #110](https://github.com/clicon/clixon/issues/110)
* Restconf FCGI (eg via nginx) have changed reply message syntax slightly as follows (due to refactoring and common code with evhtp):
  * Bodies in error retuns including html code have been removed
  * Some (extra) CRLF:s have been removed
* Restconf and Netconf error handling
  * Changed and enhanced several `bad-element` error replies to `unknown-element` with more detailed error-message.

### C/CLI-API changes on existing features

Developers may need to change their code

* Added yang-binding `yb` parameter to `xmldb_get0()` and all xmldb get functions.
* Simplified the _module-specific_ upgrade API.
  * The new API is documented here: [Module-specific upgrade](https://clixon-docs.readthedocs.io/en/latest/upgrade.html#module-specific-upgrade)
  * The change is not backward compatible. The API has been simplified which means more has to be done by the programmer.
  * In summary, a user registers an upgrade callback per module. The callback is called at startup if the module is added, has been removed or if the revision on file is different from the one in the system. 
  * The register function has removed `from` and `rev` parameters: `upgrade_callback_register(h, cb, namespace, arg)`
  * The callback function has a new `op` parameter with possible values: `XML_FLAG_ADD`, `XML_FLAG_CHANGE` or `XML_FLAG_CHANGE`: `clicon_upgrade_cb(h, xn, ns, op, from, to, arg, cbret)`

* Added new cli show functions to work with cligen_output for cligen scrolling to work. To achieve this, replace function calls as follows:
  * `xml2txt(...)` --> `xml2txt_cb(..., cligen_output)`
  * `xml2cli(...)` --> `xml2cli_cb(..., cligen_output)`
  * `clicon_xml2file(...)` --> `clicon_xml2file_cb(..., cligen_output)`
  * `xml2json(...)` --> `xml2json_cb(..., cligen_output)`
  * `yang_print(...)` --> `yang_print_cb(..., cligen_output)`

* Added prefix for `cli_show_config`/`cli_show_auto' so that it can produce parseable output
* Replaced the global variable `debug` with access function: `clicon_debug_get()`.
* Due to name collision with libevent, all clixon event functions prepended with `clixon_`. You need to rename your event functions as follows:
  * `event_reg_fd()` -> `clixon_event_reg_fd()`
  * `event_unreg_fd()` -> `clixon_event_unreg_fd()`
  * `event_reg_timeout()` -> `clixon_event_reg_timeout()`
  * `event_unreg_timeout()` -> `clixon_event_unreg_timeout()`
  * `event_poll()` -> `clixon_event_poll()`
  * `event_loop()` -> `clixon_event_loop()`
  * `event_exit()` -> `clixon_event_exit()`

### Minor changes

These are new features that did not quite make it to the "Major features" list

* Auto-CLI enhancements
  * Traditionally the autocli has only been configuration-based. The autocli has now been extended with state, where a new syntax tree (`@datanodestate`) is also generated along with the config clispec tree.
  * New mode `GT_HIDE` set by option `CLICON_CLI_GENMODEL_TYPE` to collapse non-presence containers that only contain a single list
  * Added a prefix for cli_show_config/cli_show_auto so that it can produce parseable output
  * Thanks dcornejo@netgate.com for trying it out and for suggestions

* Bundle internal NETCONF messages
  * A RESTCONF operation could produce several (up to four) internal NETCONF messages between RESTCONF server and backend. These have now been bundled into one.
  * This improves performance for RESTCONF, especially latency.
  * Added several extensions to clixon NETCONF to carry information between RESTCONF client and backend. The extensions are documented [here](https://clixon-docs.readthedocs.io/en/latest/misc.html#internal-netconf)This includes several attributes:
* New backend switch: `-q` : Quit startup directly after upgrading and print result on stdout.
  * This is useful when testing the upgrade functionality
* Enhanced Clixon if-feature handling:
  * If-feature now supports and/or lists, such as: `if-feature "a and b"` and `if-feature "a or b or c"`. However, full if-feature-expr including `not` and nested boolean experessions is still not supported.
  * Sanity check: if an `if-feature` statement exists, a corresponding `feature` statement must exists that declares that feature.
* Optimized get config xpath of large lists, such as `a[x=1000]` in a list of 100000s `a:s`.
* Added docker support for three restconf modes: nginx/fcgi(default); evhtp ; and none.
* Added [Vagrant tests](test/vagrant/README.md)
* Added new function `clicon_xml2str()` to complement xml_print and others that returns a malloced string.
* Added new function `xml_child_index_each()` to iterate over the children of an XML node according to the order defined by an explicit index variable. This is a complement to `xml_child_each()` which iterates using the default order.

### Corrected Bugs

* Fixed: [default values don't show up in datastores #111](https://github.com/clicon/clixon/issues/111).
  * See also API changes since this changes NACM behavior for example.
* Fixed: Don't call upgrade callbacks if no revision defined so there's no way to determine right way 'from' and 'to'
* Fixed: [lock candidate succeeded even though it is modified #110](https://github.com/clicon/clixon/issues/110)
* Fixed: [Need to add the possibility to use anchors around patterns #51](https://github.com/clicon/cligen/issues/51):
  * Dont escape `$` if it is last in a regexp in translation from XML to POSIX.
* Fixed `CLICON_YANG_UNKNOWN_ANYDATA` option for config and state data.
  * Set this option of you want to treat unknwon XML as *anydata_.
* Fixed: [Double free when using libxml2 as regex engine #117](https://github.com/clicon/clixon/issues/117)
* Fixed: Reading in a yang-spec file exactly the same size as the buffer (1024/2048/4096/...) could leave the buffer not terminated with a 0 byte
* Fixed: The module `clixon-rfc5277` was always enabled, but should only be enabled when `CLICON_STREAM_DISCOVERY_RFC5277` is enabled.

## 4.5.0
12 May 2020

The 4.5.0 release introduces XPaths in the NACM implementation thus
completing the RPC and Data node access. There has also been several
optimizations. Note that this version must be run with CLIgen 4.5, it
cannot run with CLIgen 4.4 or earlier.

Thanks to everyone at Netgate for making this possible

### Major New features

* NACM RFC8341 datanode read and write paths
  * This completes the NACM RPC and Data node access checks (only remaining NACM access point is notification)
* Added functionality to restart an individual plugin.
  * New clixon-lib:restart-plugin RPC
* Two new plugin callbacks added
  * ca_daemon: Called just after a server has "daemonized", ie put in background.
  * ca_trans_commit_done: Called when all plugin commits have been done.
    * Note: If you have used "end" callback and using transaction data, you should probably use this instead.

### API changes on existing protocol/config features (For users)

* Stricter validation detecting duplicate container or leaf in XML.
  * Eg `<x><a/><a/></x>` is invalid if `a` is a leaf or container.
* New clixon-lib@2020-04-23.yang revision
  * New RPC: `stats` for clixon XML and memory statistics.
  * New RPC: `restart-plugin` for restarting individual plugins without restarting backend.
* New clixon-config@2020-04-23.yang revision
  * Removed xml-stats non-config data (replaced by rpc `stats` in clixon-lib.yang)
  * Added option `CLICON_YANG_UNKNOWN_ANYDATA` to treat unknown XML (wrt YANG) as anydata.
    * This is a way to loosen sanity checks if you need to accept eg unsynchronized YANG and XML
* Stricter incoming RPC sanity checking, error messages may have changed.
* Changed output of `clixon_cli -G` option to show generated CLI spec original text instead of resulting parse-tree, which gives better detail from a debugging perspective.

### C-API changes on existing features (For developers)

* Length of xml vector in many structs changed from `size_t` to `int`since it is a vector size, not byte size.
  * Example: `transaction_data_t`
* `xml_merge()` changed to use 3-value return: 1:OK, 0:Yang failed, -1: Error
* Some function changed to use 3-value return: 1:OK, 0:Yang failed, -1: Error.
  * Example: `xml_merge()`
* `clixon_netconf_error(category, xerr, msg, arg)` removed first argument -> `clixon_netconf_error(xerr, msg, arg)`
* CLI
  * `clicon_parse()`: Changed signature due to new cligen error and result handling:
  * Removed: `cli_nomatch()`

### Optimzations
* Optimized namespace prefix checks at xml parse time: using many prefixes slowed down parsing considerably
* Optimized cbuf handling in parsing and xml2cbuf functions: use of new `cbuf_append()` function.
* Optimized xml scanner to read strings rather than single chars
* Identify early that trees are disjunct instead of recursively merge in `xml_merge`
* Optimizations of `yang_bind` for large lists: use a "sibling/template" to use same binding as previous element.
* Reduced memory for attribute and body objects, by allocating less memory in `xml_new()` than for elements, reducing XML storage with ca 25%
* Cleared startup-db cache after restart, slashing datastore cache with (best-case) a third.
* Removed nameserver binding cache for leaf/leaf-list objects.
* Remove xml value cache after sorting (just use cligen value cache at sorting, remove after use)

### Minor changes
* Added decriptive error message when plugins produce invalid state XML.
  * Example: `<error-tag>operation-failed</error-tag><error-info><bad-element>mystate</bad-element></error-info><error-message>No such yang module. Internal error, state callback returned invalid XML: example_backend</error-message>`
  * Such a message means there is something wrong in the internal plugins or elsewehere, ie it is not a proper end-user error.
* Adapted to CLIgen 4.5 API changes, eg: `cliread()` and `cliread_parse()`
* Renamed utility function `clixon_util_insert()` to `clixon_util_xml_mod()` and added merge functionality.
* Sanity check of duplicate prefixes in Yang modules and submodules as defined in RFC 7950 Sec 7.1.4

### Corrected Bugs

* Fixed: Insertion of subtree leaf nodes were not made in the correct place, always ended up last regardless of yang spec (if ordered-by system).

## 4.4.0
5 April 2020

This release focusses on refactoring and bugfixing. Lots of
changes to basic XML/YANG/RESTCONF code, including a tighter XML/YANG
binding. Memory profiling and new buffer growth management. New
features include optimized search functions and a repair callback.

### Major New features

* New "general-purpose" datastore upgrade/repair callback called once on startup, intended for low-level general upgrades and as a complement to module-specific upgrade.
  * Called on startup after initial XML parsing, but before module-specific upgrades
  * Enabled by defining the `.ca_datastore_upgrade`
  * [General-purpose upgrade documentation](https://clixon-docs.readthedocs.io/en/latest/backend.html#general-purpose)
* New and updated search functions using xpath, api-path and instance-id, and explicit indexes
  * New search functions using api-path and instance_id:
    * C search functions: `clixon_find_instance_id()` and `clixon_find_api_path()`
  * Binary search optimization in lists for indexed leafs in all three formats.
    * This improves search performance to O(logN) which is drastical improvements for large lists.
  * You can also register explicit indexes for making binary search (not only list keys)
  * For more info, see docs at [paths](https://clixon-docs.readthedocs.io/en/latest/paths.html) and
[search](https://clixon-docs.readthedocs.io/en/latest/xml.html#searching-in-xml)

### API changes on existing protocol/config features (You may have have to change how you use Clixon)
* In the bbuild system, you dont need to do `make install-include` for installing include files for compiling. This is now included in the actions done by `make install`.
* State data is now ordered-by system for performance reasons. For example, alphabetically for strings and numeric for integers
  * Controlled by compile-time option `STATE_ORDERED_BY_SYSTEM`
* Obsolete configuration options present in clixon configuration file will cause clixon application to exit at startup.
* JSON
  * Empty values in JSON has changed to comply to RFC 7951
    * empty values of yang type `empty` are encoded as: `{"x":[null]}`
    * empty string values are encoded as: `{"x":""}` (changed from `null` in 4.0 and `[null]` in 4.3)
    * empty containers are encoded as: `{"x":{}}`
    * empty elements in unknown/anydata/anyxml encoded as: `{"x":{}}` (changed from `{"x":null}`)
  * JSON parse error messages change from `on line x: syntax error,..` to `json_parse: line x: syntax error`
* State data
  * Bugfix of `config false` statement may cause change of sorting of lists in GET opertions
    * Lists were sorted that should not have been.
* Config options
  * New clixon-config@2020-02-22.yang revision
    * Search index extension `search_index` for declaring which non-key variables are explicit search indexes (to support new optimized search API)
    * Added `clixon-stats` state for clixon XML and memory statistics.
    * Added: `CLICON_CLI_BUF_START` and `CLICON_CLI_BUF_THRESHOLD` so you can change the start and threshold of quadratic and linear growth of CLIgen buffers (cbuf:s)
    * Added: CLICON_VALIDATE_STATE_XML for controling validation of user state XML
  * Obsoleted and removed XMLDB format "tree". This function did not work. Only xml and json allowed.
* CLI
  * Session-id CLI functionality delayed: "lazy evaluation"
    * From a cli perspective this is a revert to 4.1 behaviour, where the cli does not immediately exit on start if the backend is not running, but with the new session-id function
* Error messages
  * Unknown-element error message is more descriptive, eg from `namespace is: urn:example:clixon` to: `Failed to find YANG spec of XML node: x with parent: xp in namespace urn:example:clixon`.
  * On failed validation of leafrefs, error message changed from: `No such leaf` to `No leaf <name> matching path <path>`.
  * CLI Error message (clicon_rpc_generate_error()) changed when backend returns netconf error to be more descriptive:
    * Original: `Config error: Validate failed. Edit and try again or discard changes: Invalid argument`
    * New (example): `Validate failed. Edit and try again or discard changes: application operation-failed Identityref validation failed, undefined not derived from acl-base"

### C-API changes on existing features (you may need to change your plugin C-code)
* `xml_new()` changed from `xml_new(name, xp, ys)`  to `xml_new(name, xp, type)`
  * If you have used, `ys`, add `xml_spec_set(x, ys)` after the statement
  * If you have `xml_type_set(x, TYPE)`  after the statement, you can remove it and set it directly as: `xml_new(name, xp, TYPE)`
* `xml_type_set()` has been removed in the API. The type must be set at creation time with `xml_new`
* `clicon_rpc_generate_error()` renamed to `clixon_netconf_error()` and added a category parameter
* All uses of `api_path2xpath_cvv()` should be replaced by `api_path2xpath()`
   * `api_path2xpath()` added an `xerr` argument.
* XML and JSON parsing functions have been rearranged/cleaned up as follows:
   * Three value returns: -1: error, 0: parse OK, 1: parse and YANG binding OK.
   * New concept called `yang_bind` that defines how XML symbols are bound to YANG after parsing (see below)
   * New XML parsing API:
      * `clixon_xml_parse_string()`
      * `clixon_xml_parse_file()`
   * New JSON parsing API, with same signature as XML parsing:
      * `clixon_json_parse_string()`
      * `clixon_xml_parse_file()`
* Yang binding type has been introduced as a new concept and used in the API with the following values:
   * `YB_MODULE` : Search for matching yang binding among top-level symbols of Yang modules
   * `YB_PARENT` : Assume yang binding of existing parent and match its children by name
   * `YB_NONE`   : Don't do YANG binding
* XML YANG binding API have been rearranged as follows:
   * `xml_bind_yang_rpc()`
   * `xml_bind_yang_rpc_reply()`
   * `xml_bind_yang()`
   * `xml_bind_yang0()`
   * All have three-value return values: -1: error, 0: YANG binding failed, 1: parse and YANG binding OK.

### Minor changes

* Moved hello example to [clixon-examples](https://github.com/clicon/clixon-examples)
* Sanity check of mandatory key statement for Yang LISTs.
  * If fails, exit with error message, eg: `Yang error: Sanity check failed: LIST vsDataContainer lacks key statement which MUST be present (See RFC 7950 Sec 7.8.2)`
  * Can be disabled by setting `CLICON_CLICON_YANG_LIST_CHECK` to `false`
* Replaced compile option `VALIDATE_STATE_XML` with runtime option `CLICON_VALIDATE_STATE_XML`.
* Memory footprint
  * Namespace cache is populated on-demand, see `xml2ns()`.
  * CBUF start level is set to 256 (`CLICON_CLI_BUF_START` option)
  * Reduced xml child vector default size from 4 to 1 with quadratic growth to 64K then linear
* Test framework
  * Added `-- -S <file>` command-line to main example to be able to return any state to main example.
  * Added `test/cicd` test scripts for running on a set of other hosts
* C-API:
  * Added instrumentation: `xml_stats` and `xml_stats_global`.
  * Added object-based `clixon_xvec` as a new programming construct for contiguous XML object vectors.
    * See files: `clixon_xml_vec.[ch]`
* C-code restructuring
  * clixon_yang.c partitioned and moved code into clixon_yang_parse_lib.c and clixon_yang_module.c and move back some code from clixon_yang_type.c.
    * partly to reduce size, but most important to limit code that accesses internal yang structures, only clixon_yang.c does this now.

### Corrected Bugs

* Fixed: Datastore read on startup got fixed default values.
* Fixed: Default values only worked on leafs, not typedefs.
* Fixed: NACM datanode write rules now follow NACM rules in the running db (not in the db being verified).
* Fixed: NACM datanode write problem: read/write/exec default rules did not work.
* Fixed [Makefile syntax error *** mixed implicit and normal rules #104](https://github.com/clicon/clixon/issues/104). Make operator `|=` seems not to work on GNU make version < 4.
* Yang specs with recursive grouping/use statement is now fixed: instead of stack overflow, you get an error message and an exit
* Fixed: Some state data was sorted but should not have been.
  * Search function checked only own not for config false statement, should have checked all ancestors.
* Fixed: Some restconf errors were wrongly formatted such as: `{"ietf-restconf:errors":{"error":{"rpc-error":` . There should be no `"rpc-error"` level.
* Fixed: Enabling modstate (CLICON_XMLDB_MODSTATE), changing a revision on a yang, and restarting made the backend daemon exit at start (thanks Matt)
  * Also: ensure to load `ietf-yang-library.yang ` if CLICON_XMLDB_MODSTATE is set
* Fixed: Pretty-printed XML using prefixes not parsed correctly.
  * eg `<a:x>   <y/></a:x>` could lead to errors, wheras (`<x>   <y/></x>`) works fine.
* XML namespace merge bug fixed. Example: two xmlns attributes could both survive a merge whereas one should replace the other.
* Compile option `VALIDATE_STATE_XML` introduced in `include/custom.h` to control whether code for state data validation is compiled or not.
* Fixed: Validation of user state data led to wrong validation, if state relied on config data, eg leafref/must/when etc.
* Fixed: No revision in yang module led to errors in validation of state data
* Fixed: Leafref validation did not cover case of when the "path" statement is declared within a typedef, only if it was declared in the data part directly under leaf.
* Fixed: Yang `must` xpath statements containing prefixes stopped working due to namespace context updates


## 4.3.0
1 January 2020

There were several issues with multiple namespaces with augmented yangs in 4.2 that have been fixed in 4.3. Some other highlights include: several issues with XPaths including "canonical namespace context" support, a reorganization of the YANG files shipped with the release, and a wildchar in the CLICON_MODE variable.

### API changes on existing features (you may need to change your code)
* Yang files shipped with Clixon are reorganized into three classes: clixon, mandatory, optional, this is to enable users more flexibility in intergating with their own YANG files.
  * Previously there was only  "standard" and "clixon", "standard" is now split into mandatory and optional.
  * Clixon and mandatory yang spec are always installed
  * Optional yang files are loaded only if configured with `--enable-optyangs` (flipped logic and changed from `disable-stdyangs`). NOTE: you must do this to run examples and tests.
  * Optional yang files can be installed in a separate dir with `--with-opt-yang-installdir=DIR` (renamed from `with-std-yang-installdir`)
* C-API
  * Changed `clicon_rpc_generate_error(msg, xerr)` to `clicon_rpc_generate_error(xerr, msg, arg)`
    * If you pass NULL as arg it produces the same message as before.
  * Added namespace-context parameter `nsc` to `xpath_first` and `xpath_vec`, (`xpath_vec_nsc` and
xpath_first_nsc` are removed).
  * Added clicon_handle as parameter to all `clicon_connect_` functions to get better error message
  * Added nsc parameter to `xmldb_get()`
* The multi-namespace augment state may rearrange the XML namespace attributes.

### Minor changes
* Added experimental code for optimizing XPath search using binary search.
  * Enable with XPATH_LIST_OPTIMIZE in include/clixon_custom.h
  * Optimizes xpaths on the form: `a[b=c]` on sorted, yangified config lists.
* Added "canonical" global namespace context: `nsctx_global`
  * This is a normalized XML prefix:namespace pair vector computed from all loaded Yang modules. Useful when writing XML and XPATH expressions in callbacks.
  * Get it with `clicon_nsctx_global_get(h)`
* Added wildcard `*` as a mode to `CLICON_MODE` in clispec files
  * If you set "CLICON_MODE="*";" in a clispec file it means that syntax will appear in all CLI spec modes.
* State callbacks provided by user are validated. If they are invalid an internal error is returned, example, with error-tag: `operation-failed`and with error-message containing. `Internal error, state callback returned invalid XML`.
* C-code:
  * Added `xpath_first_localonly()` as an xpath function that skips prefix and namespace checks.
  * Removed most assert.h includes
  * Created two sub-files (clixon_validate.c and clixon_api_path.c) from large lib/src/clixon_xml_map.c source file.
* Fixed multi-namespace for augmented state which was not covered in 4.2.0.
* Main example yang changed to incorporate augmented state, new revision is 2019-11-15.

### Corrected Bugs
* XML parser failed on `]]]>` termination of CDATA.
* [filter in netconf - one specific entry #100](https://github.com/clicon/clixon/issues/100)
* [xpath_tree2cbuf() changes integers into floating point representations #99](https://github.com/clicon/clixon/issues/99)
* [xml_parse_string() is slow for a long XML string #96](https://github.com/clicon/clixon/issues/96)
* Mandatory variables can no longer be deleted.
* [Add missing includes](https://github.com/clicon/clixon/pulls)

## 4.3.1
2 February 2020

Patch release based on testing by Dave Cornejo, Netgate

### Corrected Bugs
* XML namespace merge bug fixed. Example: two xmlns attributes could both survive a merge whereas one should replace the other.
* Compile option `VALIDATE_STATE_XML` introduced in `include/custom.h` to control whether code for state data validation is compiled or not.
* Fixed: Validation of user state data led to wrong validation, if state relied on config data, eg leafref/must/when etc.
* Fixed: No revision in yang module led to errors in validation of state data
* Fixed: Leafref validation did not cover case of when the "path" statement is declared within a typedef, only if it was declared in the data part directly under leaf.
* Fixed: Yang `must` xpath statements containing prefixes stopped working due to namespace context updates

## 4.3.2
15 February 2020

### Major New features
* New "general-purpose" datastore upgrade callback added which i called once on startup, intended for low-level general upgrades and as a complement to module-specific upgrade.
  * Called on startup after initial XML parsing, but before module-specific upgrades
  * Enabled by definign the `.ca_datastore_upgrade`
  * [General-purpose upgrade documentation](https://clixon-docs.readthedocs.io/en/latest/backend.html#general-purpose)

### API changes on existing features (you may need to change your code)
* Session-id CLI functionality delayed: "lazy evaluation"
  * C-api: Changed `clicon_session_id_get(clicon_handle h, uint32_t *id)`
  * From a cli perspective this is a revert to 4.1 behaviour, where the cli does not immediately exit on start if the backend is not running, but with the new session-id function

### Known Issues
* If you retrieve state _and_ config data using RESTCONF or NETCONF `get`, a performance penalty occurs if you have large lists (eg ACLs). Workaround is: disable `VALIDATE_STATE_XML` in `include/clixon_custom.h` (disabled by default).

### Corrected Bugs
* Fixed: If you enabled modstate (CLICON_XMLDB_MODSTATE), changed a revision in a yang spec, and restarted the backend daemon, it exit at start (thanks Matt).
  * Also: ensure to load `ietf-yang-library.yang ` if CLICON_XMLDB_MODSTATE is set
* Fixed: Pretty-printed XML using prefixes not parsed correctly.
  * eg `<a:x>   <y/></a:x>` could lead to errors, wheras (`<x>   <y/></x>`) works fine.

## 4.3.3
20 February 2020

### Minor changes
* Due to increased memory usage in internal XML trees, the [use cbuf for xml value code](https://github.com/clicon/clixon/commit/9575d10887e35079c4a9b227dde6ab0f6f09fa03) is reversed.

## 4.2.0
27 October 2019

### Summary

The main improvement in this release concerns security in terms of privileges and credentials of accessing the clixon backend. There is also stricter multi-namespace checks which primarily effects where augmented models are used.

### Major New features
* The backend daemon can drop privileges after initialization to run as non-privileged user
  * You can start as root and drop privileges either permanently or temporary
    * use `-U <user>` clixon_backend command-line option to drop to `user`
  * Generic options are the following:
    * `CLICON_BACKEND_USER` drop of privileges to this user
    * `CLICON_BACKEND_PRIVILEGES` can have the following values:
      * `none` Make no drop/change in privileges. This is currently the default.
      * `drop_perm`  After initialization, drop privileges permanently
      * `drop_perm` After initialization, drop privileges temporarily (to a euid)
  * If dropped temporary, you can restore privileges with `restore_priv()`
* The backend socket has now support of credentials of peer clients
  * NACM users are cross-checked with client credentials (cli/netconf/restconf)
  * Only UNIX domain socket supports client credential checks (IP sockets do not).
  * Controlled by option CLICON_NACM_CREDENTIALS
    * `none` means credentials are not checked. Only option for IP sockets.
    * `exact` means credentials of client user must match NACM user exactly.
    * `except` means exact match is done except for root and www user.This is necessary for Restconf. This is default.
* Stricter handling of multi-namespace handling
  * This occurs in cases where there are more than one XML namespaces in a config tree, such as `augment`:ed trees.
  * Affects all parts of the system, including datastore, backend, restconf and cli.
  * Examples of a mandated stricter usage of a simple augment `b` of symbol `a`. Assume `a` is in module `mod1` with namespace `urn:example:a` and `b` is in module `mod2` with namespace `urn:example:b`:
    * RESTCONF: `GET http://localhost/restconf/data/mod1:a/mod2:b`
    * NETCONF: `<a xmlns="urn:example:a" xmlns:b="urn:example:b"><b:b>42</b:b></a>`
    * XPATH (in edit-config filter): `<filter type="xpath" select="a:a/b:b" xmlns:

### API changes on existing features (you may need to change your code)
* The stricter multi-namespace handling (see above) may affect the API, if you used the more relaxed usage.
* The credentials check (see above) may cause access denied if UNIX user does not match NACM user.
* Changed "Demon error" to "Daemon error" in logs and debug. Output only.
a="urn:example:a" xmlns:b="urn:example:b"/>`
* RESTCONF error reporting
  * Invalid api-path syntax (eg non-matching yang) error changed from 412 operation-failed to 400 Bad request invalid-value, or unknown-element.
  * Changed so that `400 Bad Request` are for invalid api-path or unknown yang elements, `404 Not Found` for valid xml when object not found.
* New clixon-config@2019-09-11.yang revision
  * Added: CLICON_BACKEND_USER: Drop of privileges to this user, owner of backend socket (default: `clicon`)
    * Therefore new installation should now add a UNIX `clicon` user
  * Added: CLICON_BACKEND_PRIVILEGES: If and how to drop privileges
  * Added: CLICON_NACM_CREDENTIALS: If and how to check backend socket privileges with NACM
  * Added: CLICON_NACM_RECOVERY_USER: Name of NACM recovery user.
* Restconf top-level operations GET root resource modified to comply with RFC 8040 Sec 3.1
  * non-pretty print remove all spaces, eg `{"operations":{"clixon-example:client-rpc":[null]`
  * Replaced JSON `null` with `[null]` as proper empty JSON leaf/leaf-list encoding.
* C-code change
  * Changed `clicon_rpc_get` and `clicon_rpc_get_config` as follows:
    * Added `username` as second parameter, default NULL
    * Changed `namespace` to namespace context, which needs to be created
    * Example new usage:
    ```
    cvec *nsc = xml_nsctx_init(NULL, "urn:example:clixon")
    if (clicon_rpc_get_config(h, NULL, "running", "/interfaces", nsc, &xret) < 0)
      err;
    ```
    See function reference how to make a call.
  * C-code: added `id` parameter to `clicon_msg_encode()` and `clicon_msg_decode()` due to internal backend socket message change

### Minor changes
* Changed session-id handing. Instead of using pid of peer process, a proper session id generated by the server is used, following RFC6241.
  * Clients query with a hello to the server at startup and expects a hello reply
  back containing the session-id. Which is then used in further communication.
  * Code in kill_session is removed where this fact was used to actually kill the client process. Now only the session endpoint is closed.
* XPATH canonical form implemented for NETCONF get and get-config. This means that all callbacks (including state callbacks) will have the prefixes that corresponds to module prefixes. If an xpath have other prefixes (or null as default), they will be translated to canonical form before any callbacks.
  * Example of a canonical form: `/a:x/a:y`, then symbols must belong to a yang module with prefix `a`.
* FreeBSD modifications: Configure, makefiles and test scripts modification for Freebsd

### Corrected Bugs
* Fixed CLI error messages on wrong cli_set/merge xml-key to eg:
  * `Config error: api-path syntax error \"/example:x/m1=%s\": rpc malformed-message List key m1 length mismatch : Invalid argument"`
* Hello netconf candidate capability misspelled, mentioned in [Can clixon_netconf receive netconf packets as a server? #93](https://github.com/clicon/clixon/issues/93)
* [Cannot write to config using restconf example #91](https://github.com/clicon/clixon/issues/91)
  * Updated restconf documentation (the example was wrong)
* [clixon-lib yang revision file name update #92](https://github.com/clicon/clixon/issues/92)
  * Clixon-lib yang file had conflicting filename and internal yang revision.
  * This was only detected in the use-case when a whole dir was loaded.
  * Inserted sanity check in all yang parse routines.
  * Committed updated clixon-lib yang file that triggered the error

## 4.1.0
18 August 2019

### Summary

4.1.0 is focussed on RFC 8040 RESTCONF features. Highlights include:
- RFC8040 plain PATCH,
- Query parameters: content, depth, insert, position
- Standard return codes

### Major New features
* Restconf RFC 8040 increased feature compliance
  * RESTCONF PATCH (plain patch) is implemented according to RFC 8040 Section 4.6.1
    * Note RESTCONF plain patch is different from RFC 8072 "YANG Patch Media Type" which is not implemented
  * RESTCONF "content" query parameter supported
    * Extended Netconf with content attribute for internal use
  * RESTCONF "depth" query parameter supported
    * Extended Netconf with depth attribute for internal use
  * RESTCONF "insert" and "point" query parameters supported
    * Applies to ordered-by-user leaf and leaf-lists
  * RESTCONF PUT/POST erroneously returned 200 OK. Instead restconf now returns:
    * `201 Created` for created resources
    * `204 No Content` for replaced resources.
    * identity/identityref mapped between XML and JSON
      * XML uses prefixes, JSON uses module-names (previously prefixes were used in both cases)
    * See [RESTCONF: HTTP return codes are not according to RFC 8040](https://github.com/clicon/clixon/issues/56)
    * Implementation detail: due to difference between RESTCONF and NETCONF semantics, a PUT first to make en internal netconf edit-config create operation; if that fails, a replace operation is tried.
  * HTTP `Location:` fields added in RESTCONF POST replies
  * HTTP `Cache-Control: no-cache` fields added in HTTP responses (RFC Section 5.5)
  * Restconf monitoring capabilities (RFC Section 9.1)
* Yang Netconf leaf/leaf-list insert support
  * For "ordered-by user" leafs and leaf-lists, the insert and value/key attributes are supported according to RFC7950 Sections 7.7.9 and 7.8.6
* Yang extensions support
  * New plugin callback: ca_extension
  * The main example explains how to implement a Yang extension in a backend plugin.

### API changes on existing features (you may need to change your code)
* C API changes:
  * Added `depth` parameter to function `clicon_xml2cbuf`, default is -1.
  * Added two parameters to function `clicon_rpc_get`
    * `content`: to select state or config. Allowed values: CONTENT_CONFIG,CONTENT_NOCONFIG, CONTENT_ALL (default)
    * `depth`: Get levels of XML in get function: -1 is unbounded, 0 is nothing, 1 is top-level node only.
* Netconf edit-config "operation" attribute namespace check is enforced
  * E.g.: `<a xmlns="uri:example" operation="merge">` --> `<a xmlns="uri:example" nc:operation="merge" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">`
* RESTCONF NACM access-denied error code changed from "401 Unauthorized" to "403 Forbidden"
  * See RFC 8040 (eg 4.4.1, 4.4.2, 4.5, 4.6, 4.7)
* RESTCONF PUT/POST erroneously returned 200 OK. Instead restconf now returns:
  * `201 Created` for created resources
  * `204 No Content` for replaced resources.
* RESTCONF PUT/POST `Content-Type` is enforced
  * Before accepted JSON as default, now Content-Type must be explicit, such as `Content-Type: application/yang-data+json`
  * If not, you will get 415 unsupported media type
* RESTCONF identities has changed to use module names instead of prefixes following RFC8040:
  * Eg, `curl -X POST -d '{"type":"ex:eth"}` --> `curl -X POST -d '{"type":"ietf-interfaces:eth"`}
* JSON changes
  * Non-pretty-print output removed all extra spaces.
    * Example: `{"nacm-example:x": 42}` --> `{"nacm-example:x":42}`
  * Empty JSON values changed from `null` to:
    * Empty yang container encoded as `{}`
    * Empty leaf/leaf-list of type empty encoded as `[null]`
    * Other empty values remain as `null`

### Minor changes
* New [clixon-doc sphinx/read-the-docs](https://clixon-docs.readthedocs.io) started
  * The goal is to move all clixon documentation there
* Added experimental binary search API function: `xml_binsearch` that can be used by plugin developers.
  * This provides binary search of list/leaf-lists as described here: <https://en.wikipedia.org/wiki/Binary_search_algorithm>
* Removed unnecessary configure dependencies
  * libnsl, libcrypt, if_vlan,...
* "pseudo-plugins" added, ie virtual plugins to enable callbacks also for main programs. Useful for extensions.
  * See `clixon_pseudo_plugin`

### Corrected Bugs
* If `ietf-netconf.yang` was imported from any yang module, client/backend communication stops working.
  * Fixed by adding supported netconf features before loading other yang modules
* RESTCONF JSON identity had wrong namespace in sub-objetcs
  * Showed if you GET an object with JSON encoding that have identities
* Fixed Segv in nacm write when MERGE and creating object
  * Should only be applicable on netconf MERGE and restconf PATCH
* Corrected problem with namespace context cache, was not always cleared when adding new subtrees.
* Corrected CLI bug with lists of multiple keys (netconf/restconf works).
  * Worked in 3.10, but broke in 4.0.0. Fixed in 4.0.1
  * Example: `yang list x { key "a b";...}`
    CLI error example:
    ```
      set x a 1 b 1; #OK
      set x a 1 b 2; #OK
      set x a 1 b <anything> # Error
    ```
* Fixed RESTCONF api-path leaf-list selection was not made properly
  * Requesting eg `mod:x/y=42` returned the whole list: `{"y":[41,42,43]}` whereas it should only return one element: `{"y":42}`
* Fixed [RESTCONF: HTTP return codes are not according to RFC 8040](https://github.com/clicon/clixon/issues/56)
  * See also API changes above
* Yang Unique statements with multiple schema identifiers did not work on some platforms due to memory error.

## 4.0.0
13 July 2019

### Summary

This release is a major uplift of Yang and XML features which
motivates a major version number increment.

In short, the Yang and XML support is now good enough for most
use-cases. There are still features not supported, but hopefully they
are relatively uncommon (see [README](https://github.com/clicon/clixon/#yang))

The next task for uplifting is RESTCONF where several use-cases are
not supported. There is also a need for NETCONF modernization and
added optional features.

Going forward it is planned to make more regular minor releases. With
the current Trevor CI in place, making releases should be easy, and it
is also safer to just pull a master commit. However, for synchronizing
and tracing an effort will be made to make monthly releases.

Thanks to Netgate for that enabled me to spend full time on Clixon!

Stockholm 13 July 2019
Olof Hagsand

### Major New features
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
* Improvements of yang pattern (regular expressions)
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
* Persistent CLI history supported
  * See [Preserve CLI command history across sessions. The up/down arrows](https://github.com/clicon/clixon/issues/79)
  * The design is similar to bash history:
      * The CLI loads/saves its complete history to a file on entry and exit, respectively
      * The size (number of lines) of the file is the same as the history in memory
      * Only the latest session dumping its history will survive (bash merges multiple session history).
      * Tilde-expansion is supported
      * Files not found or without appropriate access will not cause an exit but will be logged at debug level
  * New config options: CLICON_CLI_HIST_FILE with default value `~/.clixon_cli_history`
  * New config options: CLICON_CLI_HIST_SIZE with default value 300.
* New backend startup and upgrade support,
  * See (doc/startup.md) for details
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

### API changes on existing features (you may need to change your code)

* RESTCONF strict namespace validation of data in POST and PUT.
  * Accepted:
  ```
    curl -X PUT http://localhost/restconf/data/mod:a -d {"mod:a":"x"}
  ```
  * Not accepted (must prefix "a" with module):
  ```
    curl -X PUT http://localhost/restconf/data/mod:a -d {"a":"x"}
  ```
* XPATH API is extended with namespaces, in the following cases (see [README](README.md#xml-and-xpath)):
  * CLIspec functions have added optional namespace parameter:
    * `cli_show_config <db> <format> <xpath>` --> `cli_show_config <db> <format> <xpath> <namespace>`
    * `cli_copy_config <db> <xpath> ...` --> `cli_copy_config <db> <xpath> <namespace> ...`
  * Change the following XPATH API functions (xpath_first and xpath_vec remain as-is):
    * `xpath_vec_flag(x, format, flags, vec, veclen, ...)` --> `xpath_vec_flag(x, nsc, format, flags, vec, veclen, ...)`
    * `xpath_vec_bool(x, format, ...)` --> `xpath_vec_bool(x, nsc, format, ...)`
    * `xpath_vec_ctx(x, xpath, xp)` --> `xpath_vec_ctx(x, nsc, xpath, xp)`
  * New Xpath API functions with namespace contexts:
    * `xpath_first_nsc(x, nsc, format, ...)`
    * `xpath_vec_nsc(x, nsc, format, vec, veclen, ...)`
  * Change xmldb_get0 with added `nsc` parameter:
    * `xmldb_get0(h, db, xpath, copy, xret, msd)` --> `xmldb_get0(h, db, nsc, xpath, copy, xret, msd)`
  * The plugin statedata callback (ca_statedata) has been extended with an nsc parameter:
    * `int example_statedata(clicon_handle h, cvec *nsc, char *xpath, cxobj *xstate);`
  * rpc get and get-config api function has an added namespace argument:
    * `clicon_rpc_get_config(clicon_handle h, char *db, char *xpath, char *namespace, cxobj **xt);`
    * `int clicon_rpc_get(clicon_handle h, char *xpath, char *namespace, cxobj **xt);`
* Error messages for invalid number ranges and string lengths have been uniformed and changed.
  * Error messages for invalid ranges are now on the form:
  ```
    Number 23 out of range: 1 - 10
    String length 23 out of range: 1 - 10
  ```
* On validation callbacks, XML_FLAG_ADD is added to all nodes at startup validation, not just the top-level. This is the same behaviour as for steady-state validation.
* All hash_ functions have been prefixed with `clicon_` to avoid name collision with other packages (frr)
  * All calls to the following functions must be changed: `hash_init`, `hash_free`, `hash_lookup`, `hash_value`, `hash_add`, `hash_del`, `hash_dump`, and `hash_keys`.
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
* Many validation functions have changed error parameter from cbuf to xml tree.
  * XML trees are more flexible for utility tools
  * If you use these(mostly internal), you need to change the error function: `generic_validate, from_validate_common, xml_yang_validate_all_top, xml_yang_validate_all, xml_yang_validate_add, xml_yang_validate_pprpc, xml_yang_validate_list_key_only`
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

* Documented bug [Yang identityref XML encoding is not general #90](https://github.com/clicon/clixon/issues/90)
* Added new API function `xpath_parse()` to split parsing and xml evaluation.
* Rewrote `api_path2xpath` to handle namespaces.
* `api_path2xml_vec` strict mode check added if list key length mismatch
* `startup_extraxml` triggers unnecessary validation
  * Renamed startup_db_reset -> xmldb_db_reset (its a general function)
  * In startup_extraxml(), check if reset callbacks or extraxml file actually makes and changes to the tmp db.
* Print CLICON_YANG_DIR and CLICON_FEATURE lists on startup with debug flag
* Extended `util/clixon_util_xml` with yang and validate functionality so it can be used as a stand-alone utility for validating XML/JSON files
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

* Fixed: Return 404 Not found error if restconf GET does not return requested instance
* Fixed [Wrong yang-generated cli code for typeref identityref combination #88](https://github.com/clicon/clixon/issues/88)
* Fixed [identityref validation fails when using typedef #87](https://github.com/clicon/clixon/issues/87)
* Fixed a problem with some netconf error messages caused restconf daemon to exit due to no XML encoding
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
  * See in 3.9.0 minor changes: Replaced all calls to (obsolete) `cli_output` with `fprintf`
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

## 4.0.1
5 Aug 2019

This is a hotfix for a multi-key CLI bug that appeared in 4.0.0
(worked in 3.10).

### Corrected Bugs
* Corrected CLI bug with lists of multiple keys (netconf/restconf works).
  * Example: `yang list x { key "a b";...}`
    CLI error example:
    ```
      set x a 1 b 1; #OK
      set x a 1 b 2; #OK
      set x a 1 b <anything> # Error
    ```

## 3.9.0
21 Feb 2019

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

## 3.8.0
6 Nov 2018

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

## 3.7.0
22 July 2018

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


## 3.6.0
30 April 2018

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

## 3.6.1
29 May 2018

### Corrected Bugs
* https://github.com/clicon/clixon/issues/23 clixon_cli failing with error
  * The example included a reference to nacm yang file which did not exist and was not used
* Added clixon-config@2018-04-30.yang

## 3.5.0
12 February 2018

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

## 3.4.0
1 January 2018

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

## 3.3.3
25 November 2017

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

## 3.3.2
Aug 27 2017

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

## 3.3.1
June 7 2017

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

