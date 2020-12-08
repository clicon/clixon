#!/usr/bin/env bash
# Tests for using autocli extension defined in clixon-lib
# This is both a test of yang extensions and autocli
# The extension is autocli-op and can take the value "hide" (maybe more)
# Try both inline and augmented mode
# @see https://clixon-docs.readthedocs.io/en/latest/misc.html#extensions
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

fin=$dir/in
cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
fyang2=$dir/$APPNAME-augment.yang
clidir=$dir/cli
if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_GENMODEL>2</CLICON_CLI_GENMODEL>
  <CLICON_CLI_GENMODEL_TYPE>VARS</CLICON_CLI_GENMODEL_TYPE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF


cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);{
      xml("Show configuration as XML"), cli_auto_show("datamodel", "candidate", "xml", false, false);
}
}
EOF

# Yang specs must be here first for backend. But then the specs are changed but just for CLI
# Annotate original Yang spec example  directly
# First annotate /table/parameter 
cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  import clixon-lib{
      prefix cl;
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      cl:autocli-op hide; /* This is the extension */
      leaf value{
        description "a value";
        type string;
      }
      list index{
        key i;
	leaf i{
	  type string;
	}
	leaf iv{
          type string;
        }
      }
    }
  }
}
EOF

# Original no annotations for backend
cat <<EOF > $fyang2
module example-augment {
   namespace "urn:example:augment";
   prefix aug;
   import example{
      prefix ex;
   }
   import clixon-lib{
      prefix cl;
   }
}
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg

    new "waiting"
    wait_backend
fi

testparam()
{

    # Try hidden parameter list
    new "query table parameter hidden"
    expectpart "$(echo "set table ?" | $clixon_cli -f $cfg 2>&1)" 0 "set table" "<cr>" --not-- "parameter"

    cat <<EOF > $fin
set table parameter x
show config xml
EOF
    new "set table parameter hidden"
    expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "set table parameter x" "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name></parameter></table>" 

}

testvalue()
{
    # Try not hidden parameter list
    new "query table parameter hidden"
    expectpart "$(echo "set table ?" | $clixon_cli -f $cfg 2>&1)" 0 "set table" "<cr>" "parameter"

    # Try hidden value
    new "query table leaf"
    expectpart "$(echo "set table parameter x ?" | $clixon_cli -f $cfg 2>&1)" 0 "index" "<cr>" --not-- "value"

    cat <<EOF > $fin
set table parameter x value 42
show config xml
EOF
    new "set table parameter hidden leaf"
    expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value>42</value></parameter></table>"

}

# INLINE MODE

new "Test hidden parameter in table/param inline"
testparam

# Second annotate /table/parameter/value
cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  import clixon-lib{
      prefix cl;
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      leaf value{
        cl:autocli-op hide;  /* Here is the example */
        description "a value";
        type string;
      }
      list index{
        key i;
	leaf i{
	  type string;
	}
	leaf iv{
          type string;
        }
      }
    }
  }
}
EOF

new "Test hidden parameter in table/param/value inline"
testvalue

# AUGMENT MODE
# Here use a new yang module that augments, keep original example intact
cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      leaf value{
        description "a value";
        type string;
      }
      list index{
        key i;
	leaf i{
	  type string;
	}
	leaf iv{
          type string;
        }
      }
    }
  }
}
EOF

# First annotate /table/parameter 
cat <<EOF > $fyang2
module example-augment {
   namespace "urn:example:augment";
   prefix aug;
   import example{
      prefix ex;
   }
   import clixon-lib{
      prefix cl;
   }
   augment "/ex:table/ex:parameter" {
      cl:autocli-op hide;
   }
}
EOF


new "Test hidden parameter in table/param augment"
testparam

# Try hidden specific parameter key (note only cli yang)
# Second annotate /table/parameter/value
cat <<EOF > $fyang2
module example-augment {
   namespace "urn:example:augment";
   prefix aug;
   import example{
      prefix ex;
   }
   import clixon-lib{
      prefix cl;
   }
   augment "/ex:table/ex:parameter/ex:value" {
      cl:autocli-op hide;
   }
}
EOF

new "Test hidden parameter in table/param/value augment"
testvalue

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
