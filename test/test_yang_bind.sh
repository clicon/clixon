#!/usr/bin/env bash
# Check how XML/JSON associates to YANG spec in different situations
# In more detail, xml/json usually goes through these steps:
# 1. Parse syntax, eg map JSON/XML concrete syntax to cxobj trees
# 2. Populate/match cxobj tree X with yang statements, ie bind each cxobj node to yang_stmt nodes
#   a. X is a top-level node (XML and JSON)
#   b. X is a not a top-level node (XML and JSON)
# 3. Sort children
# 4. Validation (optional)
# These tests are for cases 2a and 2b primarily. They occur somewhat differently in XML and JSON.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml:="clixon_util_xml"}
: ${clixon_util_json:="clixon_util_json"}

APPNAME=example

cfg=$dir/conf_match.xml
fyang=$dir/match.yang
fxml=$dir/x.xml
fjson=$dir/x.json
ftop=$dir/top.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir_tmp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

cat <<EOF > $fyang
module match{
   yang-version 1.1;
   prefix m;

   namespace "urn:example:match";
   container a {
      description "Top level";
      presence true;
      list a {
         description "Note same as parent to catch false positives 2a/2b";
         key k;
         leaf k{
	    type uint32;
	 }
      }
      anyxml any;
   }
}
EOF

new "test params: -f $cfg"

cat <<EOF > $ftop
    <a xmlns="urn:example:match"><a><k>0</k></a></a>
EOF

cat <<EOF > $fxml
   <a xmlns="urn:example:match"><a><k>43</k></a></a>
EOF

new "2a XML Add a/a/k on top"
expectpart "$($clixon_util_xml -vy $fyang -f $fxml)" 0 '^$'

# Subtree without namespace (maybe shouldnt work?)
cat <<EOF > $fxml
   <a><k>42</k></a>
EOF
new "2b XML Add a/k under a without namespace"
expectpart "$($clixon_util_xml -vy $fyang -f $fxml -t $ftop -T m:a)" 0 '^$'

# Subtree with namespace
cat <<EOF > $fxml
   <a xmlns="urn:example:match"><k>42</k></a>
EOF

new "2b XML Add a/k under a"
expectpart "$($clixon_util_xml -vy $fyang -f $fxml -t $ftop -T m:a)" 0 '^$'

new "XML Add a/k on top, should fail"
expectpart "$($clixon_util_xml -vy $fyang -f $fxml 2> /dev/null)" 255 '^$'

cat <<EOF > $fxml
   <a xmlns="urn:example:match"><a><k>43</k></a></a>
EOF
new "2b XML Add a/a/k under a should fail"
expectpart "$($clixon_util_xml -vy $fyang -f $fxml -t $ftop -T m:a 2> /dev/null)" 255 '^$'

# Anyxml
cat <<EOF > $fxml
   <any xmlns="urn:example:match"><kalle>hej</kalle></any>
EOF
new "XML Add any under a"
expectpart "$($clixon_util_xml -vy $fyang -f $fxml -t $ftop -T m:a)" 0 '^$'

cat <<EOF > $fxml
   <a xmlns="urn:example:match"><any><kalle>hej</kalle></any></a>
EOF

new "XML Add any on top"
expectpart "$($clixon_util_xml -vy $fyang -f $fxml)" 0 '^$'

# OK, same thing with JSON!

cat <<EOF > $fjson
   {"match:a":{"a":{"k":43}}}
EOF

new "2a JSON Add a/a/k on top"
expectpart "$($clixon_util_xml -Jvy $fyang -f $fjson)" 0 '^$'


# Subtree with namespace
cat <<EOF > $fjson
   {"match:a":{"k":43}}
EOF

new "2b JSON Add a/k under a"
expectpart "$($clixon_util_xml -Jvy $fyang -f $fjson -t $ftop -T m:a)" 0 '^$'

new "JSON Add a/k on top, should fail"
expectpart "$($clixon_util_xml -Jvy $fyang -f $fjson 2> /dev/null)" 255 '^$'

cat <<EOF > $fjson
   {"match:a":{"a":{"k":43}}}
EOF
new "2b JSON Add a/a/k under a should fail"
expectpart "$($clixon_util_xml -Jvy $fyang -f $fjson -t $ftop -T m:a 2> /dev/null)" 255 '^$'

# Anyxml
cat <<EOF > $fjson
   {"match:any":{"kalle":"hej"}}
EOF
new "JSON Add any under a"
expectpart "$($clixon_util_xml -Jvy $fyang -f $fjson -t $ftop -T m:a)" 0 '^$'

cat <<EOF > $fjson
   {"match:a":{"any":{"kalle":"hej"}}}
EOF

new "JSON Add any on top"
expectpart "$($clixon_util_xml -Jvy $fyang -f $fjson)" 0 '^$'

rm -rf $dir

new "endtest"
endtest
