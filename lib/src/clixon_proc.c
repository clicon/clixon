/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

  * Processes daemons

  A description of process states.
  An entity is a process_entry_t with a unique name. pids are created for "active" processes.
  States:
     STOPPED: pid=0,   No process running
     RUNNING: pid set, Process started and believed to be running
     EXITING: pid set, Process is killed by parent but not waited for
   
  Operations:
     start, stop, restart

  Transitions:
     Process struct created by calling clixon_process_register() with static info such as name,
     description, namespace, start arguments, etc. Starts in STOPPED state:
       --> STOPPED

     On operation using clixon_process_operation():
       "start" or "restart" it gets a pid and goes into RUNNING state:
           STOPPED -- (re)start --> RUNNING(pid)

     When running, several things may happen:
     1. It is killed externally: the process gets a SIGCHLD triggers a wait and it goes to STOPPED:
           RUNNING  --sigchld/wait-->  STOPPED

     2. It is stopped due to a rpc or configuration remove: 
        The parent kills the process and enters EXITING waiting for a SIGCHLD that triggers a wait,
        therafter it goes to STOPPED
           RUNNING --stop--> EXITING  --sigchld/wait--> STOPPED
     
     3. It is restarted due to rpc or config change (eg a server is added, a key modified, etc). 
        The parent kills the process and enters EXITING waiting for a SIGCHLD that triggers a wait,
        therafter a new process is started and it goes to RUNNING with a new pid

           RUNNING --restart--> EXITING  --sigchld/wait + restart --> RUNNING(pid)

      A complete state diagram is:

      STOPPED  --(re)start-->     RUNNING(pid)
          ^   <--1.wait(kill)---   |  ^
          |                   stop/|  | 
          |                 restart|  | restart
          |                        v  |
          wait(stop) ------- EXITING(dying pid) <----> kill after timeout
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#ifdef HAVE_SETNS /* linux network namespaces */
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <syslog.h>
#include <grp.h>
#include <fcntl.h>
#include <termios.h>
#ifdef HAVE_SETNS /* linux network namespaces */
#include <sched.h> /* setns / unshare */
#endif
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <sys/param.h>
#include <sys/user.h>
#include <sys/time.h>
#include <sys/resource.h>

#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_options.h"
#include "clixon_uid.h"
#include "clixon_event.h"
#include "clixon_sig.h"
#include "clixon_map.h"
#include "clixon_string.h"
#include "clixon_queue.h"
#include "clixon_netconf_lib.h"
#include "clixon_proc.h"

/*
 * Types
 */
/* Process state
 */
enum proc_state {
    PROC_STATE_STOPPED,
    PROC_STATE_RUNNING,
    PROC_STATE_EXITING
};
typedef enum proc_state proc_state_t;

/* Process entry list */
struct process_entry_t {
    qelem_t        pe_qelem;     /* List header */
    char          *pe_name;     /* Name of process used for internal use. Unique with exiting=0 */
    char          *pe_description; /* Description of service */
    char          *pe_netns;    /* Network namespace */
    uid_t          pe_uid;      /* UID of process or -1 to keep same as backend */
    gid_t          pe_gid;      /* GID of process or -1 to keep same as backend */
    gid_t          pe_fdkeep;   /* Unless -1 skip closing (one) filedes, typically 2/stderr */
    char         **pe_argv;     /* argv with command as element 0 and NULL-terminated */
    int            pe_argc;     /* Length of argc */
    pid_t          pe_pid;      /* Running process id (state) or 0 if dead (pid is set if exiting=1) */
    proc_operation pe_operation;/* Pending operation: stop/start/restart */
    proc_state_t   pe_state;    /* stopped, running, exiting */
    pid_t          pe_exit_status;/* Status on exit as defined in waitpid */
    struct timeval pe_starttime; /* Start time */
    proc_cb_t     *pe_callback;  /* Wrapper function, may be called from process_operation  */
};

/*! Structure for checking resources before and after a call
 *
 * Currently signal settings: blocked and handlers, and termios
 * @see clixon_resource_check
 */
struct resource_context {
    sigset_t         rc_sigset;            /* See sigprocmask(2) */
    struct sigaction rc_sigaction_vec[32]; /* See sigaction(2) */
    struct termios   rc_termios;           /* See termios(3) */
};

/* Forward declaration */
static int clixon_process_sched_register(clixon_handle h, int delay);
static int clixon_process_delete_only(process_entry_t *pe);

static void
clixon_proc_sigint(int sig)
{
    /* XXX does nothing */
}

/*! Fork a child, exec a child and setup socket to child and return to caller
 *
 * @param[in]  h          Clixon handle
 * @param[in]  argv       NULL-terminated Argument vector
 * @param[in]  sock_flags Socket type/flags, typically SOCK_DGRAM or SOCK_STREAM, see
 * @param[out] pid        Process-id of child
 * @param[out] sock       Socket for stdin+stdout
 * @param[out] sockerr    Optional socket for stderr
 * @retval     O          OK
 * @retval    -1          Error.
 * @see clixon_proc_socket_close  close sockets, kill child and wait for child termination
 * @see for flags usage see man sockerpair(2)
 */
int
clixon_proc_socket(clixon_handle h,
                   char        **argv,
                   int           sock_flags,
                   pid_t        *pid,
                   int          *sock,
                   int          *sockerr)
{
    int      retval = -1;
    int      sp[2] = {-1, -1};
    int      sperr[2] = {-1, -1};
    pid_t    child;
    sigfn_t  oldhandler = NULL;
    sigset_t oset;
    int      sig = 0;
    unsigned argc;
    char    *flattened;

    if (argv == NULL){
        clixon_err(OE_UNIX, EINVAL, "argv is NULL");
        goto done;
    }
    if (argv[0] == NULL){
        clixon_err(OE_UNIX, EINVAL, "argv[0] is NULL");
	goto done;
    }
    clixon_debug(CLIXON_DBG_PROC, "%s...", argv[0]);
    for (argc = 0; argv[argc] != NULL; ++argc)
         ;
    if ((flattened = clicon_strjoin(argc, argv, "', '")) == NULL){
        clixon_err(OE_UNIX, ENOMEM, "clicon_strjoin");
        goto done;
    }
    clixon_log(h, LOG_INFO, "%s '%s'", __FUNCTION__, flattened);
    free(flattened);

    if (socketpair(AF_UNIX, sock_flags, 0, sp) < 0){
        clixon_err(OE_UNIX, errno, "socketpair");
        goto done;
    }
    if (sockerr &&
        socketpair(AF_UNIX, sock_flags, 0, sperr) < 0){
        clixon_err(OE_UNIX, errno, "socketpair");
        goto done;
    }
    sigprocmask(0, NULL, &oset);
    set_signal(SIGINT, clixon_proc_sigint, &oldhandler);
    sig++;
    if ((child = fork()) < 0) {
        clixon_err(OE_UNIX, errno, "fork");
        goto done;
    }
    if (child == 0) {   /* Child */
        /* Unblock all signals except TSTP */
        clicon_signal_unblock(0);
        signal(SIGTSTP, SIG_IGN);

        close(sp[0]);
        close(sperr[0]);
        close(0);
        if (dup2(sp[1], STDIN_FILENO) < 0){
            clixon_err(OE_UNIX, errno, "dup2(STDIN)");
            return -1;
        }
        close(1);
        if (dup2(sp[1], STDOUT_FILENO) < 0){
            clixon_err(OE_UNIX, errno, "dup2(STDOUT)");
            return -1;
        }
        close(sp[1]);
        if (sockerr){
            close(2);
            if (dup2(sperr[1], STDERR_FILENO) < 0){
                clixon_err(OE_UNIX, errno, "dup2(STDERR)");
                return -1;
            }
            close(sperr[1]);
        }
        close(sperr[1]);
        if (execvp(argv[0], argv) < 0){
            clixon_err(OE_UNIX, errno, "execvp(%s)", argv[0]);
            return -1;
        }
        exit(-1);        /* Shouldnt reach here */
    }
    clixon_debug(CLIXON_DBG_PROC, "child %u sock %d", child, sp[0]);
    /* Parent */
    close(sp[1]);
    close(sperr[1]);
    *pid = child;
    *sock = sp[0];
    if (sockerr)
        *sockerr = sperr[0];
    retval = 0;
 done:
    if (sig){   /* Restore sigmask and fn */
        sigprocmask(SIG_SETMASK, &oset, NULL);
        set_signal(SIGINT, oldhandler, NULL);
    }
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

/*! Close socket 
 *
 * @see clixon_proc_socket which creates the child and sockets closed and killed here
 */
int
clixon_proc_socket_close(pid_t pid,
                         int   sock)
{
    int retval = -1;
    int status;

    clixon_debug(CLIXON_DBG_PROC, "pid %u sock %d", pid, sock);
    if (sock != -1)
        close(sock); /* usually kills */
    kill(pid, SIGTERM);
    //    usleep(100000);     /* Wait for child to finish */
    if(waitpid(pid, &status, 0) == pid){
        retval = WEXITSTATUS(status);
        clixon_debug(CLIXON_DBG_PROC, "waitpid status %#x", retval);
    }
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

/*! Fork and exec a sub-process, let it run and return pid
 *
 * @param[in]  h     Clixon handle
 * @param[in]  argv  NULL-terminated Argument vector
 * @param[in]  netns Network namespace (or NULL)
 * @param[in]  uid   User-id or -1 to keep existing
 * @param[in]  fdkeep If -1 keep this filedes open
 * @param[out] pid   Process id
 * @retval     0     OK
 * @retval    -1     Error.
 */
static int
clixon_proc_background(clixon_handle h,
                       char        **argv,
                       const char   *netns,
                       uid_t         uid,
                       gid_t         gid,
                       int           fdkeep,
                       pid_t        *pid0)
{
    int           retval = -1;
    pid_t         child = 0;
    int           i;
    sigfn_t       oldhandler = NULL;
    sigset_t      oset;
    struct rlimit rlim = {0, };
    struct stat   fstat = {0, };
    char         *flattened;
    unsigned      argc;

    clixon_debug(CLIXON_DBG_PROC, "");
    if (argv == NULL){
        clixon_err(OE_UNIX, EINVAL, "argv is NULL");
        goto quit;
    }
    if (argv[0] == NULL){
        clixon_err(OE_UNIX, EINVAL, "argv[0] is NULL");
	goto quit;
    }
    for (argc = 0; argv[argc] != NULL; ++argc)
         ;
    if ((flattened = clicon_strjoin(argc, argv, "', '")) == NULL){
        clixon_err(OE_UNIX, ENOMEM, "clicon_strjoin");
        goto quit;
    }
    clixon_log(h, LOG_INFO, "%s '%s'", __FUNCTION__, flattened);
    free(flattened);

    /* Sanity check: program exists */
    // coverity: CID 471757: (#1 of 1): Time of check time of use (TOCTOU)9. fs_check_call: Calling function stat to perform check on argv[0]. See later execvp on filename
    if (stat(argv[0], &fstat) < 0) {
        clixon_err(OE_FATAL, errno, "%s", argv[0]);
        goto quit;
    }
    /* Before here call quit on error */
    sigprocmask(0, NULL, &oset);
    set_signal(SIGINT, clixon_proc_sigint, &oldhandler);
    /* Now call done on error */
    if ((child = fork()) < 0) {
        clixon_err(OE_UNIX, errno, "fork");
        goto done;
    }
    if (child == 0)  { /* Child */
#ifdef HAVE_SETNS
        char nsfile[PATH_MAX];
        int  nsfd;
#endif
        clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "child");
        clicon_signal_unblock(0);
        signal(SIGTSTP, SIG_IGN);
        if (chdir("/") < 0){
            clixon_err(OE_UNIX, errno, "chdir");
            exit(1);
        }
        /* Close open descriptors */
        if ( ! getrlimit(RLIMIT_NOFILE, &rlim))
            for (i = 0; i < rlim.rlim_cur; i++){
                if (fdkeep != -1 && i == fdkeep) // XXX stderr
                    continue;
                close(i);
            }
#ifdef HAVE_SETNS /* linux network namespaces */
        /* If network namespace is defined, let child join it 
         * XXX: this is work-in-progress
         */
        if (netns != NULL) {
            snprintf(nsfile, PATH_MAX, "/var/run/netns/%s", netns); /* see man setns / ip netns */
            clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "nsfile:%s", nsfile);
            /* Change network namespace */
            if ((nsfd = open(nsfile, O_RDONLY | O_CLOEXEC)) < 0){
                clixon_err(OE_UNIX, errno, "open");
                exit(1);
            }
            if (setns(nsfd, 0) < 0){       /* Join that namespace */
                clixon_err(OE_UNIX, errno, "setns");
                exit(1);
            }
            close(nsfd);
            if (unshare(CLONE_NEWNS) < 0){
                clixon_err(OE_UNIX, errno, "unshare");
                exit(1);
            }
        }
#endif /* HAVE_SETNS */
        if (gid != -1){
            if (setgid(gid) == -1) {
                clixon_err(OE_DAEMON, errno, "setgid %d", gid);
                goto done;
            }
        }
        if (uid != -1){
            if (drop_priv_perm(uid) < 0)
                goto done;
        }
        if (execvp(argv[0], argv) < 0) {
            clixon_err(OE_UNIX, errno, "execvp(%s)", argv[0]);
            exit(1);
        }
        /* Not reached */
    }
 done:
    sigprocmask(SIG_SETMASK, &oset, NULL);
    set_signal(SIGINT, oldhandler, NULL);
    *pid0 = child;
    retval = 0;
 quit:
    clixon_debug(CLIXON_DBG_PROC, "retval:%d child:%u", retval, child);
    return retval;
}

/*--------------------------------------------------------------------------------*
 * Process management: start/stop registered processes for internal use
 */

static const map_str2int proc_state_map[] = {
    {"stopped",          PROC_STATE_STOPPED},
    {"running",          PROC_STATE_RUNNING},
    {"exiting",          PROC_STATE_EXITING},
    {NULL,               -1}
};

/* Process operations
 */
static const map_str2int proc_operation_map[] = {
    {"none",                  PROC_OP_NONE},   /* Not state transition operator */
    {"start",                 PROC_OP_START},  /* State transition operator */
    {"stop",                  PROC_OP_STOP},   /* State transition operator */
    {"restart",               PROC_OP_RESTART},/* State transition operator */
    {"status",                PROC_OP_STATUS}, /* Not state transition operator */
    {NULL,                    -1}
};

/* List of process callback entries XXX move to handle */
static process_entry_t *_proc_entry_list = NULL;

int
clixon_process_op_str2int(char *opstr)
{
    return clicon_str2int(proc_operation_map, opstr);
}

/*! Access function process list argv list
 *
 * @param[in]  h     Clixon handle 
 * @param[in]  name  Name of process
 * @param[out] argv  Malloced argv list (Null terminated)
 * @param[out] argc  Length of argv
 *
 * @note Can be used to change in the argv list elements directly with care: Dont change list 
 * itself, but its elements can be freed and re-alloced.
 */
int
clixon_process_argv_get(clixon_handle h,
                        const char   *name,
                        char       ***argv,
                        int          *argc)
{
    process_entry_t *pe;

    pe = _proc_entry_list;
    do {
        if (strcmp(pe->pe_name, name) == 0){
            *argv = pe->pe_argv;
            *argc = pe->pe_argc;
        }
        pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);
    return 0;
}

/*! Register an internal process
 *
 * @param[in]  h        Clixon handle
 * @param[in]  name     Process name
 * @param[in]  description  Description of process
 * @param[in]  netns    Namespace netspace (or NULL)
 * @param[in]  uid      UID of process (or -1 to keep same)
 * @param[in]  gid      GID of process (or -1 to keep same)
 * @param[in]  fdkeep   Unless -1 skip closing (one) filedes, typically 2/stderr 
 * @param[in]  callback Wrapper function
 * @param[in]  argv     NULL-terminated vector of vectors 
 * @param[in]  argc     Length of argv
 * @retval     0        OK
 * @retval    -1        Error
 * @note name, netns, argv and its elements are all copied / re-alloced.
 */
int
clixon_process_register(clixon_handle h,
                        const char   *name,
                        const char   *description,
                        const char   *netns,
                        const uid_t   uid,
                        const gid_t   gid,
                        const int     fdkeep,
                        proc_cb_t    *callback,
                        char        **argv,
                        int           argc)
{
    int              retval = -1;
    process_entry_t *pe = NULL;
    int              i;

    if (name == NULL){
        clixon_err(OE_DB, EINVAL, "name is NULL");
        goto done;
    }
    if (argv == NULL){
        clixon_err(OE_DB, EINVAL, "argv is NULL");
        goto done;
    }

    clixon_debug(CLIXON_DBG_PROC, "name:%s (%s)", name, argv[0]);

    if ((pe = malloc(sizeof(process_entry_t))) == NULL) {
        clixon_err(OE_DB, errno, "malloc");
        goto done;
    }
    memset(pe, 0, sizeof(*pe));
    if ((pe->pe_name = strdup(name)) == NULL){
        clixon_err(OE_DB, errno, "strdup name");
        free(pe);
        goto done;
    }
    if (description && (pe->pe_description = strdup(description)) == NULL){
        clixon_err(OE_DB, errno, "strdup description");
        clixon_process_delete_only(pe);
        goto done;
    }
    if (netns && (pe->pe_netns = strdup(netns)) == NULL){
        clixon_err(OE_DB, errno, "strdup netns");
        clixon_process_delete_only(pe);
        goto done;
    }
    pe->pe_uid = uid;
    pe->pe_gid = gid;
    pe->pe_fdkeep = fdkeep;
    pe->pe_argc = argc;
    if ((pe->pe_argv = calloc(argc, sizeof(char *))) == NULL){
        clixon_err(OE_UNIX, errno, "calloc");
        clixon_process_delete_only(pe);
        goto done;
    }
    for (i=0; i<argc; i++){
        if (argv[i] != NULL &&
            (pe->pe_argv[i] = strdup(argv[i])) == NULL){
            clixon_err(OE_UNIX, errno, "strdup");
            clixon_process_delete_only(pe);
            goto done;
        }
    }
    pe->pe_callback = callback;
    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "%s ----> %s",
                 pe->pe_name,
                 clicon_int2str(proc_state_map, PROC_STATE_STOPPED)
                 );
    pe->pe_state = PROC_STATE_STOPPED;
    ADDQ(pe, _proc_entry_list);
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

static int
clixon_process_delete_only(process_entry_t *pe)
{
    char           **pa;

    if (pe->pe_name)
        free(pe->pe_name);
    if (pe->pe_description)
        free(pe->pe_description);
    if (pe->pe_netns)
        free(pe->pe_netns);
    if (pe->pe_argv){
        for (pa = pe->pe_argv; *pa != NULL; pa++){
            if (*pa)
                free(*pa);
        }
        free(pe->pe_argv);
    }
    free(pe);
    return 0;
}

/*! Delete all Upgrade callbacks
 */
int
clixon_process_delete_all(clixon_handle h)
{
    process_entry_t *pe;

    while((pe = _proc_entry_list) != NULL) {
        DELQ(pe, _proc_entry_list, process_entry_t *);
        clixon_process_delete_only(pe);
    }
    return 0;
}

/*! Run process
 */
static int
proc_op_run(pid_t pid0,
            int  *runp)
{
    int   retval = -1;
    int   run;
    pid_t pid;

    run = 0;
    if ((pid = pid0) != 0){ /* if 0 stopped */
        /* Check if alive */
        run = 1;
        if ((kill(pid, 0)) < 0){
            clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "errno:%d", errno);
            if (errno == ESRCH){
                run = 0;
            }
            else{
                clixon_err(OE_UNIX, errno, "kill(%d)", pid);
                goto done;
            }
        }
    }
    if (runp)
        *runp = run;
    retval = 0;
 done:
    return retval;
}

int
clixon_process_pid(clixon_handle h,
                   const char   *name, 
                   pid_t        *pid)
{
    int             retval = -1;
    process_entry_t *pe;
    int              isrunning; /* Process is actually running */

    if (_proc_entry_list == NULL || !pid)
    goto done;

    pe = _proc_entry_list;
    do {
        if (strcmp(pe->pe_name, name) == 0) {
            isrunning = 0;
            if (proc_op_run(pe->pe_pid, &isrunning) < 0)
                goto done;

            if (!isrunning)
                goto done;

            *pid = pe->pe_pid;
            retval = 0;
            break;
        }
        pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);

done:
    return retval;
}

/*! Find process entry given name and schedule operation
 *
 * @param[in]  h       clicon handle
 * @param[in]  name    Name of process
 * @param[in]  op0     start, stop, restart, status
 * @param[in]  wrapit  If set, call potential callback, if false, dont call it
 * @retval     0       OK
 * @retval    -1       Error

 * @see upgrade_callback_reg_fn  which registers the callbacks
 * @note operations are not made directly but postponed by a scheduling the actions.
 *       This is not really necessary for all operations (like start) but made for all
 *       for reducing complexity of code.
 * @see clixon_process_sched where operations are actually executed
 */
int
clixon_process_operation(clixon_handle  h,
                         const char    *name,
                         proc_operation op0,
                         int            wrapit)
{
    int              retval = -1;
    process_entry_t *pe;
    proc_operation   op;
    int              sched = 0; /* If set, process action should be scheduled, register a timeout */
    int              isrunning = 0;
    int              delay = 0;

    clixon_debug(CLIXON_DBG_PROC, "name:%s op:%s", name, clicon_int2str(proc_operation_map, op0));
    if (_proc_entry_list == NULL)
        goto ok;
    if ((pe = _proc_entry_list) != NULL)
        do {
            if (strcmp(pe->pe_name, name) == 0){
                /* Call wrapper function that eg changes op1 based on config */
                op = op0;
                if (wrapit && pe->pe_callback != NULL)
                    if (pe->pe_callback(h, pe, &op) < 0)
                        goto done;
                if (op == PROC_OP_START || op == PROC_OP_STOP || op == PROC_OP_RESTART){
                    pe->pe_operation = op;
                    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "scheduling name: %s pid:%d op: %s",
                                 name, pe->pe_pid,
                                 clicon_int2str(proc_operation_map, pe->pe_operation));
                    if (pe->pe_state==PROC_STATE_RUNNING &&
                        (op == PROC_OP_STOP || op == PROC_OP_RESTART)){
                        clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "AA");
                        isrunning = 0;
                        if (proc_op_run(pe->pe_pid, &isrunning) < 0)
                            goto done;
                        if (isrunning) {
                            clixon_log(h, LOG_NOTICE, "Killing old process %s with pid: %d",
                                       pe->pe_name, pe->pe_pid); /* XXX pid may be 0 */
                            kill(pe->pe_pid, SIGTERM);
                            delay = 1;
                        }
                        clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "%s(%d) %s --%s--> %s",
                                     pe->pe_name, pe->pe_pid,
                                     clicon_int2str(proc_state_map, pe->pe_state),
                                     clicon_int2str(proc_operation_map, pe->pe_operation),
                                     clicon_int2str(proc_state_map, PROC_STATE_EXITING)
                                     );
                        pe->pe_state = PROC_STATE_EXITING; /* Keep operation stop/restart */
                    }
                    sched++;/* start: immediate stop/restart: not immediate: wait timeout */
                }
                else{
                    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "name:%s op %s cancelled by wrap", name, clicon_int2str(proc_operation_map, op0));
                }
                break;          /* hit break here */
            }
            pe = NEXTQ(process_entry_t *, pe);
        } while (pe != _proc_entry_list);
    if (sched)
        clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "Before clixon_process_sched_register");
    if (sched && clixon_process_sched_register(h, delay) < 0)
        goto done;
 ok:
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

/*! Get process status according to clixon-lib.yang
 *
 * @param[in]  h       clicon handle
 * @param[in]  name    Name of process
 * @param[out] cbret   XML status string
 * @retval     0       OK
 * @retval    -1       Error

 */
int
clixon_process_status(clixon_handle  h,
                      const char    *name,
                      cbuf          *cbret)
{
    int              retval = -1;
    process_entry_t *pe;
    int              run;
    int              i;
    char             timestr[28];
    int              match = 0;

    clixon_debug(CLIXON_DBG_PROC, "name:%s", name);

    if (_proc_entry_list != NULL){
        pe = _proc_entry_list;
        do {
            if (strcmp(pe->pe_name, name) == 0){
                clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "found %s pid:%d", name, pe->pe_pid);
                /* Check if running */
                run = 0;
                if (pe->pe_pid && proc_op_run(pe->pe_pid, &run) < 0)
                    goto done;
                cprintf(cbret, "<rpc-reply xmlns=\"%s\"><active xmlns=\"%s\">%s</active>",
                        NETCONF_BASE_NAMESPACE, CLIXON_LIB_NS, run?"true":"false");
                if (pe->pe_description)
                    cprintf(cbret, "<description xmlns=\"%s\">%s</description>", CLIXON_LIB_NS, pe->pe_description);
                cprintf(cbret, "<command xmlns=\"%s\">", CLIXON_LIB_NS);
                /* The command may include any data, including XML (such as restconf -R
                 * command) and therefore needs explicit encoding */
                for (i=0; i<pe->pe_argc-1; i++){
                    if (i)
                        if (xml_chardata_cbuf_append(cbret, 0, " ") < 0)
                            goto done;
                    if (xml_chardata_cbuf_append(cbret, 0, pe->pe_argv[i]) < 0)
                        goto done;
                }
                cprintf(cbret, "</command>");
                cprintf(cbret, "<status xmlns=\"%s\">%s</status>", CLIXON_LIB_NS,
                        clicon_int2str(proc_state_map, pe->pe_state));
                if (timerisset(&pe->pe_starttime)){
                    if (time2str(&pe->pe_starttime, timestr, sizeof(timestr)) < 0){
                        clixon_err(OE_UNIX, errno, "time2str");
                        goto done;
                    }
                    cprintf(cbret, "<starttime xmlns=\"%s\">%s</starttime>", CLIXON_LIB_NS, timestr);
                }
                if (pe->pe_pid)
                    cprintf(cbret, "<pid xmlns=\"%s\">%u</pid>", CLIXON_LIB_NS, pe->pe_pid);
                cprintf(cbret, "</rpc-reply>");
                match++;
                break;      /* hit break here */
            }
            pe = NEXTQ(process_entry_t *, pe);
        } while (pe != _proc_entry_list);
    }
    if (!match){ /* No match, return error */
        if (netconf_unknown_element(cbret, "application", (char*)name, "Process service is not known") < 0)
            goto done;
    }
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

/*! Go through process list and start all processes that are enabled via config wrap function
 *
 * @param[in]  h   Clixon handle
 * @retval     0   OK
 * @retval    -1   Error
 * Commit rules should have done this, but there are some cases such as backend -s none mode
 * where commits are not made.
 */
int
clixon_process_start_all(clixon_handle h)
{
    int              retval = -1;
    process_entry_t *pe;
    proc_operation   op;
    int              sched = 0; /* If set, process action should be scheduled, register a timeout */

    clixon_debug(CLIXON_DBG_PROC, "");
    if (_proc_entry_list == NULL)
        goto ok;
    pe = _proc_entry_list;
    do {
        op = PROC_OP_START;
        /* Call wrapper function that eg changes op based on config */
        if (pe->pe_callback != NULL)
            if (pe->pe_callback(h, pe, &op) < 0)
                goto done;
        if (op == PROC_OP_START){
            clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "name:%s start", pe->pe_name);
            pe->pe_operation = op;
            sched++; /* Immediate dont delay for start */
        }
        pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);
    if (sched && clixon_process_sched_register(h, 0) < 0)
        goto done;
 ok:
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

/*! Traverse all processes and check pending start/stop/restarts
 *
 * @param[in]  h   Clixon handle
 * @retval     0   OK
 * @retval    -1   Error
 * Typical cases where postponing process start/stop is necessary:
 * (1) at startup, if started before deamoninization, process will get as child of 1
 * (2) edit changes or rpc restart especially of restconf where you may saw of your arm and terminate
 *     return socket.
 * A special complexity is restarting processes, where the old is killed, but state must be kept until it is reaped
 * @see clixon_process_waitpid where killed/restarted processes are "reaped"
 */
static int
clixon_process_sched(int           fd,
                     clixon_handle h)
{
    int              retval = -1;
    process_entry_t *pe;
    int              isrunning; /* Process is actually running */
    int              sched = 0;

    clixon_debug(CLIXON_DBG_PROC, "");
    if (_proc_entry_list == NULL)
        goto ok;
    pe = _proc_entry_list;
    do {
        clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "do proc_entry_list name: %s pid:%d %s --op:%s-->",
                     pe->pe_name, pe->pe_pid, clicon_int2str(proc_state_map, pe->pe_state), clicon_int2str(proc_operation_map, pe->pe_operation));
        /* Execute pending operations and not already exiting */
        if (pe->pe_operation != PROC_OP_NONE){
            switch (pe->pe_state){
            case PROC_STATE_EXITING:
                switch (pe->pe_operation){
                case PROC_OP_STOP:
                case PROC_OP_RESTART: /* Kill again */
                    isrunning = 0;
                    if (proc_op_run(pe->pe_pid, &isrunning) < 0)
                        goto done;
                    if (isrunning) {
                        clixon_log(h, LOG_NOTICE, "Killing old process %s with pid: %d",
                                   pe->pe_name, pe->pe_pid); /* XXX pid may be 0 */
                        kill(pe->pe_pid, SIGTERM);
                        sched++; /* Not immediate: wait timeout */
                    }
                default:
                    break;
                }
                break; /* only clixon_process_waitpid can change state in exiting */
            case PROC_STATE_STOPPED:
                switch (pe->pe_operation){
                case PROC_OP_RESTART: /* stopped -> restart can happen if its externall stopped */
                case PROC_OP_START:
                    /* Check if actual running using kill(0) */
                    isrunning = 0;
                    if (proc_op_run(pe->pe_pid, &isrunning) < 0)
                        goto done;
                    if (!isrunning)
                        if (clixon_proc_background(h, pe->pe_argv, pe->pe_netns,
                                                   pe->pe_uid, pe->pe_gid, pe->pe_fdkeep,
                                                   &pe->pe_pid) < 0)
                            goto done;
                    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL,
                                 "%s(%d) %s --%s--> %s",
                                 pe->pe_name, pe->pe_pid,
                                 clicon_int2str(proc_state_map, pe->pe_state),
                                 clicon_int2str(proc_operation_map, pe->pe_operation),
                                 clicon_int2str(proc_state_map, PROC_STATE_RUNNING)
                                 );
                    pe->pe_state = PROC_STATE_RUNNING;
                    gettimeofday(&pe->pe_starttime, NULL);
                    pe->pe_operation = PROC_OP_NONE;
                    break;
                default:
                    break;
                }
                break;
            case PROC_STATE_RUNNING:
                /* Check if actual running using kill(0) */
                isrunning = 0;
                if (proc_op_run(pe->pe_pid, &isrunning) < 0)
                    goto done;
                switch (pe->pe_operation){
                case PROC_OP_START:
                    if (isrunning) /* Already runs */
                        break;
                    if (clixon_proc_background(h, pe->pe_argv, pe->pe_netns,
                                               pe->pe_uid, pe->pe_gid, pe->pe_fdkeep,
                                               &pe->pe_pid) < 0)
                        goto done;
                    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL,
                                 "%s(%d) %s --%s--> %s",
                                 pe->pe_name, pe->pe_pid,
                                 clicon_int2str(proc_state_map, pe->pe_state),
                                 clicon_int2str(proc_operation_map, pe->pe_operation),
                                 clicon_int2str(proc_state_map, PROC_STATE_RUNNING)
                                 );
                    gettimeofday(&pe->pe_starttime, NULL);
                    pe->pe_operation = PROC_OP_NONE;
                    break;
                default:
                    break;
                }/* switch pe_state */
            default:
                break;
            } /* switch pe_state */
        }
        pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);
    if (sched && clixon_process_sched_register(h, 1) < 0)
        goto done;
 ok:
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

/*! Register scheduling of process start/stop/restart
 *
 * Schedule a process event. There are two cases:
 * 1) A process has been killed and is in EXITING, after a delay kill again. 
 * 2) A process is started, dont delay
 * @param[in]  h     Clixon handle
 * @param[in]  delay If 0 dont add a delay, if 1 add a delay
 * @retval     0     OK
 * @retval    -1     Error
 */
static int
clixon_process_sched_register(clixon_handle h,
                              int           delay)
{
    int            retval = -1;
    struct timeval t;
    struct timeval t1 = {0, 100000}; /* 100ms */

    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "");
    gettimeofday(&t, NULL);
    if (delay)
        timeradd(&t, &t1, &t);
    if (clixon_event_reg_timeout(t, clixon_process_sched, h, "process") < 0)
        goto done;
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "retval:%d", retval);
    return retval;
}

/*! Go through processes and wait for child processes
 *
 * Typically we know a child has been killed by SIGCHLD, but we do not know which process it is
 * Traverse all known processes and reap them, eg call waitpid() to avoid zombies.
 * @param[in]  h  Clixon handle
 * @retval     0  OK
 * @retval    -1  Error

 */
int
clixon_process_waitpid(clixon_handle h)
{
    int              retval = -1;
    process_entry_t *pe;
    int              status = 0;
    pid_t            wpid;

    clixon_debug(CLIXON_DBG_PROC, "");
    if (_proc_entry_list == NULL)
        goto ok;
    if ((pe = _proc_entry_list) != NULL)
        do {
            clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "%s(%d) %s op:%s",
                         pe->pe_name, pe->pe_pid,
                         clicon_int2str(proc_state_map, pe->pe_state),
                         clicon_int2str(proc_operation_map, pe->pe_operation));
            if (pe->pe_pid != 0
                && (pe->pe_state == PROC_STATE_RUNNING || pe->pe_state == PROC_STATE_EXITING)
                //      && (pe->pe_operation == PROC_OP_STOP || pe->pe_operation == PROC_OP_RESTART)
                ){
                clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "%s waitpid(%d)",
                             pe->pe_name, pe->pe_pid);
                if ((wpid = waitpid(pe->pe_pid, &status, WNOHANG)) == pe->pe_pid){
                    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "waitpid(%d) waited", pe->pe_pid);
                    pe->pe_exit_status = status;
                    switch (pe->pe_operation){
                    case PROC_OP_NONE: /* Spontaneous / External termination */
                    case PROC_OP_STOP:
                        clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL,
                                     "%s(%d) %s --%s--> %s",
                                     pe->pe_name, pe->pe_pid,
                                     clicon_int2str(proc_state_map, pe->pe_state),
                                     clicon_int2str(proc_operation_map, pe->pe_operation),
                                     clicon_int2str(proc_state_map, PROC_STATE_STOPPED)
                                     );
                        pe->pe_state = PROC_STATE_STOPPED;
                        pe->pe_pid = 0;
                        timerclear(&pe->pe_starttime);
                        break;
                    case PROC_OP_RESTART:
                        /* This is the case where there is an existing process running.
                         * it was killed above but still runs and needs to be reaped */
                        if (clixon_proc_background(h, pe->pe_argv, pe->pe_netns,
                                                   pe->pe_uid, pe->pe_gid, pe->pe_fdkeep,
                                                   &pe->pe_pid) < 0)
                            goto done;
                        gettimeofday(&pe->pe_starttime, NULL);
                        clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "%s(%d) %s --%s--> %s",
                                     pe->pe_name, pe->pe_pid,
                                     clicon_int2str(proc_state_map, pe->pe_state),
                                     clicon_int2str(proc_operation_map, pe->pe_operation),
                                     clicon_int2str(proc_state_map, PROC_STATE_RUNNING)
                                     );
                        pe->pe_state = PROC_STATE_RUNNING;
                        gettimeofday(&pe->pe_starttime, NULL);
                        break;
                    default:
                        break;
                    }
                    pe->pe_operation = PROC_OP_NONE;
                    break; /* pid is unique */
                }
                else
                    clixon_debug(CLIXON_DBG_PROC | CLIXON_DBG_DETAIL, "waitpid(%d) nomatch:%d",
                                 pe->pe_pid, wpid);
            }
            pe = NEXTQ(process_entry_t *, pe);
        } while (pe && pe != _proc_entry_list);
 ok:
    retval = 0;
 done:
    clixon_debug(CLIXON_DBG_PROC, "retval:%d", retval);
    return retval;
}

/*! Get system context, eg signal procmask (for blocking) and sigactions
 *
 * Call this before a plugin
 * @retval     pc      Plugin context structure, use free() to deallocate
 * @retval     NULL    Error
 * */
static void *
resource_context_get(void)
{
    int                      i;
    struct resource_context *rc = NULL;

    if ((rc = malloc(sizeof(*rc))) == NULL){
        clixon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memset(rc, 0, sizeof(*rc));
    if (sigprocmask(0, NULL, &rc->rc_sigset) < 0){
        clixon_err(OE_UNIX, errno, "sigprocmask");
        goto done;
    }
    for (i=1; i<32; i++){
        if (sigaction(i, NULL, &rc->rc_sigaction_vec[i]) < 0){
            clixon_err(OE_UNIX, errno, "sigaction");
            goto done;
        }
        /* Mask SA_RESTORER: Not intended for application use.
         * Note that it may not be included in user space so may be hardcoded below
         */
#ifdef SA_RESTORER
        rc->rc_sigaction_vec[i].sa_flags &= ~SA_RESTORER;
#else
        rc->rc_sigaction_vec[i].sa_flags &= ~0x04000000;
#endif
    }
    if (isatty(0) && tcgetattr(0, &rc->rc_termios) < 0){
        clixon_err(OE_UNIX, errno, "tcgetattr %d", errno);
        goto done;
    }
    return rc;
 done:
    if (rc)
        free(rc);
    return NULL;
}

/*! Check terminal+signal context, check if anything has changed
 *
 * Called twice:
 * 1) Make a check of resources
 * 2) Make a new check and compare with the old check, return 1 on success, 0 on fail
 * Log if there is a difference at loglevel WARNING.
 * Controlled by CLICON_PLUGIN_CALLBACK_CHECK:
 * 0 : No checks
 * 1 : warning logs on failure
 * 2 : log and abort on failure
 *
 * @param[in]     h      Clixon handle
 * @param[in,out] wh     Either: NULL for init, will be assigned, OR previous handle (will be freed)
 * @param[in]     name   Name of plugin for logging. Can be other name, context dependent
 * @param[in]     fn     Typically name of callback, or caller function
 * @retval        1      OK
 * @retval        0      Fail, log on syslog using LOG_WARNING
 * @retval       -1      Error
 * @note Only logs error, does not generate error
 * @note name and fn are context dependent, since the env of callback calls are very different
 * @see CLICON_PLUGIN_CALLBACK_CHECK  Enable to activate these checks
 * The naming "PLUGIN" is of historical reasons.
 */
int
clixon_resource_check(clixon_handle h,
                      void        **wh,
                      const char   *name,
                      const char   *fn)
{
    int                      retval = -1;
    int                      failed = 0;
    int                      i;
    struct resource_context *oldrc;
    struct resource_context *newrc = NULL;
    int                      option;

    if (h == NULL){
        errno = EINVAL;
        return -1;
    }
    option = clicon_option_int(h, "CLICON_PLUGIN_CALLBACK_CHECK");
    /* Check if plugion checks are enabled */
    if (option == 0)
        return 1;
    if (wh == NULL){
        errno = EINVAL;
        return -1;
    }
    if (*wh == NULL){
        *wh = resource_context_get();
        return 1;
    }
    oldrc = (struct resource_context *)*wh;
    if ((newrc = resource_context_get()) == NULL)
        goto done;
    if (oldrc->rc_termios.c_iflag != newrc->rc_termios.c_iflag){
        clixon_log(h, LOG_WARNING, "%s Plugin context %s %s: Changed termios input modes from 0x%x to 0x%x", __FUNCTION__,
                   name, fn,
                   oldrc->rc_termios.c_iflag,
                   newrc->rc_termios.c_iflag);
        failed++;
    }
    if (oldrc->rc_termios.c_oflag != newrc->rc_termios.c_oflag){
        clixon_log(h, LOG_WARNING, "%s Plugin context %s %s: Changed termios output modes from 0x%x to 0x%x", __FUNCTION__,
                   name, fn,
                   oldrc->rc_termios.c_oflag,
                   newrc->rc_termios.c_oflag);
        failed++;
    }
    if (oldrc->rc_termios.c_cflag != newrc->rc_termios.c_cflag){
        clixon_log(h, LOG_WARNING, "%s Plugin context %s %s: Changed termios control modes from 0x%x to 0x%x", __FUNCTION__,
                   name, fn,
                   oldrc->rc_termios.c_cflag,
                   newrc->rc_termios.c_cflag);
        failed++;
    }
    if (oldrc->rc_termios.c_lflag != newrc->rc_termios.c_lflag){
        clixon_log(h, LOG_WARNING, "%s Plugin context %s %s: Changed termios local modes from 0x%x to 0x%x", __FUNCTION__,
                   name, fn,
                   oldrc->rc_termios.c_lflag,
                   newrc->rc_termios.c_lflag);
        failed++;
    }
    /* XXX rc_termios.cc_t  c_cc[NCCS] not checked */
    /* Abort if option is 2 or above on failure
     */
    if (option > 1 && failed)
        abort();
    for (i=1; i<32; i++){
        if (sigismember(&oldrc->rc_sigset, i) != sigismember(&newrc->rc_sigset, i)){
            clixon_log(h, LOG_WARNING, "%s Plugin context %s %s: Changed blocking of signal %s(%d) from %d to %d", __FUNCTION__,
                       name, fn, strsignal(i), i,
                       sigismember(&oldrc->rc_sigset, i),
                       sigismember(&newrc->rc_sigset, i)
                       );
            failed++;
        }
        if (oldrc->rc_sigaction_vec[i].sa_flags != newrc->rc_sigaction_vec[i].sa_flags){
            clixon_log(h, LOG_WARNING, "%s Plugin context %s %s: Changed flags of signal %s(%d) from 0x%x to 0x%x", __FUNCTION__,
                       name, fn, strsignal(i), i,
                       oldrc->rc_sigaction_vec[i].sa_flags,
                       newrc->rc_sigaction_vec[i].sa_flags);;
            failed++;
        }
        if (oldrc->rc_sigaction_vec[i].sa_sigaction != newrc->rc_sigaction_vec[i].sa_sigaction){
            clixon_log(h, LOG_WARNING, "%s Plugin context %s %s: Changed action of signal %s(%d) from %p to %p", __FUNCTION__,
                       name, fn, strsignal(i), i,
                       oldrc->rc_sigaction_vec[i].sa_sigaction,
                       newrc->rc_sigaction_vec[i].sa_sigaction);
            failed++;
        }
        /* Abort if option is 2 or above on failure
         */
        if (option > 1 && failed)
            abort();
    }
    if (failed)
        goto fail;
    retval = 1; /* OK */
 done:
    if (newrc)
        free(newrc);
    if (oldrc)
        free(oldrc);
    if (wh && *wh)
        *wh = NULL;
    return retval;
 fail:
    retval = 0;
    goto done;
}
