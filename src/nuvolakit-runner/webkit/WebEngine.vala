/*
 * Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
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
	private static const string ZOOM_LEVEL_CONF = "webview.zoom_level";
	
	public Gtk.Widget widget {get {return web_view;}}
	public WebAppMeta web_app {get; private set;}
	public WebAppStorage storage {get; private set;}
	public bool can_go_back {get; private set; default = false;}
	public bool can_go_forward {get; private set; default = false;}
	public bool web_plugins
	{
		get {return web_view.get_settings().enable_plugins;}
		set {web_view.get_settings().enable_plugins = value;}
	}
	
	private RunnerApplication runner_app;
	private WebView web_view;
	private JsEnvironment? env = null;
	private JSApi api;
	private Diorite.Ipc.MessageServer server = null;
	private bool initialized = false;
	
	private Config config;
	private Diorite.KeyValueStorage session;
	
	public WebEngine(RunnerApplication runner_app, Diorite.Ipc.MessageServer server, WebAppMeta web_app,
		WebAppStorage storage, Config config, string? proxy_uri)
	{
		this.server = server;
		this.runner_app = runner_app;
		this.storage = storage;
		this.web_app = web_app;
		this.config = config;
		
		Environment.set_variable("WEBKITGTK_MAJOR", WebKit.get_major_version().to_string(), true);
		Environment.set_variable("WEBKITGTK_MINOR", WebKit.get_minor_version().to_string(), true);
		Environment.set_variable("WEBKITGTK_MICRO", WebKit.get_micro_version().to_string(), true);
		
		var webkit_extension_dir = Nuvola.get_libdir();
		debug("Nuvola WebKit Extension directory: %s", webkit_extension_dir);
		apply_network_proxy(proxy_uri);
		
		var wc = WebKit.WebContext.get_default();
		wc.set_web_extensions_directory(webkit_extension_dir);
		wc.set_favicon_database_directory(storage.data_dir.get_child("favicons").get_path());
		wc.set_disk_cache_directory(storage.cache_dir.get_child("webcache").get_path());
		if (WebEngine.check_webkit_version(20800))
			wc.set_property("local-storage-directory", storage.data_dir.get_child("local_storage").get_path());
		
		var cm = wc.get_cookie_manager();
		cm.set_persistent_storage(storage.data_dir.get_child("cookies.dat").get_path(),
			WebKit.CookiePersistentStorage.SQLITE);
		
		web_view = new WebView();
		config.set_default_value(ZOOM_LEVEL_CONF, 1.0);
		web_view.zoom_level = config.get_double(ZOOM_LEVEL_CONF);
		
		session = new Diorite.KeyValueMap();
		
		web_view.notify["uri"].connect(on_uri_changed);
		web_view.notify["zoom-level"].connect(on_zoom_level_changed);
		web_view.decide_policy.connect(on_decide_policy);
		web_view.script_dialog.connect(on_script_dialog);
		set_up_ipc();
	}
	
	public static uint get_webkit_version()
	{
		return WebKit.get_major_version() * 10000 + WebKit.get_minor_version() * 100 + WebKit.get_micro_version(); 
	}
	
	public signal void show_alert_dialog(ref bool handled, string message);
	
	private void apply_network_proxy(string? proxy_uri)
	{
		if (proxy_uri != null)
		{
			/* This is an ugly hack! See https://bugs.webkit.org/show_bug.cgi?id=128674 */
			Environment.unset_variable("GNOME_DESKTOP_SESSION_ID");
			Environment.unset_variable("DESKTOP_SESSION");
			Environment.set_variable("http_proxy", proxy_uri, true);
			Environment.set_variable("https_proxy", proxy_uri, true);
		}
	}
	
	public static bool check_webkit_version(uint min, uint max=0)
	{
		var version = get_webkit_version();
 		return version >= min && (max == 0 || version < max);
	}
	
	public signal void init_form(HashTable<string, Variant> values, Variant entries);
	
	private bool inject_api()
	{
		if (env != null)
			return true;
		
		env = new JsRuntime();
		uint[] webkit_version = {WebKit.get_major_version(), WebKit.get_minor_version(), WebKit.get_micro_version()};
		api = new JSApi(runner_app.storage, web_app.data_dir, storage.config_dir, config, session, webkit_version);
		api.send_message_async.connect(on_send_message_async);
		api.send_message_sync.connect(on_send_message_sync);
		try
		{
			api.inject(env);
			api.initialize(env);
		}
		catch (JSError e)
		{
			runner_app.fatal_error("Initialization error", e.message);
			return false;
		}
		return true;
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
	
	public bool load()
	{
		if (!initialized)
		{
			if (!inject_api())
				return false;
			
			var args = new Variant("(s)", "InitAppRunner");
			try
			{
				env.call_function("Nuvola.core.emit", ref args);
			}
			catch (GLib.Error e)
			{
				runner_app.fatal_error("Initialization error",
					"%s failed to initialize app runner. Initialization exited with error:\n\n%s".printf(
					runner_app.app_name, e.message));
				return false;
			}
			
			initialized = true;
		}
		
		if (check_init_form())
			return true;
		
		return restore_session();
	}
	
	private bool restore_session()
	{
		var result = false;
		try
		{
			var url = env.send_data_request_string("LastPageRequest", "url");
			if (url == null)
				return try_go_home();
			
			result = load_uri(url);
			if (!result)
				runner_app.show_error("Invalid page URL", "The web app integration script has not provided a valid page URL '%s'.".printf(url));
		}
		catch (GLib.Error e)
		{
			runner_app.show_error("Initialization error", "%s failed to retrieve a last visited page from previous session. Initialization exited with error:\n\n%s".printf(runner_app.app_name, e.message));
		}
		
		if (!result)
			return try_go_home();
		return true;
	}
	
	public void go_home()
	{
		try_go_home();
	}
	
	public bool try_go_home()
	{
		try
		{
			var url = env.send_data_request_string("HomePageRequest", "url");
			if (url == null)
			{
				runner_app.fatal_error("Invalid home page URL", "The web app integration script has provided an empty home page URL.");
				return false;
			}
			
			if (!load_uri(url))
			{
				runner_app.fatal_error("Invalid home page URL", "The web app integration script has not provided a valid home page URL '%s'.".printf(url));
				return false;
			}
		}
		catch (GLib.Error e)
		{
			runner_app.fatal_error("Initialization error", "%s failed to retrieve a home page of  a web app. Initialization exited with error:\n\n%s".printf(runner_app.app_name, e.message));
			return false;
		}
		
		return true;
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
	
	private bool check_init_form()
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
			init_form(values_hashtable, entries);
			return true;
		}
		return false;
	}
	
	private void set_up_ipc()
	{
		assert(server != null);
		server.add_handler("get_data_dir", handle_get_data_dir);
		server.add_handler("get_user_config_dir", handle_get_user_config_dir);
		server.add_handler("config_has_key", handle_config_has_key);
		server.add_handler("config_get_value", handle_config_get_value);
		server.add_handler("config_set_value", handle_config_set_value);
		server.add_handler("config_set_default_value", handle_config_set_default_value);
		server.add_handler("session_has_key", handle_session_has_key);
		server.add_handler("session_get_value", handle_session_get_value);
		server.add_handler("session_set_value", handle_session_set_value);
		server.add_handler("session_set_default_value", handle_session_set_default_value);
		server.add_handler("show_error", handle_show_error);
	}
	
	private Variant? handle_get_data_dir(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		return new Variant.string(web_app.data_dir.get_path());
	}
	
	private Variant? handle_get_user_config_dir(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		return new Variant.string(storage.config_dir.get_path());
	}
	
	private Variant? handle_session_has_key(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		return new Variant.boolean(session.has_key(data.get_string()));
	}
	
	private Variant? handle_session_get_value(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		var response = session.get_value(data.get_string());
		if (response == null)
			response = new Variant("mv", null);
		
		return response;
	}
	
	private Variant? handle_session_set_value(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(smv)");
		string? key = null;
		Variant? value = null;
		data.get("(smv)", &key, &value);
		session.set_value(key, value);
		return null;
	}
	
	private Variant? handle_session_set_default_value(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(smv)");
		string? key = null;
		Variant? value = null;
		data.get("(smv)", &key, &value);
		session.set_default_value(key, value);
		return null;
	}
	
	private Variant? handle_config_has_key(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		return new Variant.boolean(config.has_key(data.get_string()));
	}
	
	private Variant? handle_config_get_value(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		var response = config.get_value(data.get_string());
		if (response == null)
			response = new Variant("mv", null);
		
		return response;
	}
	
	private Variant? handle_config_set_value(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(smv)");
		string? key = null;
		Variant? value = null;
		data.get("(smv)", &key, &value);
		config.set_value(key, value);
		return null;
	}
	
	private Variant? handle_config_set_default_value(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(smv)");
		string? key = null;
		Variant? value = null;
		data.get("(smv)", &key, &value);
		config.set_default_value(key, value);
		return null;
	}
	
	private Variant? handle_show_error(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		runner_app.show_error("Integration error", data.get_string());
		return null;
	}
	
	private void on_send_message_async(string name, Variant? data)
	{
		try
		{
			server.send_local_message(name, data);
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
		}
	}
	
	private void on_send_message_sync(string name, Variant? data, ref Variant? result)
	{
		try
		{
			result = server.send_local_message(name, data);
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
	
	private bool decide_navigation_policy(bool new_window, WebKit.NavigationPolicyDecision decision)
	{
		var uri = decision.request.uri;
		if (!uri.has_prefix("http://") && !uri.has_prefix("https://"))
			return false;
		
		var new_window_override = new_window;
		var result = navigation_request(uri, ref new_window_override);
		var type = decision.navigation_type;
		debug("Navigation, %s window: uri = %s, result = %s, frame = %s, type = %s",
			new_window_override ? "new" : "current", uri, result.to_string(), decision.frame_name, type.to_string());
		
		// We care only about user clicks
		if (type != WebKit.NavigationType.LINK_CLICKED)
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
