/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren
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

 *
 */
#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <dirent.h>
#include <regex.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <unistd.h>
#include <netinet/in.h>
#include <stddef.h>

/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_queue.h"
#include "clixon_string.h"
#include "clixon_log.h"
#include "clixon_file.h"

/*! qsort "compar" for directory alphabetically sorting, see qsort(3)
 */
static int
clicon_file_dirent_sort(const void* arg1, 
			const void* arg2)
{
    struct dirent *d1 = (struct dirent *)arg1;
    struct dirent *d2 = (struct dirent *)arg2;

    return strcoll(d1->d_name, d2->d_name);
}

/*!
 * @param[in,out] cvv  On the format: (name, path)*
 */
static int
clicon_files_recursive1(const char *dir,
			regex_t    *re,
			cvec       *cvv)
{
    int retval = -1;
    struct  dirent *dent = NULL;
    char    path[MAXPATHLEN];
    DIR     *dirp = NULL;
    int     res = 0;
    struct stat    st;
    
    if (dir == NULL){
	clicon_err(OE_UNIX, EINVAL, "Requires dir != NULL");
	goto done;
    }
    if ((dirp = opendir(dir)) != NULL)
	while ((dent = readdir(dirp)) != NULL) {
	    if (dent->d_type == DT_DIR) {
		/* If we find a directory we might want to enter it, unless it
		   is the current directory (.) or parent (..) */
		if (strcmp(dent->d_name, ".") == 0 || strcmp(dent->d_name, "..") == 0) 
		    continue;

		/* Build the new directory and enter it. */
		sprintf(path, "%s/%s", dir, dent->d_name);
		if (clicon_files_recursive1(path, re, cvv) < 0)
		    goto done;
	    }
	    else if (dent->d_type == DT_REG) {
		/* If we encounter a file, match it against the regexp and
		   add it to the list of found files.*/
		if (re != NULL &&
		    regexec(re, dent->d_name, (size_t)0, NULL, 0) != 0)
		    continue;
		snprintf(path, MAXPATHLEN-1, "%s/%s", dir, dent->d_name);
		if ((res = lstat(path, &st)) != 0){
		    clicon_err(OE_UNIX, errno, "lstat");
		    goto done;
		}
		if ((st.st_mode & S_IFREG) == 0)
		    continue;
		if (cvec_add_string(cvv, dent->d_name, path) < 0){
		    clicon_err(OE_UNIX, errno, "cvec_add_string");
		    goto done;
		}
	    }
	}
    retval = 0;
 done:
    if (dirp)
        closedir(dirp);
    return retval;
}

/*! Find files recursively according to a regexp
 */
int
clicon_files_recursive(const char *dir,
                       const char *regexp,
		       cvec       *cvv)
{
    int     retval = -1;
    regex_t re = {0,};
    int     res = 0;
    char    errbuf[128];
 
    clicon_debug(2, "%s dir:%s", __FUNCTION__, dir);
    if (regexp && (res = regcomp(&re, regexp, REG_EXTENDED)) != 0) {
        regerror(res, &re, errbuf, sizeof(errbuf));
        clicon_err(OE_DB, 0, "regcomp: %s", errbuf);
	goto done;
    }
    if (clicon_files_recursive1(dir, &re, cvv) < 0)
	goto done;
    retval = 0;
 done:
    if (regexp)
        regfree(&re);
    return retval;
}

/*! Return alphabetically sorted files from a directory matching regexp
 * @param[in]  dir     Directory path 
 * @param[out] ent     Entries pointer, will be filled in with dir entries. Free
 *                     after use
 * @param[in]  regexp  Regexp filename matching 
 * @param[in]  type    File type matching, see stat(2) 
 *
 * @retval  n  Number of matching files in directory
 * @retval -1  Error
 *
 * @code
 *   char          *dir = "/root/fs";
 *   struct dirent *dp;
 *   if ((ndp = clicon_file_dirent(dir, &dp, "(.so)$", S_IFREG)) < 0)
 *       return -1;
 *   for (i = 0; i < ndp; i++) 
 *       do something with dp[i].d_name;
 *   free(dp);
 * @endcode
 * @note "ent" is an array with n fixed entries
 *       But this is not what is returned from the syscall, see man readdir:
 *       ... the  use sizeof(struct dirent) to capture the size of the record including 
 *       the size of d_name is also incorrect.
 * @note May block on file I/O
*/
int
clicon_file_dirent(const char     *dir,
		   struct dirent **ent,
		   const char     *regexp,
		   mode_t          type)
{
   int            retval = -1;
   DIR           *dirp = NULL;
   int            res;
   int            nent;
   regex_t        re;
   char           errbuf[128];
   char           filename[MAXPATHLEN];
   struct stat    st;
   struct dirent *dent;
   struct dirent *new = NULL;
   int            direntStructSize;

   *ent = NULL;
   nent = 0;
   if (regexp && (res = regcomp(&re, regexp, REG_EXTENDED)) != 0) {
       regerror(res, &re, errbuf, sizeof(errbuf));
       clicon_err(OE_DB, 0, "regcomp: %s", errbuf);
       return -1;
   }
   if ((dirp = opendir(dir)) == NULL) {
     if (errno == ENOENT) /* Dir does not exist -> return 0 matches */
       retval = 0;
     else
       clicon_err(OE_UNIX, errno, "opendir(%s)", dir);
     goto quit;
   }
   while((dent = readdir(dirp)) != NULL) {
       /* Filename matching */
       if (regexp) {
	   if (regexec(&re, dent->d_name, (size_t) 0, NULL, 0) != 0)
	       continue;
       }
       /* File type matching */
       if (type) {
	   snprintf(filename, MAXPATHLEN-1, "%s/%s", dir, dent->d_name);
	   res = lstat(filename, &st);
	   if (res != 0) {
	       clicon_err(OE_UNIX, errno, "lstat");
	       goto quit;
	   }
	   if ((type & st.st_mode) == 0)
	       continue;
       }
       direntStructSize = offsetof(struct dirent, d_name) + strlen(dent->d_name) + 1;
       if ((new = realloc(new, (nent+1)*sizeof(struct dirent))) == NULL) {
	   clicon_err(OE_UNIX, errno, "realloc");
	   goto quit;
       } /* realloc */
       clicon_debug(2, "%s memcpy(%p %p %u", __FUNCTION__, &new[nent], dent, direntStructSize);
       /* man (3) readdir: 
	* By implication, the  use sizeof(struct dirent) to capture the size of the record including 
	* the size of d_name is also incorrect. */
       memset(&new[nent], 0, sizeof(struct dirent));
       memcpy(&new[nent], dent, direntStructSize);
       nent++;
   } /* while */

   qsort((void *)new, nent, sizeof(*new), clicon_file_dirent_sort);
   *ent = new;
   new = NULL;
   retval = nent;
quit:
   if (new)
       free(new);
   if (dirp)
       closedir(dirp);
   if (regexp)
       regfree(&re);
   return retval;
}

/*! Make a copy of file src. Overwrite existing
 * @retval 0   OK
 * @retval -1  Error
 */
int
clicon_file_copy(char *src, 
		 char *target)
{
    int         retval = -1;
    int         inF = 0, ouF = 0;
    int         err = 0;
    char        line[512];
    int         bytes;
    struct stat st;

    if (stat(src, &st) != 0){
	clicon_err(OE_UNIX, errno, "stat");
	return -1;
    }
    if((inF = open(src, O_RDONLY)) == -1) {
	clicon_err(OE_UNIX, errno, "open(%s) for read", src);
	return -1;
    }
    if((ouF = open(target, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode)) == -1) {
	clicon_err(OE_UNIX, errno, "open(%s) for write", target);
	err = errno;
	goto error;
    }
    while((bytes = read(inF, line, sizeof(line))) > 0)
	if (write(ouF, line, bytes) < 0){
	    clicon_err(OE_UNIX, errno, "write(%s)", src);
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
