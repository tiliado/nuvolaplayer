export NUVOLA_WEB_APPS_DIR="web_apps"
export DIORITE_LOG_MESSAGE_CHANNEL="yes"
export DIORITE_DUPLEX_CHANNEL_FATAL_TIMEOUT="yes"
export LD_LIBRARY_PATH="build:$LD_LIBRARY_PATH"
export NUVOLA_ICON="eu.tiliado.Nuvola"
export DATADIR="/usr/share"
export PYTHONPATH="$PWD:$PYTHONPATH"

if [ -e /etc/fedora-release ]; then
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib64"
    export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/lib64/pkgconfig"
fi

prompt_prefix='\[\033[1;33m\]Nuvola\[\033[00m\]'
[[ "$PS1" = "$prompt_prefix"* ]] || export PS1="$prompt_prefix $PS1"
unset prompt_prefix

mk_symlinks()
{
    build_datadir="./build/share/nuvolaruntime"
    mkdir -p "$build_datadir"
    datadirs="www"
    for datadir in $datadirs; do
	if [ ! -e "${build_datadir}/${datadir}" ]; then
	    ln -sv "../../../data/$datadir" "$build_datadir"
	fi
    done
    for size in 16 22 24 32 48 64 128 256 
    do
	icon_dir="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
	test -d "$icon_dir" || mkdir -p "$icon_dir"
	cp "data/icons/${size}.png" "$icon_dir/${NUVOLA_ICON}.png"
	cp "web_apps/test/icons/${size}.png" "$icon_dir/${NUVOLA_ICON}AppTest.png"
    done
    icon_dir="$HOME/.local/share/icons/hicolor/scalable/apps"
    test -d "$icon_dir" || mkdir -p "$icon_dir"
    cp "data/icons/scalable.svg" "$icon_dir/${NUVOLA_ICON}.svg"
    cp "web_apps/test/icons/scalable.svg" "$icon_dir/${NUVOLA_ICON}AppTest.svg"
    
    if [ ! -z "$XDG_DATA_HOME" ] && [ "$XDG_DATA_HOME" != "$HOME/.local/share" ]
    then
	for size in 16 22 24 32 48 64 128 256 
	do
	    icon_dir="$XDG_DATA_HOME/icons/hicolor/${size}x${size}/apps"
	    test -d "$icon_dir" || mkdir -p "$icon_dir"
	    cp "data/icons/${size}.png" "$icon_dir/${NUVOLA_ICON}.png"
	    cp "web_apps/test/icons/${size}.png" "$icon_dir/${NUVOLA_ICON}AppTest.png"
	    cp "web_apps/test/icons/${size}.png" "$icon_dir/${NUVOLA_ICON}AppTestmse.png"
	done
	icon_dir="$XDG_DATA_HOME/icons/hicolor/scalable/apps"
	test -d "$icon_dir" || mkdir -p "$icon_dir"
	cp "data/icons/scalable.svg" "$icon_dir/${NUVOLA_ICON}.svg"
	cp "web_apps/test/icons/scalable.svg" "$icon_dir/${NUVOLA_ICON}AppTest.svg"
	cp "web_apps/test/icons/scalable.svg" "$icon_dir/${NUVOLA_ICON}AppTestmse.svg"
    fi
    
    test -e "${build_datadir}/www/engine.io.js" || \
	ln -s "$DATADIR/javascript/engine.io-client/engine.io.js" "${build_datadir}/www/engine.io.js"
}

reconf()
{
    python3 ./waf -v distclean configure \
	    $WAF_CONFIGURE "$@"
}

rebuild()
{
	python3 ./waf -v distclean configure build \
	    $WAF_CONFIGURE "$@" \
	&& NUVOLA_LIBDIR=build build/run-nuvolaruntime-tests
}

run()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build build/nuvola -D "$@"

}

build()
{
    mk_symlinks
    python3 ./waf -v
}

tests()
{
    mk_symlinks
    python3 ./waf -v && NUVOLA_LIBDIR=build build/run-nuvolaruntime-tests
}

dbus()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build build/apprunner -D --dbus -a "$@"
}

debug_dbus()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build gdb --args build/apprunner -D --dbus -a "$@"
}

ctl()
{
    python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
    NUVOLA_LIBDIR=build build/nuvolactl -D "$@"
}

debug()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build gdb --args build/nuvola -D "$@"
}

debug_criticals()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals \
	gdb  --args build/nuvola -D "$@"
}

debug_app_runner()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' build/nuvola -D "$@"
}

debug_app_runner_criticals()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' \
	build/nuvola -D "$@"
}

debug_app_runner_join()
{
	mk_symlinks
	echo Wait for App Runner process to start, then type "'target remote localhost:9090'" and "'continue'"
	libtool --mode=execute gdb build/apprunner
}

debug_web_worker()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build NUVOLA_WEB_WORKER_SLEEP=30 build/nuvola -D "$@"
}

debug_web_worker_criticals()
{
	mk_symlinks
	python3 ./waf -v && XDG_DATA_DIRS="build/share:$XDG_DATA_DIRS" \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals NUVOLA_WEB_WORKER_SLEEP=30 \
	build/nuvola -D "$@"
}

watch_and_build()
{
	while true; do inotifywait -e delete -e create -e modify -r src; sleep 1; ./waf; done
}

build_webgen_doc()
{
    (cd doc; webgen -i . -t theme)
}

build_js_doc()
{
    ./nuvolajsdoc.py
    while true; do inotifywait -e delete -e create -e modify -r src/mainjs doc/theme/templates/jsdoc.html; sleep 1; ./nuvolajsdoc.py; done
}

ulimit -c unlimited
