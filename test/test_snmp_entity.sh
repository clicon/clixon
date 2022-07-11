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
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
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
            <entPhysicalVendorType>1.3.6.1.2.1.4</entPhysicalVendorType>
            <entPhysicalContainedIn>9</entPhysicalContainedIn>
            <entPhysicalClass>powerSupply</entPhysicalClass>
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
            <entPhysicalMfgDate>11111111</entPhysicalMfgDate>
<!--            <entPhysicalUris></entPhysicalUris>-->
<!--            <entPhysicalUUID></entPhysicalUUID> -->
        </entPhysicalEntry>
        <entPhysicalEntry>
            <entPhysicalIndex>2</entPhysicalIndex>
            <entPhysicalDescr>Entity 2</entPhysicalDescr>
            <entPhysicalVendorType>1.3.6.1.2.1.4</entPhysicalVendorType>
            <entPhysicalContainedIn>4</entPhysicalContainedIn>
            <entPhysicalClass>powerSupply</entPhysicalClass>
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
            <entPhysicalMfgDate>22222222</entPhysicalMfgDate>
<!--            <entPhysicalUris></entPhysicalUris> -->
<!--            <entPhysicalUUID></entPhysicalUUID> -->
        </entPhysicalEntry>
    </entPhysicalTable>
</ENTITY-MIB>
EOF

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

    if [ $SN -ne 0 ]; then
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

OID1="${ENTITY_OID}.1.1.1"
OID2="${ENTITY_OID}.1.1.2"
OID3="${ENTITY_OID}.1.2.1"
OID4="${ENTITY_OID}.1.2.2"
OIDX="${ENTITY_OID}.1.3.1"
OIDY="${ENTITY_OID}.1.3.2"
OID5="${ENTITY_OID}.1.4.1"
OID6="${ENTITY_OID}.1.4.2"
OID7="${ENTITY_OID}.1.5.1"
OID8="${ENTITY_OID}.1.5.2"
OID9="${ENTITY_OID}.1.6.1"
OID10="${ENTITY_OID}.1.6.2"
OID11="${ENTITY_OID}.1.7.1"
OID12="${ENTITY_OID}.1.7.2"
OID13="${ENTITY_OID}.1.8.1"
OID14="${ENTITY_OID}.1.8.2"
OID15="${ENTITY_OID}.1.9.1"
OID16="${ENTITY_OID}.1.9.2"
OID17="${ENTITY_OID}.1.10.1"
OID18="${ENTITY_OID}.1.10.2"
OID19="${ENTITY_OID}.1.11.1"
OID20="${ENTITY_OID}.1.11.2"
OID21="${ENTITY_OID}.1.12.1"
OID22="${ENTITY_OID}.1.12.2"
OID23="${ENTITY_OID}.1.13.1"
OID24="${ENTITY_OID}.1.13.2"
OID25="${ENTITY_OID}.1.14.1"
OID26="${ENTITY_OID}.1.14.2"
OID27="${ENTITY_OID}.1.15.1"
OID28="${ENTITY_OID}.1.15.2"
OID29="${ENTITY_OID}.1.16.1"
OID30="${ENTITY_OID}.1.16.2"
OID31="${ENTITY_OID}.1.17.1"
OID32="${ENTITY_OID}.1.17.2"

NAME1="ENTITY-MIB::entPhysicalIndex.1"
NAME2="ENTITY-MIB::entPhysicalIndex.2"
NAME3="ENTITY-MIB::entPhysicalDescr.1"
NAME4="ENTITY-MIB::entPhysicalDescr.2"
NAMEX="ENTITY-MIB::entPhysicalVendorType.1"
NAMEY="ENTITY-MIB::entPhysicalVendorType.2"
NAME5="ENTITY-MIB::entPhysicalContainedIn.1"
NAME6="ENTITY-MIB::entPhysicalContainedIn.2"
NAME7="ENTITY-MIB::entPhysicalClass.1"
NAME8="ENTITY-MIB::entPhysicalClass.2"
NAME9="ENTITY-MIB::entPhysicalParentRelPos.1"
NAME10="ENTITY-MIB::entPhysicalParentRelPos.2"
NAME11="ENTITY-MIB::entPhysicalName.1"
NAME12="ENTITY-MIB::entPhysicalName.2"
NAME13="ENTITY-MIB::entPhysicalHardwareRev.1"
NAME14="ENTITY-MIB::entPhysicalHardwareRev.2"
NAME15="ENTITY-MIB::entPhysicalFirmwareRev.1"
NAME16="ENTITY-MIB::entPhysicalFirmwareRev.2"
NAME17="ENTITY-MIB::entPhysicalSoftwareRev.1"
NAME18="ENTITY-MIB::entPhysicalSoftwareRev.2"
NAME19="ENTITY-MIB::entPhysicalSerialNum.1"
NAME20="ENTITY-MIB::entPhysicalSerialNum.2"
NAME21="ENTITY-MIB::entPhysicalMfgName.1"
NAME22="ENTITY-MIB::entPhysicalMfgName.2"
NAME23="ENTITY-MIB::entPhysicalModelName.1"
NAME24="ENTITY-MIB::entPhysicalModelName.2"
NAME25="ENTITY-MIB::entPhysicalAlias.1"
NAME26="ENTITY-MIB::entPhysicalAlias.2"
NAME27="ENTITY-MIB::entPhysicalAssetID.1"
NAME28="ENTITY-MIB::entPhysicalAssetID.2"
NAME29="ENTITY-MIB::entPhysicalIsFRU.1"
NAME30="ENTITY-MIB::entPhysicalIsFRU.2"
NAME31="ENTITY-MIB::entPhysicalMfgDate.1"
NAME32="ENTITY-MIB::entPhysicalMfgDate.2"
NAME33="ENTITY-MIB::entPhysicalUris.1"
NAME34="ENTITY-MIB::entPhysicalUris.2"
NAME35="ENTITY-MIB::entPhysicalUris.2"

new "SNMP system tests"
testinit

new "Get index, $OID1"
validate_oid $OID1 $OID1 "INTEGER" "1"
validate_oid $NAME1 $NAME1 "INTEGER" "1"

new "Get next $OID1"
validate_oid $OID1 $OID2 "INTEGER" "2"
validate_oid $NAME1 $NAME2 "INTEGER" "2"

new "Get index, $OID2"
validate_oid $OID2 $OID2 "INTEGER" "2"
validate_oid $NAME2 $NAME2 "INTEGER" "2"

new "Get next $OID2"
validate_oid $OID2 $OID3 "STRING" "\"Entity 1\""
validate_oid $NAME2 $NAME3 "STRING" "Entity 1"

new "Get index, $OID3"
validate_oid $OID3 $OID3 "STRING" "\"Entity 1\""
validate_oid $NAME3 $NAME3 "STRING" "Entity 1"

new "Get next $OID4"
validate_oid $OID3 $OID4 "STRING" "\"Entity 2\""
validate_oid $NAME3 $NAME4 "STRING" "Entity 2"

new "Get index, $OID4"
validate_oid $OID4 $OID4 "STRING" "\"Entity 2\""
validate_oid $NAME4 $NAME4 "STRING" "Entity 2"

new "Get next $OID4"
validate_oid $OID4 $OIDX "OID" ".1.3.6.1.2.1.4"
validate_oid $NAME4 $NAMEX "OID" "IP-MIB::ip"

new "Get $NAMEX"
validate_oid $OIDX $OIDX "OID" ".1.3.6.1.2.1.4"
validate_oid $NAMEX $NAMEX "OID" "IP-MIB::ip"

new "Get next $NAMEX"
validate_oid $OIDX $OIDY "OID" ".1.3.6.1.2.1.4"
validate_oid $NAMEX $NAMEY "OID" "IP-MIB::ip"

new "Get $NAMEY"
validate_oid $OIDY $OIDY "OID" ".1.3.6.1.2.1.4"
validate_oid $NAMEY $NAMEY "OID" "IP-MIB::ip"

new "Get next $NAMEY"
validate_oid $OIDY $OID5 "INTEGER" 9
validate_oid $NAMEY $NAME5 "INTEGER" 9

new "Get container, $OID5"
validate_oid $OID5 $OID5 "INTEGER" "9"
validate_oid $NAME5 $NAME5 "INTEGER" "9"

new "Get next container, $OID5"
validate_oid $OID5 $OID6 "INTEGER" "4"
validate_oid $NAME5 $NAME6 "INTEGER" "4"

new "Get container, $OID6"
validate_oid $OID6 $OID6 "INTEGER" "4"
validate_oid $NAME6 $NAME6 "INTEGER" "4"

new "Get next container, $OID6"
validate_oid $OID6 $OID7 "INTEGER" "6"
validate_oid $NAME6 $NAME7 "INTEGER" "powerSupply(6)"

new "Get container, $OID7"
validate_oid $OID7 $OID7 "INTEGER" "6"
validate_oid $NAME7 $NAME7 "INTEGER" "powerSupply(6)"

new "Get next container, $OID7"
validate_oid $OID7 $OID8 "INTEGER" "6"
validate_oid $NAME7 $NAME8 "INTEGER" "powerSupply(6)"

new "Get container, $OID8"
validate_oid $OID8 $OID8 "INTEGER" "6"
validate_oid $NAME8 $NAME8 "INTEGER" "powerSupply(6)"

new "Get next container, $OID8"
validate_oid $OID8 $OID9 "INTEGER" 123
validate_oid $NAME8 $NAME9 "INTEGER" 123

new "Get name, $OID9"
validate_oid $OID9 $OID9 "INTEGER" 123
validate_oid $NAME9 $NAME9 "INTEGER" 123

new "Get next, $OID9"
validate_oid $OID9 $OID10 "INTEGER" 999
validate_oid $NAME9 $NAME10 "INTEGER" 999

new "Get name, $OID10"
validate_oid $OID10 $OID10 "INTEGER" 999
validate_oid $NAME10 $NAME10 "INTEGER" 999

new "Get name, $OID11"
validate_oid $OID11 $OID11 "STRING" "\"ABCD1234\""
validate_oid $NAME11 $NAME11 "STRING" "ABCD1234"

new "Get next, $OID11"
validate_oid $OID11 $OID12 "STRING" "\"XXZZ11994\""
validate_oid $NAME11 $NAME12 "STRING" "XXZZ11994"

new "Get name, $OID12"
validate_oid $OID12 $OID12 "STRING" "\"XXZZ11994\""
validate_oid $NAME12 $NAME12 "STRING" "XXZZ11994"

new "Get next, $OID12"
validate_oid $OID12 $OID13 "STRING" "\"REV 099\""
validate_oid $NAME12 $NAME13 "STRING" "REV 099"

new "Get rev, $OID13"
validate_oid $OID13 $OID13 "STRING" "\"REV 099\""
validate_oid $NAME13 $NAME13 "STRING" "REV 099"

new "Get next hw rev, $OID13"
validate_oid $OID13 $OID14 "STRING" "\"REV 100\""
validate_oid $NAME13 $NAME14 "STRING" "REV 100"

new "Get hw rev, $OID14"
validate_oid $OID14 $OID14 "STRING" "\"REV 100\""
validate_oid $NAME14 $NAME14 "STRING" "REV 100"

new "Get next hw rev, $OID14"
validate_oid $OID14 $OID15 "STRING" "\"REV 123\""
validate_oid $NAME14 $NAME15 "STRING" "REV 123"

new "Get fw rev, $OID15"
validate_oid $OID15 $OID15 "STRING" "\"REV 123\""
validate_oid $NAME15 $NAME15 "STRING" "REV 123"

new "Get next fw rev, $OID15"
validate_oid $OID15 $OID16 "STRING" "\"REV 234\""
validate_oid $NAME15 $NAME16 "STRING" "REV 234"

new "Get fw rev, $OID16"
validate_oid $OID16 $OID16 "STRING" "\"REV 234\""
validate_oid $NAME16 $NAME16 "STRING" "REV 234"

new "Get next fw rev, $OID16"
validate_oid $OID16 $OID17 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""
validate_oid $NAME16 $NAME17 "STRING" "Clixon Version XXX.YYY year ZZZ"

new "Get sw rev, $OID7"
validate_oid $OID17 $OID17 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""
validate_oid $NAME17 $NAME17 "STRING" "Clixon Version XXX.YYY year ZZZ"

new "Get next sw rev, $OID17"
validate_oid $OID17 $OID18 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""
validate_oid $NAME17 $NAME18 "STRING" "Clixon Version XXX.YYY year ZZZ"

new "Get sw rev, $OID18"
validate_oid $OID18 $OID18 "STRING" "\"Clixon Version XXX.YYY year ZZZ\""
validate_oid $NAME18 $NAME18 "STRING" "Clixon Version XXX.YYY year ZZZ"

new "Get next sw rev, $OID18"
validate_oid $OID18 $OID19 "STRING" "\"1234-1234-ABCD-ABCD\""
validate_oid $NAME18 $NAME19 "STRING" "1234-1234-ABCD-ABCD"

new "Get serial, $OID19"
validate_oid $OID19 $OID19 "STRING" "\"1234-1234-ABCD-ABCD\""
validate_oid $NAME19 $NAME19 "STRING" "1234-1234-ABCD-ABCD"

new "Get next serial, $OID19"
validate_oid $OID19 $OID20 "STRING" "\"2345-2345-ABCD-ABCD\""
validate_oid $NAME19 $NAME20 "STRING" "2345-2345-ABCD-ABCD"

new "Get serial, $OID20"
validate_oid $OID20 $OID20 "STRING" "\"2345-2345-ABCD-ABCD\""
validate_oid $NAME20 $NAME20 "STRING" "2345-2345-ABCD-ABCD"

new "Get next serial, $OID20"
validate_oid $OID20 $OID21 "STRING" "\"Olof Hagsand Datakonsult AB\""
validate_oid $NAME20 $NAME21 "STRING" "Olof Hagsand Datakonsult AB"

new "Get manufacturer, $OID21"
validate_oid $OID21 $OID21 "STRING" "\"Olof Hagsand Datakonsult AB\""
validate_oid $NAME21 $NAME21 "STRING" "Olof Hagsand Datakonsult AB"

new "Get next manufacturer, $OID21"
validate_oid $OID21 $OID22 "STRING" "\"Olof Hagsand Datakonsult AB\""
validate_oid $NAME21 $NAME22 "STRING" "Olof Hagsand Datakonsult AB"

new "Get manufacturer, $OID22"
validate_oid $OID22 $OID22 "STRING" "\"Olof Hagsand Datakonsult AB\""
validate_oid $NAME22 $NAME22 "STRING" "Olof Hagsand Datakonsult AB"

new "Get next manufacturer, $OID22"
validate_oid $OID22 $OID23 "STRING" "\"Model AA.BB\""
validate_oid $NAME22 $NAME23 "STRING" "Model AA.BB"

new "Get model, $OID23"
validate_oid $OID23 $OID23 "STRING" "\"Model AA.BB\""
validate_oid $NAME23 $NAME23 "STRING" "Model AA.BB"

new "Get next model, $OID23"
validate_oid $OID23 $OID24 "STRING" "\"Model CC.DD\""
validate_oid $NAME23 $NAME24 "STRING" "Model CC.DD"

new "Get model, $OID24"
validate_oid $OID24 $OID24 "STRING" "\"Model CC.DD\""
validate_oid $NAME24 $NAME24 "STRING" "Model CC.DD"

new "Get next model, $OID24"
validate_oid $OID24 $OID25 "STRING" "\"Alias 123\""
validate_oid $NAME24 $NAME25 "STRING" "Alias 123"

new "Get alias, $OID25"
validate_oid $OID25 $OID25 "STRING" "\"Alias 123\""
validate_oid $NAME25 $NAME25 "STRING" "Alias 123"

new "Get next alias, $OID25"
validate_oid $OID25 $OID26 "STRING" "\"Alias 456\""
validate_oid $NAME25 $NAME26 "STRING" "Alias 456"

new "Get alias, $OID26"
validate_oid $OID26 $OID26 "STRING" "\"Alias 456\""
validate_oid $NAME26 $NAME26 "STRING" "Alias 456"

new "Get next alias, $OID26"
validate_oid $OID26 $OID27 "STRING" "\"Asset 123\""
validate_oid $NAME26 $NAME27 "STRING" "Asset 123"

new "Get asset, $OID27"
validate_oid $OID27 $OID27 "STRING" "\"Asset 123\""
validate_oid $NAME27 $NAME27 "STRING" "Asset 123"

new "Get next asset, $OID27"
validate_oid $OID27 $OID28 "STRING" "\"Asset 456\""
validate_oid $NAME27 $NAME28 "STRING" "Asset 456"

new "Get asset, $OID28"
validate_oid $OID28 $OID28 "STRING" "\"ASSET 456\""
validate_oid $NAME28 $NAME28 "STRING" "ASSET 456"

new "Get next asset, $OID28"
validate_oid $OID28 $OID29 "INTEGER" "1"
validate_oid $NAME28 $NAME29 "INTEGER" "true(1)"

new "Get fru, $OID29"
validate_oid $OID29 $OID29 "INTEGER" "1"
validate_oid $NAME29 $NAME29 "INTEGER" "true(1)"

new "Get next fru, $OID29"
validate_oid $OID29 $OID30 "INTEGER" "0"
validate_oid $NAME29 $NAME30 "INTEGER" "0"

new "Get fru 2, $OID30"
validate_oid $OID30 $OID30 "INTEGER" "0"
validate_oid $NAME30 $NAME30 "INTEGER" "0"

new "Get next fru 2, $OID30"
validate_oid $NAME30 $NAME31 "STRING" "12593-49-49,49:49:49.49"

new "Get mfg date, $OID31"
validate_oid $NAME31 $NAME31 "STRING" "12593-49-49,49:49:49.49"

new "Get next mfg date, $OID31"
validate_oid $NAME31 $NAME32 "STRING" "12850-50-50,50:50:50.50"

new "Get mfg date, $OID32"
validate_oid $NAME32 $NAME32 "STRING" "12850-50-50,50:50:50.50"

new "Validate snmpwalk"
expectpart "$($snmpwalk $ENTITY_OID)" 0 "SNMPv2-SMI::mib-2.47.1.1.1.1.1.1 = INTEGER: 1" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.1.2 = INTEGER: 2" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.2.1 = STRING: \"Entity 1\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.2.2 = STRING: \"Entity 2\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.3.1 = OID: IP-MIB::ip" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.3.2 = OID: IP-MIB::ip" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.4.1 = INTEGER: 9" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.4.2 = INTEGER: 4" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.5.1 = INTEGER: 6" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.5.2 = INTEGER: 6" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.6.1 = INTEGER: 123" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.6.2 = INTEGER: 999" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.7.1 = STRING: \"ABCD1234\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.7.2 = STRING: \"XXZZ11994\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.8.1 = STRING: \"REV 099\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.8.2 = STRING: \"REV 100\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.9.1 = STRING: \"REV 123\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.9.2 = STRING: \"REV 234\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.10.1 = STRING: \"Clixon Version XXX.YYY year ZZZ\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.10.2 = STRING: \"Clixon Version XXX.YYY year ZZZ\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.11.1 = STRING: \"1234-1234-ABCD-ABCD\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.11.2 = STRING: \"2345-2345-ABCD-ABCD\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.12.1 = STRING: \"Olof Hagsand Datakonsult AB\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.12.2 = STRING: \"Olof Hagsand Datakonsult AB\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.13.1 = STRING: \"Model AA.BB\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.13.2 = STRING: \"Model CC.DD\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.14.1 = STRING: \"Alias 123\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.14.2 = STRING: \"Alias 456\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.15.1 = STRING: \"Asset 123\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.15.2 = STRING: \"Asset 456\"" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.16.1 = INTEGER: 1" \
    "SNMPv2-SMI::mib-2.47.1.1.1.1.16.2 = INTEGER: 0" \

new "Cleaning up"
# testexit

new "endtest"
endtest
