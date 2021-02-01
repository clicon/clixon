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
#include "clixon_sig.h"
#include "clixon_string.h"
#include "clixon_queue.h"
#include "clixon_proc.h"

/*
 * Types
 */
/* Process entry list */
struct process_entry_t {
    qelem_t    pe_qelem;   /* List header */
    char      *pe_name;    /* Name of process used for internal use */
    char      *pe_netns;   /* Network namespace */
    char     **pe_argv;    /* argv with command as element 0 and NULL-terminated */
    pid_t      pe_pid;     /* Running process id (state) or 0 if dead */
    proc_cb_t *pe_callback; /* Wrapper function, may be called from process_operation  */
};

/*
 * Child process ID
 * XXX Really shouldn't be a global variable
 */
static int _clicon_proc_child = 0;

/*
 * Make sure child is killed by ctrl-C
 */
static void
clixon_proc_sigint(int sig)
{
    if (_clicon_proc_child > 0)
	kill(_clicon_proc_child, SIGINT);
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
 * @param[out] pid
 * @retval     0     OK
 * @retval     -1    Error.
 * @note SIGCHLD is set to IGN here. Maybe it should be done in main?
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

    clicon_debug(1, "%s netns:%s", __FUNCTION__, netns);
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
    /* Ensure reap proc child in same session */
    if (set_signal(SIGCHLD, SIG_IGN, NULL) < 0)
	goto quit;
    *pid0 = child;
    retval = 0;
 quit:
    clicon_debug(1, "%s retval:%d child:%u", __FUNCTION__, retval, child);
    return retval;
}

/*--------------------------------------------------------------------------------*
 * Process management: start/stop registered processes for internal use
 */

/*
 * Types
 */

/* List of process callback entries */
static process_entry_t *proc_entry_list = NULL;

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
    if ((pe->pe_argv = calloc(argc, sizeof(char *))) == NULL){
	clicon_err(OE_UNIX, errno, "calloc");
	goto done;
    }
    for (i=0; i<argc; i++){
	if (argv[i] != NULL &&
	    (pe->pe_argv[i] = strdup(argv[i])) == NULL){
	    clicon_err(OE_UNIX, errno, "strdup");
	}
    }
    pe->pe_callback = callback;
    ADDQ(pe, proc_entry_list);
    retval = 0;
 done:
    return retval;
}

/*! Delete all Upgrade callbacks
 */
int
clixon_process_delete_all(clicon_handle h)
{
    process_entry_t *pe;
    char           **pa;

    while((pe = proc_entry_list) != NULL) {
	DELQ(pe, proc_entry_list, process_entry_t *);
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
    }
    return 0;
}

static int
proc_op_run(pid_t pid0,
	    int  *runp)
{
    int   retval = -1;
    int   run;
    pid_t pid;

    run = 0;
    if ((pid = pid0) != 0){ /* if 0 stopped */
	/* Check if lives */
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

/*! Perform process operation
 *
 */
static int
clixon_process_operation_one(const char *op,
			     const char *netns,
			     char      **argv,
			     pid_t      *pidp)
{
    int retval = -1;
    int run = 0;
    
    /* Check if running */
    if (proc_op_run(*pidp, &run) < 0)
	goto done;
    if (strcmp(op, "stop") == 0 ||
	strcmp(op, "restart") == 0){
	if (run)
	    pidfile_zapold(*pidp); /* Ensures its dead */
	*pidp = 0; /* mark as dead */
	run = 0;
    }
    if (strcmp(op, "start") == 0 ||
	strcmp(op, "restart") == 0){
	if (run == 1){
	    ; /* Already runs */
	}
	else{
	    if (clixon_proc_background(argv, netns, pidp) < 0)
		goto done;
	}
    }
    else if (strcmp(op, "status") == 0){
	; /* status already set */
    }

    retval = 0;
 done:
    return retval;
}

/*! Find process operation entry given name and op and perform operation if found
 *
 * @param[in]  h       clicon handle
 * @param[in]  name    Name of process
 * @param[in]  op      start, stop.
 * @param[in]  wrapit  If set, call potential callback, if false, dont call it
 * @param[out] status  true if process is running / false if not running on entry
 * @retval -1  Error
 * @retval  0  OK
 * @see upgrade_callback_reg_fn  which registers the callbacks
 */
int
clixon_process_operation(clicon_handle h,
			 const char   *name,
			 char         *op,
			 int           wrapit,
			 uint32_t     *pid)
{
    int              retval = -1;
    process_entry_t *pe;

    clicon_debug(1, "%s name:%s op:%s", __FUNCTION__, name, op);
    if (proc_entry_list == NULL)
	goto ok;
    pe = proc_entry_list;
    do {
	if (strcmp(pe->pe_name, name) == 0){
	    /* Call wrapper function that eg changes op based on config */
	    if (wrapit && pe->pe_callback != NULL)
		if (pe->pe_callback(h, pe, &op) < 0)
		    goto done;
	    if (clixon_process_operation_one(op, pe->pe_netns, pe->pe_argv, &pe->pe_pid) < 0)
		goto done;
	    if (pid)
		*pid = pe->pe_pid;
	    break; 	    /* hit break here */
	}
	pe = NEXTQ(process_entry_t *, pe);
    } while (pe != proc_entry_list);
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*! Start all processes that are enabled
 * @param[in]  h   Clixon handle
 * Commit rules should have done this, but there are some cases such as backend -s none mode
 * where commits are not made.
 */
int
clixon_process_start_all(clicon_handle h)
{
    int              retval = -1;
    process_entry_t *pe;
    char            *op;

    clicon_debug(1, "%s",__FUNCTION__);
    if (proc_entry_list == NULL)
	goto ok;
    pe = proc_entry_list;
    do {
	op = "start";
	/* Call wrapper function that eg changes op based on config */
	if (pe->pe_callback != NULL)
	    if (pe->pe_callback(h, pe, &op) < 0)
		goto done;
	if (strcmp(op, "start") == 0)
	    if (clixon_process_operation_one("start", pe->pe_netns, pe->pe_argv, &pe->pe_pid) < 0)
		goto done;
	pe = NEXTQ(process_entry_t *, pe);
    } while (pe != proc_entry_list);
 ok:
    retval = 0;
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}
