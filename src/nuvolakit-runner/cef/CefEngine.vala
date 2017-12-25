/*
 * Copyright 2014-2017 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if HAVE_CEF
namespace Nuvola {

/* TODO
 * web_app.allow_insecure_content
 * album art download
 * request filtering
 * context menu - password manager
 * JavaScript dialogs
 * initialization form - request_init_form()
 * network proxy
 * config & session key-value storage
 */

public class CefEngine : WebEngine {
	private const string ZOOM_LEVEL_CONF = "webview.cef_zoom_level";
	
	public override Gtk.Widget get_main_web_view(){return web_view;}
	
	private AppRunnerController runner_app;
	private CefGtk.WebContext web_context;
	private CefGtk.WebView web_view;
	private JsEnvironment? env = null;
	private JSApi api;
	private IpcBus ipc_bus = null;
	private Config config;
	private Drt.KeyValueStorage session;
	private HashTable<string, Variant> worker_data;
	
	public CefEngine(CefOptions web_options, WebApp web_app) {
		base(web_options, web_app);
		web_context = web_options.default_context;
	}
	
	public override void early_init(AppRunnerController runner_app, IpcBus ipc_bus,
	Config config, Connection? connection, HashTable<string, Variant> worker_data)	{
		this.ipc_bus = ipc_bus;
		this.runner_app = runner_app;
		this.config = config;
		this.web_worker = new RemoteWebWorker(ipc_bus);
		this.worker_data = worker_data;
		worker_data["NUVOLA_API_ROUTER_TOKEN"] = ipc_bus.router.hex_token;
		worker_data["WEBKITGTK_MAJOR"] = WebKit.get_major_version();
		worker_data["WEBKITGTK_MINOR"] = WebKit.get_minor_version();
		worker_data["WEBKITGTK_MICRO"] = WebKit.get_micro_version();
		worker_data["LIBSOUP_MAJOR"] = Soup.get_major_version();
		worker_data["LIBSOUP_MINOR"] = Soup.get_minor_version();
		worker_data["LIBSOUP_MICRO"] = Soup.get_micro_version();
		
		if (connection != null)
			apply_network_proxy(connection);
		if (web_app.allow_insecure_content)
			warning("Not implemented: web_app.allow_insecure_content");
		
		session = new Drt.KeyValueMap();
		register_ipc_handlers();
		web_view = new CefGtk.WebView(web_context);
		config.set_default_value(ZOOM_LEVEL_CONF, 0.0);
		web_view.zoom_level = config.get_double(ZOOM_LEVEL_CONF);
		web_view.load_started.connect(on_load_started);
	}
	
	~CefEngine() {
	}
	
	public override void init() {
		if (web_view.is_ready()) {
			load_extension();
		} else {
			web_view.ready.connect(on_web_view_ready);
		}
	}
	
	private void on_web_view_ready(CefGtk.WebView web_view) {
		load_extension();
		web_view.ready.disconnect(on_web_view_ready);
	}
	
	private void load_extension() {
		var data = worker_data;
		var size = data.size();
		var args = new Variant?[2 * size];
		var iter = HashTableIter<string, Variant>(data);
		string key = null;
		Variant val = null;
		for (var i = 0; i < size && iter.next (out key, out val); i++) {
			args[2 * i] = new Variant.string(key);
			args[2 * i + 1] = val;
		}
		web_view.load_renderer_extension(Nuvola.get_libdir() + "/libnuvolaruntime-cef-worker.so", args);
	}
	
	public override void init_app_runner() {
		if (!ready) {
			web_view.notify.connect_after(on_web_view_notify);
			update_from_web_view("is-loading");
			update_from_web_view("can-go-back");
			update_from_web_view("can-go-forward");
			
			env = new JsRuntime();
			uint[] webkit_version = {
				WebKit.get_major_version(),
				WebKit.get_minor_version(),
				WebKit.get_micro_version()};
			uint[] libsoup_version = {
				Soup.get_major_version(),
				Soup.get_minor_version(),
				Soup.get_micro_version()};
			api = new JSApi(
				runner_app.storage, web_app.data_dir, storage.config_dir, config, session, webkit_version,
				libsoup_version, false);
			api.call_ipc_method_void.connect(on_call_ipc_method_void);
			api.call_ipc_method_sync.connect(on_call_ipc_method_sync);
			api.call_ipc_method_async.connect(on_call_ipc_method_async);
			try {
				api.inject(env);
				api.initialize(env);
			} catch (JSError e) {
				runner_app.fatal_error("Initialization error", e.message);
			}
			try {
				var args = new Variant("(s)", "InitAppRunner");
				env.call_function_sync("Nuvola.core.emit", ref args);
			} catch (GLib.Error e) {
				runner_app.fatal_error("Initialization error",
					"%s failed to initialize app runner. Initialization exited with error:\n\n%s".printf(
					runner_app.app_name, e.message));
			}
			debug("App Runner Initialized");
			ready = true;
		}
		debug("App Runner Ready");
		app_runner_ready();
	}
	
	public override void load_app() {
		try {
			var url = env.send_data_request_string("LastPageRequest", "url");
			if (url != null) {
				if (load_uri(url)) {
					return;
				} else {
					runner_app.show_error("Invalid page URL",
						"The web app integration script has not provided a valid page URL '%s'.".printf(url));
				}
			}
		} catch (GLib.Error e) {
			runner_app.show_error("Initialization error",
				("%s failed to retrieve a last visited page from previous session."
				+ " Initialization exited with error:\n\n%s").printf(runner_app.app_name, e.message));
		}
		go_home();
	}
	
	public override void go_home() {
		try {
			var url = env.send_data_request_string("HomePageRequest", "url");
			if (url == null) {
				runner_app.fatal_error("Invalid home page URL",
					"The web app integration script has provided an empty home page URL.");
			} else if (!load_uri(url)) {
				runner_app.fatal_error("Invalid home page URL",
					"The web app integration script has not provided a valid home page URL '%s'.".printf(url));
			}
		} catch (GLib.Error e) {
			runner_app.fatal_error("Initialization error",
				"%s failed to retrieve a home page of  a web app. Initialization exited with error:\n\n%s".printf(
					runner_app.app_name, e.message));
		}
	}
	
	public override void apply_network_proxy(Connection connection) {
		warning("Not implemented: apply_network_proxy()");
	}
	
	public override string? get_url() {
		return web_view != null ? web_view.uri : null;
	}
	
	public override void load_url(string url) {
		load_uri(url);
	}
	
	private bool load_uri(string uri) {
		if (uri.has_prefix("http://") || uri.has_prefix("https://")) {
			web_view.load_uri(uri);
			return true;
		}
		if (uri.has_prefix("nuvola://")) {
			web_view.load_uri(web_app.data_dir.get_child(uri.substring(9)).get_uri());
			return true;
		}
		if (uri.has_prefix(web_app.data_dir.get_uri())) {
			web_view.load_uri(uri);
			return true;
		}
		return false;
	}
	
	public override void go_back() {
		web_view.go_back();
	}
	
	public override void go_forward() {
		web_view.go_forward();
	}
	
	public override void reload() {
		web_view.reload();
	}
	
	public override void zoom_in() {
		web_view.zoom_in();
	}
	
	public override void zoom_out() {
		web_view.zoom_out();
	}
	
	public override void zoom_reset() {
		web_view.zoom_reset();
	}
	
	public override void get_preferences(out Variant values, out Variant entries) {
		var args = new Variant("(s@a{sv}@av)", "PreferencesForm",
			new Variant.array(new VariantType("{sv}"), {}), new Variant.array(VariantType.VARIANT, {}));
		try {
			env.call_function_sync("Nuvola.core.emit", ref args);
		} catch (GLib.Error e) {
			runner_app.show_error("Integration error", "%s failed to load preferences with error:\n\n%s".printf(
				runner_app.app_name, e.message));
		}
		args.get("(s@a{smv}@av)", null, out values, out entries);
	}

	public override void call_function_sync(string name, ref Variant? params, bool propagate_error=false)
	throws GLib.Error {
		env.call_function_sync(name, ref params);
	}
	
	private void register_ipc_handlers() {
		assert(ipc_bus != null);
		var router = ipc_bus.router;
		message("Partially implemented: register_ipc_handlers()");
		router.add_method("/nuvola/core/web-worker-initialized", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
			"Notify that the web worker has been initialized.",
			handle_web_worker_initialized, null);
		router.add_method("/nuvola/core/web-worker-ready", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
			"Notify that the web worker is ready.",
			handle_web_worker_ready, null);
		router.add_method("/nuvola/core/get-data-dir", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
			"Return data directory.",
			handle_get_data_dir, null);
		router.add_method("/nuvola/core/get-user-config-dir", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
			"Return user config directory.",
			handle_get_user_config_dir, null);
	}
	
	private bool web_worker_initialized_cb() {
		if (!web_worker.initialized) {
			web_worker.initialized = true;
			debug("Init finished");
			init_finished();
		}
		debug("Web Worker Ready");
		web_worker_ready();
		return false;
	}
	
	private void handle_get_data_dir(Drt.RpcRequest request) throws Drt.RpcError {
		request.respond(new Variant.string(web_app.data_dir.get_path()));
	}
	
	private void handle_get_user_config_dir(Drt.RpcRequest request) throws Drt.RpcError {
		request.respond(new Variant.string(storage.config_dir.get_path()));
	}
	
	private void handle_web_worker_initialized(Drt.RpcRequest request) throws Drt.RpcError {
		var channel = request.connection as Drt.RpcChannel;
		assert(channel != null);
		ipc_bus.connect_web_worker(channel);
		Idle.add(web_worker_initialized_cb);
		request.respond(null);
	}
	
	private void handle_web_worker_ready(Drt.RpcRequest request) throws Drt.RpcError {
		if (!web_worker.ready) {
			web_worker.ready = true;
		}
		web_worker_ready();
		request.respond(null);
	}
	
	private void on_load_started(Cef.TransitionType transition) {
		if (web_worker != null) {
			debug("Load started");
		}
	}
	
	private void on_web_view_notify(GLib.Object? o, ParamSpec param) {
        update_from_web_view(param.name);
    }
    
    private void on_call_ipc_method_void(string name, Variant? data) {
		try {
			ipc_bus.local.call.begin(name, data, (o, res) => {
				try {
					ipc_bus.local.call.end(res);	
				} catch (GLib.Error e) {
					warning("IPC call error: %s", e.message);
				}});
		} catch (GLib.Error e) {
			critical("Failed to send message '%s'. %s", name, e.message);
		}
	}
	
	private void on_call_ipc_method_async(JSApi js_api, string name, Variant? data, int id) {
		try {
			ipc_bus.local.call.begin(name, data, (o, res) => {
				try {
					var response = ipc_bus.local.call.end(res);
					js_api.send_async_response(id, response, null);
				} catch (GLib.Error e) {
					js_api.send_async_response(id, null, e);
				}});
		} catch (GLib.Error e) {
			critical("Failed to send message '%s'. %s", name, e.message);
		}
	}
	
	private void on_call_ipc_method_sync(string name, Variant? data, ref Variant? result) {
		try {
			result = ipc_bus.local.call_sync(name, data);
		} catch (GLib.Error e) {
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
    
    private void update_from_web_view(string property) {
        switch (property) {
		case "zoom-level":
			config.set_double(ZOOM_LEVEL_CONF, web_view.zoom_level);
			break;
        case "uri":
            var args = new Variant("(sms)", "UriChanged", web_view.uri);
			try {
				env.call_function_sync("Nuvola.core.emit", ref args);
			} catch (GLib.Error e) {
				runner_app.show_error("Integration script error", "The web app integration caused an error: %s".printf(e.message));
			}
            break;
        case "is-loading":
			is_loading = web_view.is_loading;
            break;
        case "can-go-back":
            can_go_back = web_view.can_go_back;
            break;
        case "can-go-forward":
            can_go_forward = web_view.can_go_forward;
            break;
        }
    }
}

} // namespace Nuvola
#endif
