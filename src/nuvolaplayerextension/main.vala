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

namespace Nuvola
{

public WebExtension extension;

public class WebExtension: GLib.Object
{
	private WebKit.WebExtension extension;
	private Diorite.Ipc.MessageClient runner;
	private Diorite.Ipc.MessageServer server;
	private HashTable<unowned WebKit.Frame, FrameBridge> bridges;
	private File data_dir;
	private File user_config_dir;
	private JSApi js_api;
	private Variant[] function_calls = {};
	
	public WebExtension(WebKit.WebExtension extension, Diorite.Ipc.MessageClient runner, Diorite.Ipc.MessageServer server)
	{
		this.extension = extension;
		this.runner = runner;
		this.server = server;
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
		
		var storage = new Diorite.XdgStorage.for_project(Nuvola.get_appname());
		js_api = new JSApi(storage, data_dir, user_config_dir, new KeyValueProxy(runner, "config"),
		new KeyValueProxy(runner, "session"));
		js_api.send_message_async.connect(on_send_message_async);
		js_api.send_message_sync.connect(on_send_message_sync);
		WebKit.ScriptWorld.get_default().window_object_cleared.connect(on_window_object_cleared);
	}
	
	private void on_window_object_cleared(WebKit.ScriptWorld world, WebKit.WebPage page, WebKit.Frame frame)
	{
		if (!frame.is_main_frame())
			return; // TODO: Add api not to ignore non-main frames
		
		unowned JS.GlobalContext context = frame.get_javascript_context_for_script_world(world);
		debug("Window object cleared: %s, %p, %p, %p", frame.get_uri(), frame, page, context);
		var bridge = new FrameBridge(frame, context);
		bridges.insert(frame, bridge);
		try
		{
			js_api.inject(bridge);
			js_api.integrate(bridge);
		}
		catch (JSError e)
		{
			show_error("Failed to inject JavaScript API. %s".printf(e.message));
		}
	}
	
	private void handle_call_function(Diorite.Ipc.MessageServer server, Variant? request, out Variant? response) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(request, "(smv)");
		string name = null;
		Variant? data = null;
		request.get("(smv)", &name, &data);
		var envs = bridges.get_values();
		foreach (var env in envs)
		{
			try
			{
				env.call_function(name, ref data);
			}
			catch (JSError e)
			{
				show_error("Error during call of %s: %s".printf(name, e.message));
			}
		}
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
			runner.send_message("send_message_async", new Variant("(smv)", name, data));
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
			result = runner.send_message("send_message_sync", new Variant("(smv)", name, data));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
	
}

public void on_web_page_created(WebKit.WebExtension extension, WebKit.WebPage web_page)
{
	warning("Page %u created for %s", (uint) web_page.get_id(), web_page.get_uri());
}

} // namespace Nuvola

public void webkit_web_extension_initialize(WebKit.WebExtension extension)
{
	Diorite.Logger.init(stderr, GLib.LogLevelFlags.LEVEL_DEBUG);
	var runner = new Diorite.Ipc.MessageClient(Environment.get_variable("NUVOLA_IPC_UI_RUNNER"), 5000);
	var server = new Diorite.Ipc.MessageServer(Environment.get_variable("NUVOLA_IPC_WEB_WORKER"));
	Nuvola.extension = new Nuvola.WebExtension(extension, runner, server); 
	extension.page_created.connect(Nuvola.on_web_page_created);
}
