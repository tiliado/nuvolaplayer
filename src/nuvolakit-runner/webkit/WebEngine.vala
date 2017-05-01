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

using Nuvola.JSTools;

namespace Nuvola
{

public class WebEngine : GLib.Object, JSExecutor
{
	private const string ZOOM_LEVEL_CONF = "webview.zoom_level";
	
	public Gtk.Widget widget {get {return web_view;}}
	public WebAppMeta web_app {get; private set;}
	public WebAppStorage storage {get; private set;}
	public bool ready {get; private set; default = false;}
	public bool can_go_back {get; private set; default = false;}
	public bool can_go_forward {get; private set; default = false;}
	public bool web_plugins
	{
		get {return web_view.get_settings().enable_plugins;}
		set {web_view.get_settings().enable_plugins = value;}
	}
	public bool media_source_extension
	{
		get {return web_view.get_settings().enable_mediasource;}
		set {web_view.get_settings().enable_mediasource = value;}
	}
	
	private RunnerApplication runner_app;
	private WebView web_view;
	private JsEnvironment? env = null;
	private JSApi api;
	private IpcBus ipc_bus = null;
	public WebWorker web_worker {get; private set;}
	
	private Config config;
	private Diorite.KeyValueStorage session;
	
	private static WebKit.WebContext? default_context = null;
	
	public static bool init_web_context(WebAppStorage storage)
	{
		if (default_context != null)
			return false;
		
		var data_manager = (WebKit.WebsiteDataManager) GLib.Object.@new(
			typeof(WebKit.WebsiteDataManager),
			"base-cache-directory", storage.cache_dir.get_child("webkit").get_path(),
			"disk-cache-directory", storage.cache_dir.get_child("webcache").get_path(),
			"offline-application-cache-directory", storage.cache_dir.get_child("offline_apps").get_path(),
			"base-data-directory", storage.data_dir.get_child("webkit").get_path(),
			"local-storage-directory", storage.data_dir.get_child("local_storage").get_path(),
			"indexeddb-directory", storage.data_dir.get_child("indexeddb").get_path(),
			"websql-directory", storage.data_dir.get_child("websql").get_path());
		var cookie_manager = data_manager.get_cookie_manager();
		cookie_manager.set_persistent_storage(storage.data_dir.get_child("cookies.dat").get_path(),
			WebKit.CookiePersistentStorage.SQLITE);	
		var web_context =  new WebKit.WebContext.with_website_data_manager(data_manager);
		web_context.set_favicon_database_directory(storage.data_dir.get_child("favicons").get_path());
		default_context = web_context;
		return true;
	}
	
	public static WebKit.WebContext get_web_context()
	{
		if (default_context == null)
			error("Default context hasn't been set up yet. Call WebEngine.set_up_web_context().");
		return default_context;
	}
	
	public static uint get_webkit_version()
	{
		return WebKit.get_major_version() * 10000 + WebKit.get_minor_version() * 100 + WebKit.get_micro_version(); 
	}
	
	public static bool check_webkit_version(uint min, uint max=0)
	{
		var version = get_webkit_version();
 		return version >= min && (max == 0 || version < max);
	}
	
	public WebEngine(RunnerApplication runner_app, IpcBus ipc_bus, WebAppMeta web_app,
		WebAppStorage storage, Config config, Connection? connection, HashTable<string, Variant> worker_data)
	{
		this.ipc_bus = ipc_bus;
		this.runner_app = runner_app;
		this.storage = storage;
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
		
		if (connection != null)
			apply_network_proxy(connection);	
		var web_context = get_web_context();
		var webkit_extension_dir = Nuvola.get_libdir();
		debug("Nuvola WebKit Extension directory: %s", webkit_extension_dir);
		web_context.set_web_extensions_directory(webkit_extension_dir);
		var web_extension_data = Diorite.variant_from_hashtable(worker_data);
		debug("Nuvola WebKit Extension data: %s", web_extension_data.print(true));
		web_context.set_web_extensions_initialization_user_data(web_extension_data);
		
		if (web_app.allow_insecure_content)
			web_context.get_security_manager().register_uri_scheme_as_secure("http");
		
		web_context.download_started.connect(on_download_started);
		
		web_view = new WebView(web_context);
		config.set_default_value(ZOOM_LEVEL_CONF, 1.0);
		web_view.zoom_level = config.get_double(ZOOM_LEVEL_CONF);
		web_view.load_changed.connect(on_load_changed);
		session = new Diorite.KeyValueMap();
		register_ipc_handlers();
	}
	
	public signal void init_finished();
	public signal void web_worker_ready();
	public signal void app_runner_ready();
	public signal void init_form(HashTable<string, Variant> values, Variant entries);
	
	public signal void context_menu(WebKit.ContextMenu menu, Gdk.Event event, WebKit.HitTestResult hit_test_result);
	
	public signal void show_alert_dialog(ref bool handled, string message);
	
	public void init()
	{
		web_view.load_html("<html><body>A web app will be loaded shortly...</body></html>", WEB_ENGINE_LOADING_URI);
	}
	
	public void init_app_runner()
	{
		if (!ready)
		{
			web_view.notify["uri"].connect(on_uri_changed);
			web_view.notify["zoom-level"].connect(on_zoom_level_changed);
			web_view.decide_policy.connect(on_decide_policy);
			web_view.script_dialog.connect(on_script_dialog);
			web_view.context_menu.connect(on_context_menu);
		
			env = new JsRuntime();
			uint[] webkit_version = {WebKit.get_major_version(), WebKit.get_minor_version(), WebKit.get_micro_version()};
			uint[] libsoup_version = {Soup.get_major_version(), Soup.get_minor_version(), Soup.get_micro_version()};
			api = new JSApi(
				runner_app.storage, web_app.data_dir, storage.config_dir, config, session, webkit_version, libsoup_version);
			api.call_ipc_method_async.connect(on_call_ipc_method_async);
			api.call_ipc_method_sync.connect(on_call_ipc_method_sync);
			api.call_ipc_method_with_dict_async.connect(on_call_ipc_method_with_dict_async);
			api.call_ipc_method_with_dict_sync.connect(on_call_ipc_method_with_dict_sync);
			try
			{
				api.inject(env);
				api.initialize(env);
			}
			catch (JSError e)
			{
				runner_app.fatal_error("Initialization error", e.message);
			}
			try
			{
				var args = new Variant("(s)", "InitAppRunner");
				env.call_function("Nuvola.core.emit", ref args);
			}
			catch (GLib.Error e)
			{
				runner_app.fatal_error("Initialization error",
					"%s failed to initialize app runner. Initialization exited with error:\n\n%s".printf(
					runner_app.app_name, e.message));
			}
			debug("App Runner Initialized");
			ready = true;
		}
		if (!request_init_form())
		{
			debug("App Runner Ready");
			app_runner_ready();
		}
	}
	
	private bool web_worker_initialized_cb()
	{
		if (!web_worker.initialized)
		{
			web_worker.initialized = true;
			debug("Init finished");
			init_finished();
		}
		debug("Web Worker Ready");
		web_worker_ready();
		return false;
	}
	
	public void load_app()
	{
		try
		{
			var url = env.send_data_request_string("LastPageRequest", "url");
			if (url != null)
			{
				if (load_uri(url))
					return;
				runner_app.show_error("Invalid page URL", "The web app integration script has not provided a valid page URL '%s'.".printf(url));
			}
		}
		catch (GLib.Error e)
		{
			runner_app.show_error("Initialization error", "%s failed to retrieve a last visited page from previous session. Initialization exited with error:\n\n%s".printf(runner_app.app_name, e.message));
		}
		
		go_home();
	}
	
	public void go_home()
	{
		try
		{
			var url = env.send_data_request_string("HomePageRequest", "url");
			if (url == null)
				runner_app.fatal_error("Invalid home page URL", "The web app integration script has provided an empty home page URL.");
			else if (!load_uri(url))
			{
				runner_app.fatal_error("Invalid home page URL", "The web app integration script has not provided a valid home page URL '%s'.".printf(url));
			}
		}
		catch (GLib.Error e)
		{
			runner_app.fatal_error("Initialization error", "%s failed to retrieve a home page of  a web app. Initialization exited with error:\n\n%s".printf(runner_app.app_name, e.message));
		}
	}
	
	public void apply_network_proxy(Connection connection)
	{
		WebKit.NetworkProxyMode proxy_mode;
		WebKit.NetworkProxySettings? proxy_settings = null;
		string? host;
		int port;
		var type = connection.get_network_proxy(out host, out port);
		switch (type)
		{
		case NetworkProxyType.SYSTEM:
			proxy_mode = WebKit.NetworkProxyMode.DEFAULT;
			break;
		case NetworkProxyType.DIRECT:
			proxy_mode = WebKit.NetworkProxyMode.NO_PROXY;
			break;
		default:
			proxy_mode = WebKit.NetworkProxyMode.CUSTOM;
			var proxy_uri = "%s://%s:%d/".printf(
				type == NetworkProxyType.HTTP ? "http" : "socks",
				(host != null && host != "") ? host : "127.0.0.1", port);
			proxy_settings = new WebKit.NetworkProxySettings(proxy_uri, null);
			break;
		}
		get_web_context().set_network_proxy_settings(proxy_mode, proxy_settings);
	}
		
	private bool load_uri(string uri)
	{
		if (uri.has_prefix("http://") || uri.has_prefix("https://"))
		{
			web_view.load_uri(uri);
			return true;
		}
		
		if (uri.has_prefix("nuvola://"))
		{
			web_view.load_uri(web_app.data_dir.get_child(uri.substring(9)).get_uri());
			return true;
		}
		
		if (uri.has_prefix(web_app.data_dir.get_uri()))
		{
			web_view.load_uri(uri);
			return true;
		}
		
		return false;
	}
	
	
	
	public void go_back()
	{
		web_view.go_back();
	}
	
	public void go_forward()
	{
		web_view.go_forward();
	}
	
	public void reload()
	{
		web_view.reload();
	}
	
	public void zoom_in()
	{
		web_view.zoom_in();
	}
	
	public void zoom_out()
	{
		web_view.zoom_out();
	}
	
	public void zoom_reset()
	{
		web_view.zoom_reset();
	}
	
	public void set_user_agent(string? user_agent)
	{
		string? agent = null;
		string? browser = null;
		string? version = null;	
		if (user_agent != null)
		{
			agent = user_agent.strip();
			if (agent[0] == '\0')
				agent = null;
		}
		
		if (agent != null)
		{
			var parts = agent.split_set(" \t", 2);
			browser = parts[0];
			if (browser != null)
			{
				browser = browser.strip();
				if (browser[0] == '\0')
					browser = null;
			}
			version = parts[1];
			if (version != null)
			{
				version = version.strip();
				if (version[0] == '\0')
					version = null;
			}
		}
		
		switch (browser)
		{
		case "CHROME":
			var s = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/%s Safari/537.36";
			agent = s.printf(version ?? "50.0.2661.94");
			break;
		case "FIREFOX":
			var s = "Mozilla/5.0 (X11; Linux x86_64; rv:%1$s) Gecko/20100101 Firefox/%1$s";
			agent = s.printf(version ?? "46.0");
			break;
		}
		
		unowned WebKit.Settings settings = web_view.get_settings();	
		settings.user_agent = agent;
		message("User agent set '%s'", settings.user_agent);
	}
	public void get_preferences(out Variant values, out Variant entries)
	{
		var args = new Variant("(s@a{sv}@av)", "PreferencesForm", new Variant.array(new VariantType("{sv}"), {}), new Variant.array(VariantType.VARIANT, {}));
		try
		{
			env.call_function("Nuvola.core.emit", ref args);
		}
		catch (GLib.Error e)
		{
			runner_app.show_error("Integration error", "%s failed to load preferences with error:\n\n%s".printf(runner_app.app_name, e.message));
		}
		args.get("(s@a{smv}@av)", null, out values, out entries);
	}

	public void call_function(string name, ref Variant? params) throws GLib.Error
	{
		env.call_function(name, ref params);
	}
	
	private bool request_init_form()
	{
		Variant values;
		Variant entries;
		var args = new Variant("(s@a{sv}@av)", "InitializationForm", new Variant.array(new VariantType("{sv}"), {}), new Variant.array(VariantType.VARIANT, {}));
		try
		{
			env.call_function("Nuvola.core.emit", ref args);
		}
		catch (GLib.Error e)
		{
			runner_app.fatal_error("Initialization error", "%s failed to crate initialization form. Initialization exited with error:\n\n%s".printf(runner_app.app_name, e.message));
			return false;
		}
		
		args.get("(s@a{smv}@av)", null, out values, out entries);
		var values_hashtable = Diorite.variant_to_hashtable(values);
		if (values_hashtable.size() > 0)
		{
			debug("Init form requested");
			init_form(values_hashtable, entries);
			return true;
		}
		return false;
	}
	
	private void register_ipc_handlers()
	{
		assert(ipc_bus != null);
		var router = ipc_bus.router;
		router.add_method("/nuvola/core/web-worker-initialized", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Notify that the web worker has been initialized.",
			handle_web_worker_initialized, null);
		router.add_method("/nuvola/core/web-worker-ready", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Notify that the web worker is ready.",
			handle_web_worker_ready, null);
		router.add_method("/nuvola/core/get-data-dir", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			"Return data directory.",
			handle_get_data_dir, null);
		router.add_method("/nuvola/core/get-user-config-dir", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			"Return user config directory.",
			handle_get_user_config_dir, null);
		router.add_method("/nuvola/core/session-has-key", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			"Whether the session has a given key.",
			handle_session_has_key, {
			new Drt.StringParam("key", true, false, null, "Session key.")
		});
		router.add_method("/nuvola/core/session-get-value", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			"Get session value for the given key.",
			handle_session_get_value, {
			new Drt.StringParam("key", true, false, null, "Session key.")
		});
		router.add_method("/nuvola/core/session-set-value", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Set session value for the given key.",
			handle_session_set_value, {
			new Drt.StringParam("key", true, false, null, "Session key."),
			new Drt.VariantParam("value", true, true, null, "Session value.")
		});
		router.add_method("/nuvola/core/session-set-default-value", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Set default session value for the given key.",
			handle_session_set_default_value, {
			new Drt.StringParam("key", true, false, null, "Session key."),
			new Drt.VariantParam("value", true, true, null, "Session value.")
		});
		router.add_method("/nuvola/core/config-has-key", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			"Whether the config has a given key.",
			handle_config_has_key, {
			new Drt.StringParam("key", true, false, null, "Config key.")
		});
		router.add_method("/nuvola/core/config-get-value", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			"Get config value for the given key.",
			handle_config_get_value, {
			new Drt.StringParam("key", true, false, null, "Config key.")
		});
		router.add_method("/nuvola/core/config-set-value", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Set config value for the given key.",
			handle_config_set_value, {
			new Drt.StringParam("key", true, false, null, "Config key."),
			new Drt.VariantParam("value", true, true, null, "Config value.")
		});
		router.add_method("/nuvola/core/config-set-default-value", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Set default config value for the given key.",
			handle_config_set_default_value, {
			new Drt.StringParam("key", true, false, null, "Config key."),
			new Drt.VariantParam("value", true, true, null, "Config value.")
		});
		router.add_method("/nuvola/core/show-error", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Show error message.",
			handle_show_error, {
			new Drt.StringParam("text", true, false, null, "Error message.")
		});
		router.add_method("/nuvola/browser/download-file-async", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
				"Download file.",
				handle_download_file_async, {
				new Drt.StringParam("uri", true, false, null, "File to download."),
				new Drt.StringParam("basename", true, false, null, "Basename of the file."),
				new Drt.DoubleParam("callback-id", true, null, "Callback id.")
			});
	}
	
	private Variant? handle_web_worker_ready(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		if (!web_worker.ready)
			web_worker.ready = true;
		web_worker_ready();
		return null;
	}
	
	private Variant? handle_web_worker_initialized(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var channel = source as Drt.ApiChannel;
		return_val_if_fail(channel != null, null);
		ipc_bus.connect_web_worker(channel);
		Idle.add(web_worker_initialized_cb);
		return null;
	}
	
	
	
	private Variant? handle_get_data_dir(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		return new Variant.string(web_app.data_dir.get_path());
	}
	
	private Variant? handle_get_user_config_dir(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		return new Variant.string(storage.config_dir.get_path());
	}
	
	private Variant? handle_session_has_key(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		return new Variant.boolean(session.has_key(params.pop_string()));
	}
	
	private Variant? handle_session_get_value(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var response = session.get_value(params.pop_string());
		if (response == null)
			response = new Variant("mv", null);
		return response;
	}
	
	private Variant? handle_session_set_value(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		session.set_value(params.pop_string(), params.pop_variant());
		return null;
	}
	
	private Variant? handle_session_set_default_value(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		session.set_default_value(params.pop_string(), params.pop_variant());
		return null;
	}
	
	private Variant? handle_config_has_key(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		return new Variant.boolean(config.has_key(params.pop_string()));
	}
	
	private Variant? handle_config_get_value(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var response = config.get_value(params.pop_string());
		if (response == null)
			response = new Variant("mv", null);
		return response;
	}
	
	private Variant? handle_config_set_value(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		config.set_value(params.pop_string(), params.pop_variant());
		return null;
	}
	
	private Variant? handle_config_set_default_value(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		config.set_default_value(params.pop_string(), params.pop_variant());
		return null;
	}
	
	private Variant? handle_show_error(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		runner_app.show_error("Integration error", params.pop_string());
		return null;
	}
	
	private void on_call_ipc_method_async(string name, Variant? data)
	{
		try
		{
			ipc_bus.call_local(name, data);
		}
		catch (GLib.Error e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
		}
	}
	
	private void on_call_ipc_method_sync(string name, Variant? data, ref Variant? result)
	{
		try
		{
			result = ipc_bus.call_local(name, data);
		}
		catch (GLib.Error e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
	
	private void on_call_ipc_method_with_dict_async(string name, Variant? data)
	{
		try
		{
			ipc_bus.call_local_with_dict(name, data);
		}
		catch (GLib.Error e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
		}
	}
	
	private void on_call_ipc_method_with_dict_sync(string name, Variant? data, ref Variant? result)
	{
		try
		{
			result = ipc_bus.call_local_with_dict(name, data);
		}
		catch (GLib.Error e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
	
	private Variant? handle_download_file_async(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var uri = params.pop_string();
		var basename = params.pop_string();
		var cb_id = params.pop_double();

		var dir = storage.cache_dir.get_child("api-downloads");
		try
		{
			dir.make_directory_with_parents();
		}
		catch (GLib.Error e)
		{
		}
		var file = dir.get_child(basename);
		try
		{
			file.@delete();
		}
		catch (GLib.Error e)
		{
		}
		var download = get_web_context().download_uri(uri);
		download.set_destination(file.get_uri());
		ulong[] handler_ids = new ulong[2];
		
		handler_ids[0] = download.finished.connect((d) => {
			try
			{
				var payload = new Variant(
					"(dbusss)", cb_id, true, d.get_response().status_code, d.get_response().status_code.to_string(), file.get_path(), file.get_uri());
				web_worker.call_function("Nuvola.browser._downloadDone", ref payload);
			}
			catch (GLib.Error e)
			{
				warning("Communication failed: %s", e.message);
			}
			download.disconnect(handler_ids[0]);
			download.disconnect(handler_ids[1]);
			
		});
		
		handler_ids[1] = download.failed.connect((d, err) => {
			WebKit.DownloadError e = (WebKit.DownloadError) err;
			if (e is WebKit.DownloadError.DESTINATION)
				warning("Download failed because of destination: %s", e.message);
			else
				warning("Download failed: %s", e.message);
			try
			{
				var payload = new Variant(
					"(dbusss)", cb_id, false, d.get_response().status_code, d.get_response().status_code.to_string(), "", "");
				web_worker.call_function("Nuvola.browser._downloadDone", ref payload);
			}
			catch (GLib.Error e)
			{
				warning("Communication failed: %s", e.message);
			}
			download.disconnect(handler_ids[0]);
			download.disconnect(handler_ids[1]);
		});
		
		return null;
	}
	
	private void on_load_changed(WebKit.LoadEvent load_event)
	{
		if (load_event == WebKit.LoadEvent.STARTED && web_worker != null)
		{
			debug("Load started");
			web_worker.ready = false;
		}
	}
	
	private void on_download_started(WebKit.Download download)
	{
		download.decide_destination.connect(on_download_decide_destination);
	}
	
	private bool on_download_decide_destination(WebKit.Download download, string filename)
	{
	
		if (download.destination == null)
			download.cancel();
		download.decide_destination.disconnect(on_download_decide_destination);
		return true;
	}
	
	private bool decide_navigation_policy(bool new_window, WebKit.NavigationPolicyDecision decision)
	{
		var action = decision.navigation_action;
		var uri = action.get_request().uri;
		if (!uri.has_prefix("http://") && !uri.has_prefix("https://"))
			return false;
		
		var new_window_override = new_window;
		var result = navigation_request(uri, ref new_window_override);
		
		var type = action.get_navigation_type();
		var user_gesture = action.is_user_gesture();
		debug("Navigation, %s window: uri = %s, result = %s, frame = %s, type = %s, user gesture %s",
			new_window_override ? "new" : "current", uri, result.to_string(), decision.frame_name, type.to_string(),
			user_gesture.to_string());
		
		// We care only about user clicks
		if (type != WebKit.NavigationType.LINK_CLICKED && !user_gesture)
			return false;
		
		if (result)
		{
			if (new_window != new_window_override)
			{
				if (!new_window_override)
				{
					// Open in current window instead of a new window
					decision.ignore();
					Idle.add(() => 
					{
						web_view.load_uri(uri);
						return false;
					});
					return true;
				}
				warning("Overriding of new window flag false -> true hasn't been implemented yet.");
			}
			decision.use();
			return true;
		}
		else
		{
			try
			{
				Gtk.show_uri(null, uri, Gdk.CURRENT_TIME);
				decision.ignore();
				return true;
			}
			catch (GLib.Error e)
			{
				critical("Failed to open '%s' in a default web browser. %s", uri, e.message);
				return false;
			}
		}
	}
	
	private bool on_decide_policy(WebKit.PolicyDecision decision, WebKit.PolicyDecisionType decision_type)
	{
		switch (decision_type)
		{
		case WebKit.PolicyDecisionType.NAVIGATION_ACTION:
			return decide_navigation_policy(false, (WebKit.NavigationPolicyDecision) decision);
		case WebKit.PolicyDecisionType.NEW_WINDOW_ACTION:
			return decide_navigation_policy(true, (WebKit.NavigationPolicyDecision) decision);
		case WebKit.PolicyDecisionType.RESPONSE:
		default:
			return false;
		}
	}
	
	private bool navigation_request(string url, ref bool new_window)
	{
		var builder = new VariantBuilder(new VariantType("a{smv}"));
		builder.add("{smv}", "url", new Variant.string(url));
		builder.add("{smv}", "approved", new Variant.boolean(true));
		builder.add("{smv}", "newWindow", new Variant.boolean(new_window));
		var args = new Variant("(s@a{smv})", "NavigationRequest", builder.end());
		try
		{
			env.call_function("Nuvola.core.emit", ref args);
		}
		catch (GLib.Error e)
		{
			runner_app.show_error("Integration script error", "The web app integration script has not provided a valid response and caused an error: %s".printf(e.message));
			return true;
		}
		VariantIter iter = args.iterator();
		assert(iter.next("s", null));
		assert(iter.next("a{smv}", &iter));
		string key = null;
		Variant value = null;
		bool approved = false;
		while (iter.next("{smv}", &key, &value))
		{
			if (key == "approved")
				approved = value != null ? value.get_boolean() : false;
			else if (key == "newWindow" && value != null)
				new_window = value.get_boolean();
		}
		return approved;
	}
	
	private void on_uri_changed(GLib.Object o, ParamSpec p)
	{
		can_go_back = web_view.can_go_back();
		can_go_forward = web_view.can_go_forward();
		var args = new Variant("(sms)", "UriChanged", web_view.uri);
		try
		{
			env.call_function("Nuvola.core.emit", ref args);
		}
		catch (GLib.Error e)
		{
			runner_app.show_error("Integration script error", "The web app integration caused an error: %s".printf(e.message));
		}
	}
	
	private void on_zoom_level_changed(GLib.Object o, ParamSpec p)
	{
		config.set_double(ZOOM_LEVEL_CONF, web_view.zoom_level);
	}
	
	private bool on_script_dialog(WebKit.ScriptDialog dialog)
	{
		bool handled = false;
		if (dialog.get_dialog_type() == WebKit.ScriptDialogType.ALERT)
			show_alert_dialog(ref handled, dialog.get_message());
		return handled;
	}
	
	private bool on_context_menu(WebKit.ContextMenu menu, Gdk.Event event, WebKit.HitTestResult hit_test_result)
	{
		context_menu(menu, event, hit_test_result);
		return false;
	}
}

public enum NetworkProxyType
{
	SYSTEM,
	DIRECT,
	HTTP,
	SOCKS;
	
	public static NetworkProxyType from_string(string type)
	{
		switch (type.down())
		{
		case "none":
		case "direct":
			return DIRECT;
		case "http":
			return HTTP;
		case "socks":
			return SOCKS;
		default:
			return SYSTEM;
		}
	}
	
	public string to_string()
	{
		switch (this)
		{
		case DIRECT:
			return "direct";
		case HTTP:
			return "http";
		case SOCKS:
			return "socks";
		default:
			return "system";
		}
	}
}

} // namespace Nuvola
