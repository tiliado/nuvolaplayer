#!/bin/sh

ABI="0.3"
CC=${CC:-gcc}
OUT=${OUT:-../../build/engineio/examples}
BUILD=${BUILD:-../../build}
CFLAGS="${CFLAGS:-} -g -g3"

set -eu
NAME="example"

mkdir -p ${OUT}
	
set -x

if [ ! -f www/engine.io.js ]
then
	cd www
	wget https://raw.githubusercontent.com/socketio/engine.io-client/master/engine.io.js
	cd ..
fi
	
valac -C -d ${OUT} -b . --thread --save-temps -v \
	--vapidir $BUILD  --vapidir ../vapi \
	--pkg glib-2.0 --target-glib=2.32 --pkg=dioriteglib-${ABI} \
	--pkg engineio \
	${NAME}.vala
	
$CC ${OUT}/${NAME}.c -o ${OUT}/${NAME} \
	$CFLAGS '-DG_LOG_DOMAIN="MyEngineio"' \
	-I$BUILD -L$BUILD  "-L$(readlink -e "$BUILD")" -lengineio \
	$(pkg-config --cflags --libs glib-2.0 gobject-2.0 gthread-2.0 gio-2.0 gio-unix-2.0 dioriteglib-${ABI} libsoup-2.4 json-glib-1.0)
	
LD_LIBRARY_PATH=$BUILD ${OUT}/${NAME}
