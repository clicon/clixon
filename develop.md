# README for developers Clixon developers

1. How to document the code
2. How to work in git (branching)
3. How the meta-configure stuff works

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
 * @param[in] src         This is a description of the first parameter
 * @param[in,out] dest    This is a description of the second parameter
 * @retval TRUE           This is a description of the return value
 * @retval FALSE          This is a description of another return value
 * @see                   See also this function
 */
```

## How to work in git (branching)

Basically follows: http://nvie.com/posts/a-successful-git-branching-model/
only somewhat simplified:

Do commits in develop branch. When done, merge with master.

## How the meta-configure stuff works
```
configure.ac --.
                    |   .------> autoconf* -----> configure
     [aclocal.m4] --+---+
                    |   `-----> [autoheader*] --> [config.h.in]
     [acsite.m4] ---'

                           .-------------> [config.cache]
     configure* ------------+-------------> config.log
                            |
     [config.h.in] -.       v            .-> [config.h] -.
                    +--> config.status* -+               +--> make*
     Makefile.in ---'                    `-> Makefile ---'
```
