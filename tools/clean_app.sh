#!/bin/sh
set -eux
APP_ID="$1"

rm -rf ~/.local/share/webkitgtk ~/.cache/webkitgtk
rm -rf ~/.local/share/webkit  ~/.cache/webkit
rm -rf ~/.cache/nuvolaplayer3/webcache ~/.cache/nuvolaplayer3/WebKitCache
rm -rf ~/.local/share/nuvolaplayer3/apps_data/$APP_ID
rm -rf ~/.cache/nuvolaplayer3/apps_data/$APP_ID
rm -rf ~/.config/nuvolaplayer3/apps_data/$APP_ID
