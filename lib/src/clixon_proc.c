/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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

 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <grp.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/param.h>
#include <sys/user.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/resource.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_sig.h"
#include "clixon_string.h"
#include "clixon_queue.h"
#include "clixon_chunk.h"
#include "clixon_proc.h"

/*
 * Macros
 */
#define signal_set_mask(set)	sigprocmask(SIG_SETMASK, (set), NULL)
#define signal_get_mask(set)	sigprocmask (0, NULL, (set))

/*
 * Child process ID
 * XXX Really shouldn't be a global variable
 */
static int _clicon_proc_child = 0;

/*
 * Make sure child is killed by ctrl-C
 */
static void
clicon_proc_sigint(int sig)
{
    if (_clicon_proc_child > 0)
	kill (_clicon_proc_child, SIGINT);
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
 * @retval  number    Matches (processes affected). 
 * @retval  -1        Error.
 */
int
clicon_proc_run (char  *cmd, 
		 void (outcb)(char *), 
		 int   doerr)
{
    char 
	**argv,
	buf[512];
    int
	outfd[2] = { -1, -1 };
    int
	n,
	argc,
	status,
	retval = -1;
    pid_t
	child;
    sigfn_t   oldhandler = NULL;
    sigset_t  oset;
    
    argv = clicon_sepsplit (cmd, " \t", &argc, __FUNCTION__);
    if (!argv)
	return -1;

    if (pipe (outfd) == -1)
      goto done;
    

    signal_get_mask(&oset);
    set_signal(SIGINT, clicon_proc_sigint, &oldhandler);


    if ((child = fork ()) < 0) {
	retval = -1;
	goto done;
    }

    if (child == 0) {	/* Child */

	/* Unblock all signals except TSTP */
	clicon_signal_unblock (0);
	signal (SIGTSTP, SIG_IGN);

	close (outfd[0]);	/* Close unused read ends */
	outfd[0] = -1;

	/* Divert stdout and stderr to pipes */
	dup2 (outfd[1], STDOUT_FILENO);
	if (doerr)
	  dup2 (outfd[1], STDERR_FILENO);
	
	execvp (argv[0], argv);
	perror("execvp");
	_exit(-1);
    }

    /* Parent */

    /* Close unused write ends */
    close (outfd[1]);
    outfd[1] = -1;
    
    /* Read from pipe */
    while ((n = read (outfd[0], buf, sizeof (buf)-1)) != 0) {
	if (n < 0) {
	    if (errno == EINTR)
		continue;
	    break;
	}
	buf[n] = '\0';
	/* Pass read data to callback function is defined */
	if (outcb)
	    outcb (buf);
    }
    
    /* Wait for child to finish */
    if(waitpid (child, &status, 0) == child)
	retval = WEXITSTATUS(status);
    else
	retval = -1;

 done:

    /* Clean up all pipes */
    if (outfd[0] != -1)
      close (outfd[0]);
    if (outfd[1] != -1)
      close (outfd[1]);

    /* Restore sigmask and fn */
    signal_set_mask (&oset);
    set_signal(SIGINT, oldhandler, NULL);

    unchunk_group (__FUNCTION__);
    return retval;
}

/*! Spawn command and report exit status
 */
int
clicon_proc_daemon (char *cmd)
{
    char 
	**argv;
    int
	i,
	argc,
	retval = -1,
	status, status2;
    pid_t
	child,
	pid;
    struct rlimit 
	rlim;

    argv = clicon_sepsplit (cmd, " \t", &argc, NULL);
    if (!argv)
	return -1;

    if ((child = fork ()) < 0) {
	clicon_err(OE_UNIX, errno, "fork");
	goto done;
    }
    
    if (child == 0)  { /* Child */

	clicon_signal_unblock (0);
	if ((pid = fork ()) < 0) {
	    clicon_err(OE_UNIX, errno, "fork");
	    return -1;
	    _exit(1);
	}
	if (pid == 0) { /* Grandchild,  create new session */
	    setsid();
	    if (chdir("/") < 0){
		clicon_err(OE_UNIX, errno, "chdirq");
		_exit(1);
	    }
	    /* Close open descriptors */
	    if ( ! getrlimit (RLIMIT_NOFILE, &rlim))
		for (i = 0; i < rlim.rlim_cur; i++)
		    close(i);
	    
	    if (execv (argv[0], argv) < 0) {
		clicon_err(OE_UNIX, errno, "execv");
		_exit(1);
	    }
	    /* Not reached */
	}
	
	waitpid (pid, &status2, 0);
	_exit(status2);
    
    }

    if (waitpid (child, &status, 0) > 0)
	retval = 0;

 done:
    unchunk_group(__FUNCTION__);
    return (retval);
}


/*! Translate group name to gid. Return -1 if error or not found.
 */
int
group_name2gid(char *name, gid_t *gid)
{
    char buf[1024]; 
    struct group  g0;
    struct group *gr = &g0;
    struct group *gtmp;
    
    gr = &g0; 
    /* This leaks memory in ubuntu */
    if (getgrnam_r(name, gr, buf, sizeof(buf), &gtmp) < 0){
	clicon_err(OE_UNIX, errno, "%s: getgrnam_r(%s): %s", 
		   __FUNCTION__, name, strerror(errno));
	return -1;
    }
    if (gtmp == NULL){
	clicon_err(OE_UNIX, 0, "%s: No such group: %s", __FUNCTION__, name);
	fprintf(stderr, "No such group %s\n", name);
	return -1;
    }
    if (gid)
	*gid = gr->gr_gid;
    return 0;
}
