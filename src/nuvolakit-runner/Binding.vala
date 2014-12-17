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

public abstract class Nuvola.Binding<ObjectType>: GLib.Object
{
	/**
	 * Return value to continue propagation of binding handlers.
	 */
	public static const bool CONTINUE = false;
	public string name {get; construct;}
	public bool active {get; protected set; default = false;}
	protected Diorite.Ipc.MessageServer server;
	protected WebWorker web_worker;
	private SList<string> handlers = null;
	
	public Binding(Diorite.Ipc.MessageServer server, WebWorker web_worker, string name)
	{
		GLib.Object(name: name);
		this.web_worker = web_worker;
		this.server = server;
	}
	
	protected virtual void bind_methods()
	{
	}
	
	protected void unbind_methods()
	{
		foreach (var handler in handlers)
			server.remove_handler(handler);
		handlers = null;
		active = false;
	}
	
	protected void check_not_empty() throws Diorite.Ipc.MessageError
	{
		if (!active)
			throw new Diorite.Ipc.MessageError.UNSUPPORTED("Binding %s has no registered components.", name);
	}
	
	protected void bind(string method, owned Diorite.Ipc.MessageHandler handler)
	{
		var full_name = "%s.%s".printf(name, method);
		server.add_handler(full_name, (owned) handler);
		handlers.prepend(full_name);
	}
	
	protected void call_web_worker(string func_name, Variant? params) throws GLib.Error
	{
		web_worker.call_function(func_name, params);
	}
	
	~BaseBinding()
	{
		unbind_methods();
	}
}

public abstract class Nuvola.ObjectBinding<ObjectType>: Binding<ObjectType>
{
	protected SList<ObjectType> objects = null;
	
	public ObjectBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker, string name)
	{
		base(server, web_worker, name);
	}
	
	public bool add(GLib.Object object)
	{
		/* Valac 0.22: cannot use "is" operator with generics
		 * if (!(object is ObjectType))
		 */
		if (!object.get_type().is_a(typeof(ObjectType)))
			return false;
		
		objects.prepend((ObjectType) object);
		if (objects.next == null)
		{
			bind_methods();
			active = true;
		}
		object_added((ObjectType) object);
		return true;
	}
	
	public bool remove(GLib.Object object)
	{
		/* Valac 0.22: cannot use "is" operator with generics
		 * if (!(object is ObjectType))
		 */
		if (!object.get_type().is_a(typeof(ObjectType)))
			return false;
		
		objects.remove((ObjectType) object);
		if (objects == null)
			unbind_methods();
		
		object_removed((ObjectType) object);
		return true;
	}
	
	protected virtual void object_added(ObjectType object)
	{
	}
	
	protected virtual void object_removed(ObjectType object)
	{
	}
}

/**
 * Binding of model object.
 * 
 * Model object should only store and manipulate with data, but not to expose them in user interface, because
 * view objects that use a particular model as data source are responsible for that.
 */
public abstract class Nuvola.ModelBinding<ModelType>: Binding<ModelType>
{
	public ModelType model {get; private set;}
	
	public ModelBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker, string name, ModelType model)
	{
		base(server, web_worker, name);
		this.model = model;
		bind_methods();
		active = true;
	}
}
