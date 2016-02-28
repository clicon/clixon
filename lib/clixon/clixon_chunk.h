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
 * Copyright (C) 2002 Benny Holmgren, All rights reserved
 */

#ifndef _CLIXON_CHUNK_H_
#define _CLIXON_CHUNK_H_


/*

 * Compile with chunk diagnostics. XXX Should be in Makefile.in ??
 */
#define CHUNK_DIAG

/*
 * Base number of bits to shift getting the size of a chunk_head.
 */
#define CHUNK_BASE	6

/*
 * Number of predefined chunk sizes. I.e. the number of chunk heads in the
 * chunk_heads vector. 
 */
#define CHUNK_HEADS	(32 - CHUNK_BASE)


#ifdef CHUNK_DIAG
/*
 * Chunk diagnostics
 */
typedef struct _chunk_diag_t {
	const char     *cd_file;	/* File which requested chunk */

	int		cd_line;	/* Line in requesting file */

} chunk_diag_t;
#endif /* CHUNK_DIAG */

/*
 * The block header.
 */
struct _chunk_head_t;
typedef struct _chunk_head_t chunk_head_t;

typedef struct _chunk_block_t {
	qelem_t		cb_qelem;	/* Circular queue of blocks */

	chunk_head_t   *cb_head;	/* The chunk head I belong to */

	void	       *cb_blk;		/* Allocated memory block */

	uint16_t	cb_ref;		/* Number of used chunks of block */
	
} chunk_block_t;


/*
 * The chunk header.
 */
struct _chunk_grpent_t;
typedef struct _chunk_grpent_t chunk_grpent_t;
typedef struct _chunk_t {
	qelem_t		c_qelem;	/* Circular queue of chunks */

	chunk_block_t  *c_blk;		/* The block I belong to */

#ifdef CHUNK_DIAG
    	chunk_diag_t	c_diag;		/* The diagnostics structure */
#endif /* CHUNK_DIAG */

	chunk_grpent_t *c_grpent;
} chunk_t;

/*
 * The head of a chunk size. Each predefined size has it's own head keeping
 * track of all blocks and chunks for the size.
 */
struct _chunk_head_t {
	size_t		ch_size;	/* Chunk size */
	int		ch_nchkperblk;	/* Number pf chunks per block */

	size_t		ch_blksz;	/* Size of a block */
	int		ch_nblks;	/* Number of allocated blocks */

	chunk_block_t  *ch_blks;	/* Circular list of blocks */

	chunk_t	       *ch_cnks;	/* Circular list of chunks in use */

	size_t		ch_nfree;	/* Number of free chunks */
	chunk_t	       *ch_free;	/* Circular list of free chunks */

};


/*
 * The chunk group structure.
 */
typedef struct _chunk_group_t {
	qelem_t		cg_qelem;	/* List of chunk groups */
	
	char           *cg_name;	/* Name of group */
	
	chunk_grpent_t *cg_ent;		/* List of chunks in the group */

} chunk_group_t;


/*
 * The chunk group entry structure.
 */
struct _chunk_grpent_t {
	qelem_t		ce_qelem;	/* Circular list of entries */
	
	chunk_group_t  *ce_grp;		/* The group I belong to */

	chunk_t	       *ce_cnk;		/* Pointer to the chunk */
}; 

/*
 * Public function declarations
 */
#ifdef CHUNK_DIAG
void   *_chunk (size_t, const char *, const char *, int);
#define chunk(siz,label)	_chunk((siz),(label),__FILE__,__LINE__)
void   *_rechunk (void *, size_t, const char *, const char *, int);
#define rechunk(ptr,siz,label)	_rechunk((ptr),(siz),(label),__FILE__,__LINE__)
void   *_chunkdup (const void *, size_t, const char *, const char *, int);
#define chunkdup(ptr,siz,label)	_chunkdup((ptr),(siz),(label),__FILE__,__LINE__)
char   *_chunk_strncat (const char *, const char *, size_t, const char *, const char *, int);
#define chunk_strncat(str,new,n,label) _chunk_strncat((str),(new),(n),(label),__FILE__,__LINE__)
char   *_chunk_sprintf (const char *, const char *, int, const char *, ...);
#define chunk_sprintf(label,fmt,...) _chunk_sprintf((label),__FILE__,__LINE__,(fmt),__VA_ARGS__)
#else /* CHUNK_DIAG */
void   *chunk (size_t, const char *);
void   *rechunk (void *, size_t, const char *);
void   *chunkdup (void *, size_t, const char *);
char   *chunk_strncat (const char *, const char *, size_t, const char *);
char   *chunk_sprintf (const char *, char *, ...);
#endif /* CHUNK_DIAG */
void	unchunk (void *);
void	unchunk_group (const char *);
void	chunk_check (FILE *, const char *);
size_t	chunksize (void *);


#endif	/* _CLIXON_CHUNK_H_ */
