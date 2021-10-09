/*
 * Copyright 2021 Rubicon Communications LLC (Netgate)
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
 * NOTE 1: there is not a mechanism to free the created structures since
 * it is intended that this tree is created only at startup. if use case
 * changes, this function is trivial.
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
 * XXX consider using clixon_strsep
 */
static int
split_path(char   *path,
	   char ***plist,
	   size_t *plist_len)
{
    int    retval = -1;
    size_t allocated = PATH_CHUNKS;
    char  *work;     /* don't modify the original copy */
    char **list;
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
    *plist_len = len;

    free(work);
    retval = 0;
 done:
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
 * search through the list pointed at by peer
 *
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

    i = node->peer_head;

    while (i != NULL) {
        if (strcmp(node_name, i->node_name) == 0) {
            break;
        }
        i = i->peer;
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

        new_node->node_name = strdup(name);
        new_node->peer = NULL;
        new_node->children = NULL;
        new_node->peer_head = new_node;

        return new_node;
    } else {
        /* possibly adding to the list */

        /* search for existing, or get tail end of list */
        eptr = node->peer_head;
        while (eptr->peer != NULL) {
            if (strcmp(eptr->node_name, name) == 0) {
                return eptr;
            }
            eptr = eptr->peer;
        }

        // if eptr->node_name == name, we done
        if (strcmp(eptr->node_name, name) == 0) {
            return eptr;
        }

        new_node->node_name = strdup(name);
        new_node->peer = NULL;
        new_node->children = NULL;
        new_node->peer_head = node->peer_head;

        eptr->peer = new_node;

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

    if ((child_ptr = add_peer_node(node->children, name)) == NULL)
	return NULL;
    node->children = child_ptr->peer_head;

    return child_ptr;
}

/**
 *
 * @param root
 * @param path
 * @retval
 * @retval NULL Error
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
        char *kptr = strchr(split_path_list[i], '=');

        if ((kptr != NULL) && (*kptr == '=')) {
            *(kptr + 1) = 0;
        }
    }

    /* search down the tree */
    for (int i = 0; i < split_path_len; i++) {

        char *query = split_path_list[i];
        if ((ptr = find_peer(ptr, query)) == NULL) {
	    split_path_free(split_path_list, split_path_len);
            /* we ran out of matches, use last found handler */
            return best;
        }
        if (ptr->handler != NULL) {
            /* if handler is defined, save it */
            best = ptr;
        }

        /* skip to next element */
        ptr = ptr->children;
    }

    /* clean up */
    split_path_free(split_path_list, split_path_len);
    
    return best;
}

/**
 * given a pointer to an entry, call the handler and all
 * descendant and peer handlers.
 *
 * @param entry
 * @param path
 * @retval
 */
static int
call_handler_helper(dispatcher_entry_t *entry,
		    void               *handle,
		    char               *path,
		    void               *user_args)
{
    if (entry->children != NULL) {
        call_handler_helper(entry->children, handle, path, user_args);
    }
    if (entry->peer != NULL) {
        call_handler_helper(entry->peer, handle, path, user_args);
    }
    if (entry->handler != NULL) {
        (entry->handler)(handle, path, user_args, entry->arg);
    }

    return 1;
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
    char              **split_path_list = NULL;
    size_t              split_path_len = 0;
    dispatcher_entry_t *ptr;

    if (*x->dd_path != '/') {
	errno = EINVAL;
	//        fprintf(stderr, "%s: part '%s' must start at root\n", __func__, x->dd_path);
        return -1;
    }

    /*
     * get the path from the dispatcher_definition, break it
     * up to create the elements of the dispatcher table
     */
    if (split_path(x->dd_path, &split_path_list, &split_path_len) < 0)
	return -1;

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
	    return -1;
    }

    /* when we get here, ptr points at last entry added */
    if (x->dd_handler != NULL) {
        /*
         * we're adding/changing a handler
         * you could make this an error optionally
         */
        if (ptr->handler != NULL) {
	    //            fprintf(stderr, "%s: warning: replacing existing handler: (%s) %p -> %p\n", __func__,
	    //     ptr->node_name, ptr->handler, x->dd_handler);
        }
        ptr->handler = x->dd_handler;
    }

    /* clean up */
    split_path_free(split_path_list, split_path_len);

    return 0;
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
 * @param[in]  path
 * @retval     1    OK
 * @retval     0    Invalid
 * @retval    -1    Error
 */
int
dispatcher_call_handlers(dispatcher_entry_t *root,
			 void               *handle,
			 char               *path,
			 void               *user_args)
{
    int                 ret = 0;
    dispatcher_entry_t *best = get_entry(root, path);

    if (best->children != NULL) {
        call_handler_helper(best->children, handle, path, user_args);
    }
    if (best->handler != NULL) {
        ret = (*best->handler)(handle, path, user_args, best->arg);
    }
    return ret;
}

/*! Free a dispatcher tree
 */
int
dispatcher_free(dispatcher_entry_t *root)
{
    if (root == NULL)
	return 0;
    if (root->children)
	dispatcher_free(root->children);
    if (root->peer)
	dispatcher_free(root->peer);
    if (root->node_name)
	free(root->node_name);
    free(root);
    return 0;
}
