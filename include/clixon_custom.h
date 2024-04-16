/*
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)

  This file is part of CLIXON.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Alternatively, the contents of this file may be used under the terms of
  the GNU General Public License Version 3 or later (the "GPL"),
  in which case the provisions of the GPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of the GPL, and not to allow others to
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

  Custom file as boilerplate appended by clixon_config.h 
  These are compile-time options. Runtime options are in clixon-config.yang.
  In general they are kludges and "should be removed" when code is improved
  and not proper system config options.
  Note that clixon_config.h is only included by clixon system files, not automatically by examples
  or apps
  */

#ifndef HAVE_STRNDUP
#define strndup(s, n) clicon_strndup(s, n)
#endif

/* Set if you want to assert that all rpc messages have set username
 */
#undef RPC_USERNAME_ASSERT

/*! Tag for wrong handling of identityref prefixes (XML encoding)
 *
 * See https://github.com/clicon/clixon/issues/90
 * Instead of using generic xmlns prefix bindings, the module's own prefix
 * is used.
 * In the CLI generation case, this is actually quite complicated: the cli 
 * needs to generate a netconf statement with correct xmlns binding.
 * The easy way to do this is to always generate all prefix/namespace bindings 
 * on the top-level for the modules involved in the netconf operation.
 * Update 2022-11: seems most cornercases are covered and this is now disabled.
 * I am sure there are remaining cases but undef this for now and close #90
 */
#undef IDENTITYREF_KLUDGE

/*! Optimize special list key searches in XPath finds
 *
 * Identify xpaths that search for exactly a list key, eg: "y[k='3']" and then call
 * binary search. This only works if "y" has proper yang binding and is sorted by system
 * Dont optimize on "hierarchical" lists such as: a/y[k='3'], where a is another list.
 */
#define XPATH_LIST_OPTIMIZE

/*! Add explicit search indexes, so that binary search can be made for non-key list indexes
 *
 * This also applies if there are multiple keys and you want to search on only the second for 
 * example.
 * There may be some cases where the index vector is not updated, need to verify before 
 * enabling this completely.
 */
#define XML_EXPLICIT_INDEX

/*! Let state data be ordered-by system
 *
 * RFC 7950 is cryptic about this
 * It says in 7.7.7:
 *    This statement (red:The "ordered-by" Statement) is ignored if the list represents
 *    state data,...
 * but it is not clear it is ignored because it should always be ordered-by system?
 * Cant measure any diff on performance with this on using large state lists (500K)
 * clixon-4.4
 */
#define STATE_ORDERED_BY_SYSTEM

/*! Top-symbol in clixon datastores
 *
 * This is traditionally same as NETCONF_INPUT_CONFIG ("config") but can be different
 * If you change this, you need to change test shell variable in lib.sh: DATASTORE_TOP
 * Consider making this an option (but this has bootstrap problems) or configure option 
 */
#define DATASTORE_TOP_SYMBOL "config"

/*! If set make an internal redirect if URI path indetifies a directory
 *
 * For example, path is /local, and redirect is 'index.html, the request 
 * will be redirected to /local/index.html
 */
#define HTTP_DATA_INTERNAL_REDIRECT "index.html"

/*! Set a temporary parent for use in special case "when" xpath calls
 *
 * Problem is when changing an existing (candidate) in-memory datastore that yang "when" conditionals
 * should be changed in clixon_datastore_write.c:text_modify().
 * Problem is that the tree is in an intermediate state so that a when condition may not see the
 * full context.
 * More specifically, new nodes (x0) are created without hooking them into the existing parent (x0p)
 * and thus an xpath on the form "../PARENT" may not be evaluated as they should. x0 is eventually 
 * added to its parent but then it is more difficult to check the when condition.
 * This fix add the parent x0p as a "candidate" so that the xpath-eval function can use it as
 * an alernative if it exists.
 * Note although this solves many usecases involving parents and absolute paths, it still does not
 * solve all usecases, such as absolute usecases where the added node is looked for
 */
#define XML_PARENT_CANDIDATE

/*! Enable "remaining" attribute (sub-feature of list pagination)
 *
 * As defined in draft-wwlh-netconf-list-pagination-00 using Yang metadata value [RFC7952] 
 */
#undef LIST_PAGINATION_REMAINING

/*! If backend is restarted, cli and netconf client will retry (once) and reconnect
 *
 * Note, if client has locked or had edits in progress, these will be lost
 * A warning will be printed
 * If not set, client will exit
 */
#define PROTO_RESTART_RECONNECT

/*! Disable top-level prefix for text syntax printing and parsing introduced in 5.8
 *
 * Note this is for showing/saving/printing, it is NOT for parsing/loading.
 * This means that text output can not be parsed and loaded.
 */
#undef TEXT_SYNTAX_NOPREFIX

/*! Reply with HTTP error when HTTP request on HTTPS socket
 *
 * If not set, just close socket and return with TCP reset.
 * If set: Incoming request on an SSL socket is known to be non-TLS.
 * Problematic part is it is not known it is proper non-TLS HTTP, for that it
 * needs parsing/ALPN etc.
 * This is the approx algorithm:
 * s = accept();
 * ssl = SSL_new()
 * if (SSL_accept(ssl) < 0){
 *  if (SSL_get_error(ssl, ) == SSL_ERROR_SSL){
 *    SSL_free(ssl);
 *     // Here "s" is still open and you can reply on the non-ssl underlying socket
 */
#define HTTP_ON_HTTPS_REPLY

/*! Indentation number of spaces for XML, JSON and TEXT pretty-printed output.
 *
 * Consider moving to configure.ac(compile-time) or to clixon-config.yang(run-time)
 */
#define PRETTYPRINT_INDENT 3

/*! Autocli uses/grouping references for top-level
 *
 * Exception of expand-grouping=true in clixon-autocli.yang
 * If enabled do not expand-grouping if a yang uses is directly under module or submodule
 * Disabled does not work today and is temporary and for documentation
 */
#define AUTOCLI_GROUPING_TOPLEVEL_SKIP

/*! Skip uses/grouping references for augment
 *
 * Consider YANG constructs such as:
 *   augment x{
 *     uses y;
 *     <nodes>
 * }
 * If enabled, do not include "uses y" in the augmentation at "x" AND mark all nodes with 
 * YANG_FLAG_GROUPING
 * If disabled, include "uses y" in the augmentation AND do NOT mark expaneded nodes with 
 * YANG_FLAG_GROUPING.
 * This affects the AUTOCLI expand-grouping=true behavior.
 * Disabled does not work
 */
#define YANG_GROUPING_AUGMENT_SKIP

/*! Start of restconf from backend (when CLICON_BACKEND_RESTCONF_PROCESS=true) using -R <inline>
 *
 * If set, send initial restconf config via -R <config> parameter at fork/exec.
 * Seems to be only an optimization since the config is queried from the backend anyway
 * The reason this probably should be undef:ed is that the restconf config appears in ps and other in 
 * cleartext
 * Plan is to remove this (undef:d) in next release
 */
#undef RESTCONF_INLINE

/*! Backward compatible with 6.5 for Error, Log and Debug APIs
 *
 * Note: many(most) not covered by this constant need to GREP
 * This includes lots of clicon->clixon namechanges, see CHANGELOG for whole list
 * This constant will be removed after the 7.0 release
 */
#define COMPAT_6_5

/*! Use SHA256 (32 bytes) instead of SHA1 (20 bytes)
 *
 * Digest use is not cryptographic use, so SHA1 is enough for now
 */
#undef USE_SHA256
