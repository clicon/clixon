# README for Clixon developers

  * [Code documentation](#documentation)
  * [How to work in git (branching)](#branching)
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

## Branching
How to work in git (branching)

Try to keep a single master branch always working. Currently testing is made using [Travis CI](https://travis-ci.org/clicon/clixon).

However, releases are made periodically (ca every 3 months) which is more tested.

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
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF
 sudo clixon_backend -F -s init -f /tmp/myconf.xml -y /tmp/my.yang
 ```

### Run valgrind and callgrind
 ```
  valgrind --leak-check=full --show-leak-kinds=all clixon_netconf -qf /tmp/myconf.xml -y /tmp/my.yang
  valgrind --tool=callgrind clixon_netconf -qf /tmp/myconf.xml -y /tmp/my.yang
  sudo kcachegrind
 ```

## New release
What to think about when doing a new release.
* run test/mem.sh
* New clixon-config.yang revision?
Tagging:
* change CLIXON_VERSION in configure.ac
* git tag -a <version"
* git push origin <version>
