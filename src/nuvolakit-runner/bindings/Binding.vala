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

public abstract class Nuvola.Binding<ObjectType>: GLib.Object
{
	/**
	 * Return value to continue propagation of binding handlers.
	 */
	public const bool CONTINUE = false;
	public string name {get; construct;}
	public bool active {get; protected set; default = false;}
	protected Drt.ApiRouter router;
	protected WebWorker web_worker;
	private SList<string> handlers = null;
	
	public Binding(Drt.ApiRouter router, WebWorker web_worker, string name)
	{
		GLib.Object(name: name);
		this.web_worker = web_worker;
		this.router = router;
	}
	
	protected virtual void bind_methods()
	{
	}
	
	public override void dispose()
	{
		unbind_methods();
		base.dispose();
	}
	
	protected void unbind_methods()
	{
		foreach (var handler in handlers)
		{
			if (handler[0] == '/')
				router.remove_method(handler);
			else
				router.remove_handler(handler);
		}
		handlers = null;
		active = false;
	}
	
	protected void check_not_empty() throws Drt.MessageError
	{
		if (!active)
			throw new Drt.MessageError.UNSUPPORTED("Binding %s has no registered components.", name);
	}
	
	protected void bind(string method, Drt.ApiFlags flags, string? description, owned Drt.ApiHandler handler, Drt.ApiParam[]? params)
	{
		var path = "/%s.%s".printf(name, method).down().replace(".", "/");
		router.add_method(path, flags, description, (owned) handler, params);
		handlers.prepend(path);
	}
	
	protected void add_notification(string method, Drt.ApiFlags flags, string? description)
	{
		var path = "/%s.%s".printf(name, method).down().replace(".", "/");
		router.add_notification(path, flags, description);
		handlers.prepend(path);
	}
	
	protected void emit(string notification, string? detail=null, Variant? data=null)
	{
		var path = "/%s.%s".printf(name, notification).down().replace(".", "/");
		router.emit(path, detail, data);
	}
	
	protected void call_web_worker(string func_name, ref Variant? params) throws GLib.Error
	{
		web_worker.call_function(func_name, ref params);
	}
	
	~Binding()
	{
		unbind_methods();
	}
}

public abstract class Nuvola.ObjectBinding<ObjectType>: Binding<ObjectType>
{
	protected Drt.Lst<ObjectType> objects;
	
	public ObjectBinding(Drt.ApiRouter router, WebWorker web_worker, string name)
	{
		base(router, web_worker, name);
		objects = new Drt.Lst<ObjectType>();
	}
	
	public bool add(GLib.Object object)
	{
		if (!(object is ObjectType))
			return false;
		
		objects.prepend(object);
		if (objects.length == 1)
		{
			bind_methods();
			active = true;
		}
		object_added((ObjectType) object);
		return true;
	}
	
	public bool remove(GLib.Object object)
	{
		if (!(object is ObjectType))
			return false;
		
		objects.remove((ObjectType) object);
		if (objects.length == 0)
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
	
	public ModelBinding(Drt.ApiRouter router, WebWorker web_worker, string name, ModelType model)
	{
		base(router, web_worker, name);
		this.model = model;
		bind_methods();
		active = true;
	}
}
