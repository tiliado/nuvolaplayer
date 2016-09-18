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

public class Component: Nuvola.Component
{
	private Bindings bindings;
	private RunnerApplication app;
	private IpcBus ipc_bus;
	
	public Component(RunnerApplication app, Bindings bindings, Diorite.KeyValueStorage config, IpcBus ipc_bus)
	{
		base("httpremotecontrol", "Remote control over HTTP", "Remote media player HTTP interface for control over network.");
		this.hidden = true;
		this.bindings = bindings;
		this.app = app;
		this.ipc_bus = ipc_bus;
		config.bind_object_property("component.httpremotecontrol.", this, "enabled").set_default(false).update_property();
		enabled_set = true;
		if (enabled)
			load();
	}
	
	protected override void load()
	{
		register(true);
	}
	
	protected override void unload()
	{
		register(false);
	}
	
	private void register(bool register)
	{
		var method = "HttpRemoteControl." + (register ? "register" : "unregister");
		try
		{
			ipc_bus.master.send_message(method, new Variant.string(app.web_app.id)); 
		}
		catch (GLib.Error e)
		{
			warning("Remote call %s failed: %s", method, e.message);
		}
	}
}

} // namespace Nuvola.HttpRemoteControl
#endif
