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

public class CefEngine : WebEngine {
	private const string ZOOM_LEVEL_CONF = "webview.zoom_level";
	
	public override Gtk.Widget get_main_web_view(){return web_view;}
	public override bool get_web_plugins(){return ((CefOptions) options).flash_enabled;}
	public override void set_web_plugins(bool enabled){}
	public override void set_media_source_extension (bool enabled){}
	public override bool get_media_source_extension(){return true;}
	
	private AppRunnerController runner_app;
	private CefGtk.WebContext web_context;
	private CefGtk.WebView web_view;
	private JsEnvironment? env = null;
	private JSApi api;
	private IpcBus ipc_bus = null;
	private Config config;
	private Drt.KeyValueStorage session;
	
	public CefEngine(CefOptions web_options) {
		base(web_options);
		web_context = web_options.default_context;
	}
	
	public override void early_init(AppRunnerController runner_app, IpcBus ipc_bus,
	WebApp web_app, Config config, Connection? connection, HashTable<string, Variant> worker_data)	{
		this.ipc_bus = ipc_bus;
		this.runner_app = runner_app;
		this.web_app = web_app;
		this.config = config;
		this.web_worker = new RemoteWebWorker(ipc_bus);
		
		worker_data["NUVOLA_API_ROUTER_TOKEN"] = ipc_bus.router.hex_token;
		worker_data["WEBKITGTK_MAJOR"] = WebKit.get_major_version();
		worker_data["WEBKITGTK_MINOR"] = WebKit.get_minor_version();
		worker_data["WEBKITGTK_MICRO"] = WebKit.get_micro_version();
		worker_data["LIBSOUP_MAJOR"] = Soup.get_major_version();
		worker_data["LIBSOUP_MINOR"] = Soup.get_minor_version();
		worker_data["LIBSOUP_MICRO"] = Soup.get_micro_version();
		
		session = new Drt.KeyValueMap();
		web_view = new CefGtk.WebView(web_context);
	}
	
	~CefEngine() {
	}
	
	public override void init() {
		message("Partially implemented: init()");
		web_worker_initialized_cb();
	}
	
	public override void init_app_runner() {
		message("Partially implemented: init_app_runner()");
		if (!ready) {
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
		go_home();
	}
	
	public override void go_home() {
		try {
			var url = env.send_data_request_string("HomePageRequest", "url");
			if (url == null) {
				runner_app.fatal_error("Invalid home page URL", "The web app integration script has provided an empty home page URL.");
			} else if (!load_uri(url)) {
				runner_app.fatal_error("Invalid home page URL", "The web app integration script has not provided a valid home page URL '%s'.".printf(url));
			}
		} catch (GLib.Error e) {
			runner_app.fatal_error("Initialization error", "%s failed to retrieve a home page of  a web app. Initialization exited with error:\n\n%s".printf(runner_app.app_name, e.message));
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
	
	public override void set_user_agent(string? user_agent) {
		warning("Not implemented: set_user_agent(%s)", user_agent);
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
		warning("Not implemented: call_function_sync(%s)", name);
	}
	
	private void register_ipc_handlers() {
		assert(ipc_bus != null);
		var router = ipc_bus.router;
		warning("Not implemented: register_ipc_handlers()");
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
}

} // namespace Nuvola
#endif
