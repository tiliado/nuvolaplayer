export NUVOLA_WEB_APPS_DIR="web_apps"
export DIORITE_LOG_MESSAGE_CHANNEL="yes"
export DIORITE_DUPLEX_CHANNEL_FATAL_TIMEOUT="yes"
export LD_LIBRARY_PATH="$PWD/build:$LD_LIBRARY_PATH"
export NUVOLA_ICON="eu.tiliado.Nuvola"
export DATADIR="/usr/share"
export PYTHONPATH="$PWD:$PYTHONPATH"
export PATH="$PWD/build:$PATH"
export XDG_DATA_DIRS="$PWD/build/share:$XDG_DATA_DIRS"
export NUVOLA_LIBDIR="$PWD/build"

if [ -e /etc/fedora-release ]; then
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib64"
    export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/lib64/pkgconfig"
fi

prompt_prefix='\[\033[1;33m\]Nuvola\[\033[00m\]'
[[ "$PS1" = "$prompt_prefix"* ]] || export PS1="$prompt_prefix $PS1"
unset prompt_prefix

commands() {
    echo "Commands:"
    echo reconfigure
    echo rebuild
    echo build
    echo run-service
    echo run-app
    echo run-tests
    echo debug-service
    echo debug-app
    echo fatal_criticals
    echo fatal_criticals_off
}

mk_symlinks()
{
    build_datadir="./build/share/nuvolaruntime"
    mkdir -p "$build_datadir"
    datadirs="www tips"
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

reconfigure()
{
    python3 ./waf -v distclean configure \
            $WAF_CONFIGURE "$@"
}

rebuild()
{
        python3 ./waf -v distclean configure build \
            $WAF_CONFIGURE "$@" \
        && build/run-nuvolaruntime-tests
}

run-service()
{
        mk_symlinks
        python3 ./waf -v && build/nuvola -D "$@"

}

build()
{
    mk_symlinks
    python3 ./waf -v
}

run-tests()
{
    mk_symlinks
    python3 ./waf -v && build/run-nuvolaruntime-tests
}

run-app()
{
        mk_symlinks
        python3 ./waf -v && build/nuvolaruntime -D -a "$@"
}

debug-app()
{
        mk_symlinks
        python3 ./waf -v && gdb --args build/nuvolaruntime -D -a "$@"
}

ctl()
{
    python3 ./waf -v && build/nuvolactl -D "$@"
}

debug-service()
{
        mk_symlinks
        python3 ./waf -v && gdb --args build/nuvola -D "$@"
}

fatal_criticals()
{
    export G_DEBUG=fatal-criticals
}

fatal_criticals_off()
{
    export G_DEBUG=
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

echo "--- Limits ---"
ulimit -c unlimited
ulimit -a
echo "--- Core dump pattern ---"
echo "'`cat /proc/sys/kernel/core_pattern`'"
echo
commands
