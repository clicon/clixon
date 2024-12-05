/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2022 Olof Hagsand and Rubicon Communications, LLC(Netgate)
  UTF code is MIT licensed by:
  Copyright (c) 2009-2017 Dave Gamble and cJSON contributors

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
  * Clixon regular expression code for Yang type patterns following XML Schema
  * regex. 
  * Two modes: libxml2 and posix-translation
 * @see http://www.w3.org/TR/2004/REC-xmlschema-2-20041028
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <regex.h>
#include <ctype.h>

#include <cligen/cligen.h>

/* clixon */
#include "clixon_queue.h"
#include "clixon_hash.h"
#include "clixon_handle.h"
#include "clixon_yang.h"
#include "clixon_xml.h"
#include "clixon_err.h"
#include "clixon_log.h"
#include "clixon_debug.h"
#include "clixon_options.h"
#include "clixon_regex.h"

/*-------------------------- POSIX translation -------------------------*/

/* parse 4 digit hexadecimal number */
static unsigned
parse_hex4(const unsigned char *const input, unsigned int *h)
{
    size_t i = 0;

    for (i = 0; i < 4; i++) {
        /* parse digit */
        if ((input[i] >= '0') && (input[i] <= '9')) {
            *h += (unsigned int) input[i] - '0';
        } else if ((input[i] >= 'A') && (input[i] <= 'F')) {
            *h += (unsigned int) 10 + input[i] - 'A';
        } else if ((input[i] >= 'a') && (input[i] <= 'f')) {
            *h += (unsigned int) 10 + input[i] - 'a';
        } else { /* invalid */
            return -1;
        }

        if (i < 3) {
            /* shift left to make place for the next nibble */
            *h = *h << 4;
        }
    }

    return 0;
}

/* converts a UTF-16 literal to UTF-8
 * A literal can be one or two sequences of the form \uXXXX */
static unsigned char
utf16_literal_to_utf8(const unsigned char *const input, int len,
    unsigned char **output)
{
    long unsigned int codepoint = 0;
    unsigned int first_code = 0;
    const unsigned char *first_sequence = input;
    unsigned char utf8_length = 0;
    unsigned char utf8_position = 0;
    unsigned char sequence_length = 0;
    unsigned char first_byte_mark = 0;
    int retval = -1;

    if (len < 6) {
        /* input ends unexpectedly */
        goto fail;
    }

    /* get the first utf16 sequence */
    retval = parse_hex4(first_sequence + 2, &first_code);
    if (retval != 0) {
        goto fail;
    }

    /* check that the code is valid */
    if (((first_code >= 0xDC00) && (first_code <= 0xDFFF))) {
        goto fail;
    }

    /* UTF16 surrogate pair */
    if ((first_code >= 0xD800) && (first_code <= 0xDBFF)) {
        const unsigned char *second_sequence = first_sequence + 6;
        unsigned int second_code = 0;
        sequence_length = 12; /* \uXXXX\uXXXX */

        if (len < 12) {
            /* input ends unexpectedly */
            goto fail;
        }

        if ((second_sequence[0] != '\\') || (second_sequence[1] != 'u')) {
            /* missing second half of the surrogate pair */
            goto fail;
        }

        /* get the second utf16 sequence */
        retval = parse_hex4(second_sequence + 2, &second_code);
        if (retval != 0) {
            goto fail;
        }
        /* check that the code is valid */
        if ((second_code < 0xDC00) || (second_code > 0xDFFF)) {
            /* invalid second half of the surrogate pair */
            goto fail;
        }

        /* calculate the unicode codepoint from the surrogate pair */
        codepoint = 0x10000 + (((first_code & 0x3FF) << 10) | (second_code & 0x3FF));
    } else {
        sequence_length = 6; /* \uXXXX */
        codepoint = first_code;
    }

    /* encode as UTF-8
     * takes at maximum 4 bytes to encode:
     * 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx */
    if (codepoint < 0x80) {
        /* normal ascii, encoding 0xxxxxxx */
        utf8_length = 1;
    } else if (codepoint < 0x800) {
        /* two bytes, encoding 110xxxxx 10xxxxxx */
        utf8_length = 2;
        first_byte_mark = 0xC0; /* 11000000 */
    } else if (codepoint < 0x10000) {
        /* three bytes, encoding 1110xxxx 10xxxxxx 10xxxxxx */
        utf8_length = 3;
        first_byte_mark = 0xE0; /* 11100000 */
    } else if (codepoint <= 0x10FFFF) {
        /* four bytes, encoding 1110xxxx 10xxxxxx 10xxxxxx 10xxxxxx */
        utf8_length = 4;
        first_byte_mark = 0xF0; /* 11110000 */
    } else {
        /* invalid unicode codepoint */
        goto fail;
    }

    /* encode as utf8 */
    for (utf8_position = (unsigned char)(utf8_length - 1); utf8_position > 0; utf8_position--) {
        /* 10xxxxxx */
        (*output)[utf8_position] = (unsigned char)((codepoint | 0x80) & 0xBF);
        codepoint >>= 6;
    }
    /* encode first byte */
    if (utf8_length > 1) {
        (*output)[0] = (unsigned char)((codepoint | first_byte_mark) & 0xFF);
    } else {
        (*output)[0] = (unsigned char)(codepoint & 0x7F);
    }

    *output += utf8_length;

    return sequence_length;

fail:
    return 0;
}

/*! Transform from XSD regex to posix ERE
 *
 * The usecase is that Yang (RFC7950) supports XSD regular expressions but
 * CLIgen supports POSIX ERE
 * POSIX ERE regexps according to man regex(3).
 * @param[in]  xsd    Input regex string according XSD
 * @param[out] posix  Output (malloced) string according to POSIX ERE
 * @see https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#regexs
 * @see https://www.regular-expressions.info/posixbrackets.html#class translation
 * @see https://www.regular-expressions.info/xml.html
 * Translation is not complete but covers some character sequences:
 * \d decimal digit
 * \w all characters except the set of "punctuation", "separator" and 
 *    "other" characters: #x0000-#x10FFFF]-[\p{P}\p{Z}\p{C}]
 * \i letters + underscore and colon
 * \c XML Namechar, see: https://www.w3.org/TR/2008/REC-xml-20081126/#NT-NameChar
 *
 * \p{X} category escape.  the ones identified in openconfig and yang-models are: 
 *   \p{L} Letters     [ultmo]?
 *   \p{M} Marks       [nce]?
 *   \p{N} Numbers     [dlo]?
 *   \p{P} Punctuation [cdseifo]?
 *   \p{Z} Separators  [slp]?
 *   \p{S} Symbols     [mcko]?
 *   \p{O} Other       [cfon]?
 * For non-printable, \n, \t, \r see https://www.regular-expressions.info/nonprint.html
 */
int
regexp_xsd2posix(char  *xsd,
                 char **posix)
{
    int   retval = -1;
    cbuf *cb = NULL;
    char  x;
    int   i;
    int   j; /* lookahead */
    int   esc;
    int   minus = 0;
    size_t len;

    if ((cb = cbuf_new()) == NULL){
        clixon_err(OE_UNIX, errno, "cbuf_new");
        goto done;
    }
    esc=0;
    len = strlen(xsd);
    for (i=0; i<len; i++){
        x = xsd[i];
        if (esc){
            esc = 0;
            switch (x){
            case '-': /* \- is translated to -], ie must be last in bracket */
                minus++;
                break;
            case 'c': /* xml namechar */
                cprintf(cb, "[0-9a-zA-Z._:-]"); /* also interpunct */
                break;
            case 'd':
                cprintf(cb, "[0-9]");
                break;
            case 'i': /* initial */
                cprintf(cb, "[a-zA-Z_:]");
                break;
            case 'n': /* non-printable \n */
                cprintf(cb, "\n");
                break;
            case 'p': /* category escape: \p{IsCategory} */
                j = i+1;
                if (j+2 < strlen(xsd) &&
                    xsd[j] == '{' &&
                    (xsd[j+2] == '}' || xsd[j+3] == '}')){
                    switch (xsd[j+1]){
                    case 'L': /* Letters */
                        cprintf(cb, "a-zA-Z"); /* assume in [] */
                        break;
                    case 'M': /* Marks */
                        cprintf(cb, "\?!"); /* assume in [] */
                        break;
                    case 'N': /* Numbers */
                        cprintf(cb, "0-9");
                        break;
                    case 'P': /* Punctuation */
                        cprintf(cb, "a-zA-Z"); /* assume in [] */
                        break;
                    case 'Z': /* Separators */
                        cprintf(cb, "\t "); /* assume in [] */
                        break;
                    case 'S': /* Symbols */
                         /* assume in [] */
                        break;
                    case 'C': /* Others */
                         /* assume in [] */
                        break;
                    default:
                        break;
                    }
                    if (xsd[j+2] == '}')
                        i = j+2;
                    else
                        i = j+3;
                }
                /* if syntax error, just leave it */
                break;
            case 'r': /* non-printable */
                cprintf(cb, "\r");
                break;
            case 's':
                cprintf(cb, "[ \t\r\n]");
                break;
            case 'S':
                cprintf(cb, "[^ \t\r\n]");
                break;
            case 't': /* non-printable */
                cprintf(cb, "\t");
                break;
            case 'w': /* word */
                //cprintf(cb, "[0-9a-zA-Z_\\\\-]")
                cprintf(cb, "[[:alnum:]|_]");
                break;
            case 'W': /* inverse of \w */
                cprintf(cb, "[^[[:alnum:]|_]]");
                break;
            case 'u': {
                int   n;
                char utf8[4];
                char *ptr = utf8;

                n = utf16_literal_to_utf8((void*)(xsd + i - 1),
                    strlen(xsd) - i + 1, (void*)&ptr);
                if (n == 0) {
                    goto done;
                }
                cbuf_append_buf(cb, utf8, ptr - utf8);
                i += n - 2;
            }
            break;
            default:
                cprintf(cb, "\\%c", x);
                break;
            }
        }
        else if (x == '\\')
            esc++;
        else if (x == '$' && i != strlen(xsd)-1) /* Escape $ unless it is last */
            cprintf(cb, "\\%c", x);
        else if (x == ']' && minus){
            cprintf(cb, "-]");
            minus = 0;
        }
        else
            cprintf(cb, "%c", x);
    }
    if ((*posix = strdup(cbuf_get(cb))) == NULL){
        clixon_err(OE_UNIX, errno, "strdup");
        goto done;
    }
    retval = 0;
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
}

/*-------------------------- Generic API functions ------------------------*/

/*! Compilation of regular expression / pattern
 *
 * @param[in]   h       Clixon handle
 * @param[in]   regexp  Regular expression string in XSD regex format
 * @param[out]  recomp  Compiled regular expression (malloc:d, should be freed)
 * @retval      1       OK
 * @retval      0       Invalid regular expression (syntax error?)
 * @retval     -1       Error
 * @note Clixon supports Yang's XSD regexp only. But CLIgen can support both
 *       POSIX and XSD(using libxml2). But to use CLIgen's POSIX, Clixon must
 *       translate from XSD to POSIX.
 */
int
regex_compile(clixon_handle h,
              char         *regexp,
              void        **recomp)
{
    int              retval = -1;
    char            *posix = NULL;    /* Transform to posix regex */

    switch (clicon_yang_regexp(h)){
    case REGEXP_POSIX:
        if (regexp_xsd2posix(regexp, &posix) < 0)
            goto done;
        retval = cligen_regex_posix_compile(posix, recomp);
        break;
    case REGEXP_LIBXML2:
        retval = cligen_regex_libxml2_compile(regexp, recomp);
        break;
    default:
        clixon_err(OE_CFG, 0, "clicon_yang_regexp invalid value: %d", clicon_yang_regexp(h));
        break;
    }
    /* retval from fns above */
 done:
    if (posix)
        free(posix);
    return retval;
}

/*! Execution of (pre-compiled) regular expression / pattern
 *
 * @param[in]  h       Clixon handle
 * @param[in]  recomp  Compiled regular expression 
 * @param[in]  string  Content string to match
 * @retval     0       OK
 * @retval    -1       Error
 */
int
regex_exec(clixon_handle h,
           void         *recomp,
           char         *string)
{
    int   retval = -1;

    switch (clicon_yang_regexp(h)){
    case REGEXP_POSIX:
        retval = cligen_regex_posix_exec(recomp, string);
        break;
    case REGEXP_LIBXML2:
        retval = cligen_regex_libxml2_exec(recomp, string);
        break;
    default:
        clixon_err(OE_CFG, 0, "clicon_yang_regexp invalid value: %d",
                   clicon_yang_regexp(h));
        goto done;
    }
    /* retval from fns above */
 done:
    return retval;
}

/*! Free of (pre-compiled) regular expression / pattern
 *
 * @param[in]  h       Clixon handle
 * @param[in]  recomp  Compiled regular expression 
 * @retval     0       OK
 * @retval    -1       Error
 */
int
regex_free(clixon_handle h,
           void         *recomp)
{
    int   retval = -1;

    switch (clicon_yang_regexp(h)){
    case REGEXP_POSIX:
        retval = cligen_regex_posix_free(recomp);
        break;
    case REGEXP_LIBXML2:
        retval = cligen_regex_libxml2_free(recomp);
        break;
    default:
        clixon_err(OE_CFG, 0, "clicon_yang_regexp invalid value: %d", clicon_yang_regexp(h));
        goto done;
    }
    /* retval from fns above */
 done:
    return retval;
}
