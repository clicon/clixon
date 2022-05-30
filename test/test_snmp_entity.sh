#!/usr/bin/env bash
# SNMP "smoketest" Basic snmpget test for a scalar

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Re-use main example backend state callbacks
APPNAME=example

if [ ${ENABLE_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

snmpd=$(type -p snmpd)
snmpget="$(type -p snmpget) -On -c public -v2c localhost "
snmpgetstr="$(type -p snmpget) -c public -v2c localhost "
snmpgetnext="$(type -p snmpgetnext) -On -c public -v2c localhost "
snmpgetnextstr="$(type -p snmpgetnext) -c public -v2c localhost "
snmptable="$(type -p snmptable) -c public -v2c localhost "
snmptranslate="$(type -p snmptranslate) "

cfg=$dir/conf_startup.xml
fyang=$dir/clixon-example.yang
fstate=$dir/state.xml

# AgentX unix socket
SOCK=/var/run/snmp.sock

# Relies on example_backend.so for $fstate file handling

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${MIB_GENERATED_YANG_DIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/var/tmp/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_SNMP_AGENT_SOCK>unix:$SOCK</CLICON_SNMP_AGENT_SOCK>
  <CLICON_SNMP_MIB>ENTITY-MIB</CLICON_SNMP_MIB>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import ENTITY-MIB {
      prefix "entity-mib";
  }
}
EOF

# This is state data written to file that backend reads from (on request)
# integer and string have values, sleeper does not and uses default (=1)

cat <<EOF > $fstate
<ENTITY-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:ENTITY-MIB">
    <entPhysicalTable>
        <entPhysicalEntry>
            <entPhysicalIndex>1</entPhysicalIndex>
            <entPhysicalDescr>Entity 1</entPhysicalDescr>
            <entPhysicalVendorType>1</entPhysicalVendorType>
            <entPhysicalContainedIn>9</entPhysicalContainedIn>
<!--            <entPhysicalClass>6</entPhysicalClass> -->
            <entPhysicalParentRelPos>123</entPhysicalParentRelPos>
            <entPhysicalName>ABCD1234</entPhysicalName>
            <entPhysicalHardwareRev>REV 099</entPhysicalHardwareRev>
            <entPhysicalFirmwareRev>REV 123</entPhysicalFirmwareRev>
            <entPhysicalSoftwareRev>Clixon Version XXX.YYY year ZZZ</entPhysicalSoftwareRev>
            <entPhysicalSerialNum>1234-1234-ABCD-ABCD</entPhysicalSerialNum>
            <entPhysicalMfgName>Olof Hagsand Datakonsult AB</entPhysicalMfgName>
            <entPhysicalModelName>Model AA.BB</entPhysicalModelName>
            <entPhysicalAlias>Alias 123</entPhysicalAlias>
            <entPhysicalAssetID>Asset 123</entPhysicalAssetID>
            <entPhysicalIsFRU>true</entPhysicalIsFRU>
<!--            <entPhysicalUris>1</entPhysicalUris> -->
<!--            <entPhysicalUUID></entPhysicalUUID> -->
        </entPhysicalEntry>
        <entPhysicalEntry>
            <entPhysicalIndex>2</entPhysicalIndex>
            <entPhysicalDescr>Entity 2</entPhysicalDescr>
<!--            <entPhysicalVendorType></entPhysicalVendorType> -->
            <entPhysicalContainedIn>4</entPhysicalContainedIn>
<!--            <entPhysicalClass>6</entPhysicalClass> -->
            <entPhysicalParentRelPos>999</entPhysicalParentRelPos>
            <entPhysicalName>XXZZ11994</entPhysicalName>
            <entPhysicalHardwareRev>REV 100</entPhysicalHardwareRev>
            <entPhysicalFirmwareRev>REV 234</entPhysicalFirmwareRev>
            <entPhysicalSoftwareRev>Clixon Version XXX.YYY year ZZZ</entPhysicalSoftwareRev>
            <entPhysicalSerialNum>2345-2345-ABCD-ABCD</entPhysicalSerialNum>
            <entPhysicalMfgName>Olof Hagsand Datakonsult AB</entPhysicalMfgName>
            <entPhysicalModelName>Model CC.DD</entPhysicalModelName>
            <entPhysicalAlias>Alias 456</entPhysicalAlias>
            <entPhysicalAssetID>Asset 456</entPhysicalAssetID>
            <entPhysicalIsFRU>false</entPhysicalIsFRU>
<!--            <entPhysicalMfgDate></entPhysicalMfgDate> -->
<!--            <entPhysicalUris>1</entPhysicalUris> -->
<!--            <entPhysicalUUID></entPhysicalUUID> -->
        </entPhysicalEntry>
    </entPhysicalTable>
    <entLogicalTable>
        <entLogicalEntry>
            <entLogicalIndex>111</entLogicalIndex>
            <entLogicalDescr>Entry 1</entLogicalDescr>
<!--            <entLogicalType></entLogicalType> -->
            <entLogicalCommunity>public</entLogicalCommunity>
<!--            <entLogicalTAddress></entLogicalTAddress> -->
<!--            <entLogicalTDomain></entLogicalTDomain> -->
<!--            <entLogicalContextEngineID></entLogicalContextEngineID> -->
            <entLogicalContextName>Context name</entLogicalContextName>
        </entLogicalEntry>
    </entLogicalTable>
</ENTITY-MIB>
EOF

function validate_oid(){
    oid=$1
    oid2=$2
    type=$3
    value=$4

    name="$($snmptranslate $oid)"
    name2="$($snmptranslate $oid2)"

    if [ $oid == $oid2 ]; then
        new "Validating numerical OID: $oid2 = $type: $value"
        expectpart "$($snmpget $oid)" 0 "$oid2 = $type: $value"

        new "Validating textual OID: $name2 = $type: $value"
        expectpart "$($snmpgetstr $name)" 0 "$name2 = $type: $value"
    else
        new "Validating numerical next OID: $oid2 = $type: $value"
        expectpart "$($snmpgetnext $oid)" 0 "$oid2 = $type: $value"

        new "Validating textual next OID: $name2 = $type: $value"
        expectpart "$($snmpgetnextstr $name)" 0 "$name2 = $type: $value"
    fi
}

function testinit(){
    new "test params: -f $cfg -- -sS $fstate"
    if [ $BE -ne 0 ]; then
    # Kill old backend and start a new one
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err "Failed to start backend"
    fi

    sudo pkill -f clixon_backend

    new "Starting backend"
    start_backend -s init -f $cfg -- -sS $fstate
    fi

    new "wait backend"
    wait_backend

    if [ $CS -ne 0 ]; then
    # Kill old clixon_snmp, if any
    new "Terminating any old clixon_snmp processes"
    sudo killall -q clixon_snmp

    new "Starting clixon_snmp"
    start_snmp $cfg &
    fi

    new "wait snmp"
    wait_snmp
}

function testexit(){
    stop_snmp
}

ENTITY_OID=".1.3.6.1.2.1.47.1.1.1"

OID_INDEX_1="${ENTITY_OID}.1.1.1"
OID_INDEX_2="${ENTITY_OID}.1.1.2"

OID_DESCR_1="${ENTITY_OID}.1.2.1"
OID_DESCR_2="${ENTITY_OID}.1.2.2"

OID_CONTAINED_1="${ENTITY_OID}.1.4.1"
OID_CONTAINED_2="${ENTITY_OID}.1.4.2"

OID_PARENT_1="${ENTITY_OID}.1.6.1"
OID_PARENT_2="${ENTITY_OID}.1.6.2"

OID_NAME_1="${ENTITY_OID}.1.7.1"
OID_NAME_2="${ENTITY_OID}.1.7.2"

OID_HWREV_1="${ENTITY_OID}.1.8.1"
OID_HWREV_2="${ENTITY_OID}.1.8.2"

OID_FWREV_1="${ENTITY_OID}.1.9.1"
OID_FWREV_2="${ENTITY_OID}.1.9.2"

OID_SWREV_1="${ENTITY_OID}.1.10.1"
OID_SWREV_2="${ENTITY_OID}.1.10.2"

OID_SERIAL_1="${ENTITY_OID}.1.11.1"
OID_SERIAL_2="${ENTITY_OID}.1.11.2"

OID_MFGNAME_1="${ENTITY_OID}.1.12.1"
OID_MFGNAME_2="${ENTITY_OID}.1.12.2"

OID_MODEL_1="${ENTITY_OID}.1.13.1"
OID_MODEL_2="${ENTITY_OID}.1.13.2"

OID_ALIAS_1="${ENTITY_OID}.1.14.1"
OID_ALIAS_2="${ENTITY_OID}.1.14.2"

OID_ASSET_1="${ENTITY_OID}.1.15.1"
OID_ASSET_2="${ENTITY_OID}.1.15.2"

OID_FRU_1="${ENTITY_OID}.1.16.1"
OID_FRU_2="${ENTITY_OID}.1.16.2"

new "SNMP system tests"
testinit

new "Get index, $OID_INDEX_1"
validate_oid $OID_INDEX_1 $OID_INDEX_1 "INTEGER" "1"

new "Get next $OID_INDEX_1"
validate_oid $OID_INDEX_1 $OID_INDEX_2 "INTEGER" "2"

new "Get index, $OID_INDEX_2"
validate_oid $OID_INDEX_2 $OID_INDEX_2 "INTEGER" "2"

new "Get next $OID_INDEX_2"
validate_oid $OID_INDEX_2 $OID_DESCR_1 "STRING" "\"Entity 1\""

new "Get index, $OID_DESCR_1"
validate_oid $OID_DESCR_1 $OID_DESCR_1 "STRING" "\"Entity 1\""

new "Get next $OID_DESCR_1"
validate_oid $OID_DESCR_1 $OID_DESCR_2 "STRING" "\"Entity 2\""

new "Get index, $OID_DESCR_2"
validate_oid $OID_DESCR_2 $OID_DESCR_2 "STRING" "\"Entity 2\""

# new "Get next $OID_DESCR_2"
# validate_oid $OID_DESCR_2 $OID_CONTAINER_1 "INTEGER" "9"

# new "Get container, $OID_CONTAINED_1"
# validate_oid $OID_CONTAINED_1 $OID_CONTAINED_1 "INTEGER" "9"

new "Get next container, $OID_CONTAINED_1"
validate_oid $OID_CONTAINED_1 $OID_CONTAINED_2 "INTEGER" "4"

new "Get container, $OID_CONTAINED_2"
validate_oid $OID_CONTAINED_2 $OID_CONTAINED_2 "INTEGER" "4"

new "Get next container, $OID_CONTAINED_2"
validate_oid $OID_CONTAINED_2 $OID_PARENT_1 "INTEGER" "123"

new "Get container, $OID_PARENT_1"
validate_oid $OID_PARENT_1 $OID_PARENT_1 "INTEGER" "123"

new "Get next container, $OID_PARENT_1"
validate_oid $OID_PARENT_1 $OID_PARENT_2 "INTEGER" "999"

new "Get container, $OID_PARENT_2"
validate_oid $OID_PARENT_2 $OID_PARENT_2 "INTEGER" "999"

new "Get next container, $OID_PARENT_2"
validate_oid $OID_PARENT_2 $OID_NAME_1 "STRING" "\"ABCD1234\""

new "Get name, $OID_NAME_1"
validate_oid $OID_NAME_1 $OID_NAME_1 "STRING" "\"ABCD1234\""

new "Get next container, $OID_NAME_1"
validate_oid $OID_NAME_1 $OID_NAME_2 "STRING" "\"XXZZ11994\""

new "Get name, $OID_NAME_2"
validate_oid $OID_NAME_2 $OID_NAME_2 "STRING" "\"XXZZ11994\""

new "Get next, $OID_NAME_2"
validate_oid $OID_NAME_2 $OID_HWREV_1 "STRING" "\"REV 099\""

new "Get rev, $OID_HWREV_1"
validate_oid $OID_HWREV_1 $OID_HWREV_1 "STRING" "\"REV 099\""

new "Get next hw rev, $OID_HWREV_1"
validate_oid $OID_HWREV_1 $OID_HWREV_2 "STRING" "\"REV 100\""

new "Get hw rev, $OID_HWREV_2"
validate_oid $OID_HWREV_2 $OID_HWREV_2 "STRING" "\"REV 100\""

new "Get next hw rev, $OID_HWREV_2"
validate_oid $OID_HWREV_2 $OID_FWREV_1 "STRING" "\"REV 123\""

new "Get fw rev, $OID_FWREV_1"
validate_oid $OID_FWREV_1 $OID_FWREV_1 "STRING" "\"REV 123\""

new "Get next fw rev, $OID_FWREV_1"
validate_oid $OID_FWREV_1 $OID_FWREV_2 "STRING" "\"REV 234\""

new "Get fw rev, $OID_FWREV_2"
validate_oid $OID_FWREV_2 $OID_FWREV_2 "STRING" "\"REV 234\""

new "Get next fw rev, $OID_FWREV_2"
validate_oid $OID_FWREV_2 $OID_SWREV_1 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""

new "Get sw rev, $OID_SWREV_1"
validate_oid $OID_SWREV_1 $OID_SWREV_1 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""

new "Get next sw rev, $OID_SWREV_1"
validate_oid $OID_SWREV_1 $OID_SWREV_2 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""

new "Get sw rev, $OID_SWREV_2"
validate_oid $OID_SWREV_2 $OID_SWREV_2 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""

new "Get next sw rev, $OID_SWREV_2"
validate_oid $OID_SWREV_2 $OID_SERIAL_1 "STRING" "\"1234-1234-ABCD-ABCD\""

new "Get serial, $OID_SERIAL_1"
validate_oid $OID_SERIAL_1 $OID_SERIAL_1 "STRING" "\"1234-1234-ABCD-ABCD\""

new "Get next serial, $OID_SERIAL_1"
validate_oid $OID_SERIAL_1 $OID_SERIAL_2 "STRING" "\"2345-2345-ABCD-ABCD\""

new "Get serial, $OID_SERIAL_2"
validate_oid $OID_SERIAL_2 $OID_SERIAL_2 "STRING" "\"2345-2345-ABCD-ABCD\""

new "Get next serial, $OID_SERIAL_2"
validate_oid $OID_SERIAL_2 $OID_MFGNAME_1 "STRING" "\"Olof Hagsand Datakonsult AB\""

new "Get manufacturer, $OID_MFGNAME_1"
validate_oid $OID_MFGNAME_1 $OID_MFGNAME_1 "STRING" "\"Olof Hagsand Datakonsult AB\""

new "Get next manufacturer, $OID_MFGNAME_1"
validate_oid $OID_MFGNAME_1 $OID_MFGNAME_2 "STRING" "\"Olof Hagsand Datakonsult AB\""

new "Get manufacturer, $OID_MFGNAME_2"
validate_oid $OID_MFGNAME_2 $OID_MFGNAME_2 "STRING" "\"Olof Hagsand Datakonsult AB\""

new "Get next manufacturer, $OID_MFGNAME_2"
validate_oid $OID_MFGNAME_2 $OID_MODEL_1 "STRING" "\"Model AA.BB\""

new "Get model, $OID_MODEL_1"
validate_oid $OID_MODEL_1 $OID_MODEL_1 "STRING" "\"Model AA.BB\""

new "Get next model, $OID_MODEL_1"
validate_oid $OID_MODEL_1 $OID_MODEL_2 "STRING" "\"Model CC.DD\""

new "Get model, $OID_MODEL_2"
validate_oid $OID_MODEL_2 $OID_MODEL_2 "STRING" "\"Model CC.DD\""

new "Get next model, $OID_MODEL_2"
validate_oid $OID_MODEL_2 $OID_ALIAS_1 "STRING" "\"Alias 123\""

new "Get alias, $OID_ALIAS_1"
validate_oid $OID_ALIAS_1 $OID_ALIAS_1 "STRING" "\"Alias 123\""

new "Get next alias, $OID_ALIAS_1"
validate_oid $OID_ALIAS_1 $OID_ALIAS_2 "STRING" "\"Alias 456\""

new "Get alias, $OID_ALIAS_2"
validate_oid $OID_ALIAS_2 $OID_ASSET_1 "STRING" "\"Asset 123\""

new "Get next alias, $OID_ALIAS_2"
validate_oid $OID_ALIAS_2 $OID_ASSET_1 "STRING" "\"Asset 123\""

new "Get asset, $OID_ASSET_1"
validate_oid $OID_ASSET_1 $OID_ASSET_1 "STRING" "\"ASSET 123\""

new "Get next asset, $OID_ASSET_1"
validate_oid $OID_ASSET_1 $OID_ASSET_2 "STRING" "\"Asset 456\""

new "Get asset, $OID_ASSET_2"
validate_oid $OID_ASSET_2 $OID_ASSET_2 "STRING" "\"ASSET 456\""

new "Get next asset, $OID_ASSET_2"
validate_oid $OID_ASSET_2 $OID_FRU_1 "INTEGER" "1"

new "Get fru, $OID_FRU_1"
validate_oid $OID_FRU_1 $OID_FRU_1 "INTEGER" "1"

new "Get next fru, $OID_FRU_1"
validate_oid $OID_FRU_1 $OID_FRU_2 "INTEGER" "0"

new "Get fru 2, $OID_FRU_2"
validate_oid $OID_FRU_2 $OID_FRU_2 "INTEGER" "0"

new "Cleaning up"
testexit

new "endtest"
endtest
