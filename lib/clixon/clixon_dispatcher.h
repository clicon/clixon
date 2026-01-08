/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2021 Rubicon Communications, LLC(Netgate)

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
  use your version of this file under the terms of Apache License version 2,
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 * @see https://github.com/dcornejo/dispatcher
 */

#ifndef _CLIXON_DISPATCH_DISPATCHER_H
#define _CLIXON_DISPATCH_DISPATCHER_H

/*! Prototype for a function to handle a path
 *
 * minimally needs the path it's working on, but probably
 * we want to hand down cached data somehow
 * @param[in]  h        Generic handler
 * @param[in]  xpath    Registered XPath using canonical prefixes
 * @param[in]  userargs Per-call user arguments
 * @param[in]  arg      Per-path user argument
 * @retval     0        OK
 * @retval    -1        Error
 */
// Backward-compatible 7.6
#define CLIXON_DISPATCHER_HANDLER_CONST
typedef int (*handler_function)(void *handle, const char *path, void *userargs, void *arg);

/*
 * this structure is used to map a handler to a path
 */
typedef struct {
    char            *dd_path;
    handler_function dd_handler;
    void            *dd_arg;
} dispatcher_definition;

/*
 * the dispatcher_entry_t is the structure created from
 * the registered dispatcher_definitions
 */
struct _dispatcher_entry;
typedef struct _dispatcher_entry dispatcher_entry_t;

struct _dispatcher_entry {
    /*
     * the name of this node, NOT the complete path
     */
    char              *de_node_name;

    /*
     * peer points at peer to the right of this one
     * if NULL then this is the rightmost and last on list
     */
    dispatcher_entry_t *de_peer;

    /*
     * peer_head points at leftmost peer at this level
     * if NULL, then this is the leftmost and first on the list
     * XXX: it seems it points to itself if it is first on the list?
     */
    dispatcher_entry_t *de_peer_head;

    /*
     * points at peer_head of children list
     * if NULL, then no children
     */
    dispatcher_entry_t *de_children;

    /*
     * pointer to handler function for this node
     */
    handler_function    de_handler;

    /*
     * End-user argument
     */
    void               *de_arg;
};

/*
 * Prototypes
 */
int dispatcher_register_handler(dispatcher_entry_t **root, dispatcher_definition *x);
int dispatcher_call_handlers(dispatcher_entry_t *root, void *handle, const char *path, void *user_args);
int dispatcher_match_exact(dispatcher_entry_t *root, const char *path);
int dispatcher_free(dispatcher_entry_t *root);
int dispatcher_print(FILE *f, int level, dispatcher_entry_t *root);

#endif /* _CLIXON_DISPATCH_DISPATCHER_H */
