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
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 */
#ifdef HAVE_CONFIG_H
#include "clicon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#define __USE_GNU /* strverscmp */
#include <string.h>
#include <errno.h>
#include <dirent.h>
#include <regex.h>
#include <pwd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <unistd.h>
#include <netinet/in.h>
 
/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clicon_err.h"
#include "clicon_queue.h"
#include "clicon_chunk.h"
#include "clicon_string.h"
#include "clicon_file.h"

/*
 * Resolve the real path of a given 'path', following symbolic links and '../'.
 * If 'path' relative, it will be resolved based on the currnt working 
 * directory 'cwd'. The response is a 2 entry vector of strings. The first 
 * entry is the resolved path and the second is the part of the path which 
 * actually exist.
 */
char **
clicon_realpath(const char *cwd, char *path, const char *label)
{
    char **ret = NULL;
    char *rest;
    char **vec, **vec2;
    int nvec, nvec2;
    char *p;
    char *rp = NULL;
    char *ptr;
    int i;
    struct passwd *pwd;
    char cwdbuf[PATH_MAX];

    /* Prepend 'cwd' if not absolute */
    if (path[0] == '/')
	p = path;
    else {
	if (cwd == NULL || strlen(cwd) == 0) 
	    cwd = getcwd(cwdbuf, sizeof(cwdbuf));
	else if (cwd[0] == '~') {
	    if((pwd = getpwuid(getuid())) == NULL)
		goto catch;
	    cwd = pwd->pw_dir;
	}
	p = chunk_sprintf(__FUNCTION__, "%s%s/%s",
			  (cwd[0]=='/' ? "" : "/"), cwd, path);
    }
    if (p == NULL)
	goto catch;

    /* Make a local copy of 'path' */
    if ((path = chunkdup(p, strlen(p)+1, __FUNCTION__)) == NULL)
	goto catch;

    /* Find the smallest portion of the path that exist and run realpath() */
    while(strlen(p) && ((rp = realpath(p, NULL)) == NULL)) {
	if((ptr = strrchr(p, '/')) == NULL)
	    break;
	*ptr = '\0';
    }
    if(rp == NULL)
	goto catch;
    
    /* Use the result of realpath() and the rest of 'path' untouched, to 
       form a new path */
    rest = path + strlen(p);
    ptr = chunk_sprintf(__FUNCTION__, "%s%s", rp, rest);
    p = ptr;
    
    /* Split path based on '/'. Loop through vector from the end and copy
       each  entry into a new vector, skipping '..' and it's previous directory
       as well as all '.' */
    vec = clicon_strsplit (p, "/", &nvec, __FUNCTION__);
    vec2 = chunk(nvec * sizeof(char *), __FUNCTION__);
    nvec2 = i = nvec;
    while(--i >= 0) {
	if(strcmp(vec[i], "..") == 0)
	    i--; /* Skip previous */
	else if(strcmp(vec[i], ".") == 0)
	    /* do nothing */ ;
	else 
	    vec2[--nvec2] = vec[i];
    }

    /* Create resulting vector */
    if ((ret = chunk(sizeof(char *) * 2, label)) != NULL) {
	if((ret[0] = clicon_strjoin(nvec-nvec2, &vec2[nvec2], "/", label)) == NULL) {
	    unchunk(ret); 
	    ret = NULL;
	}
	if ((ret[1] = chunkdup(rp, strlen(rp)+1, label)) == NULL) {
	    unchunk(ret[0]); 
	    unchunk(ret); 
	    ret = NULL;
	}
    }

catch:
    if(rp)
	free(rp);
    unchunk_group(__FUNCTION__);
    return ret;
}


/*
 * qsort function
 */
static int
clicon_file_dirent_sort(const void* arg1, const void* arg2)
{
    struct dirent *d1 = (struct dirent *)arg1;
    struct dirent *d2 = (struct dirent *)arg2;

#ifdef  HAVE_STRVERSCMP
    return strverscmp(d1->d_name, d2->d_name);     /* strverscmp specific GNU function */
#else /* HAVE_STRVERSCMP */ 
    return strcoll(d1->d_name, d2->d_name);
#endif /* HAVE_STRVERSCMP */
}


/*! Return sorted matching files from a directory
 * @param[in]  dir     Directory path 
 * @param[out] ent     Entries pointer, will be filled in with dir entries
 * @param[in]  regexp  Regexp filename matching 
 * @param[in]  type    File type matching, see stat(2) 
 * @param[in]  label   Clicon Chunk label for memory handling, unchunk after use
 *
 * @retval  n  Number of matching files in directory
 * @retval -1  Error
 *
 * @code
 *   char          *dir = "/root/fs";
 *   struct dirent *dp;
 *   if ((ndp = clicon_file_dirent(dir, &dp, "(.so)$", S_IFREG, __FUNCTION__)) < 0)
 *       return -1;
 *   for (i = 0; i < ndp; i++) 
 *       do something with dp[i].d_name;
 *   unchunk_group(__FUNCTION__);
 * @endcode
*/
int
clicon_file_dirent(const char     *dir,
		   struct dirent **ent,
		   const char     *regexp,	
		   mode_t          type, 	
		   const char     *label)
{
   DIR *dirp;
   int retval = -1;
   int res;
   int nent;
   char *filename;
   regex_t re;
   char errbuf[128];
   struct stat st;
   struct dirent dent;
   struct dirent *dresp;
   struct dirent *tmp;
   struct dirent *new = NULL;
   struct dirent *dvecp = NULL;

   *ent = NULL;
   nent = 0;

   if (regexp && (res = regcomp(&re, regexp, REG_EXTENDED)) != 0) {
       regerror(res, &re, errbuf, sizeof(errbuf));
       clicon_err(OE_DB, 0, "regcomp: %s", errbuf);
       return -1;
   }

   if ((dirp = opendir (dir)) == NULL) {
     if (errno == ENOENT) /* Dir does not exist -> return 0 matches */
       retval = 0;
     else
       clicon_err(OE_UNIX, errno, "opendir(%s)", dir);
     goto quit;
   }
   
   for (res = readdir_r (dirp, &dent, &dresp); dresp; res = readdir_r (dirp, &dent, &dresp)) {
       if (res != 0) {
	   clicon_err(OE_UNIX, 0, "readdir: %s", strerror(errno));
	   goto quit;
       }

       /* Filename matching */
       if (regexp) {
	   if (regexec(&re, dent.d_name, (size_t) 0, NULL, 0) != 0)
	       continue;
       }
       /* File type matching */
       if (type) {
	   if ((filename = chunk_sprintf(__FUNCTION__, "%s/%s", dir, dent.d_name)) == NULL) {
	       clicon_err(OE_UNIX, 0, "chunk: %s", strerror(errno));
	       goto quit;
	   }	
	   res = lstat (filename, &st);
	   unchunk (filename);
	   if (res != 0) {
	       clicon_err(OE_UNIX, 0, "lstat: %s", strerror(errno));
	       goto quit;
	   }
	   if ((type & st.st_mode) == 0)
	       continue;
       }
       
       if ((tmp = rechunk(new, (nent+1)*sizeof(*dvecp), label)) == NULL) {
	   clicon_err(OE_UNIX, 0, "chunk: %s", strerror(errno));
	   goto quit;
       }
       new = tmp;
       memcpy (&new[nent], &dent, sizeof(dent));
       nent++;

   } /* while */

   qsort((void *)new, nent, sizeof(*new), clicon_file_dirent_sort);
   *ent = new;
   retval = nent;

quit:
   if (dirp)
       closedir(dirp);
   if (regexp)
       regfree(&re);
   unchunk_group(__FUNCTION__);

   return retval;
}

/*
 * Use mkstep() to create an empty temporary file, accessible only by this user. 
 * A chunk:ed file name is returned so that caller can overwrite file safely.
 */ 
char *
clicon_tmpfile(const char *label)
{
  int fd;
  char file[] = "/tmp/.tmpXXXXXX";

  if ((fd = mkstemp(file)) < 0){
	clicon_err(OE_UNIX, errno, "mkstemp");
	return NULL;
  }
  close(fd);

  return (char *)chunkdup(file, strlen(file)+1, label);
}

/*
 * Make a copy of file src
 * On error returns -1 and sets errno.
 */
int
file_cp(char *src, char *target)
{
    int inF = 0, ouF = 0;
    int err = 0;
    char line[512];
    int bytes;
    struct stat st;
    int retval = -1;

    if (stat(src, &st) != 0)
	return -1;
    if((inF = open(src, O_RDONLY)) == -1) 
	return -1;
    if((ouF = open(target, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode)) == -1) {
	err = errno;
	goto error;
    }
    while((bytes = read(inF, line, sizeof(line))) > 0)
	if (write(ouF, line, bytes) < 0){
	    err = errno;
	    goto error;
	}
    retval = 0;
  error:
    close(inF);
    if (ouF)
	close(ouF);
    if (retval < 0)
	errno = err;
    return retval;
}


#ifdef NOTUSED
/*
 * (un)lock a whole file. 
 * Arguments:
 *   fd	       - File descriptor
 *   cmd       - F_GETLK, F_SETLK, F_SETLKW
 *   type      - F_RDLCK, F_WRLCK, F_UNLCK
 */
int
file_lock(int fd, int cmd, int type)
{
    struct flock lock;

    lock.l_type = type;
    lock.l_whence = SEEK_SET;
    lock.l_start = 0;
    lock.l_len = 0;

    return fcntl(fd, cmd, &lock);	
}
#endif
