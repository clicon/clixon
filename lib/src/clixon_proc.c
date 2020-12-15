/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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
#include <sys/sysctl.h>
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

/*! Fork a child process, setup a pipe between parent and child.
 * Allowing parent to read the output of the child. 
 * @param[in]   doerr   If non-zero, stderr will be directed to the pipe as well. 
 * The pipe for the parent to write
 * to the child is closed and cannot be used.
 *
 * When child process is done with the pipe setup, execute the specified
 * command, execv(argv[0], argv).
 *
 * When parent is done with the pipe setup it will read output from the child
 * until eof. The read output will be sent to the specified output callback,
 * 'outcb' function.
 *
 * @param[in]  argv    NULL-terminated Argument vector
 * @param[in]  outcb
 * @param[in]  doerr
 * @retval     number  Matches (processes affected). 
 * @retval     -1      Error.
 */
int
clixon_proc_run(char **argv,
		void  (outcb)(char *), 
		int    doerr)
{
    int      retval = -1;
    char     buf[512];
    int      outfd[2] = { -1, -1 };
    int      n;
    int      status;
    pid_t    child;
    sigfn_t  oldhandler = NULL;
    sigset_t oset;
    int      sig = 0;
    
    if (argv == NULL){
	clicon_err(OE_UNIX, EINVAL, "argv is NULL");
	goto done;
    }
    if (pipe(outfd) == -1){
	clicon_err(OE_UNIX, errno, "pipe");
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

	close(outfd[0]);	/* Close unused read ends */
	outfd[0] = -1;

	/* Divert stdout and stderr to pipes */
	dup2(outfd[1], STDOUT_FILENO);
	if (doerr)
	  dup2(outfd[1], STDERR_FILENO);
	
	execvp(argv[0], argv);
	perror("execvp"); /* Shouldnt reach here */
	exit(-1);
    }

    /* Parent */

    /* Close unused write ends */
    close(outfd[1]);
    outfd[1] = -1;
    
    /* Read from pipe */
    while ((n = read(outfd[0], buf, sizeof(buf)-1)) != 0) {
	if (n < 0) {
	    if (errno == EINTR)
		continue;
	    break;
	}
	buf[n] = '\0';
	/* Pass read data to callback function is defined */
	if (outcb)
	    outcb(buf);
    }
    
    /* Wait for child to finish */
    if(waitpid(child, &status, 0) == child)
	retval = WEXITSTATUS(status);
 done:
    /* Clean up all pipes */
    if (outfd[0] != -1)
      close(outfd[0]);
    if (outfd[1] != -1)
      close(outfd[1]);
    if (sig){ 	/* Restore sigmask and fn */
	sigprocmask(SIG_SETMASK, &oset, NULL);
	set_signal(SIGINT, oldhandler, NULL);
    }
    return retval;
}

/*! Fork and exec a sub-process, let it run and return pid
 *
 * @param[in]  argv  NULL-terminated Argument vector
 * @param[in]  netns Network namespace (or NULL)
 * @param[out] pid
 * @retval     0     OK
 * @retval     -1    Error.
 * @see clixon_proc_daemon
 * @note SIGCHLD is set to IGN here. Maybe it should be done in main?
 */
int
clixon_proc_background(char **argv,
		       char  *netns,
		       pid_t *pid0)
{
    int           retval = -1;
    pid_t         child;
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
        char nsfile[PATH_MAX];
	int  nsfd;

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
	clicon_debug(1, "%s argv0:%s", __FUNCTION__, argv[0]);
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
    clicon_debug(1, "%s retval:%d child:%d", __FUNCTION__, retval, child);
    return retval;
}

/*! Double fork and exec a sub-process as a daemon, let it run and return pid
 *
 * @param[in]  argv  NULL-terminated Argument vector
 * @param[out] pid
 * @retval     0     OK
 * @retval     -1    Error.
 * @see clixon_proc_background
 */
int
clixon_proc_daemon(char **argv,
		   pid_t *pid0)
{
    int           retval = -1;
    int           status;
    pid_t         child;
    pid_t         pid;
    int           i;
    struct rlimit rlim = {0, };
    FILE         *fpid = NULL;

    if (argv == NULL){
	clicon_err(OE_UNIX, EINVAL, "argv is NULL");
	goto done;
    }
    if ((fpid = tmpfile()) == NULL){
	clicon_err(OE_UNIX, errno, "tmpfile");
	goto done;
    }
    if ((child = fork()) < 0) {
	clicon_err(OE_UNIX, errno, "fork");
	goto done;
    }
    if (child == 0)  { /* Child */
	clicon_signal_unblock(0);
	if ((pid = fork()) < 0) {
	    clicon_err(OE_UNIX, errno, "fork");
	    return -1;
	}
	if (pid == 0) { /* Grandchild,  create new session */
	    setsid();
	    if (chdir("/") < 0){
		clicon_err(OE_UNIX, errno, "chdirq");
		exit(1);
	    }
	    /* Close open descriptors */
	    if ( ! getrlimit(RLIMIT_NOFILE, &rlim))
		for (i = 0; i < rlim.rlim_cur; i++)
		    close(i);
	    if (execv(argv[0], argv) < 0) {
		clicon_err(OE_UNIX, errno, "execv");
		exit(1);
	    }
	    /* Not reached */
	}
	if (fprintf(fpid, "%ld\n", (long) pid) < 1){
	    clicon_err(OE_DAEMON, errno, "fprintf Could not write pid");
	    goto done;
	}
	fclose(fpid);
	//	waitpid(pid, &status2, 0);
	exit(pid);
    }

    if (waitpid(child, &status, 0) > 0){
	pidfile_get_fd(fpid, pid0);
	retval = 0;
    }
    fclose(fpid);
 done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    return retval;
}

/*--------------------------------------------------------------------------------*
 * Process management: start/stop registered processes for internal use
 */

/*
 * Types
 */
typedef struct {
    qelem_t   pe_qelem;   /* List header */
    char     *pe_name;    /* Name of process used for internal use */
    char     *pe_netns;   /* Network namespace */
    char    **pe_argv;    /* argv with command as element 0 and NULL-terminated */
    pid_t     pe_pid;
} process_entry_t;

/* List of process callback entries */
static process_entry_t *proc_entry_list = NULL;

/*! Register an internal process
 *
 * @param[in]  h       Clixon handle
 * @param[in]  name    Process name
 * @param[in]  netns   Namespace netspace (or NULL)
 * @param[in]  argv    NULL-terminated vector of vectors 
 * @retval     0       OK
 * @retval    -1       Error
 * @note name, netns, argv and its elements are all copied / re-alloced.
 */
int
clixon_process_register(clicon_handle h,
			const char   *name,
			const char   *netns,
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
proc_op_run(process_entry_t *pe,
	    int             *runp)
{
    int   retval = -1;
    int   run;
    pid_t pid;

    run = 0;
    if ((pid = pe->pe_pid) != 0){ /* if 0 stopped */
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

/*! Upgrade specific module identified by namespace, search matching callbacks
 *
 * @param[in]  h       clicon handle
 * @param[in]  name    Name of process
 * @param[in]  op      start, stop.
 * @param[out] status  true if process is running / false if not running on entry
 * @retval -1  Error
 * @retval  0  OK
 * @see upgrade_callback_reg_fn  which registers the callbacks
 */
int
clixon_process_operation(clicon_handle h,
			 char         *name,
			 char         *op,
			 int          *status)
{
    int              retval = -1;
    process_entry_t *pe;
    int              run;

    clicon_debug(1, "%s name:%s op:%s", __FUNCTION__, name, op);
    if (proc_entry_list == NULL)
	goto ok;
    pe = proc_entry_list;
    do {
	if (strcmp(pe->pe_name, name) == 0){
	    /* Check if running */
	    if (proc_op_run(pe, &run) < 0)
		goto done;
	    if (status) /* Store as output parameter */
		*status = run;
	    if (strcmp(op, "stop") == 0 ||
		strcmp(op, "restart") == 0){
		if (run)
		    pidfile_zapold(pe->pe_pid); /* Ensures its dead */
		pe->pe_pid = 0; /* mark as dead */
		run = 0;
	    }
	    if (strcmp(op, "start") == 0 ||
		strcmp(op, "restart") == 0){
		if (run == 1){
		    ; /* Already runs */
		}
		else{
		    if (clixon_proc_background(pe->pe_argv, pe->pe_netns, &pe->pe_pid) < 0)
			goto done;
		}
	    }
	    else if (strcmp(op, "status") == 0){
		; /* status already set */
	    }
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
