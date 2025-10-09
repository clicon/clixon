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

/*
 * we start with a series of dispatcher_definitions, which are a
 * path and handler.
 *
 * we break the path up into elements and build a tree out of them
 * example:
 *
 * we start with two paths /a/b/c and /a/d with handler_c() and
 * handler_d() as their handlers respectively.
 *
 * this produces a tree like this:
 *
 * [/] root_handler()
 *     [a] NULL
 *         [b] NULL
 *             [c] handler_c()
 *         [d] handler_d()
 *
 * NULL means that there is no handler defined - if the terminal
 * element of the path has a NULL handler then you look for the
 * closest ancestor that does.
 *
 * for example, if I lookup /a/b I get back a pointer to root_handler()
 * if i lookup /a/d, I get handler_d().
 *
 * if a element has a key (/a/b=c) then the list element is
 * marked with an = sign and without the key
 * so /a/b=c creates multiple entries:
 *
 *  [/]
 *      [a]
 *          [b=]
 *          [b]
 *
 * NOTE 2: there is no attempt to optimize list searching here, sorry. I
 * do not think that the known use cases will get big enough to make the
 * tree get too large. I do not recommend that you encode every possible
 * path, just top level key handlers.
 *
 * there are 2 functions to the API:
 * clixon_register_handler(): build the dispatcher table
 * clixon_call_handlers(): query the dispatcher table
 */

/*
 * Important for writing handlers: a handler must return a complete
 * valid response. It must operate in isolation, it must not expect
 * any ordering in the calls and [under review] it should not call
 * another handler directly or indirectly. Responses must me bound
 * to a yang model and properly sorted and indexed.
 */

#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <stdlib.h>
#include <errno.h>

#include "clixon_dispatcher.h"

/* ===== utility routines ==== */

#define PATH_CHUNKS 32

/*! Spilt a path into elements
 *
 * given an api-path, break it up into chunks separated by '/'
 * characters. it is expected that api-paths are URI encoded, so no need
 * to deal with unescaped special characters like ', ", and /
 *
 * @param[in]  path      Path string
 * @param[in]  plist     Pointer to split path array
 * @param[out] plist_len Pointer to storage space for path array length
 * @retval     0         OK
 * @retval    -1         Error
 * XXX consider using clixon_strsep1
 */
static int
split_path(char   *path,
           char ***plist,
           size_t *plist_len)
{
    int    retval = -1;
    size_t allocated = PATH_CHUNKS;
    char  *work = NULL;     /* don't modify the original copy */
    char **list = NULL;
    size_t len = 0;
    char  *ptr;
    char  *new_element;

    if ((work = strdup(path)) == NULL)
        goto done;
    if ((list = malloc(allocated * sizeof(char *))) == NULL)
        goto done;
    memset(list, 0, allocated * sizeof(char *));
    ptr = work;
    if (*ptr == '/') {
        if ((new_element = strdup("/")) == NULL)
            goto done;
        list[len++] = new_element;
        ptr++;
    }
    ptr = strtok(ptr, "/");
    while (ptr != NULL) {
        if (len > allocated) {
            /* we've run out of space, allocate a bigger list */
            allocated += PATH_CHUNKS;
            if ((list = realloc(list, allocated * sizeof(char *))) == NULL)
                goto done;
        }
        if ((new_element = strdup(ptr)) == NULL)
            goto done;
        list[len++] = new_element;
        ptr = strtok(NULL, "/");
    }
    *plist = list;
    list = NULL;
    *plist_len = len;
    retval = 0;
 done:
    if (list)
        free(list);
    if (work)
        free(work);
    return retval;
}

/*! Free a split path structure
 *
 * @param[in] list pointer to split path array
 * @param[in] len length of split path array
 */
static void
split_path_free(char **list,
                size_t len)
{
    size_t i;

    for (i = 0; i < len; i++) {
        free(list[i]);
    }
    free(list);
}

/*! Find a peer of this node by name
 *
 * search through the list pointed at by peer
 * @param[in] node       Pointer to a node in the peer list
 * @param[in] node_name  Name of node we're looking for
 * @retval    pointer    Pointer to found node or NULL
 * @retval    NULL
 */
static dispatcher_entry_t *
find_peer(dispatcher_entry_t *node, char *node_name)
{
    dispatcher_entry_t *i;

    if ((node == NULL) || (node_name == NULL)) {
        /*  protect against idiot users */
        return NULL;
    }

    i = node->de_peer_head;

    while (i != NULL) {
        if (strcmp(node_name, i->de_node_name) == 0) {
            break;
        }
        i = i->de_peer;
    }

    return i;
}

/*! Add a node as the last node in peer list
 *
 * @param[in]  node    Pointer to an element of the peer list
 * @param[in]  name    Name of new node
 * @retval     pointer Pointer to added/existing node
 * @retval     NULL    Error
 */
static dispatcher_entry_t *
add_peer_node(dispatcher_entry_t *node,
              char               *name)
{
    dispatcher_entry_t *new_node = NULL;
    dispatcher_entry_t *eptr;

    if ((new_node = malloc(sizeof(dispatcher_entry_t))) == NULL)
        return NULL;
    memset(new_node, 0, sizeof(dispatcher_entry_t));
    if (node == NULL) {
        /* this is a new node */

        new_node->de_node_name = strdup(name);
        new_node->de_peer = NULL;
        new_node->de_children = NULL;
        new_node->de_peer_head = new_node;

        return new_node;
    }
    else {
        /* possibly adding to the list */

        /* search for existing, or get tail end of list */
        eptr = node->de_peer_head;
        while (eptr->de_peer != NULL) {
            if (strcmp(eptr->de_node_name, name) == 0) {
                free(new_node);
                return eptr;
            }
            eptr = eptr->de_peer;
        }

        // if eptr->de_node_name == name, we done
        if (strcmp(eptr->de_node_name, name) == 0) {
            free(new_node);
            return eptr;
        }

        new_node->de_node_name = strdup(name);
        new_node->de_peer = NULL;
        new_node->de_children = NULL;
        new_node->de_peer_head = node->de_peer_head;

        eptr->de_peer = new_node;

        return new_node;
    }
}

/*! Add a node as a child of this node
 *
 * this is different from add_peer_node() in that it returns a
 * pointer to the head_peer of the children list where the node was
 * added.
 *
 * @param[in] node    Pointer to parent node of children list
 * @param[in] name    Name of child node
 * @retval    pointer Pointer to head of children list
 * @retval    NULL    Error
 */
static dispatcher_entry_t *
add_child_node(dispatcher_entry_t *node,
               char               *name)
{
    dispatcher_entry_t *child_ptr;

    if ((child_ptr = add_peer_node(node->de_children, name)) == NULL)
        return NULL;
    node->de_children = child_ptr->de_peer_head;

    return child_ptr;
}

/*!
 *
 * @param[in] root
 * @param[in] path
 * @retval    entry
 * @retval    NULL  Error
 */
static dispatcher_entry_t *
get_entry(dispatcher_entry_t *root,
          char               *path)
{
    char              **split_path_list = NULL;
    size_t              split_path_len = 0;
    dispatcher_entry_t *ptr = root;
    dispatcher_entry_t *best = root;

    /* cut the path up into individual elements */
    if (split_path(path, &split_path_list, &split_path_len) < 0)
        return NULL;

    /* some elements may have keys defined, strip them off */
    for (int i = 0; i < split_path_len; i++) {
        char *kptr = split_path_list[i];
        strsep(&kptr, "=[]");
    }

    /* search down the tree */
    for (int i = 0; i < split_path_len; i++) {
        char *query = split_path_list[i];
        if ((ptr = find_peer(ptr, query)) == NULL) {
            split_path_free(split_path_list, split_path_len);
            /* we ran out of matches, use last found handler */
            return best;
        }
        if (ptr->de_handler != NULL) {
            /* if handler is defined, save it */
            best = ptr;
        }

        /* skip to next element */
        ptr = ptr->de_children;
    }

    /* clean up */
    split_path_free(split_path_list, split_path_len);
    return best;
}

/*! Given a pointer to an entry, call the handler and all descendant and peer handlers.
 *
 * @param[in] entry
 * @param[in] handle
 * @param[in] path
 * @param[in] user_args
 * @retval    0         OK
 * @retval   -1         Error
 */
static int
call_handler_helper(dispatcher_entry_t *entry,
                    void               *handle,
                    char               *path,
                    void               *user_args)
{
    int retval = -1;

    if (entry->de_children != NULL) {
        if (call_handler_helper(entry->de_children, handle, path, user_args) < 0)
            goto done;
    }
    if (entry->de_peer != NULL) {
        if (call_handler_helper(entry->de_peer, handle, path, user_args) < 0)
            goto done;
    }
    if (entry->de_handler != NULL) {
        if ((entry->de_handler)(handle, path, user_args, entry->de_arg) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*
 * ===== PUBLIC API FUNCTIONS =====
 */

/*! Register a dispatcher handler
 *
 * called from initialization code to build a dispatcher tree
 *
 * @param[in]  root Pointer to pointer to dispatch tree
 * @param[in]  x    Handler to registration data
 * @retval     0    OK
 * @retval    -1    Error
 */
int
dispatcher_register_handler(dispatcher_entry_t   **root,
                            dispatcher_definition *x)
{
    int                 retval = -1;
    char              **split_path_list = NULL;
    size_t              split_path_len = 0;
    dispatcher_entry_t *ptr;

    if (*x->dd_path != '/') {
        errno = EINVAL;
        goto done;
    }

    /*
     * get the path from the dispatcher_definition, break it
     * up to create the elements of the dispatcher table
     */
    if (split_path(x->dd_path, &split_path_list, &split_path_len) < 0)
        goto done;

    /*
     * the first element is always a peer to the top level
     */
    ptr = *root;

    if ((ptr = add_peer_node(ptr, split_path_list[0])) == NULL)
        return -1;
    if (*root == NULL) {
        *root = ptr;
    }

    for (size_t i = 1; i < split_path_len; i++) {
        if ((ptr = add_child_node(ptr, split_path_list[i])) == NULL)
            goto done;
    }

    /* when we get here, ptr points at last entry added */
    ptr->de_handler = x->dd_handler;
    ptr->de_arg = x->dd_arg;

    /* clean up */
    split_path_free(split_path_list, split_path_len);
    retval = 0;
 done:
    return retval;
}

/*! Call the handler and all its descendant handlers
 *
 * NOTE: There is no guarantee of the order in which handlers
 * are called! Any handler must assume that it is called in
 * isolation, even if this duplicates work. The right to
 * reorder calls by this code is reserved.
 *
 * @param[in]  handle
 * @param[in]  root
 * @param[in]  path   Note must be on the form: /a/b (no keys)
 * @retval     0      OK
 * @retval    -1      Error
 */
int
dispatcher_call_handlers(dispatcher_entry_t *root,
                         void               *handle,
                         char               *path,
                         void               *user_args)
{
    int                 retval = -1;
    dispatcher_entry_t *best;

    if ((best = get_entry(root, path)) == NULL){
        errno = ENOENT;
        goto done;
    }
    if (best->de_children != NULL) {
        if (call_handler_helper(best->de_children, handle, path, user_args) < 0)
            goto done;
    }
    if (best->de_handler != NULL) {
        if ((*best->de_handler)(handle, path, user_args, best->de_arg) < 0)
            goto done;
    }
    retval = 0;
 done:
    return retval;
}

/*! Check if any handler is registered for the path
 * @param[in]  root
 * @param[in]  path   Note must be on the form: /a/b (no keys)
 * @retval     1      Yes, at least one handler
 * @retval     0      No handler
 * @retval    -1      Error
 */
int
dispatcher_match_exact(dispatcher_entry_t *root,
                       char               *path)
{
    int                 retval = -1;
    dispatcher_entry_t *ptr;
    dispatcher_entry_t *ptr1 = NULL;
    char              **split_path_list = NULL;
    size_t              split_path_len = 0;
    char               *str;
    int                 i;

    /* cut the path up into individual elements */
    if (split_path(path, &split_path_list, &split_path_len) < 0)
        goto done;
    ptr = root;
    /* search down the tree */
    for (i = 0; i < split_path_len; i++) {
        str = split_path_list[i];
        strsep(&str, "=[]");
        str = split_path_list[i];
        if ((ptr1 = find_peer(ptr, str)) == NULL)
            break;
        ptr = ptr1->de_children;
    }
    if (i == split_path_len && ptr1 && ptr1->de_handler)
        retval = 1;
    else
        retval = 0;
 done:
    /* clean up */
    if (split_path_list)
        split_path_free(split_path_list, split_path_len);
    return retval;
}

/*! Free a dispatcher tree
 */
int
dispatcher_free(dispatcher_entry_t *root)
{
    if (root == NULL)
        return 0;
    if (root->de_children)
        dispatcher_free(root->de_children);
    if (root->de_peer)
        dispatcher_free(root->de_peer);
    if (root->de_node_name)
        free(root->de_node_name);
    free(root);
    return 0;
}

/*! Pretty-print dispatcher tree
 */
#define INDENT 3
int
dispatcher_print(FILE               *f,
                 int                 level,
                 dispatcher_entry_t *de)
{
    fprintf(f, "%*s%s", level*INDENT, "", de->de_node_name);
    if (de->de_handler)
        fprintf(f, " %p", de->de_handler);
    if (de->de_arg)
        fprintf(f, " (%p)", de->de_arg);
    fprintf(f, "\n");
    if (de->de_children)
        dispatcher_print(f, level+1, de->de_children);
    if (de->de_peer)
        dispatcher_print(f, level, de->de_peer);
    return 0;
}
