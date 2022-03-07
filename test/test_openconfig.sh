#!/usr/bin/env bash
# Parse "all" openconfig yangs from https://github.com/openconfig/public
# Notes:
# Notes:
# - A simple smoketest (CLI check) is made, essentially YANG parsing. 
#    - A full system is worked on
# - Env-var OPENCONFIG should point to checkout place. (define it in site.sh for example)
# - Env variable IETFRFC should point to checkout place, derived from YANG_STANDARD_DIR config option
# - Some DIFFs are necessary in yangmodels
#         release/models/wifi/openconfig-ap-interfaces.yang

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml

new "openconfig"
if [ ! -d "$OPENCONFIG" ]; then
#    err "Hmm Openconfig dir does not seem to exist, try git clone https://github.com/openconfig/public?"
    echo "...skipped: OPENCONFIG not set"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# OPENCONFIG dir has a small number of extra yangs apart from OCDIR
OCDIR=$OPENCONFIG/release/models

files=$(find ${OPENCONFIG} -name "*.yang")

# Count nr of modules (exclude submodule) Assume "module" or "submodule"
# first word on first line
let ms=0; # Nr of modules
let ss=0; # Nr of smodules
for f in $files; do
    let m=0; # Nr of modules
    let s=0; # Nr of modules
    if [ -n "$(head -15 $f|grep '^[ ]*module')" ]; then
	let m++;
	let ms++;
    elif [ -n "$(head -15 $f|grep '^[ ]*submodule')" ]; then
	let s++;
	let ss++;
    else
	echo "No module or submodule found $f"
	exit
    fi
    if [ $m -eq 1 -a $s -eq 1 ]; then
	echo "Double match $f"
	exit
    fi
done

new "Openconfig test: $clixon_cli -1f $cfg show version ($m modules)"
for f in $files; do
    if [ -n "$(head -1 $f|grep '^module')" ]; then
	modname=$(basename $f | awk -F "." '{print $1}')
	# Generate autocli for these modules
	AUTOCLI=$(autocli_config $modname kw-nokey false)
	
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${OPENCONFIG}</CLICON_YANG_DIR>
  <CLICON_YANG_AUGMENT_ACCEPT_BROKEN>true</CLICON_YANG_AUGMENT_ACCEPT_BROKEN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  ${AUTOCLI}
</clixon-config>
EOF

	new "$clixon_cli -D $DBG  -1f $cfg -o CLICON_YANG_MAIN_FILE=$f show version"
	expectpart "$($clixon_cli -D $DBG -1f $cfg -y $f show version)" 0 "${CLIXON_VERSION}"
    fi
done

rm -rf $dir

new "endtest"
endtest
