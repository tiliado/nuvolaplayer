export NUVOLA_WEB_APPS_DIR="web_apps"
export DIORITE_LOG_MESSAGE_CHANNEL="yes"
export LD_LIBRARY_PATH="build"

if [ -e /etc/fedora-release ]; then
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib64"
    export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/lib64/pkgconfig"
fi

prompt_prefix='\[\033[1;33m\]Nuvola\[\033[00m\]'
[[ "$PS1" = "$prompt_prefix"* ]] || export PS1="$prompt_prefix $PS1"
unset prompt_prefix

rebuild()
{
	./waf distclean configure build "$@"
}

run()
{
	./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build build/nuvolaplayer3 -D "$@"

}

ctl()
{
    ./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
    NUVOLA_LIBDIR=build build/nuvolaplayer3ctl -D "$@"
}

debug()
{
	./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build gdb --args build/nuvolaplayer3 -D "$@"
}

debug_criticals()
{
	./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals \
	gdb  --args build/nuvolaplayer3 -D "$@"
}

debug_app_runner()
{
	./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' build/nuvolaplayer3 -D "$@"
}

debug_app_runner_criticals()
{
	./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' \
	build/nuvolaplayer3 -D "$@"
}

debug_app_runner_join()
{
	echo Wait for App Runner process to start, then type "'target remote localhost:9090'" and "'continue'"
	libtool --mode=execute gdb build/apprunner
}

debug_web_worker()
{
	./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build NUVOLA_WEB_WORKER_SLEEP=30 build/nuvolaplayer3 -D "$@"
}

debug_web_worker_criticals()
{
	./waf -v && XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals NUVOLA_WEB_WORKER_SLEEP=30 \
	build/nuvolaplayer3 -D "$@"
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
