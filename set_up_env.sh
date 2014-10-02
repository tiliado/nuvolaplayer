export NUVOLA_WEB_APPS_DIR="web_apps"
export DIORITE_LOG_IPC_SERVER="yes"
export DIORITE_LOG_MESSAGE_SERVER="yes"

prompt_prefix='\[\033[1;33m\]Nuvola\[\033[00m\]'
[[ "$PS1" = "$prompt_prefix"* ]] || export PS1="$prompt_prefix $PS1"
unset prompt_prefix

rebuild()
{
	./waf distclean configure build "$@"
}

run()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build build/nuvolaplayer3 -D "$@"

}

ctl()
{
    ./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
    NUVOLA_LIBDIR=build build/nuvolaplayer3ctl -D "$@"
}

debug()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build gdb --follow-fork-mode --args build/nuvolaplayer3 -D "$@"
}

debug_criticals()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals \
	gdb  --args build/nuvolaplayer3 -D "$@"
}

debug_app_runner()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' build/nuvolaplayer3 -D "$@"
}

debug_app_runner_criticals()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=build/share:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' \
	build/nuvolaplayer3 -D "$@"
}

debug_app_runner_join()
{
	echo Use "'target remote localhost:9090'"
	libtool --mode=execute gdb build/apprunner
}


watch_and_build()
{
	while true; do inotifywait -e delete -e create -e modify -r src; sleep 1; ./waf; done
}

build_pelican_doc()
{
    (cd doc; pelican -r -t theme)
}

build_js_doc()
{
    ./nuvolajsdoc.py
    while true; do inotifywait -e delete -e create -e modify -r src/mainjs doc/theme/templates/jsdoc.html; sleep 1; ./nuvolajsdoc.py; done
}
