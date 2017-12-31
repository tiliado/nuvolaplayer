namespace Nuvola {

/* TODO
 * context menu - password manager
 */

public class CefRendererExtension : GLib.Object {
	private CefGtk.RendererContext ctx;
	private int browser_id;
	private Drt.RpcChannel channel;
	private File data_dir;
	private File user_config_dir;
	private string? api_token = null;
	private HashTable<string, Variant>? worker_data;
	private HashTable<string, Variant>? js_properties;
	private Drt.XdgStorage storage;
	private CefJSApi js_api;
	
	public CefRendererExtension(CefGtk.RendererContext ctx, int browser_id, Drt.RpcChannel channel,
	HashTable<string, Variant> worker_data) {
		Assert.on_js_thread();
		this.ctx = ctx;
		this.browser_id = browser_id;
		this.channel = channel;
		this.worker_data = worker_data;
		this.storage = new Drt.XdgStorage.for_project(Nuvola.get_app_id());
		ctx.js_context_created.connect(on_js_context_created);
		ctx.js_context_released.connect(on_js_context_released);
	}
	
	private void init() {
		Assert.on_glib_thread();
		ainit.begin((o, res) => {ainit.end(res);});
	}
	
	public void show_error(string error) {
		if (currently_on_js_thread()) {
			ctx.event_loop.add_idle(() => {show_error(error); return false;});
		} else {
			Assert.on_glib_thread();
			channel.call.begin(
				"/nuvola/core/show-error", new Variant("(s)", error),
				(o, res) => {
				try {
					channel.call.end(res);
				} catch (GLib.Error e) {
					critical("Failed to send error message '%s'. %s", error, e.message);
				}
			});
		}
	}
	
	private async void ainit() {
		Assert.on_glib_thread();
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
			Assert.on_glib_thread();
			data_dir = File.new_for_path(response.get_string());
			response = yield channel.call("/nuvola/core/get-user-config-dir", null);
			Assert.on_glib_thread();
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
		js_properties = Utils.extract_js_properties(worker_data);
		worker_data = null;
		Assert.on_glib_thread();
		js_api = new CefJSApi(ctx.event_loop, storage, data_dir, user_config_dir,
			new KeyValueProxy(channel, "config"), new KeyValueProxy(channel, "session"),
			webkit_version, libsoup_version, true);
		js_api.call_ipc_method_void.connect(on_call_ipc_method_void);
		js_api.call_ipc_method_async.connect(on_call_ipc_method_async);
		
		channel.call.begin("/nuvola/core/web-worker-initialized", null, (o, res) => {
			try {
				Assert.on_glib_thread();
				channel.call.end(res);
			} catch (GLib.Error e) {
				error("Runner client error: %s", e.message);
			}
		});
	}
	
	private void on_js_context_created(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		Assert.on_js_thread();
		apply_javascript_fixes(browser, frame, context);
		if (frame.is_main() > 0 && browser.get_identifier() == browser_id) {
			debug("Got JS context");
			init_frame(browser, frame, context);
		}
	}
	
	private void on_js_context_released(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		Assert.on_js_thread();
		if (frame.is_main() > 0 && browser.get_identifier() == browser_id) {
			debug("Lost JS context");
			js_api.release_context(context);
		}
	}
	
	private void apply_javascript_fixes(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		Assert.on_js_thread();
		/* No-op */
	}
	
	private void init_frame(Cef.Browser browser, Cef.Frame frame, Cef.V8context context) {
		Assert.on_js_thread();
		if (WEB_ENGINE_LOADING_URI == frame.get_url()) {
			ctx.event_loop.add_idle(() => {init(); return false;});
		} else {
			context.enter();
			try {
				js_api.inject(context, js_properties);
				js_api.integrate(context);
				js_api.acquire_context(context);
				ctx.event_loop.add_idle(emit_web_worker_ready_and_init_web_worker_cb);
			} catch (GLib.Error e) {
				show_error("Failed to inject JavaScript API. %s".printf(e.message));
			} finally {
				context.exit();
			}
		}
	}
	
	private bool emit_web_worker_ready_and_init_web_worker_cb() {
		Assert.on_glib_thread();
		channel.call.begin("/nuvola/core/web-worker-ready", null, (o, res) => {
			try {
				channel.call.end(res);
			} catch (GLib.Error e) {
				warning("Runner client error: %s", e.message);
			}
		});
		try {
			var args = new Variant("(s)", "InitWebWorker");
			js_api.call_function_sync("Nuvola.core.emit", args, true);
		} catch (GLib.Error e) {
			show_error("Failed to inject JavaScript API. %s".printf(e.message));
		}
		return false;
	}
	
	private void on_call_ipc_method_void(string name, Variant? data) {
		Assert.on_js_thread();
		ctx.event_loop.add_idle(() => {
			Assert.on_glib_thread();
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
		Assert.on_js_thread();
		ctx.event_loop.add_idle(() => {
			Assert.on_glib_thread();
			channel.call.begin(name, data, (o, res) => {
				Variant? response = null;
				GLib.Error? error = null;
				try {
					response = channel.call.end(res);
				} catch (GLib.Error e) {
					error = e;
				}
				try {
					if (error != null) {
						js_api.send_async_response(id, null, error);
					} else {
						js_api.send_async_response(id, response, null);
					}
				} catch (GLib.Error e) {
					critical("Failed to send async response: %s", e.message);
				}
			});
			return false;
		});
	}
	
	private void handle_call_function(Drt.RpcRequest request) throws GLib.Error {
		Assert.on_glib_thread();
		var name = request.pop_string();
		var func_params = request.pop_variant();
		var propagate_error = request.pop_bool();
		GLib.Error? error = null;
		try {
			func_params = js_api.call_function_sync(name, func_params, true);
		} catch (GLib.Error e) {
			if (propagate_error) {
				error = e;
			} else {
				show_error("Error during call of %s: %s".printf(name, e.message));
			}
		}
		if (error != null) {
			request.fail(error);
		} else {
			request.respond(func_params);
		}
	}
}

} // namespace Nuvola
