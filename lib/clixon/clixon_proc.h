/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

 */

#ifndef _CLIXON_PROC_H_
#define _CLIXON_PROC_H_

/*
 * Types
 */ 
typedef struct process_entry_t process_entry_t;

/* Process RPC callback function */
typedef int (proc_cb_t)(clicon_handle h, process_entry_t *pe, char **operation); 

/*
 * Prototypes
 */ 
int clixon_proc_socket(char **argv, pid_t *pid, int *fdin, int *fdout);
int clixon_proc_socket_close(pid_t pid, int fdin, int fdout);
int clixon_proc_background(char **argv, const char *netns, pid_t *pid);
int clixon_process_register(clicon_handle h, const char *name, const char *netns, proc_cb_t *callback, char **argv, int argc);
int clixon_process_delete_all(clicon_handle h);
int clixon_process_operation(clicon_handle h, const char *name, char *op, const int wrapit, uint32_t *pid);

#endif  /* _CLIXON_PROC_H_ */
