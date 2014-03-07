rebuild()
{
	./waf distclean configure build "$@"
}

debug()
{
	./waf -v && LD_LIBRARY_PATH=build XDG_DATA_DIRS=data:/usr/share:/usr/local/share \
	NUVOLA_WEBKIT_EXTENSION_DIR=build build/nuvolaplayer3 -D "$@"

}
