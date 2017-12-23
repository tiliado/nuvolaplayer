namespace Nuvola {

/* TODO
 * context menu - password manager
 * error handling
 */

public class CefRendererExtension : GLib.Object {
	private CefGtk.RendererContext ctx;
	private int browser_id;
	private Drt.RpcChannel channel;
	private File data_dir;
	private File user_config_dir;
	private string? api_token = null;
	private HashTable<string, Variant>? worker_data;
	private Drt.XdgStorage storage;
	private CefJSApi js_api;
	
	public CefRendererExtension(CefGtk.RendererContext ctx, int browser_id, Drt.RpcChannel channel,
	HashTable<string, Variant> worker_data) {
		this.ctx = ctx;
		this.browser_id = browser_id;
		this.channel = channel;
		this.worker_data = worker_data;
		this.storage = new Drt.XdgStorage.for_project(Nuvola.get_app_id());
	}
	
	public void init() {
		ainit.begin((o, res) => {ainit.end(res);});
	}
	
	public void show_error(string err) {
		error(err);
	}
	
	private async void ainit() {
		var router = channel.router;
		router.add_method("/nuvola/webworker/call-function", Drt.RpcFlags.WRITABLE,
			"Call JavaScript function.",
			handle_call_function, {
			new Drt.StringParam("name", true, false, null, "Function name."),
			new Drt.VariantParam("params", true, true, null, "Function parameters."),
			new Drt.BoolParam("propagate_error", true, true, "Whether to propagate error.")
		});
		
		Variant response;
		try {
			response = yield channel.call("/nuvola/core/get-data-dir", null);
			data_dir = File.new_for_path(response.get_string());
			response = yield channel.call("/nuvola/core/get-user-config-dir", null);
			user_config_dir = File.new_for_path(response.get_string());
		} catch (GLib.Error e) 	{
			error("Runner client error: %s", e.message);
		}
		
		/* Use worker_data and free it. */
		uint[] webkit_version = new uint[3];
		webkit_version[0] = (uint) worker_data["WEBKITGTK_MAJOR"].get_int64();
		webkit_version[1] = (uint) worker_data["WEBKITGTK_MINOR"].get_int64();
		webkit_version[2] = (uint) worker_data["WEBKITGTK_MICRO"].get_int64();
		uint[] libsoup_version = new uint[3];
		libsoup_version[0] = (uint) worker_data["LIBSOUP_MAJOR"].get_int64();
		libsoup_version[1] = (uint) worker_data["LIBSOUP_MINOR"].get_int64();
		libsoup_version[2] = (uint) worker_data["LIBSOUP_MICRO"].get_int64();
		api_token = worker_data["NUVOLA_API_ROUTER_TOKEN"].get_string();
		worker_data = null;
		
		js_api = new CefJSApi(storage, data_dir, user_config_dir, new KeyValueProxy(channel, "config"),
			new KeyValueProxy(channel, "session"), webkit_version, libsoup_version, true);
		js_api.call_ipc_method_void.connect(on_call_ipc_method_void);
		js_api.call_ipc_method_async.connect(on_call_ipc_method_async);
		
		channel.call.begin("/nuvola/core/web-worker-initialized", null, (o, res) => {
			try {
				channel.call.end(res);
			} catch (GLib.Error e) {
				error("Runner client error: %s", e.message);
			}
		});
		
		ctx.js_context_created.connect(on_js_context_created);
		ctx.js_context_released.connect(on_js_context_released);
	}
	
	private void on_js_context_created(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		apply_javascript_fixes(browser, frame, context);
		if (frame.is_main() > 0 && browser.get_identifier() == browser_id) {
			debug("Got JS context");
			init_frame(browser, frame, context);
		}
	}
	
	private void on_js_context_released(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		if (frame.is_main() > 0 && browser.get_identifier() == browser_id) {
			debug("Lost JS context");
			js_api.release_context(context);
		}
	}
	
	private void apply_javascript_fixes(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		/* No-op */
	}
	
	private void init_frame(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		try {
			js_api.inject(context);
			js_api.integrate(context);
		} catch (GLib.Error e) {
			error("Failed to inject JavaScript API. %s".printf(e.message));
		}
		ctx.event_loop.add_idle(emit_web_worker_ready_cb);
		try {
			var args = new Variant("(s)", "InitWebWorker");
			js_api.call_function_sync("Nuvola.core.emit", ref args, true);
		} catch (GLib.Error e) {
			show_error("Failed to inject JavaScript API. %s".printf(e.message));
		}
	}
	
	private bool emit_web_worker_ready_cb() {
		channel.call.begin("/nuvola/core/web-worker-ready", null, (o, res) => {
			try {
				channel.call.end(res);
			} catch (GLib.Error e) {
				warning("Runner client error: %s", e.message);
			}
		});
		return false;
	}
	
	private void on_call_ipc_method_void(string name, Variant? data) {
		ctx.event_loop.add_idle(() => {
			channel.call.begin(name, data, (o, res) => {
				try {
					channel.call.end(res);
				} catch (GLib.Error e) {
					critical("Failed to send message '%s'. %s", name, e.message);
				}
			});
			return false;
		});
	}
	
	private void on_call_ipc_method_async(CefJSApi js_api, string name, Variant? data, int id) {
		ctx.event_loop.add_idle(() => {
			channel.call.begin(name, data, (o, res) => {
				try {
					var response = channel.call.end(res);
					js_api.send_async_response(id, response, null);
				} catch (GLib.Error e) {
					js_api.send_async_response(id, null, e);
				}
			});
			return false;
		});
	}
	
	private void handle_call_function(Drt.RpcRequest request) throws GLib.Error {
		var name = request.pop_string();
		var func_params = request.pop_variant();
		var propagate_error = request.pop_bool();
		try {
			if (js_api.is_valid()) {
				js_api.call_function_sync(name, ref func_params, true);
			} else {
				warning("CefJSApi is not valid");
			}
		} catch (GLib.Error e) {
			if (propagate_error) {
				throw e;
			} else {
				show_error("Error during call of %s: %s".printf(name, e.message));
			}
		}
		request.respond(func_params);
	}
}

} // namespace Nuvola
