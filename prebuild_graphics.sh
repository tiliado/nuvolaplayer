#!/bin/bash
set -eu # European Union compliance mode

PREFIX="${PREFIX:-.}"

prebuild_app_icon()
{
	source="$1"
	size="$2"
	directory="$PREFIX/data/icons/hicolor/${size}x${size}/apps"
	[ -d "$directory" ] || mkdir -p "$directory"
	set -x
	rsvg-convert -w $size -h $size \
	"graphics/nuvola-icon/nuvola-player.${source}.svg" \
	-o "$directory/nuvolaplayer.png"
	{ set +x; } 2>/dev/null
}

prebuild_web_app_icon()
{
	source="$1"
	size=48
	name="$(basename "$source")"
	name="${name%.svg}"
	directory="$PREFIX/data/nuvolaplayer3/web_apps/$name"
	[ -d "$directory" ] || mkdir -p "$directory"
	set -x
	rsvg-convert -w $size -h $size \
	"${source}" \
	-o "$directory/icon.png"
	{ set +x; } 2>/dev/null
}

optimize_svg()
{
	source="$1"
	output="$2"
	directory="$(dirname "$output")"
	[ -d "$directory" ] || mkdir -p "$directory"
	set -x
	scour -q -i "$source" -o "$output"
	{ set +x; } 2>/dev/null
}

for size in 16; do prebuild_app_icon 16 $size; done
for size in 22 24 32; do prebuild_app_icon 22 $size; done
for size in 48 64; do prebuild_app_icon orig $size; done

optimize_svg \
graphics/nuvola-icon/nuvola-player.orig.svg \
"$PREFIX/data/icons/hicolor/scalable/apps/nuvolaplayer.svg"

for source in graphics/service-icons/*.svg; do
	[[ "$source" != *.*.svg ]] || continue
	prebuild_web_app_icon "$source"
done
