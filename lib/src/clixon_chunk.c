/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 *
 * Copyright (C) 2002-2011 Benny Holmgren, All rights reserved
 */
/* Error handling: dont use clicon_err, treat as unix system calls. That is,
   ensure errno is set and return -1/NULL */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/mman.h>
#include <sys/param.h>
#include <sys/types.h>

/* clicon */
#include "clixon_queue.h"
#include "clixon_chunk.h"

/*
 * The chunk  head array for the predefined chunk sizes.
 */
static chunk_head_t	chunk_heads[CHUNK_HEADS];

/* 
 * Did we initialize the chunk heads yet?
 */
static int 		chunk_initialized = 0;


/*
 * The pagesize of this system
 */
static int		chunk_pagesz;


/*
 * List of chunk groups
 */
static chunk_group_t	*chunk_grp;

/*
 * Hack to tell unchunk() not to remove chunk_group if empty
 */
static int		dont_unchunk_group;


/*
 * Initialize chunk library
 */
static void
chunk_initialize ()
{
	int pgs;
	register int idx;

	chunk_pagesz = getpagesize();

	bzero (&chunk_heads, sizeof (chunk_heads));

	for (idx = 0; idx < CHUNK_HEADS; idx++) {
		chunk_head_t *chead = &chunk_heads[idx];


		/*
		 * Calculate the size of a block
		 */
		pgs = (0x01lu << (CHUNK_BASE + idx)) / chunk_pagesz;
		if (pgs == 0)
			pgs = 1;
		chead->ch_blksz = pgs * chunk_pagesz;


		/*
		 * Chunks per block is 1 for all size above a page. For sizes
		 * (including the chunk header) less than a page it's as many
		 * as fits		 
		 */
		chead->ch_nchkperblk = chead->ch_blksz / (0x01lu << (CHUNK_BASE + idx));


		/*
		 * Size of each chunk is:
		 *	(size + chnkhdr) * ncnkperblk = blksiz - blkhdr
		 */
		chead->ch_size =
			(chead->ch_blksz / chead->ch_nchkperblk)
			- sizeof (chunk_t);

	}

	/* Zero misc variables */
	chunk_grp = NULL;
	dont_unchunk_group = 0;
  
	chunk_initialized = 1;
}


/*
 * chunk_new_block()	- Allocate new block, initialize it and it's chunks.
 */
static int
chunk_new_block (chunk_head_t *chead)
{
	register int	idx;
	register char  *c;
	chunk_block_t  *blk;
	chunk_t	       *cnk;

	/* Map block header mem */
	blk = (chunk_block_t *)
		mmap(NULL, sizeof(chunk_block_t),
		     PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
	if (blk == MAP_FAILED)
		return -1;
	memset ((void *)blk, 0, sizeof(*blk));

	/* Allocate chunk block */
	blk->cb_blk = (void *)
		mmap(NULL, chead->ch_blksz, 
		     PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
	if (blk->cb_blk == MAP_FAILED) {
	    munmap (blk, chead->ch_blksz);
	    return -1;
	}
	memset (blk->cb_blk, 0, chead->ch_blksz);

	
	/* Initialize chunk header */
	blk->cb_head = chead;
	INSQ (blk, chead->ch_blks);
	chead->ch_nblks++;

	/* Initialize chunks */
	c = ((char *)blk->cb_blk);
	for (idx = 0; idx < chead->ch_nchkperblk; idx++) {
	       
		cnk = (chunk_t *)c;
		cnk->c_blk = blk;
		INSQ (cnk, chead->ch_free);
		chead->ch_nfree++;

		c += (chead->ch_size + sizeof (chunk_t));
	}


	return 0;
}

/*
 * chunk_release_block()	- Unqueue a block, it's chunks and free mem
 */
static void
chunk_release_block (chunk_block_t *cblk)
{
	int		idx;
	char		*c;
	chunk_t		*cnk;
	chunk_head_t	*chead;


	chead = cblk->cb_head;
	
	/*
	 * Dequeue block 
	 */
	DELQ (cblk, chead->ch_blks, chunk_block_t *);
	chead->ch_nblks--;
		
	/* 
	 * Dequeue all chunks in the block 
	 */
	c = (char *)cblk->cb_blk;
	for (idx = 0; idx < chead->ch_nchkperblk; idx++) {
		
		cnk = (chunk_t *)c;
		DELQ (cnk, chead->ch_free, chunk_t *);
		chead->ch_nfree--;
		
		c += (chead->ch_size + sizeof (chunk_t));
	}
	
	/*
	 * Free block 
	 */
	munmap ((void *)cblk->cb_blk, chead->ch_blksz);
	munmap ((void *)cblk, sizeof(*cblk));
}



/*
 * chunk_alloc()	- Map new chunk of memory
 */
static void *
chunk_alloc (size_t len)
{
	register int	idx;
	chunk_head_t   *chead;
	chunk_t	       *cnk;


	if (!len)
		return (void *)NULL;



	/* Find sufficient sized block head */
	for (idx = 0; idx < CHUNK_HEADS; idx++)
		if (chunk_heads[idx].ch_size >= len)
			break;

	/* Too large chunk? */
	if (idx >= CHUNK_HEADS) {
		errno = ENOMEM;
		return (void *)NULL;
	}

	chead = &chunk_heads[idx];

	
	/* Get new block if necessary */
	if (!chead->ch_nfree)
		if (chunk_new_block (chead))
 			return (void *)NULL;
		

	/* Move a free chunk to the in-use list */
	cnk = chead->ch_free;
	DELQ (cnk, chead->ch_free, chunk_t *);
	chead->ch_nfree--;
	INSQ (cnk, chead->ch_cnks);
	/* Add reference to the corresponding block */
	cnk->c_blk->cb_ref++;
	
#ifdef CHUNK_DIAG
	/* Clear diag info */
	bzero ((void *)&cnk->c_diag, sizeof (cnk->c_diag));
#endif /* CHUNK_DIAG */
	
	/* Return pointer to first byte after the chunk header */
	return (void *) (cnk + 1);
}


/*
 * chunk()	- Map new chunk of memory in group
 */
void *
#ifdef CHUNK_DIAG
_chunk (size_t len, const char *name, const char *file, int line)
#else
chunk (size_t len, const char *name)
#endif
{
	int		 newgrp = 0;
	void		*ptr = NULL;
	chunk_t		*cnk;
	chunk_group_t	*tmp;
	chunk_group_t	*grp = NULL;
	chunk_grpent_t	*ent = NULL;
	
	/* Make sure chunk_heads are initialized */
	if (!chunk_initialized)
		chunk_initialize();

	if (!len)
		return (void *)NULL;

	/* Get actual chunk 
	 */
	ptr = chunk_alloc (len);
	if (!ptr)
		goto error;
	cnk = (chunk_t *) (((char *)ptr) - sizeof (chunk_t));

#ifdef CHUNK_DIAG
	/* Store who reuested us
	 */
	cnk->c_diag.cd_file = file;
	cnk->c_diag.cd_line = line;
#endif /* CHUNK_DIAG */

	/* No name given. Get an ungrouped chunk
	 */
	if (!name)
		return ptr;


	/* Try to find already existing entry 
	 */
	if (chunk_grp) {
		tmp = chunk_grp;
		do {
			if (!strcmp (tmp->cg_name, name)) {
				grp = tmp;
				break;
			}
			
			tmp = NEXTQ(chunk_group_t *, tmp);
			
		} while (tmp != chunk_grp);
	}

	/* New group.
	 */
	if ( !grp ) {
		
		grp = (chunk_group_t *) chunk_alloc (sizeof (chunk_group_t));
		if (!grp)
			goto error;

		bzero (grp, sizeof (chunk_group_t));

		grp->cg_name = (char *) chunk_alloc (strlen (name) + 1);
		if (!grp->cg_name)
		  goto error;
		bcopy (name, grp->cg_name, strlen(name)+1);
		newgrp = 1;
	}
		
	
	/* Get new entry.
	 */
	ent = (chunk_grpent_t *) chunk_alloc (sizeof (chunk_grpent_t));
	if (!ent)
		goto error;
	bzero (ent, sizeof (chunk_grpent_t));

	/* Now put everything together
	 */
	cnk->c_grpent = ent;
	
	ent->ce_cnk = cnk;
	ent->ce_grp = grp;

	INSQ (ent, grp->cg_ent);
	if (newgrp)
		INSQ (grp, chunk_grp);
	
	return (ptr);

 error:
	if (grp && newgrp) {
	  	if (grp->cg_name)
		 	unchunk (grp->cg_name);
		unchunk (grp);
	}
	if (ent)
		unchunk (ent);
	if (ptr)
		unchunk (ptr);
	
	return (void *)	NULL;
}


/*
 * rechunk()	- Resize previously allocated chunk.
 */
void *
#ifdef CHUNK_DIAG
_rechunk (void *ptr, size_t len, const char *name, const char *file, int line)
#else
rechunk (void *ptr, size_t len, const char *name)
#endif
{
	int		idx;
	void		*new;
	chunk_t		*cnk;
	chunk_t		*newcnk;
	chunk_head_t	*chead;
	chunk_head_t	*newchead;


	/* No previoud chunk, get new
	 */
	if (!ptr) {
#ifdef CHUNK_DIAG
	  return _chunk (len, name, file, line);
#else
	  return chunk (len, name);
#endif
	}

	/* Zero length, free chunk 
	 */
	if (len == 0) {
		unchunk (ptr);
		return (void *) NULL;
	}

	/* Rewind pointer to beginning of chunk header 
	 */
	cnk = (chunk_t *) (((char *)ptr) - sizeof (chunk_t));
	chead = cnk->c_blk->cb_head;

	/* Find sufficient sized block head 
	 */
	for (idx = 0; idx < CHUNK_HEADS; idx++)
		if (chunk_heads[idx].ch_size >= len)
			break;
	/* Too large chunk? */
	if (idx >= CHUNK_HEADS) {
		errno = ENOMEM;
		return (void *)NULL;
	}

	/* Check if chunk size remains unchanged
	 */
	if (chunk_heads[idx].ch_size == chead->ch_size)
		return (ptr);

	/* Get new chunk 
	 */
#ifdef CHUNK_DIAG
	new = _chunk (len, name, file, line);
#else
	new = chunk (len, name);
#endif
	if (!new)
		return (void *) NULL;
	newcnk = (chunk_t *) (((char *)new) - sizeof (chunk_t));
	newchead =  newcnk->c_blk->cb_head;

	/* Copy contents to new chunk 
	 */
	bcopy (ptr, new, MIN(newchead->ch_size, chead->ch_size));
	
	/* Free old chunk
	 */
	unchunk (ptr);


	return (new);
}
	  
/*
 * unchunk()	- Release chunk
 */
void
unchunk (void *ptr)
{
	chunk_t		*cnk;
	chunk_head_t	*chead;
	chunk_block_t	*cblk;
	chunk_grpent_t	*ent;
	chunk_group_t	*grp;

	if (!chunk_initialized)
		return;

	/* Rewind pointer to beginning of chunk header 
	 */
	cnk = (chunk_t *) (((char *)ptr) - sizeof (chunk_t));
	cblk = cnk->c_blk;
	chead = cblk->cb_head;

	/* Move chunk back to free list
	 */
	DELQ (cnk, chead->ch_cnks, chunk_t *);
	INSQ (cnk, chead->ch_free);
	chead->ch_nfree++;

	/* If chunk is grouped, remove from group.
	 */
	ent = cnk->c_grpent;
	if (ent) {
		grp = ent->ce_grp;
		DELQ (ent, grp->cg_ent, chunk_grpent_t *);
		unchunk (ent);
		cnk->c_grpent = NULL;

		/* Group empty? */
		if (!dont_unchunk_group && !grp->cg_ent) {
			DELQ (grp, chunk_grp, chunk_group_t *);
			unchunk(grp->cg_name);
			unchunk(grp);
		}
	}

	/* Check block refs is nil, if so free it
	 */
	cblk->cb_ref--;
	if (cblk->cb_ref == 0)
		chunk_release_block (cblk);
}


/*
 * unchunk_group()	- Release all group chunks.
 */
void
unchunk_group (const char *name)
{
	chunk_group_t	*tmp;
	chunk_group_t	*grp = NULL;
	chunk_t		*cnk;

	if (!chunk_initialized)
		return;

	/* Try to find already existing entry 
	 */
	if (chunk_grp) {
		tmp = chunk_grp;
		do {
			if (!strcmp (tmp->cg_name, name)) {
				grp = tmp;
				break;
			}
			
			tmp = NEXTQ(chunk_group_t *, tmp);
			
		} while (tmp != chunk_grp);
	}
	if (!grp)
		return;


	/* Walk through all chunks in group an free them
	 */
	dont_unchunk_group = 1;
	while (grp->cg_ent) {
		cnk = grp->cg_ent->ce_cnk;
		unchunk ((chunk_t *)(((char *)cnk) + sizeof (chunk_t)));
	}
	dont_unchunk_group = 0;
		

	/* Remove group from list and free it 
	 */
	DELQ (grp, chunk_grp, chunk_group_t *);
	unchunk (grp->cg_name);
	unchunk (grp);
}

/*
 * chunkdup()	- Copy block of data to a new chunk of memory in group 
 */
void *
#ifdef CHUNK_DIAG
_chunkdup (const void *ptr, size_t len, const char *name, const char *file, int line)
#else
chunkdup (const void *ptr, size_t len, const char *name)
#endif
{
	void		*new;

	/* No input data or no length
	 */
	if (!ptr || len <= 0)
		return (void *)NULL;

	/* Get new chunk 
	 */
#ifdef CHUNK_DIAG
	new = _chunk (len, name, file, line);
#else
	new = chunk (len, name);
#endif
	if (!new)
		return (void *)NULL;

	/* Copy data to new chunk 
	 */
	memcpy(new, ptr, len);

	return (new);
}

/*
 * chunksize()	- Return size of memory chunk.
 */
size_t
chunksize (void *ptr)
{
	chunk_t		*cnk;
	chunk_head_t	*chead;
	chunk_block_t	*cblk;

	if (!chunk_initialized)
		return -1;

	/* Rewind pointer to beginning of chunk header 
	 */
	cnk = (chunk_t *) (((char *)ptr) - sizeof (chunk_t));
	cblk = cnk->c_blk;
	chead = cblk->cb_head;

	return chead->ch_size;
}

/*
 * chunk_strncat() - Concatenate 'n' characters to a chunk allocated string. If
 *		     'n' is zero, do the whole src string.
 *
 */
char *
#ifdef CHUNK_DIAG
_chunk_strncat (const char *dst, const char *src, size_t n, const char *name,
		const char *file, int line)
#else
chunk_strncat (const char *dst, const char *src, size_t n, const char *name)
#endif
{
	size_t len;
	char *new;
	void *ptr = (void *)dst;

	if (n == 0)  /* zero length means cat whole string */
		n = strlen(src);
	len = (dst ? strlen(dst) : 0) + n + 1;
#ifdef CHUNK_DIAG
	ptr = _rechunk(ptr, len, name, file, line);
#else
	ptr = rechunk (ptr, len, name);
#endif
	if (ptr == NULL) 
		return NULL;
  
	new = (char *)ptr;
	new += strlen(new);
	while (n-- > 0 && *src)
	  *new++ = *src++;
	*new = '\0';

	return (char *)ptr;
}

/*
 * chunk_sprintf() - Format string into new chunk.
 */
char *
#ifdef CHUNK_DIAG
_chunk_sprintf (const char *name, const char *file, 
		int line, const char *fmt, ...)
#else
chunk_sprintf (const char *name, char *fmt, ...)
#endif
{
	size_t len;
	char *str;
	va_list args;

	/* Calculate formatted string length */
	va_start(args, fmt);
	len = vsnprintf(NULL, 0, fmt, args) + 1;
	va_end (args);

	/* get chunk */
#ifdef CHUNK_DIAG
 	str = _chunk (len, name, file, line);
#else
 	str = chunk (len, name);
#endif
	if (str == NULL) 
		return NULL;

	/* Format string */
	va_start(args, fmt);
	len = vsnprintf(str, len, fmt, args);
	va_end (args);
	
	return str;
}

#ifdef CHUNK_DIAG
/*
 * chunk_check()	- Report all non-freed chunk for given group (if any)
 */
void
chunk_check(FILE *fout, const char *name)
{
	int		idx;
	chunk_t	       *cnk;
	chunk_group_t  *tmp;
	chunk_group_t  *grp = NULL;
	chunk_grpent_t *ent;


	if (!chunk_initialized)
		return;


	/* No name given, walk through everything
	 */
	if (name == (const char *)NULL) {
	    
		for (idx = 0; idx < CHUNK_HEADS; idx++) {
			chunk_head_t *chead = &chunk_heads[idx];

			cnk = chead->ch_cnks;
			if (cnk == (chunk_t *)NULL)
			    continue;

			do {
			    
				/* If no file name it's an internal chunk */
				if (cnk->c_diag.cd_file) 
					fprintf(fout ? fout : stdout,
						"%s:%d,\t%zu bytes (%p), group \"%s\"\n", 
						cnk->c_diag.cd_file,
						cnk->c_diag.cd_line,
						cnk->c_blk->cb_head->ch_size,
						(cnk +1),
						cnk->c_grpent ? 
						    cnk->c_grpent->ce_grp->cg_name :
						    "NULL");

				cnk = NEXTQ(chunk_t *, cnk);
				
			} while (cnk != chead->ch_cnks);
		}
	}

	/* Walk through group
	 */
	else {
	    

		/* Try to find already existing entry 
		 */
		if (chunk_grp) {
			tmp = chunk_grp;
			do {
				if (!strcmp (tmp->cg_name, name)) {
					grp = tmp;
					break;
				}
			
				tmp = NEXTQ(chunk_group_t *, tmp);
			
			} while (tmp != chunk_grp);
		}
		if (!grp)
			return;

		ent = grp->cg_ent;
		do {
			cnk = ent->ce_cnk;	    

			fprintf(fout ? fout : stdout,
				"%s:%d,\t%zu bytes (%p), group \"%s\"\n", 
				cnk->c_diag.cd_file,
				cnk->c_diag.cd_line,
				cnk->c_blk->cb_head->ch_size,
				(cnk +1),
				cnk->c_grpent ?
			            cnk->c_grpent->ce_grp->cg_name :
			            "NULL");

			ent = NEXTQ(chunk_grpent_t *, ent);
		} while (ent != grp->cg_ent);	    
	}
}
#endif /* CHUNK_DIAG */
