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

namespace Nuvola
{

public class WebExtension: GLib.Object
{
	private WebKit.WebExtension extension;
	private Diorite.Ipc.MessageClient runner;
	private Diorite.Ipc.MessageServer server;
	private HashTable<unowned WebKit.Frame, FrameBridge> bridges;
	private File data_dir;
	private File user_config_dir;
	private JSApi js_api;
	private JsRuntime bare_env;
	private JSApi bare_api;
	
	public InitState initialized {get; private set; default = InitState.NONE;}
	
	public WebExtension(WebKit.WebExtension extension, Diorite.Ipc.MessageClient runner, Diorite.Ipc.MessageServer server)
	{
		this.extension = extension;
		this.runner = runner;
		this.server = server;
		
		WebKit.ScriptWorld.get_default().window_object_cleared.connect(on_window_object_cleared);
		extension.page_created.connect(on_web_page_created);
		
		server.add_handler("call_function", handle_call_function);
		bridges = new HashTable<unowned WebKit.Frame, FrameBridge>(direct_hash, direct_equal);
		try
		{
			server.start_service();
		}
		catch (Diorite.IOError e)
		{
			error("Web Worker server error: %s", e.message);
		}
		
		Idle.add(late_init_cb);
	}
	
	private bool late_init_cb()
	{
		switch (initialized)
		{
		case InitState.DONE:
		case InitState.PENDING:
			return false;
		}
		
		initialized = InitState.PENDING;
		
		/* 
		 * For unknown reason, runner.wait_for_echo() in WebExtension constructor blocks window_object_cleared signal,
		 * so it has been moved to the late init method.
		 */
		assert(runner.wait_for_echo(1000));
		
		Variant response;
		try
		{
			response = runner.send_message("get_data_dir");
			data_dir = File.new_for_path(response.get_string());
			response = runner.send_message("get_user_config_dir");
			user_config_dir = File.new_for_path(response.get_string());
		}
		catch (Diorite.Ipc.MessageError e)
		{
			error("Runner client error: %s", e.message);
		}
		
		var storage = new Diorite.XdgStorage.for_project(Nuvola.get_app_id());
		js_api = new JSApi(storage, data_dir, user_config_dir, new KeyValueProxy(runner, "config"),
		new KeyValueProxy(runner, "session"));
		js_api.send_message_async.connect(on_send_message_async);
		js_api.send_message_sync.connect(on_send_message_sync);
		
		bare_env = new JsRuntime();
		bare_api = new JSApi(storage, data_dir, user_config_dir, new KeyValueProxy(runner, "config"),
			new KeyValueProxy(runner, "session"));
		try
		{
			bare_api.inject(bare_env);
			bare_api.initialize(bare_env);
			// TODO: differentiate from the JS environment in the runner process
			var args = new Variant("(s)", "InitAppRunner");
			bare_env.call_function("Nuvola.core.emit", ref args);
		}
		catch (GLib.Error e)
		{
			critical("Initialization error: %s", e.message);
		}
		
		initialized = InitState.DONE;
		return false;
	}
	
	private void on_window_object_cleared(WebKit.ScriptWorld world, WebKit.WebPage page, WebKit.Frame frame)
	{
		if (page.get_id() != 1)
		{
			debug("Ignoring JavaScript environment of a page with id = %s", page.get_id().to_string());
			return;
		}
		
		if (!frame.is_main_frame())
			return; // TODO: Add api not to ignore non-main frames
		
		wait_until_initialized();
		init_frame(world, page, frame);
	}
	
	private void init_frame(WebKit.ScriptWorld world, WebKit.WebPage page, WebKit.Frame frame)
	{
		unowned JS.GlobalContext context = (JS.GlobalContext) frame.get_javascript_context_for_script_world(world);
		debug("Window object cleared: %s, %p, %p, %p", frame.get_uri(), frame, page, context);
		var bridge = new FrameBridge(frame, context);
		bridges.insert(frame, bridge);
		try
		{
			js_api.inject(bridge);
			js_api.integrate(bridge);
			var args = new Variant("(s)", "InitWebWorker");
			bridge.call_function("Nuvola.core.emit", ref args);
		}
		catch (GLib.Error e)
		{
			show_error("Failed to inject JavaScript API. %s".printf(e.message));
		}
	}
	
	private Variant? handle_call_function(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(smv)");
		string name = null;
		Variant? params = null;
		data.get("(smv)", &name, &params);
		var envs = bridges.get_values();
		foreach (var env in envs)
		{
			try
			{
				env.call_function(name, ref params);
			}
			catch (GLib.Error e)
			{
				show_error("Error during call of %s: %s".printf(name, e.message));
			}
		}
		return params;
	}
	
	public void wait_until_initialized()
	{
		if (initialized == InitState.DONE)
			return;
		
		Idle.add(late_init_cb);
		var loop = new MainLoop();
		var handler_id = notify["initialized"].connect_after((o, p) => {
			if (initialized == InitState.DONE)
				loop.quit();
		});
		loop.run();
		disconnect(handler_id);
	}
	
	private void show_error(string message)
	{
		try
		{
			runner.send_message("show_error", new Variant.string(message));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Failed to send error message '%s'. %s", message, e.message);
		}
	}
	
	private void on_send_message_async(string name, Variant? data)
	{
		try
		{
			runner.send_message(name, data);
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
			result = runner.send_message(name, data);
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
	
	private void on_web_page_created(WebKit.WebExtension extension, WebKit.WebPage web_page)
	{
		debug("Page %u created for %s", (uint) web_page.get_id(), web_page.get_uri());
		
		if (web_page.get_id() != 1)
			return;
		
		web_page.send_request.connect(on_send_request);
	}
	
	private bool on_send_request(WebKit.URIRequest request, WebKit.URIResponse? redirected_response)
	{
		var approved = true;
		var uri = request.uri;
		resource_request(ref uri, ref approved);
		request.uri = uri;
		return !approved;
	}
	
	private void resource_request(ref string url, ref bool approved)
	{
		wait_until_initialized();
		var builder = new VariantBuilder(new VariantType("a{smv}"));
		builder.add("{smv}", "url", new Variant.string(url));
		builder.add("{smv}", "approved", new Variant.boolean(true));
		var args = new Variant("(s@a{smv})", "ResourceRequest", builder.end());
		
		try
		{
			bare_env.call_function("Nuvola.core.emit", ref args);
		}
		catch (GLib.Error e)
		{
			critical(e.message);
			var msg = "The web app integration script has not provided a valid response and caused an error: %s";
			show_error(msg.printf(e.message));
			return;
		}
		
		VariantIter iter = args.iterator();
		assert(iter.next("s", null));
		assert(iter.next("a{smv}", &iter));
		string key = null;
		Variant value = null;
		while (iter.next("{smv}", &key, &value))
		{
			if (key == "approved")
				approved = value != null ? value.get_boolean() : false;
			else if (key == "url" && value != null)
				url = value.get_string();
		}
		
		if (url.has_prefix("nuvola://"))
			url = data_dir.get_child(url.substring(9)).get_uri();
			
		if (url.has_prefix("file:"))
		{
			var file = File.new_for_uri(url);
			if (!file.has_prefix(data_dir))
			{
				warning("URI '%s' is blocked because it is not a child of data dir '%s'.", url, data_dir.get_path());
				approved = false;
			}
			else if (!file.query_exists())
			{
				warning("File '%s' doesn't exist.", file.get_path());
			}
		}
	}
	
	public enum InitState
	{
		NONE,
		PENDING,
		DONE;
	}
}

} // namespace Nuvola
