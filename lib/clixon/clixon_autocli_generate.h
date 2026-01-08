/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand
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

 */

#ifndef _CLIXON_AUTOCLI_GENERATE_H_
#define _CLIXON_AUTOCLI_GENERATE_H_

/*
 * Constants
 */
/* This is the default "virtual" callback function of the auto-cli. It should be overwritten by
 * a callback specified in a clispec, such as:
 * @code
 * set @datamodel, cli_set();
 * @endcode
 * where the virtual callback (overwrite_me) is overwritten by cli_set.
 */
#define GENERATE_CALLBACK "overwrite_me"
#define GROUPING_CALLBACK "prepend_me"
#define MTPOINT_PREFIX    "mtpoint"

/* variable expand function */
#define GENERATE_EXPAND_XMLDB "expand_dbvar"

/* Name of autocli CLIgen treename */
#define AUTOCLI_TREENAME "basemodel"

/*! Delimiter when creating yang2cli grouping cmd label */
#define AUTOCLI_CMD_DELIM ":"

/*
 * Prototypes
 */
int mtpoint_encode(cbuf *cb, const char *delim, const char *domain, const char *spec);
int mtpoint_decode(const char *str, const char *delim, char **domain, char **spec);
int yang2cli_treeref_encode(cbuf *cb, const char *delim, const char *domain, const char *spec, const char *module,
                            const char *revision, const char *keyword, const char *argument);
int yang2cli_treeref_decode(const char *str, const char *delim, char **domain, char **spec, char **module,
                            char **revision, char **keyword, char **argument);
int yang2cli_grouping(clixon_handle h, yang_stmt *ys, yang_stmt *ymod, const char *domain, const char *treename, cbuf *cb);
int yang2cli_stmt(clixon_handle h, yang_stmt *ys, int level, cbuf *cb);

#endif  /* _CLIXON_AUTOCLI_GENERATE_H_ */
