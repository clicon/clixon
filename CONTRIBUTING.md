# Contributing clixon code

The clixon project welcomes contributions from the community.

Contributions are best done posting issues and pull requests. Discussions are welcome on the Matrix clixon forum https://matrix.to/#/#clixonforum:matrix.org.

## Licensing

A contribution must follow the [CLIXON licensing](https://github.com/clicon/clixon/blob/master/LICENSE.md)
with the dual licensing: either Apache License, Version 2.0 or
GNU General Public License Version 3.

Note especially, the contribution license agreement (CLA) is described in the CLA section of the Apache License, Version 2.0.

## C style

Clixon uses 4-char space indentation.

### Function declarations

Functions in C code are written as follows:
```
static int
myfn(int           par1,
     my_structure *par2)
{
    int           retval = -1;
    my_structure *ms;

    ms = NULL;
```
Notes:
1. The return type of the function and all qualifers on first line (`static int`)
2. Function name and first parameter on second line, thereafter each parameter on own line
3. Each parameter indented to match the "longest" (`my_structure`)
4. Pointer declarations written: `type *p`, not: `type* p`.
5. All local variables in a function declared at top of function, not inline with C-statements.
6. Local variables can be initialized with scalars or constants, not eg malloc or functions with return values that need to be  checked for errors
7. There is a single empty line between local variable declarations and the first function statement.

Function signatures are declared in include files or in forward declaration using "one-line" syntax, unless very long:
```
static int myfn(int par1, my_structure *par2);
```

### Errors

Error handling follows the "fail early and loud" principle. That is, unless a specific error-handling
is identified, exit as soon as possible and with an explicit error log.

Errors are typically declared as follows:
```
    if (myfn(0) < 0){
       clixon_err(OE_UNIX, EINVAL, "myfn");
       goto done;
    }
```

All function returns that have return values must be checked

Default return values form a function are:
- `0`  OK
- `-1` Fatal Error

In some cases, Clixon uses three-value returns as follows:
- `1`  OK
- `0`  Invalid
- `-1` Fatal error

### Return values and goto:s

Clixon uses goto:s only to get a single point of exit functions as follows:
```
{
    int retval = -1;

    ...
    retval = 0;
  done:
    return retval
}
```

Notes:
1. Use only a single return statement in a function
2. Do not use goto:s in other ways

### Comments

Use `/* */`. Use `//` only for temporary comments.

Do not use "======", ">>>>>" or "<<<<<<" in comments since git merge conflict uses that.

### Format ints

Use:

- %zu for size_t
- PRIu64 for uint64
- %p for pointers

### Include files

Avoid include statements in .h files, place them in .c files whenever possible.

The reason is to avoid deep include chains where file dependencies are
difficult to analyze and understand. If include statements are only placed in .c
files, there is only a single level of include file dependencies.

The drawback is that the same include file may need to be repeated in many .c files.

### Structs

Struct fields should have a prefix to distinguish them from other struct fields. The prefix should use an abbreviation of the struct name.

Example:
```
  struct my_struct{
    int   ms_foo;
    char *ms_string[42];
  }
```
where `ms_` is the prefix and is an abbreviation of `my_struct`.

### Global variables

Try to avoid global variables.

If you absolutely need a global variable, try to contain it as static within a
single C-file, ie do not declare it extern and do not use it in other files.

Also, always prepend a global variable with `_`, underscore.

## Testing

For a new feature, it is important to write (or extend) [a clixon test](https://github.com/clicon/clixon/blob/master/test/README.md), including some functionality tests and preferably some negative tests. Tests are then run automatically as regression on commit [by github actions](https://github.com/clicon/clixon/actions/).

These tests are also the basis for more extensive CI tests run by the project which
include:
- [Memory tests](https://github.com/clicon/clixon/tree/master/test#memory-leak-test), using Valgrind. Running the .mem.sh for cli, backend,netconf and restconf is mandatory.
- [Vagrant tests on other operating systems](https://github.com/clicon/clixon/tree/master/test/vagrant). Other OS:s include ubuntu, centos and freebsd
- [CI on other platforms](https://github.com/clicon/clixon/tree/master/test/cicd). Other platforms include x86-64, 32-bit i686, and armv71
- [Coverage tests](https://app.codecov.io/gh/clicon/clixon)
- [Fuzzing](https://github.com/clicon/clixon/tree/master/test/fuzz) Fuzzing are run occasionally using AFL

## Optimization

Optimizating Clixon code should be based on an observable improvement
of measurements of cycles or memory usage.

Usually, new clixon code starts out with functional compliance
with appropriate regression tests.

Therafter "non-functional" analysis, including performance tests can
be made. Performance improvements should be based on specific usecase
and actual measurement. The benefit of an optimization should
be larger than a potential increase of complexity.

## How to document the code

```
/*! This is a small comment on one line
 *
 * This is a detailed description
 * spanning several lines.
 *
 * Example usage:
 * @code
 *   fn(a, &b);
 * @endcode
 *
 * @param[in]     src     This is a description of the first parameter
 * @param[in,out] dest    This is a description of the second parameter
 * @retval        0       This is a description of the return value
 * @retval       -1       This is a description of another return value
 * @see                   See also this function
 */
```
