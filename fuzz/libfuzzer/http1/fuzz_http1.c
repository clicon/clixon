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

 * LLVM libfuzzer for the HTTP/1 parser (clixon_http1_parseparse).
 *
 * Fuzz target: drives the flex/bison HTTP/1.1 parser directly using only the
 * clixon_http1_yacc struct, with no restconf_conn, no network, no backend.
 * Only clixon lib code is needed (libclixon + libcligen).
 *
 * Build (from fuzz/libfuzzer/http1/):
 *   clang -g -O1 -fsanitize=fuzzer,address \
 *     -I../../../apps/restconf \
 *     -I../../../lib/clixon -I../../../lib/src -I../../../lib \
 *     -I../../../include -I../../.. \
 *     -DHAVE_CONFIG_H \
 *     fuzz_http1.c \
 *     ../../../apps/restconf/clixon_http1_parse.tab.c \
 *     ../../../apps/restconf/lex.clixon_http1_parse.c \
 *     -o fuzz_http1 \
 *     -L/usr/local/lib -lclixon -lcligen
 *
 * Run with seed corpus:
 *   LD_LIBRARY_PATH=/usr/local/lib ./fuzz_http1 corpus/
 *
 * The lexer may leak tokens abandoned on a parse error (tokens without a
 * %destructor in the grammar).  To suppress these expected per-iteration leaks
 * and focus on heap-overflows/use-after-free:
 *   ASAN_OPTIONS=detect_leaks=0 LD_LIBRARY_PATH=/usr/local/lib ./fuzz_http1 corpus/
 */

#include "clixon_config.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <syslog.h>

#include <cligen/cligen.h>
#include <clixon/clixon.h>

#include "clixon_http1_parse.h"

/* Persistent handle — allocated once, reused across fuzz iterations */
static clixon_handle _fuzz_h = NULL;

/*! One-time setup
 */
static int
fuzz_init(void)
{
    if ((_fuzz_h = clixon_handle_init()) == NULL)
        return -1;
    /* Suppress all log output so fuzzer stderr stays clean */
    clixon_log_init(_fuzz_h, "fuzz_http1", LOG_DEBUG, 0);
    return 0;
}

/*! libfuzzer entry point
 *
 * Each call receives an arbitrary byte sequence and feeds it to the HTTP/1
 * flex/bison parser.  Parse errors are expected and ignored — we are only
 * looking for crashes, heap overflows, and other sanitizer findings.
 *
 * @param[in]  data  Fuzzer-supplied byte sequence
 * @param[in]  size  Length of data
 * @retval     0     Always
 */
int
LLVMFuzzerTestOneInput(const uint8_t *data,
                       size_t         size)
{
    clixon_http1_yacc hy = {0,};
    char             *str = NULL;

    if (_fuzz_h == NULL) {
        if (fuzz_init() < 0)
            return 0;
    }

    /* Parser requires a null-terminated string */
    if ((str = malloc(size + 1)) == NULL)
        return 0;
    memcpy(str, data, size);
    str[size] = '\0';

    hy.hy_parse_string = str;
    hy.hy_name         = "fuzz";
    hy.hy_h            = _fuzz_h;
    hy.hy_linenum      = 1;

    /* Allocate output containers — grammar actions write into these */
    if ((hy.hy_header = cvec_new(0)) == NULL)
        goto done;
    if ((hy.hy_indata = cbuf_new()) == NULL)
        goto done;

    if (http1_scan_init(&hy) < 0)
        goto done;
    if (http1_parse_init(&hy) < 0) {
        http1_scan_exit(&hy);
        goto done;
    }
    clixon_http1_parseparse(&hy, hy.hy_scanner);
    http1_parse_exit(&hy);
    http1_scan_exit(&hy);

 done:
    if (hy.hy_header)
        cvec_free(hy.hy_header);
    if (hy.hy_indata)
        cbuf_free(hy.hy_indata);
    if (hy.hy_qvec)
        cvec_free(hy.hy_qvec);
    free(str);
    return 0;
}
