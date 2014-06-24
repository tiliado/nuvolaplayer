export NUVOLA_WEB_APPS_DIR="web_apps"

rebuild()
{
	./waf distclean configure build "$@"
}

run()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build build/nuvolaplayer3 -D "$@"

}

debug()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build gdb --follow-fork-mode --args build/nuvolaplayer3 -D "$@"
}

debug_criticals()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals \
	gdb  --args build/nuvolaplayer3 -D "$@"
}

debug_app_runner()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' build/nuvolaplayer3 -D "$@"
}

debug_app_runner_criticals()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_LIBDIR=build G_DEBUG=fatal-criticals NUVOLA_APP_RUNNER_GDB_SERVER='localhost:9090' \
	build/nuvolaplayer3 -D "$@"
}

debug_app_runner_join()
{
	echo Use "'target remote localhost:9090'"
	libtool --mode=execute gdb build/uirunner
}
