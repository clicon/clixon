/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 */

#ifdef HAVE_CONFIG_H
#include "clicon_config.h"
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
#include "clicon_err.h"
#include "clicon_log.h"
#include "clicon_sig.h"
#include "clicon_string.h"
#include "clicon_queue.h"
#include "clicon_chunk.h"
#include "clicon_proc.h"

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

/*
 * Fork a child process, setup a pipe between parent and child, allowing 
 * parent to read the output of the child. If 'doerr' is non-zero, stderr
 * will be directed to the pipe as well. The pipe for the parent to write
 * to the child is closed and cannot be used.
 *
 * When child process is done with the pipe setup, execute the specified
 * command, execv(argv[0], argv).
 *
 * When parent is done with the pipe setup it will read output from the child
 * until eof. The read output will be sent to the specified output callback,
 * 'outcb' function.
 *
 * Return number of matches (processes affected). -1 on error.
 */
int
clicon_proc_run (char *cmd, void (outcb)(char *), int doerr)
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


/*
 * Spawm command and report exit status
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


#ifdef moved_to_osr
#ifdef linux
/*
 * Send 'sig' (if not 0) to all processes matching 'name'.
 * Return the number of matches.
 */
int
clicon_proc_killbyname (const char *name, int sig)
{
  /* XXXX FIXME. Should scan /proc/<pid>/status */
  char buf[512];
  snprintf (buf, sizeof (buf)-1, "pkill -%d %s", sig, name);

  return clicon_proc_run (buf, NULL, 0);
}
#endif /* Linux */


#ifdef BSD
/*
 * Send 'sig' (if not 0) to all processes matching 'name'.
 * Return the number of matches.
 */
int
clicon_proc_killbyname (const char *name, int sig)
{
	int
		i,
		nproc,
		nmatch,
		mib[3];
	size_t
		size;
	struct proc
		*p;
	struct kinfo_proc
		*kp = NULL;

	mib[0] = CTL_KERN;
	mib[1] = KERN_NPROCS; /* KERN_MACPROC, KERN_PROC */
	size = sizeof (nproc);
	if (sysctl(mib, 2, &nproc, &size, NULL, 0) < 0)
		return -1;

	size = nproc * sizeof(struct kinfo_proc);
	kp = chunk(size * sizeof(char), "bsdkill");
	if (kp == NULL)
		goto error;

	mib[1] = KERN_PROC;
	mib[2] = KERN_PROC_ALL;
	
	if (sysctl(mib, 3, kp, &size, NULL, 0) < 0)
		goto error;
	
	nproc = size / sizeof(struct kinfo_proc);
	for (nmatch = i = 0; i < nproc; i++) {
		p = (struct proc *)&kp[i].kp_proc;
		if (!strcmp (name, p->p_comm)) {
			nmatch++;
			kill (p->p_pid, sig);
		}
	}

	unchunk (kp);
	return nmatch;

 error:
	if (kp)
		unchunk (kp);
	return -1;
}
#endif /* BSD */
#endif

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
