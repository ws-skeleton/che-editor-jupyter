#!/bin/sh
set -e
set -u

if [ -f che-editor-plugin.tar.gz ]; then
    rm che-editor-plugin.tar.gz
fi

cd etc
tar zcvf ../che-editor-plugin.tar.gz .

