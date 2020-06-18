# README for Clixon developers

  * [Code documentation](#documentation)
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

## How to work in git

Clixon uses semantic versioning (https://semver.org).

Try to keep a single master branch always working. Currently testing is made using [Travis CI](https://travis-ci.org/clicon/clixon).

However, releases are made periodically (ca every 1 month) which is more tested.

A release branch can be made, eg release-4.0 where 4.0.0, 4.0.1 are tagged

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
Note: remember to run autoheader sometimes (when?)
And when you do note (https://github.com/olofhagsand/cligen/issues/17) which states that cligen_custom.h should be in quote. 

Get config.sub and config.guess:
$ wget -O config.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
$ wget -O config.sub 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'

## Debug
How to debug

### Configure in debug mode
```
   CFLAGS="-g -Wall" INSTALLFLAGS="" ./configure
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

## New release
What to think about when doing a new release.
* Ensure all tests run OK
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

Use MAXPATHLEN (not PATH_MAX)

## Emulating a serial console

olof@alarik> socat PTY,link=/tmp/clixon-tty,rawer EXEC:"/usr/local/bin/clixon_cli -f /usr/local/etc/example.xml",pty,stderr &
olof@alarik> screen /tmp/clixon-tty
