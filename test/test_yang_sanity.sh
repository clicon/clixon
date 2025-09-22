#!/usr/bin/env bash
# Test some yang sanity cases:
# 1) circular includes is OK
# 2) circular imports is not OK
# 3) Mandatory child
# 4) Wrong order
# 5) Too many

# circular inputs are ok

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fymain=$dir/main.yang
fyimport1=$dir/import1.yang
fyimport2=$dir/import2.yang
fyinclude1=$dir/include1.yang
fyinclude2=$dir/include2.yang
clispec=$dir/clispec
test -d $clispec || mkdir $clispec

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fymain</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fymain
module main{
    yang-version 1.1;
    prefix m;
    namespace "urn:example:main";
    include include1;
    import  import1{
       prefix imp1;
    }
    revision 2020-12-01;
    leaf main{
        type string;
    }
}
EOF

cat <<EOF > $fyinclude1
submodule include1{
    yang-version 1.1;
    belongs-to main {
       prefix m;
    }
    include include2;
    import  import1{
       prefix imp1;
    }
    leaf include11{
        type string;
    }
}
EOF

cat <<EOF > $fyinclude2
submodule include2{
    yang-version 1.1;
    belongs-to main{
       prefix m;
    }
    include include1; // recursive
    leaf include11{
        type string;
    }
}
EOF

cat <<EOF > $fyimport1
module import1{
    yang-version 1.1;
    prefix imp1;
    namespace "urn:example:import1";
    import import2{
       prefix imp2;
    }
    leaf import1{
        type string;
    }
}
EOF

cat <<EOF > $fyimport2
module import2 {
    yang-version 1.1;
    prefix imp2;
    namespace "urn:example:import2";
/*
    import import1{
        prefix imp1;
    }
*/
    leaf import2{
        type string;
    }
}
EOF
cat <<EOF > $clispec/example.cli
CLICON_MODE="example";
CLICON_PROMPT="cli> ";

# Reference generated data model
set @datamodel, cli_set();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_config("candidate", "text");
    version("Show version"), cli_show_version("candidate", "text", "/");
    xpath("Show configuration") <xpath:string>("XPATH expression") <ns:string>("Namespace"), show_conf_xpath("candidate");
    yang("Show yang specs"), show_yang(); {
        example("Show example yang spec"), show_yang("example");
    }
}
EOF

new "test params: -f $cfg"

new "baseline, circular include is ok"
expectpart "$(sudo $clixon_backend -s init -1 -f $cfg -l o)" 0 "Terminated" --not-- "Error"

# Circular imports
cat <<EOF > $fyimport2
module import2 {
    yang-version 1.1;
    prefix imp2;
    namespace "urn:example:import2";
    import import1{
        prefix imp1;
    }
    leaf import2{
        type string;
    }
}
EOF
new "circular imports is not ok"
expectpart "$(sudo $clixon_backend -s init -1 -f $cfg -l o)" 255 "import is circular"

cat <<EOF > $fyimport2
module import2 {
    yang-version 1.1;
    prefix imp2;
//    namespace "urn:example:import2";
    leaf import2{
        type string;
    }
}
EOF

new "Mandatory child: No namespace in module"
expectpart "$(sudo $clixon_backend -s init -1 -f $cfg -l o)" 255 "\"namespace\" is missing but is mandatory child of \"module\""

cat <<EOF > $fyimport2
module import2 {
    yang-version 1.1;
    yang-version 1.1;
    prefix imp2;
    leaf import2{
        type string;
    }
    namespace "urn:example:import2";}
EOF

new "Wrong order"
expectpart "$(sudo $clixon_backend -s init -1 -f $cfg -l o)" 255 "\"namespace\"(urn:example:import2) which is child of \"module\"(import2) is not in correct order"

cat <<EOF > $fyimport2
module import2 {
    yang-version 1.1;
    yang-version 1.1;
    prefix imp2;
    namespace "urn:example:import2";
    leaf import2{
        type string;
    }
}
EOF

new "Too many"
expectpart "$(sudo $clixon_backend -s init -1 -f $cfg -l o)" 255 "\"module\" has 2 children of type \"yang-version\", but only 1 allowed"

rm -rf "$dir"

new "endtest"
endtest
