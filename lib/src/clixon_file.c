/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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
#include <grp.h>
 
/* cligen */
#include <cligen/cligen.h>

/* clicon */
#include "clixon_err.h"
#include "clixon_queue.h"
#include "clixon_string.h"
#include "clixon_file.h"

/*! qsort "compar" for directory alphabetically sorting, see qsort(3)
 */
static int
clicon_file_dirent_sort(const void* arg1, 
			const void* arg2)
{
    struct dirent *d1 = (struct dirent *)arg1;
    struct dirent *d2 = (struct dirent *)arg2;

#ifdef  HAVE_STRVERSCMP
    return strverscmp(d1->d_name, d2->d_name);     /* strverscmp specific GNU function */
#else /* HAVE_STRVERSCMP */ 
    return strcoll(d1->d_name, d2->d_name);
#endif /* HAVE_STRVERSCMP */
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
*/
int
clicon_file_dirent(const char     *dir,
		   struct dirent **ent,
		   const char     *regexp,	
		   mode_t          type)
{
   int            retval = -1;
   DIR           *dirp;
   int            res;
   int            nent;
   regex_t        re;
   char           errbuf[128];
   char           filename[MAXPATHLEN];
   struct stat    st;
   struct dirent  dent;
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
   if ((dirp = opendir(dir)) == NULL) {
     if (errno == ENOENT) /* Dir does not exist -> return 0 matches */
       retval = 0;
     else
       clicon_err(OE_UNIX, errno, "opendir(%s)", dir);
     goto quit;
   }
   for (res = readdir_r(dirp, &dent, &dresp); 
	dresp; 
	res = readdir_r(dirp, &dent, &dresp)) {
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
	   snprintf(filename, MAXPATHLEN-1, "%s/%s", dir, dent.d_name);
	   res = lstat(filename, &st);
	   if (res != 0) {
	       clicon_err(OE_UNIX, 0, "lstat: %s", strerror(errno));
	       goto quit;
	   }
	   if ((type & st.st_mode) == 0)
	       continue;
       }
       if ((tmp = realloc(new, (nent+1)*sizeof(*dvecp))) == NULL) {
	   clicon_err(OE_UNIX, errno, "realloc");
	   goto quit;
       }
       new = tmp;
       memcpy(&new[nent], &dent, sizeof(dent));
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
    int inF = 0, ouF = 0;
    int err = 0;
    char line[512];
    int bytes;
    struct stat st;
    int retval = -1;

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


/*! Translate group name to gid. Return -1 if error or not found.
 * @param[in]   name  Name of group
 * @param[out]  gid   Group id
 * @retval  0   OK
 * @retval -1   Error. or not found
 */
int
group_name2gid(char *name, 
	       gid_t *gid)
{
    char          buf[1024]; 
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
