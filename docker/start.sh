#!/bin/bash
# Script reads yang spec from stdin then start clicon_cli
read -d $'\cd' -p "input yang spec(end with ^d). Or just ^d for default spec> " spec
if [ "$spec" != "" ]; then
    echo "module datamodel{" > /usr/local/share/clicon_yang/yang/clicon_yang.yang
    echo $spec >> /usr/local/share/clicon_yang/yang/clicon_yang.yang
    echo "}" >> /usr/local/share/clicon_yang/yang/clicon_yang.yang
fi
clicon_cli -cf /usr/local/etc/clicon_yang.conf
