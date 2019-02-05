#!/bin/bash
# Load yang files. Test the different options 
# CLICON_YANG_MODULE_DIR vs CLICON_YANG_MAIN_FILE vs CLICON_YANG_MAIN_DIR
# as well as revisions
# Test is made by having different config files and then try to set configure
# options available in specific modules
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang1=$dir/$APPNAME@2018-12-02.yang
fyang2=$dir/$APPNAME@2018-01-01.yang
fyang3=$dir/other.yang

# 1st variant of the example module
cat <<EOF > $fyang1
module example{
  prefix ex;
  revision 2018-12-02;
  namespace "urn:example:clixon";
  leaf newex{
    type string;
  }
}
EOF

# 2nd variant of the same example module
cat <<EOF > $fyang2
module example{
  prefix ex;
  revision 2018-01-01;
  namespace "urn:example:clixon";
  leaf oldex{
    type string;
  }
}
EOF

# Other module
cat <<EOF > $fyang3
module other{
  prefix oth;
  revision 2018-01-01;
  namespace "urn:example:clixon2";
  leaf other{
    type string;
  }
}
EOF

#---------------------------------
new "1. Load module as file"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang1</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
</config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg"
    sudo $clixon_backend -s init -f $cfg -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "1. Set newex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set oldex should fail (since oldex is in old revision and only the new is loaded)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>oldex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Set other should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>other</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend

#--------------------------------------
new "2. Load old module as file"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang2</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
</config>
EOF

new "start backend  -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
fi

new "Set oldex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set newex should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>newex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Set other should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>other</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend

#--------------------------------------
new "3. Load module with no revision"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "start backend  -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
fi

new "Set newex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set oldex should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>oldex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Set other should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>other</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend

#--------------------------------------
new "4. Load module with old revision"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_YANG_MODULE_REVISION>2018-01-01</CLICON_YANG_MODULE_REVISION>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "start backend  -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
fi

new "Set oldex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set newex should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>newex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Set other should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>other</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend

#--------------------------------------
new "5. Load dir"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "start backend  -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
fi

new "Set newex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set oldex should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>oldex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Set other"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>'  '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend

#--------------------------------------
new "6. Load dir override with file"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang2</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "start backend  -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
fi

new "Set oldex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set newex should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>newex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>'

new "Set other"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>'  '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend


#--------------------------------------
new "7. Load dir override with module + revision"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_YANG_MODULE_REVISION>2018-01-01</CLICON_YANG_MODULE_REVISION>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "start backend  -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
fi

new "Set oldex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set newex should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>newex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Set other"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>'  '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend

#--------------------------------------
new "8. Load module w new revision overrided by old file"
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang2</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_YANG_MODULE_REVISION>2018-12-02</CLICON_YANG_MODULE_REVISION>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "start backend  -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
fi

new "Set oldex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><oldex xmlns="urn:example:clixon">str</oldex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Set newex should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><newex xmlns="urn:example:clixon">str</newex></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>newex</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Set other should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><other xmlns="urn:example:clixon2">str</other></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>other</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi
sudo pkill -u root -f clixon_backend

rm -rf $dir
