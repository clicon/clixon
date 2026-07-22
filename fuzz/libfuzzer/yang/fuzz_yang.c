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

 * LLVM libfuzzer for the YANG parse path.
 *
 * Feeds arbitrary byte sequences through yang_spec_parse_file() — the full
 * YANG pipeline including lexer, parser, and yang_parse_post() which covers:
 *   - cardinality checks
 *   - feature/if-feature evaluation
 *   - type population (ys_populate)
 *   - type resolution (ys_resolve_type)
 *   - grouping/uses expansion
 *   - augment and uses processing
 *   - leafref/must/when binding
 *
 * The fuzzer writes each input to a temp file named "fuzz.yang" and calls
 * yang_spec_parse_file().  Missing imports silently return errors (no crash)
 * because no CLICON_YANG_DIR is configured.
 *
 * After each input the newly-added modules are pruned from the persistent
 * yspec so they don't accumulate across iterations.
 *
 * Build: see build.sh
 */

#include "clixon_config.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <syslog.h>
#include <unistd.h>

#include <cligen/cligen.h>
#include <clixon/clixon.h>

/* Persistent state — allocated once in LLVMFuzzerInitialize */
static clixon_handle _fuzz_h    = NULL;
static yang_stmt    *_fuzz_yspec = NULL;
static char          _fuzz_tmpfile[64];

int
LLVMFuzzerInitialize(int *argc, char ***argv)
{
    if ((_fuzz_h = clixon_handle_init()) == NULL)
        return 0;
    clixon_log_init(_fuzz_h, "fuzz_yang", LOG_DEBUG, 0);
    if (yang_init(_fuzz_h) < 0)
        return 0;
    if ((_fuzz_yspec = yspec_new(_fuzz_h, "fuzz")) == NULL)
        return 0;
    /* Fixed tmpfile per process — safe because libFuzzer is single-threaded */
    snprintf(_fuzz_tmpfile, sizeof(_fuzz_tmpfile), "/tmp/fuzz_yang_%d.yang", getpid());
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
    int        modmin;
    int        modmax;
    int        i;
    yang_stmt *ym;
    FILE      *f;

    if (_fuzz_yspec == NULL)
        goto done;

    /* Write fuzz input to temp file */
    if ((f = fopen(_fuzz_tmpfile, "w")) == NULL)
        goto done;
    fwrite(data, 1, size, f);
    fclose(f);

    /* Track how many modules exist before this parse */
    modmin = yang_len_get(_fuzz_yspec);

    /* Full YANG pipeline: lex + parse + yang_parse_post */
    yang_spec_parse_file(_fuzz_h, _fuzz_tmpfile, _fuzz_yspec);

    /* Prune and free any modules added by this iteration */
    modmax = yang_len_get(_fuzz_yspec);
    for (i = modmax - 1; i >= modmin; i--) {
        ym = ys_prune(_fuzz_yspec, i);
        if (ym)
            ys_free(ym);
    }

 done:
    return 0;
}
