namespace Nuvola.Assert {

private void on_js_thread(string context=GLib.Log.METHOD) {
	if (Cef.currently_on(Cef.ThreadId.RENDERER) == 0) {
		error("%s: Not on JavaScript thread.", context);
	}
}

private void on_glib_thread(string context=GLib.Log.METHOD) {
	if (Cef.currently_on(Cef.ThreadId.RENDERER) == 1) {
		error("%s: Not on GLib thread.", context);
	}
}

} // namespace Nuvola.Assert

namespace Nuvola {
	
public inline bool currently_on_js_thread() {
	return (bool) Cef.currently_on(Cef.ThreadId.RENDERER);
}

} // namespace Nuvola
