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
namespace Nuvola
{

public class HttpRemoteControlServer: Soup.Server
{
	Diorite.Ipc.MessageServer ipc_server;
    private MasterController app;
	private HashTable<string, AppRunner> app_runners;
    private unowned Queue<AppRunner> app_runners_order;
    private GenericSet<string> registered_runners;
    private bool running = false;
	
	public HttpRemoteControlServer(
        MasterController app, Diorite.Ipc.MessageServer ipc_server,
        HashTable<string, AppRunner> app_runners, Queue<AppRunner> app_runners_order)
	{
		this.app = app;
        this.ipc_server = ipc_server;
		this.app_runners = app_runners;
		this.app_runners_order = app_runners_order;
        registered_runners = new GenericSet<string>(str_hash, str_equal);
        ipc_server.add_handler("HttpRemoteControl.register", handle_register);
        ipc_server.add_handler("HttpRemoteControl.unregister", handle_unregister);
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
		var self = server as HttpRemoteControlServer;
		assert(self != null);
		self.handle_request(msg, path, query, client);
	}
	
	protected void handle_request(Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client)
    {
        respond_not_found(msg, path, query, client);
    }
    
	protected void respond_not_found(Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client)
    {
		msg.set_response(
            "text/html", Soup.MemoryUse.COPY,
            "<html><head><title>404</title></head><body><h1>404</h1><p>%s</p></body></html>".printf(
                msg.uri.to_string(false)).data);
		msg.status_code = 404;
	}
    
    private Variant? handle_register(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		register_app(data.get_string());
		return null;
	}
    
    private Variant? handle_unregister(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		var app_id = data.get_string();
        if (!unregister_app(app_id))
            warning("App %s hasn't been registered yet!", app_id);
		return null;
	}
}

} // namespace Nuvola
#endif

