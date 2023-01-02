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
 */

#ifdef HAVE_CONFIG_H
#include "clixon_config.h"
#endif

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>

#include <cligen/cligen.h>

/* clicon */
#include "clixon_queue.h"
#include "clixon_string.h"
#include "clixon_err.h"

/*! Split string into a vector based on character delimiters. Using malloc
 *
 * The given string is split into a vector where the delimiter can be
 * _any_ of the characters in the specified delimiter string. 
 *
 * The vector returned is one single memory block that must be freed
 * by the caller
 *
 * @code
 *   char **vec = NULL;
 *   char  *v;
 *   int    nvec;
 *   if ((vec = clicon_strsep("/home/user/src/clixon", "/", &nvec)) == NULL)
 *     err;
 *   for (i=0; i<nvec; i++){
 *     v = vec[i]; 
 *     ...
 *   }
 *   free(vec); 
 * @endcode
 * @param[in]   string     String to be split
 * @param[in]   delim      String of delimiter characters
 * @param[out]  nvec       Number of entries in returned vector
 * @retval      vec        Vector of strings. NULL terminated. Free after use
 * @retval      NULL       Error * 
 * @see clicon_strsplit
 */
char **
clicon_strsep(char *string, 
              char *delim, 
              int  *nvec0)
{
    char **vec = NULL;
    char  *ptr;
    char  *p;
    int   nvec = 1;
    int   i;
    size_t siz;
    char *s;
    char *d;
    
    if ((s = string)==NULL)
        goto done;
    while (*s){
        if ((d = index(delim, *s)) != NULL)
            nvec++;
        s++;
    }
    /* alloc vector and append copy of string */
    siz = (nvec+1)* sizeof(char*) + strlen(string)+1;
    if ((vec = (char**)malloc(siz)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc"); 
        goto done;
    } 
    memset(vec, 0, siz);
    ptr = (char*)vec + (nvec+1)* sizeof(char*); /* this is where ptr starts */
    strcpy(ptr, string);
    i = 0;
    while ((p = strsep(&ptr, delim)) != NULL)
        vec[i++] = p;
    *nvec0 = nvec;
 done:
    return vec;
}

/*! Concatenate elements of a string array into a string. 
 * An optional delimiter string can be specified which will be inserted betwen 
 * each element. 
 * @retval  str   Joined string. Free after use.
 * @retval  NULL  Failure
 */
char *
clicon_strjoin(int         argc, 
               char      **argv, 
               char       *delim)
{
    int i;
    int len;
    char *str;

    len = 0;
    for (i = 0; i < argc; i++)
        len += strlen(argv[i]);
    if (delim)
        len += (strlen(delim) * argc);
    len += 1; /* '\0' */
    if ((str = malloc(len)) == NULL)
        return NULL;
    memset(str, '\0', len);
    for (i = 0; i < argc; i++) {
        if (i != 0)
            strncat(str, delim, len - strlen(str));
        strncat(str, argv[i], len - strlen(str));
    }
    return str;
}

/*! Join two string with delimiter.
 * @param[in] str1   string 1 (will be freed) (optional)
 * @param[in] del    delimiter string (not freed) cannot be NULL (but "")
 * @param[in] str2   string 2 (not freed) mandatory
 * @see clicon_strjoin
 * This is somewhat of a special case.
 */
char*
clixon_string_del_join(char *str1,
                       char *del,
                       char *str2)
{
    char *str;
    int   len;
    
    if (str2 == NULL){
        clicon_err(OE_UNIX, EINVAL, "str2 is NULL");
        return NULL;
    }
    len = strlen(str2) + 1;
    if (str1)
        len += strlen(str1);
    len += strlen(del);
    if ((str = malloc(len)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc");
        return NULL;
    }
    if (str1){
        snprintf(str, len, "%s%s%s", str1, del, str2);
        free(str1);
    }
    else
        snprintf(str, len, "%s%s", del, str2);
    return str;
}

/*! Split a string once into two parts: prefix and suffix
 * @param[in]  string
 * @param[in]  delim
 * @param[out] prefix  If non-NULL, return malloced string, or NULL.
 * @param[out] suffix  If non-NULL, return malloced identifier.
 * @retval     0       OK
 * @retval    -1       Error
 * @code
 *    char      *a = NULL;
 *    char      *b = NULL;
 *    if (clixon_strsplit(nodeid, ':', &a, &b) < 0)
 *       goto done;
 *    if (a)
 *       free(a);
 *    if (b)
 *       free(b);
 * @note caller need to free prefix and suffix after use
 * @see clicon_strsep  not just single split
 */
int
clixon_strsplit(char     *string,
                const int delim,
                char    **prefix,
                char    **suffix)
{
    int   retval = -1;
    char *str;
    
    if ((str = strchr(string, delim)) == NULL){
        if (suffix && (*suffix = strdup(string)) == NULL){
            clicon_err(OE_YANG, errno, "strdup");
            goto done;
        }
    }
    else {
        if (prefix){
            if ((*prefix = strdup(string)) == NULL){
                clicon_err(OE_YANG, errno, "strdup");
                goto done;
            }
            (*prefix)[str-string] = '\0';
        }
        str++;
        if (suffix && (*suffix = strdup(str)) == NULL){
            clicon_err(OE_YANG, errno, "strdup");
            goto done;
        }
    }
    retval = 0;
 done:
    return retval;
}

static int
uri_unreserved(unsigned char in)
{
    switch(in) {
    case '0': case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
    case 'a': case 'b': case 'c': case 'd': case 'e':
    case 'f': case 'g': case 'h': case 'i': case 'j':
    case 'k': case 'l': case 'm': case 'n': case 'o':
    case 'p': case 'q': case 'r': case 's': case 't':
    case 'u': case 'v': case 'w': case 'x': case 'y': case 'z':
    case 'A': case 'B': case 'C': case 'D': case 'E':
    case 'F': case 'G': case 'H': case 'I': case 'J':
    case 'K': case 'L': case 'M': case 'N': case 'O':
    case 'P': case 'Q': case 'R': case 'S': case 'T':
    case 'U': case 'V': case 'W': case 'X': case 'Y': case 'Z':
    case '-': case '.': case '_': case '~':
        return 1;
    default:
        break;
    }
    return 0;
}

/*! Percent encoding according to RFC 3986 URI Syntax
 * @param[out]  encp   Encoded malloced output string
 * @param[in]   fmt    Not-encoded input string (stdarg format string)
 * @param[in]   ...    stdarg variable parameters
 * @retval      0      OK
 * @retval     -1      Error
 * @code
 *  char *enc;
 *  if (uri_percent_encode(&enc, "formatstr: <>= %s", "substr<>") < 0)
 *    err;
 *  if(enc)
 *    free(enc);
 * @endcode
 * @see RFC 3986 Uniform Resource Identifier (URI): Generic Syntax
 * @see uri_percent_decode
 * @see xml_chardata_encode
 */
int
uri_percent_encode(char **encp, 
                   const char *fmt, ...)
{
    int     retval = -1;
    char   *str = NULL;  /* Expanded format string w stdarg */
    char   *enc = NULL;
    int     fmtlen;
    size_t  len;
    int     i, j;
    va_list args;

    /* Two steps: (1) read in the complete format string */
    va_start(args, fmt); /* dryrun */
    fmtlen = vsnprintf(NULL, 0, fmt, args) + 1;
    va_end(args);
    if ((str = malloc(fmtlen)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memset(str, 0, fmtlen);
    va_start(args, fmt); /* real */
    fmtlen = vsnprintf(str, fmtlen, fmt, args) + 1;
    va_end(args);
    /* Now str is the combined fmt + ... */

    /* Step (2) encode and expand str --> enc */
    /* This is max */
    len = strlen(str)*3+1;
    if ((enc = malloc(len)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc"); 
        goto done;
    }
    memset(enc, 0, len);
    len = strlen(str);
    j = 0;
    for (i=0; i<len; i++){
        if (uri_unreserved(str[i]))
            enc[j++] = str[i];
        else{
            snprintf(&enc[j], 4, "%%%02X", str[i]&0xff);
            j += 3;
        }
    }
    *encp = enc;
    retval = 0;
 done:
    if (str)
        free(str);
    if (retval < 0 && enc)
        free(enc);
    return retval;
}

/*! Percent decoding according to RFC 3986 URI Syntax
 * @param[in]   enc    Encoded input string     
 * @param[out]  strp   Decoded malloced output string. Deallocate with free()
 * @retval      0      OK
 * @retval     -1      Error
 * @see RFC 3986 Uniform Resource Identifier (URI): Generic Syntax
 * @see uri_percent_encode
 */
int
uri_percent_decode(char  *enc, 
                   char **strp)
{
    int   retval = -1;
    char *str = NULL;
    int   i, j;
    char  hstr[3];
    size_t len;
    char *ptr;
    
    if (enc == NULL){
        clicon_err(OE_UNIX, EINVAL, "enc is NULL");
        goto done;
    }
    /* This is max */
    len = strlen(enc)+1;
    if ((str = malloc(len)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc"); 
        goto done;
    }
    memset(str, 0, len);
    len = strlen(enc);
    j = 0;
    for (i=0; i<len; i++){
        if (enc[i] == '%' && strlen(enc)-i > 2 && 
            isxdigit(enc[i+1]) && isxdigit(enc[i+2])){
            hstr[0] = enc[i+1];
            hstr[1] = enc[i+2];
            hstr[2] = 0;
            str[j] = strtoul(hstr, &ptr, 16);
            i += 2;
        }
        else
            str[j] = enc[i];
        j++;
    }
    str[j++] = '\0';
    *strp = str;
    retval = 0;
 done:
    if (retval < 0 && str)
        free(str);
    return retval;
}

/*! Encode escape characters according to XML definition
 * @param[out]  encp   Encoded malloced output string
 * @param[in]   fmt    Not-encoded input string (stdarg format string)
 * @param[in]   ...    stdarg variable parameters
 * @retval      0      OK
 * @retval     -1      Error
 * @code
 *   char *encstr = NULL;
 *   if (xml_chardata_encode(&encstr, "fmtstr<>& %s", "substr<>") < 0)
 *      err;
 *   if (encstr)
 *      free(encstr);
 * @endcode
 * Essentially encode as follows:
 *     & -> "&amp;"   must
 *     < -> "&lt;"    must
 *     > -> "&gt;"    must for backward compatibility
 *     ' -> "&apos;"  may
 *     " -> "&quot;"  may
 * @see https://www.w3.org/TR/2008/REC-xml-20081126/#syntax chapter 2.6
 * @see uri_percent_encode
 * @see AMPERSAND mode in clixon_xml_parse.l, implicit decoding
 * @see xml_chardata_cbuf_append for a specialized version
 * @see xml_chardata_decode for decoding
 */
int
xml_chardata_encode(char      **escp,
                    const char *fmt,...)
{
    int     retval = -1;
    char   *str = NULL;  /* Expanded format string w stdarg */
    int     fmtlen;
    char   *esc = NULL;
    int     l;
    int     len;
    int     i, j;
    int     cdata; /* when set, skip encoding */
    va_list args;
    size_t  slen;
    
    /* Two steps: (1) read in the complete format string */
    va_start(args, fmt); /* dryrun */
    fmtlen = vsnprintf(NULL, 0, fmt, args) + 1;
    va_end(args);
    if ((str = malloc(fmtlen)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memset(str, 0, fmtlen);
    va_start(args, fmt); /* real */
    fmtlen = vsnprintf(str, fmtlen, fmt, args) + 1;
    va_end(args);
    /* Now str is the combined fmt + ... */

    /* Step (2) encode and expand str --> enc */
    /* First compute length (do nothing) */
    len = 0; cdata = 0;
    slen = strlen(str);
    for (i=0; i<slen; i++){
        if (cdata){
            if (strncmp(&str[i], "]]>", strlen("]]>")) == 0)
                cdata = 0;
            len++;
        }
        else
            switch (str[i]){
            case '&':
                len += strlen("&amp;");
                break;
            case '<':
                if (strncmp(&str[i], "<![CDATA[", strlen("<![CDATA[")) == 0){
                    len++;
                    cdata++;
                }
                else
                    len += strlen("&lt;");
                break;
            case '>':
                len += strlen("&gt;");
                break;
            default:
                len++;
            }
    }
    len++; /* trailing \0 */
    /* We know length, allocate encoding buffer  */
    if ((esc = malloc(len)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc"); 
        goto done;
    }
    memset(esc, 0, len);

    /* Same code again, but now actually encode into output buffer */
    j = 0; cdata = 0;
    slen = strlen(str);
    for (i=0; i<slen; i++){
        if (cdata){
            if (strncmp(&str[i], "]]>", strlen("]]>")) == 0){
                cdata = 0;
                esc[j++] = str[i++];
                esc[j++] = str[i++];
            }
            esc[j++] = str[i];
        }
        else
        switch (str[i]){
        case '&':
            if ((l=snprintf(&esc[j], 6, "&amp;")) < 0){
                clicon_err(OE_UNIX, errno, "snprintf");
                goto done;
            }
            j += l;
            break;
        case '<':
            if (strncmp(&str[i], "<![CDATA[", strlen("<![CDATA[")) == 0){
                esc[j++] = str[i];
                cdata++;
                break;
            }
            if ((l=snprintf(&esc[j], 5, "&lt;")) < 0){
                clicon_err(OE_UNIX, errno, "snprintf");
                goto done;
            }
            j += l;
            break;
        case '>':
            if ((l=snprintf(&esc[j], 5, "&gt;")) < 0){
                clicon_err(OE_UNIX, errno, "snprintf");
                goto done;
            }
            j += l;
            break;
        default:
            esc[j++] = str[i];
        }
    }
    *escp = esc;
    retval = 0;
 done:
    if (str)
        free(str);
    if (retval < 0 && esc)
        free(esc);
    return retval;
}

/*! Escape characters according to XML definition and append to cbuf
 * @param[in]   cb     CLIgen buf
 * @param[in]   str    Not-encoded input string
 * @retdata     0      OK
 * @see xml_chardata_encode for the generic function
 */
int
xml_chardata_cbuf_append(cbuf *cb,
                         char *str)
{
    int  retval = -1;
    int  i;
    int  cdata; /* when set, skip encoding */
    size_t len;

    /* The orignal of this code is in xml_chardata_encode */
    /* Step: encode and expand str --> enc */
    /* Same code again, but now actually encode into output buffer */
    cdata = 0;

    len = strlen(str);
    for (i=0; i<len; i++){
        if (cdata){
            if (strncmp(&str[i], "]]>", strlen("]]>")) == 0){
                cdata = 0;
                cbuf_append(cb, str[i++]);
                cbuf_append(cb, str[i++]);
            }
            cbuf_append(cb, str[i]);
        }
        else
        switch (str[i]){
        case '&':
            cbuf_append_str(cb, "&amp;");
            break;
        case '<':
            if (strncmp(&str[i], "<![CDATA[", strlen("<![CDATA[")) == 0){
                cbuf_append(cb, str[i]);
                cdata++;
                break;
            }
            cbuf_append_str(cb, "&lt;");
            break;
        case '>':
            cbuf_append_str(cb, "&gt;");
            break;
        default:
            cbuf_append(cb, str[i]);
        }
    }
    retval = 0;
    // done:
    return retval;
}

/*! xml decode &...; 
 *
 * @param[in]     str Input string on the form &..; with & stripped
 * @param[out]    ch  Decoded character 
 * @param[in,out] ip
 * @retval        1   OK and identified a decoding
 * @retval        0   OK No identified decoding
 * @retval       -1   Error
 */
static int
xml_chardata_decode_ampersand(char *str,
                              char *ch,
                              int  *ip)
{
    int      retval = -1;
    char    *semi;
    char    *p;
    size_t   len;
    uint32_t code;
    cbuf    *cb = NULL;
    int      ret;
    
    if ((semi = index(str, ';')) == NULL)
        goto fail;
    *semi = '\0';
    len = strlen(str);
    p = str;
    if (strcmp(p, "amp") == 0)
        *ch = '&';
    else if (strcmp(p, "lt") == 0)
        *ch = '<';
    else if (strcmp(p, "gt") == 0)
        *ch = '>';
    else if (strcmp(p, "apos") == 0)
        *ch = '\'';
    else if (strcmp(p, "quot") == 0)
        *ch = '"';
    else if (len > 0 && *p == '#'){
        p++;
        if ((cb = cbuf_new()) == NULL){
            clicon_err(OE_UNIX, errno, "parse_uint32");
            goto done;
        }
        if (len > 1 && *p == 'x'){
            cprintf(cb, "0x");
            p++;
        }
        cprintf(cb, "%s", p);
        if ((ret = parse_uint32(cbuf_get(cb), &code, NULL)) < 0){
            clicon_err(OE_UNIX, errno, "parse_uint32");
            goto done;
        }
        if (ret == 0){
            goto fail;
        }
        *ch = code;
    }
    else
        goto fail;
    *ip += len+1;
    retval = 1;
 done:
    if (cb)
        cbuf_free(cb);
    return retval;
 fail:
    retval = 0;
    if (semi)
        *semi = ';';
    goto done;
}

/*! Decode escape characters according to XML definition
 * @param[out]  decp   Decoded malloced output string
 * @param[in]   fmt    Encoded input string (stdarg format string)
 * @see xml_chardata_encode for encoding
 */
int
xml_chardata_decode(char      **decp,
                    const char *fmt,...)
{
    int     retval = -1;
    char   *str = NULL;  /* Expanded encoded format string w stdarg */
    char   *dec = NULL;
    int     fmtlen;
    va_list args;
    size_t  slen;
    int     i;
    int     j;
    char    ch;
    int     ret;

    /* Two steps: (1) read in the complete format string */
    va_start(args, fmt); /* dryrun */
    fmtlen = vsnprintf(NULL, 0, fmt, args) + 1;
    va_end(args);
    if ((str = malloc(fmtlen)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc");
        goto done;
    }
    memset(str, 0, fmtlen);
    va_start(args, fmt); /* real */
    fmtlen = vsnprintf(str, fmtlen, fmt, args) + 1;
    va_end(args);
    /* Now str is the combined fmt + ... */

    /* Step (2) decode str --> dec 
     * First allocate decoded string, encoded is always >= larger */
    slen = strlen(str);
    if ((dec = malloc(slen+1)) == NULL){
        clicon_err(OE_UNIX, errno, "malloc"); 
        goto done;
    }
    j = 0;
    memset(dec, 0, slen+1);
    for (i=0; i<slen; i++){
        ch = str[i];
        switch (ch){
        case '&':
            if ((ret = xml_chardata_decode_ampersand(&str[i+1], &ch, &i)) < 0)
                goto done;
            if (ret == 0)
                dec[j++] = str[i];
            else
                dec[j++] = ch;
            break;
        default:
            dec[j++] = str[i];
        }
    }
    *decp = dec;
    retval = 0;
 done:
    if (str)
        free(str);
    if (retval < 0 && dec)
        free(dec);
    return retval;
}


/*! Split a string into a cligen variable vector using 1st and 2nd delimiter
 * 
 * (1) Split a string into elements delimited by delim1, 
 * (2) split elements into pairs delimited by delim2, 
 * (3) Optionally URI-decode values
 * @param[in]  string String to split
 * @param[in]  delim1 First delimiter char that delimits between elements
 * @param[in]  delim2 Second delimiter char for pairs within an element
 * @param[in]  decode If set, URI decode values. The caller may want to decode, or add another level
 * @param[out] cvp    Created cligen variable vector, deallocate w cvec_free
 * @retval     0      OK
 * @retval    -1      error
 * @code
 * cvec  *cvv = NULL;
 * if (uri_str2cvec("a=b&c=d", '&', '=', 1, &cvv) < 0)
 *   err;
 * @endcode
 *
 * a=b&c=d    ->  [[a,"b"][c,"d"]
 * a&b=       ->  [[a,null][b,""]]  
 * Note difference between empty (CGV_EMPTY) and empty string (CGV_STRING)
 * XXX differentiate between error and null cvec.
 */
int
uri_str2cvec(char  *string, 
             char   delim1, 
             char   delim2, 
             int    decode,
             cvec **cvp)
{
    int     retval = -1;
    char   *s;
    char   *s0 = NULL;;
    char   *val;     /* value */
    char   *valu;    /* unescaped value */
    char   *snext; /* next element in string */
    cvec   *cvv = NULL;
    cg_var *cv;

    if ((s0 = strdup(string)) == NULL){
        clicon_err(OE_UNIX, errno, "strdup");
        goto err;
    }
    s = s0;
    if ((cvv = cvec_new(0)) ==NULL){
        clicon_err(OE_UNIX, errno, "cvec_new");
        goto err;
    }
    while (s != NULL) {
        /*
         * In the pointer algorithm below:
         * name1=val1;  name2=val2;
         * ^     ^      ^
         * |     |      |
         * s     val    snext
         */
        if ((snext = index(s, delim1)) != NULL)
            *(snext++) = '\0';
        if ((val = index(s, delim2)) != NULL){
            *(val++) = '\0';
            if (decode){
                if (uri_percent_decode(val, &valu) < 0)
                    goto err;
            }
            else
                if ((valu = strdup(val)) == NULL){
                    clicon_err(OE_UNIX, errno, "strdup");
                    goto err;
                }
            if ((cv = cvec_add(cvv, CGV_STRING)) == NULL){
                clicon_err(OE_UNIX, errno, "cvec_add");
                goto err;
            }
            while ((strlen(s) > 0) && isblank(*s))
                s++;
            cv_name_set(cv, s);
            cv_string_set(cv, valu);
            free(valu); valu = NULL;
        }
        else{
            if (strlen(s)){
                if ((cv = cvec_add(cvv, CGV_EMPTY)) == NULL){
                    clicon_err(OE_UNIX, errno, "cvec_add");
                    goto err;
                }
                cv_name_set(cv, s);
            }
        }
        s = snext;
    }
    retval = 0;
 done:
    *cvp = cvv;
    if (s0)
        free(s0);
    return retval;
 err:
    if (cvv){
        cvec_free(cvv);
        cvv = NULL;
    }
    goto done;
}

/*! Map from int to string using str2int map
 * @param[in] ms   String, integer map
 * @param[in] i    Input integer
 * @retval    str  String value
 * @retval    NULL Error, not found
 * @note linear search
 */
const char *
clicon_int2str(const map_str2int *mstab, 
               int                i)
{
    const struct map_str2int *ms;

    for (ms = &mstab[0]; ms->ms_str; ms++)
        if (ms->ms_int == i)
            return ms->ms_str;
    return NULL;
}

/*! Map from string to int using str2int map
 * @param[in] ms   String, integer map
 * @param[in] str  Input string
 * @retval    int  Value
 * @retval   -1    Error, not found
 * @see clicon_str2int_search for optimized lookup, but strings must be sorted
 */
int
clicon_str2int(const map_str2int *mstab, 
               char              *str)
{
    const struct map_str2int *ms;

    for (ms = &mstab[0]; ms->ms_str; ms++)
        if (strcmp(ms->ms_str, str) == 0)
            return ms->ms_int;
    return -1;
}

/*! Map from string to int using binary (alphatical) search
 * @param[in]  ms    String, integer map
 * @param[in]  str   Input string
 * @param[in]  low   Lower bound index
 * @param[in]  upper Upper bound index
 * @param[in]  len   Length of array (max)
 * @param[out] found Integer found (can also be negative)
 * @retval    0      Not found
 * @retval    1      Found with "found" value set.
 * @note Assumes sorted strings, tree search
 */
static int
str2int_search1(const map_str2int *mstab, 
                char              *str,
                int                low,
                int                upper,
                int                len,
                int               *found)
{
    const struct map_str2int *ms;
    int                       mid;
    int                       cmp;

    if (upper < low)
        return 0; /* not found */
    mid = (low + upper) / 2;
    if (mid >= len)  /* beyond range */
        return 0; /* not found */
    ms = &mstab[mid];
    if ((cmp = strcmp(str, ms->ms_str)) == 0){
        *found = ms->ms_int;
        return 1; /* found */
    }
    else if (cmp < 0)
        return str2int_search1(mstab, str, low, mid-1, len, found);
    else
        return str2int_search1(mstab, str, mid+1, upper, len, found);
}

/*! Map from string to int using str2int map
 * @param[in] ms   String, integer map
 * @param[in] str  Input string
 * @retval    int  Value
 * @retval   -1    Error, not found
 * @note Assumes sorted strings, tree search
 * @note -1 can not be value
 */
int
clicon_str2int_search(const map_str2int *mstab, 
                      char              *str,
                      int                len)
{
    int found;

    if (str2int_search1(mstab, str, 0, len, len, &found)) 
        return found;
    return -1; /* not found */
}

/*! Map from string to string using str2str map
 * @param[in] mstab String, string map
 * @param[in] str   Input string
 * @retval    str   Output string
 * @retval    NULL  Error, not found
 */
char*
clicon_str2str(const map_str2str *mstab, 
               char              *str)
{
    const struct map_str2str *ms;

    for (ms = &mstab[0]; ms->ms_s0; ms++)
        if (strcmp(ms->ms_s0, str) == 0)
            return ms->ms_s1;
    return NULL;
}

/*! Split colon-separated node identifier into prefix and name
 * @param[in]  node-id
 * @param[out] prefix  If non-NULL, return malloced string, or NULL.
 * @param[out] id      If non-NULL, return malloced identifier.
 * @retval     0       OK
 * @retval    -1       Error
 * @code
 *    char      *prefix = NULL;
 *    char      *id = NULL;
 *    if (nodeid_split(nodeid, &prefix, &id) < 0)
 *       goto done;
 *    if (prefix)
 *       free(prefix);
 *    if (id)
 *       free(id);
 * @note caller need to free id and prefix after use
 */
int
nodeid_split(char  *nodeid,
             char **prefix,
             char **id)
{
    return clixon_strsplit(nodeid, ':', prefix, id);
}

/*! Trim blanks from front and end of a string, return new string 
 * @param[in]  str 
 * @retval     s   Pointer into existing str after trimming blanks
 */
char *
clixon_trim(char *str)
{
    char *s = str;
    int   i;

    while (strlen(s) && isblank(s[0])) /* trim from front */
        s++;
    for (i=strlen(s)-1; i>=0; i--){ /* trim from rear */
        if (isblank(s[i]))
            s[i] = '\0';
        else
            break;
    }
    return s;
}

/*! Trim blanks from front and end of a string, return new string 
 * @param[in]  str 
 * @param[in]  trims  Characters to trim: a vector of characters
 * @retval     s      Pointer into existing str after trimming blanks
 */
char *
clixon_trim2(char *str,
             char *trims)
{
    char *s = str;
    int   i;

    while (strlen(s) && index(trims, s[0])) /* trim from front */
        s++;
    for (i=strlen(s)-1; i>=0; i--){ /* trim from rear */
        if (index(trims, s[i]))
            s[i] = '\0';
        else
            break;
    }
    return s;
}

/*! check string equals (NULL is equal) 
 * @param[in]  s1  String 1
 * @param[in]  s2  String 2
 * @retval     0   Equal
 * @retval    <0   s1 is less than s2
 * @retval    >0   s1 is greater than s2
 */
int
clicon_strcmp(char *s1, 
              char *s2)
{
    if (s1 == NULL && s2 == NULL) 
        return 0;
    if (s1 == NULL) /* empty string first */
        return -1;
    if (s2 == NULL)
        return 1;
    return strcmp(s1, s2);
}


/*! strndup() for systems without it, such as xBSD
 */
#ifndef HAVE_STRNDUP
char *
clicon_strndup(const char *str, 
               size_t      len)
{
  char *new;
  size_t slen;

  slen  = strlen(str);
  len = (len < slen ? len : slen);

  new = malloc(len + 1);
  if (new == NULL)
    return NULL;

  new[len] = '\0';
  memcpy(new, str, len);

  return new;
}
#endif /* ! HAVE_STRNDUP */

/*
 * Turn this on for uni-test programs
 * Usage: clixon_string join
 * Example compile:
 gcc -g -o clixon_string -I. -I../clixon ./clixon_string.c -lclixon -lcligen
 * Example run:
*/
#if 0 /* Test program */

static int
usage(char *argv0)
{
    fprintf(stderr, "usage:%s <string>\n", argv0);
    exit(0);
}

int
main(int argc, char **argv)
{
    int nvec;
    char **vec;
    char *str0;
    char *str1;
    int   i;

    if (argc != 2){
        usage(argv[0]);
        return 0;
    }
    str0 = argv[1];
    if ((vec = clicon_strsep(str0, " \t", &nvec)) == NULL)
        return -1;
    fprintf(stderr, "nvec: %d\n", nvec);
    for (i=0; i<nvec+1; i++)
        fprintf(stderr, "vec[%d]: %s\n", i, vec[i]);
    if ((str1 = clicon_strjoin(nvec, vec, " ")) == NULL)
        return -1;
    fprintf(stderr, "join: %s\n", str1);
    free(vec);
    free(str1);
    return 0;
}

#endif /* Test program */
