#/usr/bin/env bash

# Traverses a directory ($MIBDIR) and tries to convert each file from SMI format
# to YANG and preserve directory structure etc.
# This script can be used like this: ./mib_to_yang /usr/share/snmp/mibs yang/

MIBDIR=$1
YANGDIR=$2

function parse_mibs(){
    indir=$1
    outdir=$2

    for i in $indir/*; do        
        outfile="$outdir`basename $i | cut -d"." -f1`.yang"
        SMIPATH=$MIBDIR smidump -f yang -k $i > $outfile
    done
}

if [ $# -ne 2 ]; then
    echo "Usage: $0 <MIB directory, usually /usr/share/snmp/mibs> <out directory, for example yang/>"
    exit
fi

for i in `find $MIBDIR -type d -or -type l`; do    
    if [ `basename $i` == `basename $MIBDIR` ]; then
        outdir=$YANGDIR
    else
        outdir="$YANGDIR`basename $i`/"
    fi

    mkdir -p $outdir
    parse_mibs $i $outdir
done
