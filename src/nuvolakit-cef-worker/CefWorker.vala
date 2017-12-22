Nuvola.CefRendererExtension nuvola_cef_renderer_extension;

public void init_renderer_extension(CefGtk.RendererContext ctx, int browser_id, Variant?[] parameters) {
    Drt.Logger.init(stderr, GLib.LogLevelFlags.LEVEL_DEBUG, true, "Worker");
    var data = new HashTable<string, Variant>(str_hash, str_equal);
    for (var i = 2; i < parameters.length; i++) {
        data[parameters[i - 1].get_string()] = parameters[i++];
    }
	try {
		var channel = new Drt.RpcChannel.from_name(0, data["RUNNER_BUS_NAME"].dup_string(), null,
			data["NUVOLA_API_ROUTER_TOKEN"].dup_string(), 5000);
		nuvola_cef_renderer_extension = new Nuvola.CefRendererExtension(ctx, browser_id, channel, data); 
	} catch (GLib.Error e) {
		error("Failed to connect to app runner. %s", e.message);
	}
    nuvola_cef_renderer_extension.init();
}
