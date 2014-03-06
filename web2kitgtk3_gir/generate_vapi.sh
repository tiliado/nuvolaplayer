#!/bin/sh

WEBKITGTK_CUSTOM_VALA=
WEBKITGTK_METADATA=.
MYVAPIDIR=../vapi
MYGIRDIR=.

mkdir -p "$MYVAPIDIR"
rm -vf $MYVAPIDIR/webkit2gtk-3.0.vapi $MYVAPIDIR/webkit2gtk-web-extension-3.0.vapi
 
vapigen-0.22 --directory=$MYVAPIDIR --vapidir=${MYVAPIDIR} --girdir=$MYGIRDIR \
--pkg=gio-2.0 --pkg=gtk+-3.0 --pkg=libsoup-2.4 \
--metadatadir=. \
--library=webkit2gtk-3.0  ${WEBKITGTK_CUSTOM_VALA} \
$MYGIRDIR/WebKit2-3.0.gir
#mv -v webkit2gtk-3.0.vapi  $MYVAPIDIR

vapigen-0.22 --directory=$MYVAPIDIR --vapidir=${MYVAPIDIR} --girdir=$MYGIRDIR \
--pkg=gio-2.0 --pkg=gtk+-3.0 --pkg=libsoup-2.4 --pkg=webkit2gtk-3.0 \
--metadatadir=. \
--library=webkit2gtk-web-extension-3.0  ${WEBKITGTK_CUSTOM_VALA} \
$MYGIRDIR/WebKit2WebExtension-3.0.gir

#mv -v webkit2gtk-3.0.vapi  $MYVAPIDIR
exit


vapigen-0.22 --directory=${MYVAPIDIR} --vapidir=${MYVAPIDIR} \
--pkg=gio-2.0 --pkg=gtk+-3.0 --pkg=libsoup-2.4  \
--metadatadir=. --metadatadir=${WEBKITGTK_METADATA} \
--library=webkit2gtk-3.0  ${WEBKITGTK_CUSTOM_VALA} \
$MYGIRDIR/WebKit2WebExtension-3.0.gir

