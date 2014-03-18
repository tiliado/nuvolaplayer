rebuild()
{
	./waf distclean configure build "$@"
}

run()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_WEBKIT_EXTENSION_DIR=build build/nuvolaplayer3 -D "$@"

}

debug()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_WEBKIT_EXTENSION_DIR=build gdb --args build/nuvolaplayer3 -D "$@"
}

debug_criticals()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_WEBKIT_EXTENSION_DIR=build G_DEBUG=fatal-criticals \
	gdb --args build/nuvolaplayer3 -D "$@"
}
