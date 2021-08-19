/*
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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
  These are compile-time options. RUntime options are in clixon-config.yang.
  In general they are kludges and "should be removed" when cod eis improved
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
 * See https://github.com/clicon/clixon/issues/90
 * Instead of using generic xmlns prefix bindings, the module's own prefix
 * is used.
 * In the CLI generation case, this is actually quite complicated: the cli 
 * needs to generate a netconf statement with correct xmlns binding.
 * The easy way to do this is to always generate all prefix/namespace bindings 
 * on the top-level for the modules involved in the netconf operation.
 */
#define IDENTITYREF_KLUDGE

/*! Optimize special list key searches in XPATH finds
 * Identify xpaths that search for exactly a list key, eg: "y[k=3]" and then call
 * binary search. This only works if "y" has proper yang binding and is sorted by system
 */
#define XPATH_LIST_OPTIMIZE

/*! Add explicit search indexes, so that binary search can be made for non-key list indexes
 * This also applies if there are multiple keys and you want to search on only the second for 
 * example.
 * There may be some cases where the index vector is not updated, need to verify before 
 * enabling this completely.
 */
#define XML_EXPLICIT_INDEX

/*! Let state data be ordered-by system
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
 * This is traditionally same as NETCONF_INPUT_CONFIG ("config") but can be different
 * If you change this, you need to change test shell variable in lib.sh: DATASTORE_TOP
 * Consider making this an option (but this has bootstrap problems) or configure option 
 */
#define DATASTORE_TOP_SYMBOL "config"

/*! Name of default netns for clixon-restconf.yang socket/namespace field
 * Restconf allows opening sockets in different network namespaces. This is teh name of 
 * "host"/"default" namespace. Unsure what to really label this but seems like there is differing
 * consensus on how to label it.
 * Either find that proper label, or move it to a option
 */
#define RESTCONF_NETNS_DEFAULT "default"

/*! Set a temporary parent for use in special case "when" xpath calls
 * Problem is when changing an existing (candidate) in-memory datastore that yang "when" conditionals
 * should be changed in clixon_datastore_write.c:text_modify().
 * Problem is that the tree is in an intermediate state so that a when condition may not see the
 * full context.
 * More specifically, new nodes (x0) are created without hooking them into the existing parent (x0p)
 * and thus an xpath on the form ".."/PARENT may not be evaluated as they should. x0 is eventually 
 * added to its parent but then it is more difficult to check trhe when condition.
 * This fix add the parent x0p as a "candidate" so that the xpath-eval function can use it as
 * an alernative if it exists.
 * Note although this solves many usecases involving parents and absolute paths, it still does not
 * solve all usecases, such as absolute usecases where the added node is looked for
 */
#define XML_PARENT_CANDIDATE

/*! Enable yang patch RFC 8072 
 * Remove this when regression test
 */
#undef YANG_PATCH

/*! Enable list pagination drafts
 * draft-wwlh-netconf-list-pagination-00, 
 * draft-wwlh-netconf-list-pagination-nc-01
 * draft-wwlh-netconf-list-pagination-rc-01
 */
#define LIST_PAGINATION

/*! Clixon netconf pagination
 */
#define CLIXON_PAGINATION
