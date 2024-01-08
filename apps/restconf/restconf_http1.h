/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
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

 * HTTP/1.1 parser according to RFC 7230
 */
#ifndef _RESTCONF_HTTP1_H_
#define _RESTCONF_HTTP1_H_

/*
 * Prototypes
 */
int clixon_http1_parse_file(clixon_handle h, restconf_conn *rc, FILE *f, const char *filename);
int clixon_http1_parse_string(clixon_handle h, restconf_conn *rc, char *str);
int clixon_http1_parse_buf(clixon_handle h, restconf_conn *rc, char *buf, size_t n);
int restconf_http1_path_root(clixon_handle h, restconf_conn *rc);
int http1_check_expect(clixon_handle h, restconf_conn *rc, restconf_stream_data *sd);
int http1_check_content_length(clixon_handle h, restconf_stream_data *sd, int *status);

#endif  /* _RESTCONF_HTTP1_H_ */
