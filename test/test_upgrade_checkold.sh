#!/usr/bin/env bash
# Test of CLICON_XMLDB_UPGRADE_CHECKOLD where original config in an upgrade scenario is tested,
# not just current after upgrade
# Assume read a config from startup of module A@2016 to be upgraded to A@2021 using auto-upgrade
# Using CLICON_XMLDB_UPGRADE_CHECKOLD=true try all variations of:
#   oldyang:  A@2016 exists or not
#   modstate: startupdb has correct modstate or not
#   xmlok:    startdb has the right "old" syntax or not "wrong"
# These are 8 combinations. Only one is right, others give some variants of error messages
# XXX remains to check all cases with CLICON_XMLDB_UPGRADE_CHECKOLD = false

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang1=$dir/A@2016-01-01.yang
fyang2=$dir/A@2021-01-01.yang
changelog=$dir/changelog.xml # Module revision changelog

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XML_CHANGELOG>true</CLICON_XML_CHANGELOG>
  <CLICON_XML_CHANGELOG_FILE>$changelog</CLICON_XML_CHANGELOG_FILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <!-- given as -o option in clixon_backend start: CLICON_XMLDB_UPGRADE_CHECKOLD>true</CLICON_XMLDB_UPGRADE_CHECKOLD -->
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# New yang
cat <<EOF > $fyang2
module A{
  prefix a;
  namespace "urn:example:a";
  revision 2021-01-01;
  container upgraded{
  }
}
EOF

# Changelog of example-a: 
cat <<EOF > $changelog
<changelogs xmlns="http://clicon.org/xml-changelog" xmlns:a="urn:example:a" xmlns:b="urn:example:b" >
  <changelog>
    <namespace>urn:example:a</namespace>
    <revfrom>2016-01-01</revfrom>
    <revision>2021-01-01</revision>
    <step>
      <name>0</name>
      <op>rename</op>
      <where>/a:old</where>
      <tag>"upgraded"</tag>
    </step>
  </changelog>
</changelogs>
EOF

# Arguments:
# 1: expect return xml
function testrun(){
    checkold=$1
    expectxml=$2

    new "test params: -f $cfg"

    new "start backend -D $DBG -s startup -f $cfg -q -l o"
    expectpart "$(sudo $clixon_backend -D $DBG -o CLICON_XMLDB_UPGRADE_CHECKOLD=$checkold -s startup -f $cfg -q -l e 2>&1)" 0 "$expectxml"
}

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi

let j=1
for checkold in true; do # XXX remains to check all cases with CLICON_XMLDB_UPGRADE_CHECKOLD = false
for oldyang in true false; do
    if $oldyang; then
    # create old yang
    cat <<EOF > $fyang1
module A{
  prefix a;
  namespace "urn:example:a";
  revision 2016-01-01;
  container old{
  }
}
EOF
    else
	rm -f $fyang1
    fi
    for modstate in true false; do
	if $modstate; then
	    modstatestr="<modules-state xmlns=\"urn:example:a\"><module-set-id>42</module-set-id><module><name>A</name><revision>2016-01-01</revision><namespace>urn:example:a</namespace></module></modules-state>"
	else
	    modstatestr=""
	fi
	for xml in true false; do
	    if $xml; then
		xmltag="old"
		expectxml="<error-message>Failed to find YANG spec of XML node: $xmltag with parent: config in namespace: urn:example:a</error-message>"
		if $oldyang; then
		    if $modstate; then
			expectxml="<upgraded xmlns=\"urn:example:a\"/>"
		    fi
		elif $modstate; then
		    expectxml="<error-message>Internal error: No yang files found matching \"A@2016-01-01\" in the list of CLICON_YANG_DIRs</error-message>"
		fi
	    else # xml false
		xmltag="wrong"
		expectxml="<error-message>Failed to find YANG spec of XML node: $xmltag with parent: config in namespace: urn:example:a</error-message>"
		if ! $oldyang; then
		    if $modstate; then
			expectxml="<error-message>Internal error: No yang files found matching \"A@2016-01-01\" in the list of CLICON_YANG_DIRs</error-message>"
		    fi
		fi
	    fi
	    cat <<EOF > $dir/startup_db
	    <${DATASTORE_TOP}>
	      $modstatestr
	      <$xmltag xmlns="urn:example:a"/>
	    </${DATASTORE_TOP}>
EOF
	    # Here is actual call
	    new "$j. checkold:$checkold oldyang:$oldyang modstate:$modstate xmlok:$xml"
	    testrun "$checkold" "$expectxml"
	    let j++
	done
    done
done
done
rm -rf $dir

unset j
unset xml
unset xmltag
unset oldyang
unset modstate
unset modstatestr
unset fyang1
unset fyang2

new "endtest"
endtest
