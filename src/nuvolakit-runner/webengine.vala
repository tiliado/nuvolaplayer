/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class WebEngine : GLib.Object
{
	public Gtk.Widget widget {get {return web_view;}}
	public WebApp web_app {get; private set;}
	public bool can_go_back {get; private set; default = false;}
	public bool can_go_forward {get; private set; default = false;}
	private AppRunnerController app;
	private WebKit.WebView web_view;
	private JsEnvironment? env = null;
	private JSApi api;
	private Diorite.Ipc.MessageServer server = null;
	private Diorite.Ipc.MessageClient web_worker = null;
	private bool web_worker_ready = false;
	
	private static const string WEB_WORKER_SUFFIX = ".webworker";
	private Config config;
	private VariantHashTable session;
	
	public WebEngine(AppRunnerController app, WebApp web_app, Config config)
	{
		server = app.server;
		var webkit_extension_dir = Nuvola.get_libdir();
		Environment.set_variable("NUVOLA_IPC_WEB_WORKER", app.app_id + WEB_WORKER_SUFFIX, true);
		debug("Nuvola WebKit Extension directory: %s", webkit_extension_dir);
		
		var wc = WebKit.WebContext.get_default();
		wc.set_web_extensions_directory(webkit_extension_dir);
		wc.set_favicon_database_directory(web_app.user_data_dir.get_child("favicons").get_path());
		wc.set_disk_cache_directory(web_app.user_cache_dir.get_child("webcache").get_path());
		
		var cm = wc.get_cookie_manager();
		cm.set_persistent_storage(web_app.user_data_dir.get_child("cookies.dat").get_path(), WebKit.CookiePersistentStorage.SQLITE);
		
		this.app = app;
		this.web_app = web_app;
		this.config = config;
		this.web_view = new WebKit.WebView();
		session = new VariantHashTable();
		
		var ws = web_view.get_settings();
		ws.enable_developer_extras = true;
		ws.enable_java = false;
		ws.enable_page_cache = false;
		ws.enable_smooth_scrolling = true;
		ws.enable_write_console_messages_to_stdout = true;
		web_view.notify["uri"].connect(on_uri_changed);
		web_view.decide_policy.connect(on_decide_policy);
		set_up_ipc();
	}
	
	public signal void init_request(HashTable<string, Variant> values, Variant entries);
	
	private bool inject_api()
	{
		if (env != null)
			return true;
		
		env = new JsRuntime();
		api = new JSApi(app.storage, web_app.data_dir, web_app.user_config_dir, config, session);
		api.send_message_async.connect(on_send_message_async);
		api.send_message_sync.connect(on_send_message_sync);
		try
		{
			api.inject(env);
			api.initialize(env);
		}
		catch (JSError e)
		{
			app.fatal_error("Initialization error", e.message);
			return false;
		}
		return true;
	}
	
	private string? data_request(string name, string key, string? default_value=null) throws JSError
	{
		string? result = null;
		var builder = new VariantBuilder(new VariantType("a{smv}"));
		builder.add("{smv}", key, default_value == null ? null : new Variant.string(default_value));
		var args = new Variant("(s@a{smv})", name, builder.end());
		env.call_function("Nuvola.Core.emit", ref args);
		VariantIter iter = args.iterator();
		assert(iter.next("s", null));
		assert(iter.next("a{smv}", &iter));
		string dict_key = null;
		Variant value = null;
		while (iter.next("{smv}", &dict_key, &value))
			if (dict_key == key)
				result =  value != null && value.is_of_type(VariantType.STRING)
				?  value.get_string() : null;
		
		if(result == "")
			result = null;
		return result;
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
		
		return false;
	}
	
	public bool load()
	{
		if (!inject_api())
			return false;
		
		if (!web_worker.wait_for_echo(2000))
			error("Cannot connect to web worker process.");
		
		web_worker_ready = true;
		
		if (check_init_request())
			return true;
		
		return restore_session();
	}
	
	private bool restore_session()
	{
		var result = false;
		try
		{
			var url = data_request("last-page", "url");
			if (url == null)
				return try_go_home();
			
			result = load_uri(url);
			if (!result)
				app.show_error("Invalid page URL", "The web app integration script has not provided a valid page URL '%s'.".printf(url));
		}
		catch (JSError e)
		{
			app.show_error("Initialization error", "%s failed to retrieve a last visited page from previous session. Initialization exited with error:\n\n%s".printf(app.app_name, e.message));
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
			var url = data_request("home-page", "url");
			if (url == null)
				app.show_error("Invalid home page URL", "The web app integration script has an empty home page URL.");
			else if (!load_uri(url))
				app.show_error("Invalid home page URL", "The web app integration script has not provided a valid home page URL '%s'.".printf(url));
		}
		catch (JSError e)
		{
			app.fatal_error("Initialization error", "%s failed to retrieve a home page of  a web app. Initialization exited with error:\n\n%s".printf(app.app_name, e.message));
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
	
	public void call_function(string name, Variant? params) throws Diorite.Ipc.MessageError
	{
		if (!web_worker_ready)
			throw new Diorite.Ipc.MessageError.NOT_READY("Web worker process is not ready yet");
		
		var data = new Variant("(smv)", name, params);
		web_worker.send_message("call_function", data);
	}
	
	public void get_preferences(out Variant values, out Variant entries)
	{
		var args = new Variant("(s@a{sv}@av)", "append-preferences", new Variant.array(new VariantType("{sv}"), {}), new Variant.array(VariantType.VARIANT, {}));
		env.call_function("Nuvola.Core.emit", ref args);
		args.get("(s@a{smv}@av)", null, out values, out entries);
	}
	
	private bool check_init_request()
	{
		Variant values;
		Variant entries;
		var args = new Variant("(s@a{sv}@av)", "init-request", new Variant.array(new VariantType("{sv}"), {}), new Variant.array(VariantType.VARIANT, {}));
		env.call_function("Nuvola.Core.emit", ref args);
		args.get("(s@a{smv}@av)", null, out values, out entries);
		var values_hashtable = Diorite.variant_to_hashtable(values);
		if (values_hashtable.size() > 0)
		{
			init_request(values_hashtable, entries);
			return true;
		}
		return false;
	}
	
	private void set_up_ipc()
	{
		assert(server != null);
		server.add_handler("get_data_dir", handle_get_data_dir);
		server.add_handler("get_user_config_dir", handle_get_user_config_dir);
		server.add_handler("config_save", handle_config_save);
		server.add_handler("config_has_key", handle_config_has_key);
		server.add_handler("config_get_value", handle_config_get_value);
		server.add_handler("config_set_value", handle_config_set_value);
		server.add_handler("config_set_default_value", handle_config_set_default_value);
		server.add_handler("session_has_key", handle_session_has_key);
		server.add_handler("session_get_value", handle_session_get_value);
		server.add_handler("session_set_value", handle_session_set_value);
		server.add_handler("session_set_default_value", handle_session_set_default_value);
		server.add_handler("show_error", handle_show_error);
		
		web_worker = new Diorite.Ipc.MessageClient(app.app_id + WEB_WORKER_SUFFIX, 5000);
	}
	
	private Variant? handle_get_data_dir(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		return new Variant.string(web_app.data_dir.get_path());
	}
	
	private Variant? handle_get_user_config_dir(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		return new Variant.string(web_app.user_config_dir.get_path());
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
	
	private Variant? handle_config_save(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		try
		{
			return new Variant.boolean(config.save());
		}
		catch (GLib.Error e)
		{
			throw new Diorite.Ipc.MessageError.REMOTE_ERROR("Failed to save configuration: %s", e.message);
		}
	}
	
	private Variant? handle_show_error(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		app.show_error("Integration error", data.get_string());
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
	
	private bool on_decide_policy(WebKit.PolicyDecision decision, WebKit.PolicyDecisionType decision_type)
	{
		switch (decision_type)
		{
		case WebKit.PolicyDecisionType.NAVIGATION_ACTION:
			WebKit.NavigationPolicyDecision navigation_decision = (WebKit.NavigationPolicyDecision) decision;
			if (navigation_decision.mouse_button == 0)
				return false;
			var uri = navigation_decision.request.uri;
			if (!uri.has_prefix("http://") && !uri.has_prefix("https://"))
				return false;
			var result = navigation_request(uri);
			debug("Mouse Navigation: %s %s", uri, result.to_string());
			if (result)
			{
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
		case WebKit.PolicyDecisionType.NEW_WINDOW_ACTION:
		case WebKit.PolicyDecisionType.RESPONSE:
		default:
			return false;
		}
	}
	
	private bool navigation_request(string url)
	{
		var builder = new VariantBuilder(new VariantType("a{smv}"));
		builder.add("{smv}", "url", new Variant.string(url));
		builder.add("{smv}", "approved", new Variant.boolean(true));
		var args = new Variant("(s@a{smv})", "navigation-request", builder.end());
		try
		{
			env.call_function("Nuvola.Core.emit", ref args);
		}
		catch (JSError e)
		{
			app.show_error("Integration script error", "The web app integration script has not provided a valid response and caused an error: %s".printf(e.message));
			return true;
		}
		VariantIter iter = args.iterator();
		assert(iter.next("s", null));
		assert(iter.next("a{smv}", &iter));
		string key = null;
		Variant value = null;
		bool approved = false;
		while (iter.next("{smv}", &key, &value))
			if (key == "approved")
				approved = value != null ? value.get_boolean() : false;
		
		return approved;
	}
	
	private void on_uri_changed(GLib.Object o, ParamSpec p)
	{
		can_go_back = web_view.can_go_back();
		can_go_forward = web_view.can_go_forward();
		var args = new Variant("(sms)", "uri-changed", web_view.uri);
		try
		{
			env.call_function("Nuvola.Core.emit", ref args);
		}
		catch (JSError e)
		{
			app.show_error("Integration script error", "The web app integration caused an error: %s".printf(e.message));
		}
	}
}

} // namespace Nuvola
