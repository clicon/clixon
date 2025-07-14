/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC (Netgate)

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

#ifndef _CLIXON_QUEUE_H_
#define _CLIXON_QUEUE_H_

/*! Circular queue structure for use as first entry in a parent structure.
 *
 * Add qelem_t as first element in struct
 * @code
 * struct a{
 *   qelem_t a_q; # this must be there
 *   int     a_b; # other elements
 *   ...
 * };
 * @endcode
 */
typedef struct _qelem_t {
        struct _qelem_t  *q_next;
        struct _qelem_t  *q_prev;
} qelem_t;

/*! Append element 'elem' to queue.
 *
 * @param[in]     elem   Element to be added
 * @param[in,out] pred   Add element after this
 * @code
 *   struct a *list; # existing list
 *   struct a *new = malloc(...);
 *  ADDQ(new, list);
 * @endcode
 */
#define ADDQ(elem, pred) { \
        register qelem_t *Xe = (qelem_t *) (elem);      \
        register qelem_t *Xp = (qelem_t *) (pred);      \
        if (pred) {                                     \
            Xe->q_next = Xp;                            \
            Xe->q_prev = Xp->q_prev;                    \
            Xp->q_prev->q_next = Xe;                    \
            Xp->q_prev = Xe;                            \
        } else {                                        \
            Xe->q_next = Xe->q_prev = Xe;               \
            pred = elem;                                \
        }                                               \
    }

/*! Insert element 'elem' in queue after 'pred'
 *
 * @param[in]     elem   Element to be added
 * @param[in,out] pred   Add element after this
 * @code
 *   struct a *list; # existing list
 *   struct a *new = malloc(...);
 *   INSQ(new, list);
 * @endcode
 */
#define INSQ(elem, pred) { \
                register qelem_t *Xe = (qelem_t *) (elem); \
                register qelem_t *Xp = (qelem_t *) (pred); \
                if (pred) {                                \
                    Xe->q_next = Xp;                       \
                    Xe->q_prev = Xp->q_prev;               \
                    Xp->q_prev->q_next = Xe;               \
                    Xp->q_prev = Xe;                       \
                } else {                                   \
                    Xe->q_next = Xe->q_prev = Xe;          \
                }                                          \
                pred = elem;                               \
    }

/*! Remove element 'elem' from queue. 'head' is the pointer to the queue and
 *
 * is of 'type'.
 * @param[in]  elem
 * @param[in]  head
 * @param[in]  type  XXX needed?
 * @code
 *   struct a *list; # existing list
 *   struct a *el; # remove this
 *  DELQ(el, list, struct a*);
 * @endcode
 */
#define DELQ(elem, head, type)  { \
                register qelem_t *Xe = (qelem_t *) elem; \
                if (Xe->q_next == Xe) \
                        head = NULL; \
                (Xe->q_prev->q_next = Xe->q_next)->q_prev = Xe->q_prev; \
                if (elem == head) \
                        head = (type)Xe->q_next; \
        }

/*! Get next entry in list
 *
 * @param[in]  type  Type of element
 * @param[in]  el    Return next element after elem.
 * @code
 *  struct a *list; # existing element (or list)
 *  NEXTQ(struct a*, el);
 */
#define NEXTQ(type, elem)       ((type)((elem)?((qelem_t *)(elem))->q_next:NULL))
#define PREVQ(type, elem)       ((type)((elem)?((qelem_t *)(elem))->q_prev:NULL))

#endif  /* _CLIXON_QUEUE_H_ */
