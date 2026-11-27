#!/bin/bash
# Usage: setup.sh <conf_name>
#   Copy binaries from bin/x-nix into bin, then generate config in bin/config.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CONF="$1"
if [ -z "$CONF" ]; then
    echo "Usage: $0 <conf_name>"
    exit 1
fi

# copy binaries from the default unix build dir
SRC_DIR="$SCRIPT_DIR/x-nix"
if [ ! -d "$SRC_DIR" ]; then
    echo "build directory not found: $SRC_DIR"
    exit 1
fi
FILE_COUNT=$(find "$SRC_DIR" -maxdepth 1 -type f | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "no binaries found in $SRC_DIR"
    exit 1
fi
find "$SRC_DIR" -maxdepth 1 -type f -exec cp -f {} "$SCRIPT_DIR"/ \;
echo "copied binaries from $SRC_DIR to $SCRIPT_DIR"

# generate config files (keep environ/ and template/ subdirs, only refresh *.conf at config root)
find config -maxdepth 1 -name "*.conf" -delete
cd config/template

SCRIPT=../../../tools/lmake/ltemplate.lua
ENVIRON=../environ/$CONF.conf
for file in *.conf; do
    ../../lua $SCRIPT $file ../$file $ENVIRON
done
