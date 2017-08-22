#!/bin/sh

NAMES="Nuvola-1.0"
BUILD=build
DEST=/usr/lib/girepository-1.0

for name in $NAMES
do
    symlink="$DEST/${name}.typelib"
    target="$PWD/$BUILD/${name}.typelib"
    if ! [ -L "$symlink" ]
    then
        mkdir -p "$DEST"
        ln -sv "$target" "$symlink"
    fi
done
