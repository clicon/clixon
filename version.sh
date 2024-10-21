#!/usr/bin/env bash
# Version script
# Usage:
# ./version.sh
# with optional fields:
# PREFIX= INDEX=1 ARCH= SUFFIX=
# Example:
# PREFIX=cligen INDEX=1 ARCH=amd64 SUFFIX=deb ./version.sh
set -eu
: ${PREFIX:=}
: ${INDEX=1}
: ${ARCH=}
: ${SUFFIX=}
# Get version string from default git describe: <tag>-<nr>-g<hash>
if [ -f .version ]; then
    v1=$(cat .version)
else
    v1=$(git describe)
fi
if [ -z $v1 ]; then
    echo "No base version"
    exit 1
fi
TAG=$(echo $v1 | awk -F- '{print $1}')
NR=$(echo $v1 | awk -F- '{print $2}')
HASH=$(echo $v1 | awk -F- '{print $3}')
V=""
if [ -n "$PREFIX" ]; then
    V="${V}${PREFIX}_"
fi
V="${V}${TAG}"
V="${V}-${INDEX}"
V="${V}+${NR}"
V="${V}+${HASH}"
if [ -n "$ARCH" ]; then
    V="${V}_${ARCH}"
fi
if [ -n "$SUFFIX" ]; then
    V="${V}.${SUFFIX}"
fi
echo "${V}"
