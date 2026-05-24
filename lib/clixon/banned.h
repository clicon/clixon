/*
 * banned.h - Prohibit use of unsafe C functions at compile time.
 *
 * Include this header LAST among all #include statements in each .c file
 * (after all system and clixon includes). Any use of a banned function
 * in a function body will produce a compile error.
 *
 * Generated files (parser .tab.c, lex.*.c) are excluded.
 *
 * Safe alternatives:
 *   strcpy  -> memcpy (when length is known)
 *   strcat  -> manual append with snprintf or explicit memcpy
 *   sprintf -> snprintf
 *   vsprintf -> vsnprintf
 *   gets    -> fgets
 *   system  -> fork + execv (see clixon_proc.c)
 */

#ifdef __GNUC__

#undef strcpy
#define strcpy(d, s)   _Pragma("GCC error \"strcpy is banned: use memcpy\"")

#undef strcat
#define strcat(d, s)   _Pragma("GCC error \"strcat is banned: use snprintf or explicit memcpy\"")

#undef sprintf
#define sprintf(...)   _Pragma("GCC error \"sprintf is banned: use snprintf\"")

#undef vsprintf
#define vsprintf(...)  _Pragma("GCC error \"vsprintf is banned: use vsnprintf\"")

#undef gets
#define gets(s)        _Pragma("GCC error \"gets is banned: use fgets\"")

#undef system
#define system(s)      _Pragma("GCC error \"system is banned: use fork + execv (see clixon_proc.c)\"")

#endif /* __GNUC__ */
