#!/usr/bin/env bash
reset='\033[0m'

# White Background
BG='\033[47m'

# Black Foreground
FG='\033[0;30m'

printf "%+5s %+6s %+6s  %s\n" PID VIRT RES VBOX
pids=$(ps -eo pid,cmd | grep VBoxHeadless |awk '{print $1}')
for pid in $pids; do
#    echo "ps -o rss,vsize,cmd -h -p $pid"
    line=$(ps -o rss,vsize,cmd -h -p $pid)
    if [ -z "$line" ]; then
        continue;
    fi
    rss=$(echo "$line"| awk '{print $1}')
    let rss=rss/1000
    virt=$(echo "$line"| awk '{print $2}')
    let virt=virt/1000
    rest=$(echo "$line"| sed 's/^.*--comment//' | sed 's/ --startvm.*$//' | awk -F- '{print $1 "-" $2}')
    printf "%+5s %+5sM %+5sM  %s\n" $pid $virt $rss $rest

done

