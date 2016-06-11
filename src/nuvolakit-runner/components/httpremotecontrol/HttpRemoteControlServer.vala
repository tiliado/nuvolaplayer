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

public class Server: Soup.Server
{
	Diorite.Ipc.MessageServer ipc_server;
    private MasterController app;
	private HashTable<string, AppRunner> app_runners;
    private unowned Queue<AppRunner> app_runners_order;
    private GenericSet<string> registered_runners;
    private WebAppRegistry web_app_registry;
    private bool running = false;
	
	public Server(
        MasterController app, Diorite.Ipc.MessageServer ipc_server,
        HashTable<string, AppRunner> app_runners, Queue<AppRunner> app_runners_order,
        WebAppRegistry web_app_registry)
	{
		this.app = app;
        this.ipc_server = ipc_server;
		this.app_runners = app_runners;
		this.app_runners_order = app_runners_order;
        this.web_app_registry = web_app_registry;
        registered_runners = new GenericSet<string>(str_hash, str_equal);
        ipc_server.add_handler("HttpRemoteControl.register", "s", handle_register);
        ipc_server.add_handler("HttpRemoteControl.unregister", "s", handle_unregister);
        app.runner_exited.connect(on_runner_exited);
	}
    
    ~HttpRemoteControlServer()
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
        if (!running)
            start();
    }
    
    private bool unregister_app(string app_id)
    {
        message("HttpRemoteControlServer: unregister app id: %s", app_id);
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
	
	protected void handle_request(RequestContext request)
    {
        var path = request.path;
        if (path == "/+api/app")
        {
            request.respond_json(200, list_apps());
            return;
        }
        if (path.has_prefix("/+api/app/"))
        {
            var app_path = path.substring(10);
            var slash_pos = app_path.index_of_char('/');
            if (slash_pos == -1)
            {
                var data = get_app_info(app_path);
                if (data != null)
                    request.respond_json(200, data);
                else
                    request.respond_not_found();
                return;
            }
            if (slash_pos > 0)
            {
                var app_id = app_path.substring(0, slash_pos);
                app_path = app_path.substring(slash_pos + 1);
                
                if (!(app_id in registered_runners))
                {
                    request.respond_not_found();
                }
                else
                {
                    var app_request = new AppRequest.from_request_context(app_path, request);
                    message("App-specific request %s: %s => %s", app_id, app_path, app_request.to_string());
                    var data = send_app_request(app_id, app_request);
                    if (data == null)
                        request.respond_not_found();
                    else
                        request.respond_json(200, data);
                    return;
                }
            }
        }
        request.respond_not_found();
    }
    
    private Json.Node? send_app_request(string app_id, AppRequest app_request)
    {
        var app = app_runners[app_id];
        var flags = app_request.method == "POST" ? "rw" : "r";
        var method = "/nuvola/%s::%s,,".printf(app_request.app_path, flags);  
		try
		{
			return Json.gvariant_serialize(app.send_message(method, app_request.to_variant())); 
		}
		catch (Diorite.MessageError e)
		{
			warning("Remote call %s failed: %s", method, e.message);
		}
        return null;
    }
    
    private Json.Node? list_apps()
    {
        var builder = new Json.Builder();
        builder.begin_object().set_member_name("apps").begin_array();
        var all_apps = web_app_registry.list_web_apps();
        var keys = all_apps.get_keys();
        keys.sort(string.collate);
        foreach (var app_id in keys)
        {
            var app = all_apps[app_id];
            builder.begin_object();
            builder.set_member_name("id").add_string_value(app_id);
            builder.set_member_name("name").add_string_value(app.name);
            builder.set_member_name("version").add_string_value("%u.%u".printf(app.version_major, app.version_minor));
            builder.set_member_name("maintainer").add_string_value(app.maintainer_name);
            builder.set_member_name("running").add_boolean_value(app_id in app_runners);
            builder.set_member_name("registered").add_boolean_value(app_id in registered_runners);
            builder.end_object();
        }
        builder.end_array().end_object();
        return builder.get_root();
    }
    
    protected Json.Node? get_app_info(string app_id)
    {
		var app = web_app_registry.get_app_meta(app_id);
        if (app == null)
            return null;
        
        var builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("id").add_string_value(app_id);
        builder.set_member_name("name").add_string_value(app.name);
        builder.set_member_name("version").add_string_value("%u.%u".printf(app.version_major, app.version_minor));
        builder.set_member_name("maintainer").add_string_value(app.maintainer_name);
        builder.set_member_name("running").add_boolean_value(app_id in app_runners);
        builder.set_member_name("registered").add_boolean_value(app_id in registered_runners);
        builder.end_object();
        return builder.get_root();
	}
    
    private Variant? handle_register(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		register_app(data.get_string());
		return null;
	}
    
    private Variant? handle_unregister(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var app_id = data.get_string();
        if (!unregister_app(app_id))
            warning("App %s hasn't been registered yet!", app_id);
		return null;
	}
}

} // namespace Nuvola.HttpRemoteControl
#endif

