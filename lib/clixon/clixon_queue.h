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

#ifndef _CLIXON_QUEUE_H_
#define _CLIXON_QUEUE_H_

/*
 * Circular queue structure for use as first entry in a parent structure.
 */
typedef struct _qelem_t {
	struct _qelem_t  *q_next;
	struct _qelem_t  *q_prev;
} qelem_t;

  /*
  * Append element 'elem' to queue.
  */
#define ADDQ(elem, pred) { \
	register qelem_t *Xe = (qelem_t *) (elem);	\
	register qelem_t *Xp = (qelem_t *) (pred);	\
	if (pred) {					\
	    Xe->q_next = Xp;				\
	    Xe->q_prev = Xp->q_prev;			\
	    Xp->q_prev->q_next = Xe;			\
	    Xp->q_prev = Xe;				\
	} else {					\
	    Xe->q_next = Xe->q_prev = Xe;		\
	    pred = elem;				\
	}						\
    }

/*
 * Insert element 'elem' in queue after 'pred'
 */
#define INSQ(elem, pred) { \
		register qelem_t *Xe = (qelem_t *) (elem); \
		register qelem_t *Xp = (qelem_t *) (pred); \
		if (pred) {				   \
		    Xe->q_next = Xp;			   \
		    Xe->q_prev = Xp->q_prev;		   \
		    Xp->q_prev->q_next = Xe;		   \
		    Xp->q_prev = Xe;			   \
		} else {				   \
		    Xe->q_next = Xe->q_prev = Xe;	   \
		}					   \
		pred = elem;				   \
    }

/*
 * Remove element 'elem' from queue. 'head' is the pointer to the queue and 
 * is of 'type'.
 */
#define	DELQ(elem, head, type)	{ \
    		register qelem_t *Xe = (qelem_t *) elem; \
		if (Xe->q_next == Xe) \
			head = NULL; \
		(Xe->q_prev->q_next = Xe->q_next)->q_prev = Xe->q_prev; \
		if (elem == head) \
			head = (type)Xe->q_next; \
	}
	
/*
 * Get next entry in list
 */
#define NEXTQ(type, elem)	((type)((elem)?((qelem_t *)(elem))->q_next:NULL))


#endif	/* _CLIXON_QUEUE_H_ */
