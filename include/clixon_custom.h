/*
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

/*! Treat <config> and <data> specially in a xmldb datastore.
 * config/data is treated as a "neutral" tag that does not have a yang spec.
 * In particular when binding xml to yang, if <config> is encountered as top-of-tree, do not
 * try to bind a yang-spec to this symbol.
 * The root of this is GET and PUT commands where the <config> and <data> tag belongs to the
 * RPC rather than the data.
 * This is a hack, there must be a way to make this more generic
 */
#define XMLDB_CONFIG_HACK

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
