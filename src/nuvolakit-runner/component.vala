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

public abstract class Nuvola.Component: GLib.Object
{
	public string name {get; construct;}
	private Diorite.Ipc.MessageServer server;
	private WebEngine web_engine;
	private SList<string> handlers = null;
	
	public Component(Diorite.Ipc.MessageServer server, WebEngine web_engine, string name)
	{
		GLib.Object(name: name);
		this.web_engine = web_engine;
		this.server = server;
	}
	
	public abstract bool add(GLib.Object object);
	
	protected void bind(string method, owned Diorite.Ipc.MessageHandler handler)
	{
		var full_name = "%s.%s".printf(name, method);
		server.add_handler(full_name, (owned) handler);
		handlers.prepend(full_name);
	}
	
	protected void call_web_worker(string func_name, Variant? params) throws Diorite.Ipc.MessageError
	{
		web_engine.call_function(func_name, params);
	}
	
	~Component()
	{
		foreach (var handler in handlers)
			server.remove_handler(handler);
		handlers = new SList<string>();
	}
}
