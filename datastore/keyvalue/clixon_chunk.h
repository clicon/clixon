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

 *
 */

#ifndef _CLIXON_CHUNK_H_
#define _CLIXON_CHUNK_H_


/*
 * Compile with chunk diagnostics. XXX Should be in Makefile.in ??
 */
#undef CHUNK_DIAG

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
void   *chunkdup (const void *, size_t, const char *);
char   *chunk_strncat (const char *, const char *, size_t, const char *);
char   *chunk_sprintf (const char *, char *, ...);
#endif /* CHUNK_DIAG */
void	unchunk (void *);
void	unchunk_group (const char *);
void	chunk_check (FILE *, const char *);
size_t	chunksize (void *);


#endif	/* _CLIXON_CHUNK_H_ */
