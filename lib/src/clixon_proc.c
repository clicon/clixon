/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

  * Processes daemons
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
#ifdef HAVE_SETNS /* linux network namespaces */
#include <sched.h> /* setns / unshare */
#endif
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/param.h>
#include <sys/user.h>
#include <sys/time.h>
#include <sys/resource.h>

#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_event.h"
#include "clixon_sig.h"
#include "clixon_string.h"
#include "clixon_queue.h"
#include "clixon_proc.h"

/*
 * Types
 */

/* Process entry list */
struct process_entry_t {
    qelem_t        pe_qelem;     /* List header */
    char          *pe_name;     /* Name of process used for internal use. Unique with exiting=0 */
    char          *pe_netns;    /* Network namespace */
    char         **pe_argv;     /* argv with command as element 0 and NULL-terminated */
    int            pe_argc;     /* Length of argc */
    pid_t          pe_pid;      /* Running process id (state) or 0 if dead (pid is set if exiting=1) */
    int            pe_exiting;  /* If set process is in the process of dying needs reaping */
    int            pe_clone;    /* Duplicate when restarting, delete when reaped */
    pid_t          pe_status;   /* Status on exit as defined in waitpid */
    proc_operation pe_op;       /* Operation pending? */
    proc_cb_t     *pe_callback; /* Wrapper function, may be called from process_operation  */
};

static void
clixon_proc_sigint(int sig)
{
    /* XXX does nothing */
}

/*! Fork a child, exec a child and setup socket to child and return to caller
 * @param[in]  argv    NULL-terminated Argument vector
 * @param[in]  doerr   If non-zero, stderr will be directed to the pipe as well. 
 * @param[out] s       Socket
 * @retval     O       OK
 * @retval     -1      Error.
 * @see clixon_proc_socket_close  close sockets, kill child and wait for child termination
 */
int
clixon_proc_socket(char **argv,
		   pid_t *pid,
		   int   *sock)
{
    int      retval = -1;
    int      sp[2] = {-1, -1};
    pid_t    child;
    sigfn_t  oldhandler = NULL;
    sigset_t oset;
    int      sig = 0;
    
    if (argv == NULL){
	clicon_err(OE_UNIX, EINVAL, "argv is NULL");
	goto done;
    }
    if (socketpair(AF_UNIX, SOCK_DGRAM|SOCK_CLOEXEC, 0, sp) < 0){
	clicon_err(OE_UNIX, errno, "socketpair");
	goto done;
    }
    sigprocmask(0, NULL, &oset);
    set_signal(SIGINT, clixon_proc_sigint, &oldhandler);
    sig++;
    if ((child = fork()) < 0) {
	clicon_err(OE_UNIX, errno, "fork");
	goto done;
    }
    if (child == 0) {	/* Child */
	/* Unblock all signals except TSTP */
	clicon_signal_unblock(0);
	signal(SIGTSTP, SIG_IGN);

	close(sp[0]);
	close(0);
	if (dup2(sp[1], STDIN_FILENO) < 0){
	    perror("dup2");
	    return -1;
	}
	close(1);
	if (dup2(sp[1], STDOUT_FILENO) < 0){
	    perror("dup2");
	    return -1;
	}
	close(sp[1]); 
	
	if (execvp(argv[0], argv) < 0){
	    perror("execvp");
	    return -1;
	}
	exit(-1); 	 /* Shouldnt reach here */
    }
    /* Parent */
    close(sp[1]);
    *pid = child;
    *sock = sp[0];
    retval = 0;
 done:
    if (sig){ 	/* Restore sigmask and fn */
	sigprocmask(SIG_SETMASK, &oset, NULL);
	set_signal(SIGINT, oldhandler, NULL);
    }
    return retval;
}

/*! 
 * @see clixon_proc_socket which creates the child and sockets closed and killed here
 */
int
clixon_proc_socket_close(pid_t pid,
			 int   sock)
{
    int retval = -1;
    int status;

    if (sock != -1)
	close(sock); /* usually kills */
    kill(pid, SIGTERM);
    //    usleep(100000);     /* Wait for child to finish */
    if(waitpid(pid, &status, 0) == pid)
	retval = WEXITSTATUS(status);
    return retval;
}

/*! Fork and exec a sub-process, let it run and return pid
 *
 * @param[in]  argv  NULL-terminated Argument vector
 * @param[in]  netns Network namespace (or NULL)
 * @param[out] pid   Process id
 * @retval     0     OK
 * @retval     -1    Error.
 */
int
clixon_proc_background(char       **argv,
		       const char  *netns,
		       pid_t       *pid0)
{
    int           retval = -1;
    pid_t         child = 0;
    int           i;
    sigfn_t       oldhandler = NULL;
    sigset_t      oset;
    struct rlimit rlim = {0, };

    clicon_debug(1, "%s", __FUNCTION__);
    if (argv == NULL){
	clicon_err(OE_UNIX, EINVAL, "argv is NULL");
	goto quit;
    }
    /* Before here call quit on error */
    sigprocmask(0, NULL, &oset);
    set_signal(SIGINT, clixon_proc_sigint, &oldhandler);
    /* Now call done on error */
    
    if ((child = fork()) < 0) {
	clicon_err(OE_UNIX, errno, "fork");
	goto done;
    }
    if (child == 0)  { /* Child */
#ifdef HAVE_SETNS
        char nsfile[PATH_MAX];
	int  nsfd;
#endif

	clicon_debug(1, "%s child", __FUNCTION__);
	clicon_signal_unblock(0);
	signal(SIGTSTP, SIG_IGN);
	if (chdir("/") < 0){
	    clicon_err(OE_UNIX, errno, "chdirq");
	    exit(1);
	}
	/* Close open descriptors */
	if ( ! getrlimit(RLIMIT_NOFILE, &rlim))
	    for (i = 0; i < rlim.rlim_cur; i++)
		close(i);
#ifdef HAVE_SETNS /* linux network namespaces */
	/* If network namespace is defined, let child join it 
	 * XXX: this is work-in-progress
	 */
	if (netns != NULL) {
	    snprintf(nsfile, PATH_MAX, "/var/run/netns/%s", netns); /* see man setns / ip netns */
	    clicon_debug(1, "%s nsfile:%s", __FUNCTION__, nsfile);
	    /* Change network namespace */
	    if ((nsfd = open(nsfile, O_RDONLY | O_CLOEXEC)) < 0){
		clicon_err(OE_UNIX, errno, "open");
		exit(1);
	    }
	    if (setns(nsfd, 0) < 0){       /* Join that namespace */
		clicon_err(OE_UNIX, errno, "setns");
		exit(1);
	    }
	    close(nsfd);
	    if (unshare(CLONE_NEWNS) < 0){
		clicon_err(OE_UNIX, errno, "unshare");
		exit(1);
	    }
	}
#endif /* HAVE_SETNS */
	if (execv(argv[0], argv) < 0) {
	    clicon_err(OE_UNIX, errno, "execv");
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
    clicon_debug(1, "%s retval:%d child:%u", __FUNCTION__, retval, child);
    return retval;
}

/*--------------------------------------------------------------------------------*
 * Process management: start/stop registered processes for internal use
 */

/* Process operations
 */
static const map_str2int proc_operation_map[] = {
    {"none",                  PROC_OP_NONE},
    {"start",                 PROC_OP_START},
    {"stop",                  PROC_OP_STOP},
    {"restart",               PROC_OP_RESTART},
    {"status",                PROC_OP_STATUS},
    {NULL,                    -1}
};

/* List of process callback entries XXX move to handle */
static process_entry_t *_proc_entry_list = NULL;

proc_operation
clixon_process_op_str2int(char *opstr)
{
    return clicon_str2int(proc_operation_map, opstr);
}

/*! Make a copy of process-entry struct */
static int
clixon_process_register_dup(process_entry_t  *pe0,
			    process_entry_t **pnew)
{
    int              retval = -1;
    process_entry_t *pe1 = NULL;
    int              i;
    
    if (pe0 == NULL){
	clicon_err(OE_DB, EINVAL, "pe0 is NULL");
	goto done;
    }
    if (pnew == NULL){
	clicon_err(OE_DB, EINVAL, "pnew is NULL");
	goto done;
    }
    if ((pe1 = malloc(sizeof(process_entry_t))) == NULL) {
	clicon_err(OE_DB, errno, "malloc");
	goto done;
    }
    memset(pe1, 0, sizeof(*pe1));
    memcpy(pe1, pe0, sizeof(process_entry_t)); /* Note lots of malloced memory that needs to be handled after this copy*/
    pe1->pe_exiting = 0;
    pe1->pe_clone = 0;
    if ((pe1->pe_name = strdup(pe0->pe_name)) == NULL){
	clicon_err(OE_DB, errno, "strdup name");
	goto done;
    }
    if (pe0->pe_netns && (pe1->pe_netns = strdup(pe0->pe_netns)) == NULL){
	clicon_err(OE_DB, errno, "strdup netns");
	goto done;
    }
    if ((pe1->pe_argv = calloc(pe0->pe_argc, sizeof(char *))) == NULL){
	clicon_err(OE_UNIX, errno, "calloc");
	goto done;
    }
    for (i=0; i<pe0->pe_argc; i++){
	if (pe0->pe_argv[i] != NULL &&
	    (pe1->pe_argv[i] = strdup(pe0->pe_argv[i])) == NULL){
	    clicon_err(OE_UNIX, errno, "strdup");
	    goto done;
	}
    }
    ADDQ(pe1, _proc_entry_list);
    *pnew = pe1;
    retval = 0;
 done:
    /* dealloc pe1 on error */
    return retval;
}

/*! Register an internal process
 *
 * @param[in]  h        Clixon handle
 * @param[in]  name     Process name
 * @param[in]  netns    Namespace netspace (or NULL)
 * @param[in]  callback
 * @param[in]  argv     NULL-terminated vector of vectors 
 * @param[in]  argc     Length of argv
 * @retval     0        OK
 * @retval    -1        Error
 * @note name, netns, argv and its elements are all copied / re-alloced.
 */
int
clixon_process_register(clicon_handle h,
			const char   *name,
			const char   *netns,
			proc_cb_t    *callback,
		        char        **argv,
			int           argc)
{
    int              retval = -1;
    process_entry_t *pe = NULL;
    int              i;
	
    if (name == NULL){
	clicon_err(OE_DB, EINVAL, "name is NULL");
	goto done;
    }
    if (argv == NULL){
	clicon_err(OE_DB, EINVAL, "argv is NULL");
	goto done;
    }
    if ((pe = malloc(sizeof(process_entry_t))) == NULL) {
	clicon_err(OE_DB, errno, "malloc");
	goto done;
    }
    memset(pe, 0, sizeof(*pe));
    if ((pe->pe_name = strdup(name)) == NULL){
	clicon_err(OE_DB, errno, "strdup name");
	goto done;
    }
    if (netns && (pe->pe_netns = strdup(netns)) == NULL){
	clicon_err(OE_DB, errno, "strdup netns");
	goto done;
    }
    pe->pe_argc = argc;
    if ((pe->pe_argv = calloc(argc, sizeof(char *))) == NULL){
	clicon_err(OE_UNIX, errno, "calloc");
	goto done;
    }
    for (i=0; i<argc; i++){
	if (argv[i] != NULL &&
	    (pe->pe_argv[i] = strdup(argv[i])) == NULL){
	    clicon_err(OE_UNIX, errno, "strdup");
	    goto done;
	}
    }
    pe->pe_callback = callback;
    ADDQ(pe, _proc_entry_list);
    retval = 0;
 done:
    return retval;
}

static int
clixon_process_delete_only(process_entry_t *pe)
{
    char           **pa;

    if (pe->pe_name)
	free(pe->pe_name);
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
clixon_process_delete_all(clicon_handle h)
{
    process_entry_t *pe;

    while((pe = _proc_entry_list) != NULL) {
	DELQ(pe, _proc_entry_list, process_entry_t *);
	clixon_process_delete_only(pe);
    }
    return 0;
}

/*!
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
	    if (errno == ESRCH){
		run = 0;
	    }
	    else{
		clicon_err(OE_UNIX, errno, "kill(%d)", pid);
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

/*! Find process operation entry given name and op and perform operation if found
 *
 * @param[in]  h       clicon handle
 * @param[in]  name    Name of process
 * @param[in]  op      start, stop, restart, status
 * @param[in]  wrapit  If set, call potential callback, if false, dont call it
 * @param[out] pid     >0 process# and is running / 0: not running 
 * @retval -1  Error
 * @retval  0  OK
 * @see upgrade_callback_reg_fn  which registers the callbacks
 * @note operations are not made directly but postponed by a scheduling the actions.
 *       This is not really necessary for all operations (like start) but made for all
 *       for reducing complexity of code.
 * @see clixon_process_sched where operations are actually executed
 */
int
clixon_process_operation(clicon_handle  h,
			 const char    *name,
			 proc_operation op,
			 int            wrapit,
			 uint32_t      *pid)
{
    int              retval = -1;
    process_entry_t *pe;
    int              sched = 0; /* If set, process action should be scheduled, register a timeout */

    clicon_debug(1, "%s name:%s op:%s", __FUNCTION__, name, clicon_int2str(proc_operation_map, op));
    if (_proc_entry_list == NULL)
	goto ok;
    pe = _proc_entry_list;
    do {
	if (strcmp(pe->pe_name, name) == 0){
	    if (op == PROC_OP_STATUS){
		if (pe->pe_clone)
		    continue; /* this may be a dying duplicate */
		if (pid)
		    *pid = pe->pe_pid;
	    }
	    else {
		/* Call wrapper function that eg changes op based on config */
		if (wrapit && pe->pe_callback != NULL)
		    if (pe->pe_callback(h, pe, &op) < 0)
			goto done;
		clicon_debug(1, "%s name: %s pid:%d op: %s", __FUNCTION__,
			     name, pe->pe_pid, clicon_int2str(proc_operation_map, op));
		if (op == PROC_OP_START || op == PROC_OP_STOP || op == PROC_OP_RESTART){
		    pe->pe_op = op;
		    clicon_debug(1, "%s scheduling %s pid:%d", __FUNCTION__, name, pe->pe_pid);
		    sched++;
		}

	    }
	    break; 	    /* hit break here */
	}
	pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);
    if (sched && clixon_process_sched_register(h) < 0)
	goto done;
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Go through process list and start all processes that are enabled via config wrap function
 * @param[in]  h   Clixon handle
 * Commit rules should have done this, but there are some cases such as backend -s none mode
 * where commits are not made.
 */
int
clixon_process_start_all(clicon_handle h)
{
    int              retval = -1;
    process_entry_t *pe;
    proc_operation   op;
    int              sched = 0; /* If set, process action should be scheduled, register a timeout */

    clicon_debug(1, "%s",__FUNCTION__);
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
	    pe->pe_op = op;
	    sched++;
	}
	pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);
    if (sched && clixon_process_sched_register(h) < 0)
	goto done;
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Traverse all processes and check pending start/stop/restarts
 * @param[in]  h   Clixon handle
 * Typical cases where postponing process start/stop is necessary:
 * (1) at startup, if started before deamoninization, process will get as child of 1
 * (2) edit changes or rpc restart especially of restconf where you may saw of your arm and terminate
 *     return socket.
 * A special complexity is restarting processes, where the old is killed, but state must be kept until it is reaped
 * @see clixon_process_waitpid where killed/restarted processes are "reaped"
 */
static int
clixon_process_sched(int           fd,
		     clicon_handle h)
{
    int              retval = -1;
    process_entry_t *pe;
    process_entry_t *pe1;
    proc_operation   op;
    pid_t            newpid;
    int              run;

    clicon_debug(1, "%s",__FUNCTION__);
    if (_proc_entry_list == NULL)
	goto ok;
    pe = _proc_entry_list;
    do {
	clicon_debug(1, "%s name: %s pid:%d op: %s", __FUNCTION__,
		     pe->pe_name, pe->pe_pid, clicon_int2str(proc_operation_map, pe->pe_op));
	/* Execute pending operations and not already exiting */
	if ((op = pe->pe_op) != PROC_OP_NONE &&
	    pe->pe_exiting == 0){
	    /* Check if running */
	    run = 0;
	    clicon_debug(1, "%s run: %d", __FUNCTION__, run);
	    if (proc_op_run(pe->pe_pid, &run) < 0)
		goto done;
	    switch (op){
	    case PROC_OP_STOP:
		clicon_debug(1, "%s stop pid:%d", __FUNCTION__, pe->pe_pid);
	    case PROC_OP_RESTART:
		if (run){
		    clicon_log(LOG_NOTICE, "Killing old process %s with pid: %d", pe->pe_name, pe->pe_pid);
		    kill(pe->pe_pid, SIGTERM);
		    /* Cant wait here because it would block the backend and terminating may involve
		     * some protocol handling, instead SIGCHLD is receoved and 
		     * clixon_process_waitpid is called that for waits/reaps the dead process */
		    pe->pe_exiting = 1;
		}
		if (op == PROC_OP_STOP)
		    break;
		if (clixon_proc_background(pe->pe_argv, pe->pe_netns, &newpid) < 0)
		    goto done;
		clicon_debug(1, "%s restart pid:%d -> %d", __FUNCTION__, pe->pe_pid, newpid);
		/* Create a new pe */
		if (clixon_process_register_dup(pe, &pe1) < 0)
		    goto done;
		pe->pe_clone = 1; /* Delete when reaped */
		pe1->pe_op = PROC_OP_NONE; /* Dont restart again */
		pe1->pe_pid = newpid;
		break;
	    case PROC_OP_START:
		if (run) /* Already runs */
		    break;
		if (clixon_proc_background(pe->pe_argv, pe->pe_netns, &pe->pe_pid) < 0)
		    goto done;
		clicon_debug(1, "%s started pid:%d", __FUNCTION__, pe->pe_pid);
		break;
	    default:
		break;
	    }
	}
	pe->pe_op = PROC_OP_NONE;
	pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Register scheduling of process start/stop/restart
 * After a delay t1, schedule the process
 * @note The delay is for mitigating a race condition if a process is restarted that is used in the 
 * session restarting it. In this way, the process "should have" time to exit.
 * However, for slow machines, this delay may need to be longer.
 * On a Raspberry pi it was measured to need be 1.5ms.
 * However, if it is much longer, it may kill restconf as an unrelated session has been opened.
 */
int
clixon_process_sched_register(clicon_handle h)
{
    int            retval = -1;
    struct timeval t;
    struct timeval t1 = {0, 1500}; /* See discussion ^*/

    clicon_debug(2, "%s", __FUNCTION__);
    gettimeofday(&t, NULL);
    timeradd(&t, &t1, &t);
    if (clixon_event_reg_timeout(t, clixon_process_sched, h, "process") < 0)
	goto done;
    retval = 0;
 done:
    clicon_debug(2, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Go through processes and wait for child processes
 * Typically we know a child has been killed by SIGCHLD, but we do not know which process it is
 * Traverse all known processes and reap them, eg call waitpid() to avoid zombies.
 * @param[in]  h  Clixon handle
 */
int
clixon_process_waitpid(clicon_handle h)
{
    int              retval = -1;
    process_entry_t *pe;
    int              status = 0;
    pid_t            wpid;

    clicon_debug(1, "%s", __FUNCTION__);
    pe = _proc_entry_list;
    do {
	if (pe->pe_pid != 0){
	    clicon_debug(1, "%s waitpid(%d)", __FUNCTION__, pe->pe_pid);
	    if ((wpid = waitpid(pe->pe_pid, &status, WNOHANG)) == pe->pe_pid){
		clicon_debug(1, "%s waitpid(%d) waited", __FUNCTION__, pe->pe_pid);
		pe->pe_exiting = 0;
		pe->pe_pid = 0;       /* mark as dead */
		pe->pe_status = status;   
		if (pe->pe_clone){
		    /* Delete it */
		    DELQ(pe, _proc_entry_list, process_entry_t *);
		    clixon_process_delete_only(pe);
		}
		break; /* pid is unique */
	    }
	    else
		clicon_debug(1, "%s waitpid(%d) nomatch:%d", __FUNCTION__, pe->pe_pid, wpid);
	}
    	pe = NEXTQ(process_entry_t *, pe);
    } while (pe != _proc_entry_list);
    retval = 0;
    // done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}
