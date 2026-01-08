/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
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
 * Event handling and loop
 */

#ifndef _CLIXON_EVENT_H_
#define _CLIXON_EVENT_H_

/*
 * Prototypes
 */
int clixon_exit_set(int nr);
int clixon_exit_get(void);
int clixon_exit_decr(void);
int clicon_sig_child_set(int val);
int clicon_sig_child_get(void);
int clicon_sig_ignore_set(int val);
int clicon_sig_ignore_get(void);
int clixon_event_reg_fd(int fd, int (*fn)(int, void*), void *arg, const char *str);
int clixon_event_reg_fd_prio(int fd, int (*fn)(int, void*), void *arg, const char *str, int prio);
int clixon_event_unreg_fd(int s, int (*fn)(int, void*));
int clixon_event_reg_timeout(struct timeval t,  int (*fn)(int, void*),
                             void *arg, const char *str);
int clixon_event_unreg_timeout(int (*fn)(int, void*), void *arg);
int clixon_event_poll(int fd);
int clixon_event_loop(clixon_handle h);
int clixon_event_exit(void);
int clixon_event_init(clixon_handle h);

#endif  /* _CLIXON_EVENT_H_ */
