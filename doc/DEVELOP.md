# README for Clixon developers

  * [Code documentation](#documentation)
  * [C style](#c-style)	
  * [How to work in git (how-to-work-in-git)](#how-to-work-in-git)
  * [How the meta-configure stuff works](#meta-configure)
  * [How to debug](#debug)
  * [New release](#new-release)

## Documentation
How to document the code

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

## C style

Clixon uses 4-char indentation, a la emacs "cc-mode".

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
1. the return type of the function and all qualifers on first line (`static int`)
2. function name and first parameter on second line, thereafter each parameter on own line
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

Errors are typically declared as follows:
```
    if (myfn(0) < 0){
       clicon_err(OE_UNIX, EINVAL, "myfn");
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

### Return values

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
2. Do not use of goto:s in other ways

### Comments

Use `/* */`. Use `//` only for temporal comments.

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

## How to work in git

Clixon uses semantic versioning (https://semver.org).

Try to keep a single master branch always working. Currently testing is made using [Travis CI](https://travis-ci.org/clicon/clixon).

However, releases are made periodically (ca every 1 month) which is more tested.

A release branch can be made, eg release-4.0 where 4.0.0, 4.0.1 are tagged

Commit messages: https://chris.beams.io/posts/git-commit/

## How the autotools stuff works
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
Note: remember to run autoheader sometimes (when?)
And when you do note (https://github.com/clicon/cligen/issues/17) which states that cligen_custom.h should be in quote. 

Get config.sub and config.guess:
```
$ wget -O config.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
$ wget -O config.sub 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
```

Or generate:
```
libtoolize --force
aclocal
autoheader
automake --force-missing --add-missing
```

## Debug
How to debug

### Configure in debug mode

```
   ./configure --enable-debug
```

Send debug level in run-time to backend:
```
  echo "<rpc username=\"root\" xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><debug xmlns=\"http://clicon.org/lib\"><level>1</level></debug></rpc>]]>]]>" | clixon_netconf -q -o CLICON_NETCONF_HELLO_OPTIONAL=true
```

### Set backend debug

Using netconf:
```
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><debug xmlns="http://clicon.org/lib"><level>1</level></debug></rpc>
```

Using curl:
```
curl -Ssik -X POST -H "Content-Type: application/yang-data+json" http://localhost/restconf/operations/clixon-lib:debug -d '{"clixon-lib:input":{"level":1}}'
```

### Set restconf debug

All three must be true:
  1. clixon-restconf.yang is used (so that debug config can be set)
  2. AND the <restconf> XML is in running db not in clixon-config (so that restconf reads the new config from backend)
  3 CLICON_BACKEND_RESTCONF_PROCESS is true (so that backend restarts restconf)

Otherwise you need to restart clixon_restconf manually

Using netconf:
```
clixon_netconf -q -o CLICON_NETCONF_HELLO_OPTIONAL=true <<EOF
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><restconf xmlns="http://clicon.org/restconf"><debug>1</debug></restconf></config></edit-config></rpc>]]>]]>
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><commit/></rpc>]]>]]>
EOF
```
Using restconf/curl
```
curl -Ssik -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/clixon-restconf:restconf/debug -d '{"clixon-restconf:debug":1}' 
```

Get restconf daemon status:
```
curl -Ssik -X POST -H "Content-Type: application/yang-data+json" http://localhost/restconf/operations/clixon-lib:process-control -d '{"clixon-lib:input":{"name":"restconf","operation":"status"}}'
```

### Make your own simplified yang and configuration file.
```
cat <<EOF > /tmp/my.yang
module mymodule{
   container x {
    list y {
      key "a";
      leaf a {
        type string;
      }
    }
  }
}
EOF
cat <<EOF > /tmp/myconf.xml
<config>
  <CLICON_CONFIGFILE>/tmp/myconf.xml</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/example/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/example/example.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/example.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/example</CLICON_XMLDB_DIR>
</config>
EOF
 sudo clixon_backend -F -s init -f /tmp/myconf.xml -y /tmp/my.yang
 ```

### Run valgrind and callgrind
 ```
  valgrind --leak-check=full --show-leak-kinds=all clixon_netconf -qf /tmp/myconf.xml -y /tmp/my.yang
  LD_BIND_NOW=y valgrind --tool=callgrind clixon_netconf -qf /tmp/myconf.xml -y /tmp/my.yang
  sudo kcachegrind
  valgrind --tool=massif clixon_netconf -qf /tmp/myconf.xml -y /tmp/my.yang
  massif-visualizer
 ```

To turn callgrind off/on:
 ```
  valgrind --tool=callgrind --instr-atstart=no clixon_netconf -qf /tmp/myconf.xml -y /tmp/my.yang
  ...
  callgrind_control -i on
 ```

### valgrind and gdb

```
valgrind --vgdb=yes --vgdb-error=0 clixon_cli

gdb clixon_cli
(gdb) target remote | /usr/lib/valgrind/../../bin/vgdb --pid=1311 # see output from valgrind
(gdb) cont
```

## New release
What to think about when doing a new release.
* Ensure all tests run OK
* review CHANGELOG, write one-liner
* New yang/clicon/clixon-config@XXX.yang revision?
* In configure.ac, for minor releases change CLIXON_VERSION in configure.ac to eg: (minor should have been bumped):
```
  CLIXON_VERSION="\"${CLIXON_VERSION_MAJOR}.${CLIXON_VERSION_MINOR}.${CLIXON_VERSION_PATCH}\""
```
* For patch releases change CLIXON_VERSION_PATCH
* Run autoconf
* Git stuff:
```
  git tag -a <version>
  git push origin <version>
```
* Add a github "release" and copy release info from CHANGELOG

After release:
* Bump minor version and add a "PRE":
```
  CLIXON_VERSION_MINOR="10" ++
  CLIXON_VERSION="\"${CLIXON_VERSION_MAJOR}.${CLIXON_VERSION_MINOR}.${CLIXON_VERSION_PATCH}.PRE\""
```
* Run autoconf

Create release branch:
```
  git checkout -b release-4.2 4.2.0
  git push origin release-4.2
```

Merge a branch back:
```
  git merge --no-ff release-4.2
```

## Use of constants etc

Use MAXPATHLEN (not PATH_MAX) in sys/param.h

## Emulating a serial console

socat PTY,link=/tmp/clixon-tty,rawer EXEC:"/usr/local/bin/clixon_cli -f /usr/local/etc/example.xml",pty,stderr &
screen /tmp/clixon-tty

## Coverage

```
LDFLAGS=-coverage LINKAGE=static CFLAGS="-O2 -Wall -coverage" ./configure
bash <(curl -s https://codecov.io/bash) -t <token>
```

## Static analysis

```
sudo apt install clang-tools # on ubuntu
scan-build ./configure --enable-debug
scan-build make
scan-view /tmp/scan-build-2022-02-03-100113-27646-1 # example
```
