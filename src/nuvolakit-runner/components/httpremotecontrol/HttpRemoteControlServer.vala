/*
 * Copyright 2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

#if EXPERIMENTAL
namespace Nuvola.HttpRemoteControl
{

public const string CAPABILITY_NAME = "httpcontrol";

public class Server: Soup.Server
{
	private MasterBus bus;
	private MasterController app;
	private HashTable<string, AppRunner> app_runners;
	private unowned Queue<AppRunner> app_runners_order;
	private GenericSet<string> registered_runners;
	private WebAppRegistry web_app_registry;
	private bool running = false;
	private File[] www_roots;
	private Channel eio_channel;
	
	public Server(
		MasterController app, MasterBus bus,
		HashTable<string, AppRunner> app_runners, Queue<AppRunner> app_runners_order,
		WebAppRegistry web_app_registry, File[] www_roots)
	{
		this.app = app;
		this.bus = bus;
		this.app_runners = app_runners;
		this.app_runners_order = app_runners_order;
		this.web_app_registry = web_app_registry;
		this.www_roots = www_roots;
		registered_runners = new GenericSet<string>(str_hash, str_equal);
		bus.router.add_method("/nuvola/httpremotecontrol/register", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			null, handle_register, {
			new Drt.StringParam("id", true, false)
		});
		bus.router.add_method("/nuvola/httpremotecontrol/unregister", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			null, handle_unregister, {
			new Drt.StringParam("id", true, false)
		});
		app.runner_exited.connect(on_runner_exited);
		var eio_server = new Engineio.Server(this, "/nuvola.io/");
		eio_channel = new Channel(eio_server, this);
	}
	
	~Server()
	{
		app.runner_exited.disconnect(on_runner_exited);
	}
	
	public void start()
	{
		var port = 8089;
		message("Start HttpRemoteControlServer at port %d", port);
		add_handler("/", default_handler);
		try
		{
			listen_all(port, 0);
			running = true;
		}
		catch (GLib.Error e)
		{
			critical("Cannot start HttpRemoteControlServer at port %d: %s", port, e.message);
		}
	}
	
	public void stop()
	{
		message("Stop HttpRemoteControlServer");
		disconnect();
		remove_handler("/");
		running = false;
	}
	
	private void register_app(string app_id)
	{
		message("HttpRemoteControlServer: Register app id: %s", app_id);
		registered_runners.add(app_id);
		var app = app_runners[app_id];
		app.add_capatibility(CAPABILITY_NAME);
		if (!running)
			start();
	}
	
	private bool unregister_app(string app_id)
	{
		message("HttpRemoteControlServer: unregister app id: %s", app_id);
		var app = app_runners[app_id];
		if (app != null)
			app.remove_capatibility(CAPABILITY_NAME);
		var result = registered_runners.remove(app_id);
		if (running && registered_runners.length == 0)
			stop();
		return result;
	}
	
	private void on_runner_exited(AppRunner runner)
	{
		unregister_app(runner.app_id);
	}
	
	private static void default_handler(
		Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client)
	{
		var self = server as Server;
		assert(self != null);
		self.handle_request(new RequestContext(server, msg, path, query, client));
	}
	
	public async Variant? handle_eio_request(string path, Variant? params) throws GLib.Error
	{
		if (path.has_prefix("/app/"))
		{
			var app_path = path.substring(5);
			string app_id;
			var slash_pos = app_path.index_of_char('/');
			if (slash_pos <= 0)
			{
				app_id = app_path;
				app_path = "";
			}
			else
			{
				app_id = app_path.substring(0, slash_pos);
				app_path = app_path.substring(slash_pos);
			}
			if (!(app_id in registered_runners))
			{
				throw new ChannelError.APP_NOT_FOUND("App with id '%s' doesn't exist or HTTP interface is not enabled.", app_id);
			}
			
			var app = app_runners[app_id];
			return yield app.call_full("/nuvola" + app_path, false, "rw", "dict", params);
		}
		if (path.has_prefix("/master/"))
		{
			var master_path = path.substring(7);
			return bus.call_local_sync_full("/nuvola" + master_path, false, "rw", "dict", params);
		}
		throw new ChannelError.INVALID_REQUEST("Request '%s' is invalid.", path);
	}
	
	protected void handle_request(RequestContext request)
	{
		var path = request.path;
		if (path == "/+api/app" || path == "/+api/app/")
		{
			request.respond_json(200, list_apps());
			return;
		}
		if (path.has_prefix("/+api/app/"))
		{
			var app_path = path.substring(10);
			string app_id;
			var slash_pos = app_path.index_of_char('/');
			if (slash_pos <= 0)
			{
				app_id = app_path;
				app_path = "";
			}
			else
			{
				app_id = app_path.substring(0, slash_pos);
				app_path = app_path.substring(slash_pos + 1);
			}
			if (!(app_id in registered_runners))
			{
				request.respond_not_found();
			}
			else
			{
				var app_request = new AppRequest.from_request_context(app_path, request);
				message("App-specific request %s: %s => %s", app_id, app_path, app_request.to_string());
				try
				{
					var data = send_app_request(app_id, app_request);
					request.respond_json(200, data);
				}
				catch (GLib.Error e)
				{
					var builder = new VariantBuilder(new VariantType("a{sv}"));
					builder.add("{sv}", "error", new Variant.int32(e.code));
					builder.add("{sv}", "message", new Variant.string(e.message));
					builder.add("{sv}", "quark", new Variant.string(e.domain.to_string()));
					request.respond_json(400, Json.gvariant_serialize(builder.end()));
				}
			}
			return;
		}
		else if (path.has_prefix("/+api/"))
		{
			try
			{
				var data = send_local_request(path.substring(6), request);
				request.respond_json(200, data);
			}
			catch (GLib.Error e)
			{
				var builder = new VariantBuilder(new VariantType("a{sv}"));
				builder.add("{sv}", "error", new Variant.int32(e.code));
				builder.add("{sv}", "message", new Variant.string(e.message));
				builder.add("{sv}", "quark", new Variant.string(e.domain.to_string()));
				request.respond_json(400, Json.gvariant_serialize(builder.end()));
			}
			return;
		}
		serve_static(request);
	}
	
	private void serve_static(RequestContext request)
	{
		
		var path = request.path == "/" ? "index" : request.path.substring(1);
		if (path.has_suffix("/"))
			path += "index";
		
		var file = find_static_file(path);
		if (file == null)
		{
			request.respond_not_found();
			return;
		}
		request.serve_file(file);
	}
	
	private File? find_static_file(string path)
	{
		foreach (var www_root in www_roots)
		{
			var file = www_root.get_child(path);
			if (file.query_file_type(0) == FileType.REGULAR)
				return file;
			file = www_root.get_child(path + ".html");
			if (file.query_file_type(0) == FileType.REGULAR)
				return file;
		}
		return null;
	}
	
	private Json.Node send_app_request(string app_id, AppRequest app_request) throws GLib.Error
	{
		var app = app_runners[app_id];
		var flags = app_request.method == "POST" ? "rw" : "r";
		var method = "/nuvola/%s::%s,dict,".printf(app_request.app_path, flags);
		unowned string? form_data = app_request.method == "POST" ? (string) app_request.body.data : app_request.uri.query;
		return to_json(app.send_message(method, serialize_params(form_data)));
	}
	
	private Json.Node send_local_request(string path, RequestContext request) throws GLib.Error
	{
		var msg = request.msg;
		var body = msg.request_body.flatten();
		var flags = msg.method == "POST" ? "rw" : "r";
		var method = "/nuvola/%s::%s,dict,".printf(path, flags);
		unowned string? form_data = msg.method == "POST" ? (string) body.data : msg.uri.query;
		return to_json(bus.send_local_message(method, serialize_params(form_data)));
	}
	
	private Variant? serialize_params(string? form_data)
	{
		if (form_data != null)
		{
			var query_params = Soup.Form.decode(form_data);
			return Drt.str_table_to_variant_dict(query_params);
		}
		return null;
	}
	
	private Json.Node to_json(Variant? data)
	{
		Variant? result = data;
		if (data == null || !data.get_type().is_subtype_of(VariantType.DICTIONARY))
		{
			var builder = new VariantBuilder(new VariantType("a{smv}"));
			if (data != null)
				g_variant_ref(data); // FIXME: How to avoid this hack
			builder.add("{smv}", "result", data);
			result = builder.end();
		}
		return Json.gvariant_serialize(result);
	}
	
	private Json.Node? list_apps()
	{
		var builder = new Json.Builder();
		builder.begin_object().set_member_name("apps").begin_array();
		var keys = registered_runners.get_values();
		keys.sort(string.collate);
		foreach (var app_id in keys)
			builder.add_string_value(app_id);
		builder.end_array().end_object();
		return builder.get_root();
	}
	
	private Variant? handle_register(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		register_app(params.pop_string());
		return null;
	}
	
	private Variant? handle_unregister(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var app_id = params.pop_string();
		if (!unregister_app(app_id))
			warning("App %s hasn't been registered yet!", app_id);
		return null;
	}
}

} // namespace Nuvola.HttpRemoteControl

// FIXME
private extern Variant* g_variant_ref(Variant* variant);
#endif

