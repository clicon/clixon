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

 */

#ifdef HAVE_CONFIG_H
#include "clicon_config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <sys/types.h>
#include <limits.h>
#include <regex.h>
#include <sys/stat.h>
#include <sys/param.h>

#if defined(HAVE_DEPOT_H) || defined(HAVE_QDBM_DEPOT_H)
#ifdef HAVE_DEPOT_H
#include <depot.h> /* qdb api */
#else /* HAVE_QDBM_DEPOT_H */
#include <qdbm/depot.h> /* qdb api */
#endif 

#include <cligen/cligen.h>

/* clicon */
#include "clicon_log.h"
#include "clicon_err.h"
#include "clicon_queue.h"
#include "clicon_chunk.h"
#include "clicon_qdb.h" 

/*! Initialize database
 * @param[in]  file    database file
 * @param[in]  omode   see man dpopen
 */
static int 
db_init_mode(char *file, int omode)
{
    DEPOT *dp;

    /* Open database for writing */
    if ((dp = dpopen(file, omode | DP_OLCKNB, 0)) == NULL){
	clicon_err(OE_DB, 0, "db_init: dpopen(%s): %s", 
		file,
		dperrmsg(dpecode));
	return -1;
    }
    clicon_debug(1, "db_init(%s)", file);
    if (dpclose(dp) == 0){
	clicon_err(OE_DB, 0, "db_set: dpclose: %s", dperrmsg(dpecode));
	return -1;
    }
    return 0;
}

/*! Open database for reading and writing
 * @param[in]  file    database file
 */
int 
db_init(char *file)
{
    return db_init_mode(file, DP_OWRITER | DP_OCREAT ); /* DP_OTRUNC? */
}

/*! Write data to database 
 * @param[in]  file    database file
 * @param[in]  key     database key
 * @param[out] data    Buffer containing content
 * @param[out] datalen Length of buffer
 * @retval  0 if OK: value returned. If not found, zero string returned
 * @retval -1 on error   
 */
int 
db_set(char *file, char *key, void *data, size_t datalen)
{
    DEPOT *dp;

    /* Open database for writing */
    if ((dp = dpopen(file, DP_OWRITER | DP_OLCKNB, 0)) == NULL){
	clicon_err(OE_DB, 0, "db_set: dpopen(%s): %s", 
		file,
		dperrmsg(dpecode));
	return -1;
    }
    clicon_debug(2, "%s: db_put(%s, len:%d)", 
		file, key, (int)datalen);
    if (dpput(dp, key, -1, data, datalen, DP_DOVER) == 0){
	clicon_err(OE_DB, 0, "%s: db_set: dpput(%s, %d): %s", 
		file,
		key,
		datalen,
		dperrmsg(dpecode));
	dpclose(dp);
	return -1;
    }
    if (dpclose(dp) == 0){
	clicon_err(OE_DB, 0, "db_set: dpclose: %s", dperrmsg(dpecode));
	return -1;
    }
    return 0;
}

/*! Get data from database 
 * @param[in]  file    database file
 * @param[in]  key     database key
 * @param[out] data    Pre-allocated buffer where data corresponding key is placed
 * @param[out] datalen Length of pre-allocated buffer
 * @retval  0 if OK: value returned. If not found, zero string returned
 * @retval -1 on error   
 * @see db_get_alloc  Allocates memory
 */
int 
db_get(char   *file, 
       char   *key, 
       void   *data, 
       size_t *datalen)
{
    DEPOT *dp;
    int len;

    /* Open database for readinf */
    if ((dp = dpopen(file, DP_OREADER | DP_OLCKNB, 0)) == NULL){
	clicon_err(OE_DB, dpecode, "%s: db_get(%s, %d): dpopen: %s", 
		file,
		key,
		datalen,
		dperrmsg(dpecode));
	return -1;
    }
    len = dpgetwb(dp, key, -1, 0, *datalen, data);
    if (len < 0){
	if (dpecode == DP_ENOITEM){
	    data = NULL;
	    *datalen = 0;
	}
	else{
	    clicon_err(OE_DB, 0, "db_get: dpgetwb: %s (%d)", 
		    dperrmsg(dpecode), dpecode);
	    dpclose(dp);
	    return -1;
	}
    }
    else
	*datalen = len;	
    clicon_debug(2, "db_get(%s, %s)=%s", file, key, (char*)data);
    if (dpclose(dp) == 0){
	clicon_err(OE_DB, 0, "db_get: dpclose: %s", dperrmsg(dpecode));
	return -1;
    }
    return 0;
}

/*! Get data from database and allocates memory
 * Similar to db_get but returns a malloced pointer to the data instead 
 * of copying data to pre-allocated buffer. This is necessary if the 
 * length of the data is not known when calling the function.
 * @param[in]  file    database file
 * @param[in]  key     database key
 * @param[out] data    Allocated buffer where data corresponding key is placed
 * @param[out] datalen Length of pre-allocated buffer
 * @retval  0 if OK: value returned. If not found, zero string returned
 * @retval -1 on error   
 * @note: *data needs to be freed after use.
 * @code
 *  char             *lvec = NULL;
 *  size_t            len = 0;
 *  if (db_get-alloc(dbname, "a.0", &val, &vlen) == NULL)
 *     return -1;
 *  ..do stuff..
 *  if (val) free(val);
 * @endcode
 * @see db_get Pre-allocates memory
 */
int 
db_get_alloc(char   *file, 
	     char   *key, 
	     void  **data, 
	     size_t *datalen)
{
    DEPOT *dp;
    int len;

    /* Open database for writing */
    if ((dp = dpopen(file, DP_OREADER | DP_OLCKNB, 0)) == NULL){
	clicon_err(OE_DB, 0, "%s: dpopen(%s): %s", 
		   __FUNCTION__,
		   file,
		   dperrmsg(dpecode));
	return -1;
    }
    if ((*data = dpget(dp, key, -1, 0, -1, &len)) == NULL){
	if (dpecode == DP_ENOITEM){
	    *datalen = 0;
	    *data = NULL;
	    len = 0;
	}
	else{
	    /* No entry vs error? */
	    clicon_err(OE_DB, 0, "db_get_alloc: dpgetwb: %s (%d)", 
		    dperrmsg(dpecode), dpecode);
	    dpclose(dp);
	    return -1;
	}
    }
    *datalen = len;
    if (dpclose(dp) == 0){
	clicon_err(OE_DB, 0, "db_get_alloc: dpclose: %s", dperrmsg(dpecode));
	return -1;
    }
    return 0;
}

/*! Delete database entry
 * @param[in]  file    database file
 * @param[in]  key     database key
 * @retval  -1  on failure, 
 * @retval   0  if key did not exist 
 * @retval   1  if successful.
 */
int 
db_del(char *file, char *key)
{
    int retval = 0;
    DEPOT *dp;

    /* Open database for writing */
    if ((dp = dpopen(file, DP_OWRITER | DP_OLCKNB, 0)) == NULL){
	clicon_err(OE_DB, 0, "db_del: dpopen(%s): %s", 
		file,
		dperrmsg(dpecode));
	return -1;
    }
    if (dpout(dp, key, -1)) {
        retval = 1;
    }
    if (dpclose(dp) == 0){
	clicon_err(OE_DB, 0, "db_del: dpclose: %s", dperrmsg(dpecode));
	return -1;
    }
    return retval;
}


/*! Check if entry in database exists
 * @param[in]  file    database file
 * @param[in]  key     database key
 * @retval  1  if key exists in database
 * @retval  0  key does not exist in database
 * @retval -1  error
 */
int 
db_exists(char *file, char *key)
{
    DEPOT *dp;
    int len;

    /* Open database for reading */
    if ((dp = dpopen(file, DP_OREADER | DP_OLCKNB, 0)) == NULL){
	clicon_err(OE_DB, dpecode, "%s: dpopen: %s", 
		   __FUNCTION__, dperrmsg(dpecode));
	return -1;
    }

    len = dpvsiz(dp, key, -1);
    if (len < 0 && dpecode != DP_ENOITEM)
	clicon_err(OE_DB, 0, "^s: dpvsiz: %s (%d)", 
		   __FUNCTION__, dperrmsg(dpecode), dpecode);

    if (dpclose(dp) == 0) {
	clicon_err(OE_DB, 0, "%s: dpclose: %s", dperrmsg(dpecode),__FUNCTION__);
	return -1;
    }

    return (len < 0) ? 0 : 1;
}

/*! Return all entries in database that match a regular expression.
 * @param[in]  file    database file
 * @param[in]  regexp  regular expression for database keys
 * @param[in]  label   for memory/chunk allocation
 * @param[out] pairs   Vector of database keys and values
 * @param[in]  noval   If set don't retreive values, just keys
 * @retval -1  on error   
 * @retval  n  Number of pairs
 * @code
 * struct db_pair *pairs;
 * int             npairs;
 * if ((npairs = db_regexp(dbname, "^/test/kalle$", __FUNCTION__, 
 *                         &pairs, 0)) < 0)
 *    err;
 * 
 * @endcode
 */
int
db_regexp(char            *file,
	  char            *regexp, 
	  const char      *label, 
	  struct db_pair **pairs,
	  int              noval)
{
    int npairs;
    int status;
    int retval = -1;
    int vlen = 0;
    char *key = NULL;
    void *val = NULL;
    char errbuf[512];
    struct db_pair *pair;
    struct db_pair *newpairs;
    regex_t iterre;
    DEPOT *iterdp = NULL;
    regmatch_t pmatch[1];
    size_t nmatch = 1;
    
    npairs = 0;
    *pairs = NULL;
    
    if (regexp) {
	if ((status = regcomp(&iterre, regexp, REG_EXTENDED)) != 0) {
	    regerror(status, &iterre, errbuf, sizeof(errbuf));
	    clicon_err(OE_DB, 0, "%s: regcomp: %s", __FUNCTION__, errbuf);
	    return -1;
	}
    }
    
    /* Open database for reading */
    if ((iterdp = dpopen(file, DP_OREADER | DP_OLCKNB, 0)) == NULL){
	clicon_err(OE_DB, 0, "%s: dpopen(%s): %s", 
		   __FUNCTION__, file, dperrmsg(dpecode));
	goto quit;
    }
    
    /* Initiate iterator */
    if(dpiterinit(iterdp) == 0) {
	clicon_err(OE_DB, 0, "%s: dpiterinit: %s", __FUNCTION__, dperrmsg(dpecode));
	goto quit;
    }
    
    /* Iterate through DB */
    while((key = dpiternext(iterdp, NULL)) != NULL) {
	
	if (regexp && regexec(&iterre, key, nmatch, pmatch, 0) != 0) {
	    free(key);
	    continue;
	}
	
	/* Retrieve value if required */
	if ( ! noval) {
	    if((val = dpget(iterdp, key, -1, 0, -1, &vlen)) == NULL) {
		clicon_log(OE_DB, "%s: dpget: %s", __FUNCTION__, dperrmsg(dpecode));
		goto quit;
	    }
	}

	/* Resize and populate resulting array */
	newpairs = rechunk(*pairs, (npairs+1) * sizeof(struct db_pair), label);
	if (newpairs == NULL) {
	    clicon_err(OE_DB, errno, "%s: rechunk", __FUNCTION__);
	    goto quit;
	}
	pair = &newpairs[npairs];
	memset (pair, 0, sizeof(*pair));
	
	pair->dp_key = chunk_sprintf(label, "%s", key);
	if (regexp)
	    pair->dp_matched = chunk_sprintf(label, "%.*s",
					     pmatch[0].rm_eo - pmatch[0].rm_so,
					     key + pmatch[0].rm_so);
	else
	    pair->dp_matched = chunk_sprintf(label, "%s", key);
	if (pair->dp_key == NULL || pair->dp_matched == NULL) {
	    clicon_err(OE_DB, errno, "%s: chunk_sprintf");
	    goto quit;
	}
	if ( ! noval) {
	    if (vlen){
		pair->dp_val = chunkdup (val, vlen, label);
		if (pair->dp_val == NULL) {
		    clicon_err(OE_DB, errno, "%s: chunkdup", __FUNCTION__);
		    goto quit;
		}
	    }
	    pair->dp_vlen = vlen;
	    free(val);
	    val = NULL;
	}

	(*pairs) = newpairs;
	npairs++;
	free(key);
    }
	
    retval = npairs;
    
quit:
    if (key)
	free(key);
    if (val)
	free(val);
    if (regexp)
	regfree(&iterre);
    if (iterdp)
	dpclose(iterdp);
    if (retval < 0)
	unchunk_group(label);

    return retval;
}

/*! Sanitize regexp string. Escape '\' etc.
 */
char *
db_sanitize(char *rx, const char *label)
{
  char *new;
  char *k, *p, *s;

  k = chunk_sprintf(__FUNCTION__, "%s", "");
  p = rx;
  while((s = strstr(p, "\\"))) {
    if ((k = chunk_sprintf(__FUNCTION__, "%s%.*s\\\\", k, s-p, p)) == NULL)
      goto quit;
    p = s+1;
  }
  if ((k = chunk_strncat(k, p, strlen(p), __FUNCTION__)) == NULL)
    goto quit;

  new = (char *)chunkdup(k, strlen(k)+1, label);
  unchunk_group(__FUNCTION__);
  return new;

 quit:
  unchunk_group(__FUNCTION__);
  return NULL;
}


#endif /* DEPOT */

