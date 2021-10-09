/*
 * Copyright 2021 Rubicon Communications LLC (Netgate)
 * @see https://github.com/dcornejo/dispatcher
 */

#ifndef DISPATCH_DISPATCHER_H
#define DISPATCH_DISPATCHER_H

/*! prototype for a function to handle a path
 * minimally needs the path it's working on, but probably
 * we want to hand down cached data somehow
 * @param[in]  h        Generic handler
 * @param[in]  xpath    Registered XPath using canonical prefixes
 * @param[in]  userargs Per-call user arguments
 * @param[in]  arg      Per-path user argument
 */
typedef int (*handler_function)(void *handle, char *path, void *userargs, void *arg);

/*
 * this structure is used to map a handler to a path
 */
typedef struct {
    char            *dd_path;
    handler_function dd_handler;
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
    char *node_name;

    /*
     * peer points at peer to the right of this one
     * if NULL then this is the rightmost and last on list
     */
    dispatcher_entry_t *peer;

    /*
     * peer_head points at leftmost peer at this level
     * if NULL, then this is the leftmost and first on the list
     * XXX: it seems it points to itself if it is first on the list? 
     */
    dispatcher_entry_t *peer_head;

    /*
     * points at peer_head of children list
     * if NULL, then no children
     */
    dispatcher_entry_t *children;

    /*
     * pointer to handler function for this node
     */
    handler_function handler;

    /*
     * End-user argument
     */
    void *arg;
};

/*
 * Prototypes
 */
int dispatcher_register_handler(dispatcher_entry_t **root, dispatcher_definition *x);
int dispatcher_call_handlers(dispatcher_entry_t *root, void *handle, char *path, void *user_args);
int dispatcher_free(dispatcher_entry_t *root);

#endif /* DISPATCH_DISPATCHER_H */
