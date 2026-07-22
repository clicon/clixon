/*
 *
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2024 Olof Hagsand

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

 * LLVM libfuzzer for the XPath parse path.
 *
 * Feeds arbitrary byte sequences through xpath_parse() — exercises the
 * XPath lexer and grammar, including error recovery and memory cleanup.
 *
 * Build: see build.sh
 */

#include "clixon_config.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

#include <cligen/cligen.h>
#include <clixon/clixon.h>

/* Persistent handle — allocated once in LLVMFuzzerInitialize, reused per input */
static clixon_handle _fuzz_h = NULL;

int
LLVMFuzzerInitialize(int *argc, char ***argv)
{
    if ((_fuzz_h = clixon_handle_init()) == NULL)
        return 0;
    clixon_log_init(_fuzz_h, "fuzz_xpath", LOG_DEBUG, 0);
    return 0;
}

/*! libfuzzer entry point
 *
 * @param[in]  data  Fuzzer-supplied byte sequence
 * @param[in]  size  Length of data
 * @retval     0     Always (errors are expected and ignored)
 */
int
LLVMFuzzerTestOneInput(const uint8_t *data,
                       size_t         size)
{
    char       *str  = NULL;
    xpath_tree *xpt  = NULL;

    /* xpath_parse requires a null-terminated string */
    if ((str = malloc(size + 1)) == NULL)
        goto done;
    memcpy(str, data, size);
    str[size] = '\0';

    xpath_parse(str, &xpt);

 done:
    if (xpt)
        xpath_tree_free(xpt);
    free(str);
    return 0;
}
