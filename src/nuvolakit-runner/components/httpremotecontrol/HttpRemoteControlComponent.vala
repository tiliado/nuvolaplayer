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
		this.has_settings = true;
		this.bindings = bindings;
		this.app = app;
		this.ipc_bus = ipc_bus;
		config.bind_object_property("component.httpremotecontrol.", this, "enabled").set_default(false).update_property();
		enabled_set = true;
		if (enabled)
			load();
	}
	
	public override Gtk.Widget? get_settings()
	{		
		return new Settings(ipc_bus);
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
		var method = "/nuvola/httpremotecontrol/" + (register ? "register" : "unregister");
		try
		{
			ipc_bus.master.call_sync(method, new Variant("(s)", app.web_app.id)); 
		}
		catch (GLib.Error e)
		{
			warning("Remote call %s failed: %s", method, e.message);
		}
	}
	
	private class Settings : Gtk.Grid
	{
		private IpcBus ipc_bus;
		
		public Settings(IpcBus ipc_bus)
		{
			GLib.Object(row_spacing: 5, column_spacing: 10, hexpand: true, halign: Gtk.Align.CENTER);
			this.ipc_bus = ipc_bus;
			load.begin((o, res) => {load.end(res);});			
		}
		
		private async void load()
		{
			try
			{
				var addresses = yield ipc_bus.master.call("/nuvola/httpremotecontrol/get-addresses", null);
				var port = Diorite.variant_to_uint(yield ipc_bus.master.call("/nuvola/httpremotecontrol/get-port", null));
				return_if_fail(addresses != null);
				var iter = addresses.iterator();
				string? address; string? name; bool enabled;
				int line = 0;
				var label = new Gtk.Label("<b>Security Warning</b>");
				label.use_markup = true;
				label.hexpand = true;
				label.margin = 10;
				attach(label, 0, line, 3, 1);
				label = new Gtk.Label("All network communication is unencrypted and there is no authorization/password. Enable trustworthy network interfaces only (e.g. home network). <a href=\"https://github.com/tiliado/nuvolaplayer/issues/268\">Encrypted communication is planned</a>.");
				label.wrap = true;
				label.use_markup = true;
				label.hexpand = true;
				attach(label, 0, ++line, 3, 1);
				label = new Gtk.Label("<b>Network Interfaces</b>");
				label.use_markup = true;
				label.margin = 10;
				label.hexpand = true;
				attach(label, 0, ++line, 3, 1);
				label = new Gtk.Label("Specify a port and addresses Nuvola Player will be listening on.");
				label.wrap = true;
				label.use_markup = true;
				label.hexpand = true;
				attach(label, 0, ++line, 3, 1);
				label = new Gtk.Label("Port");
				label.use_markup = true;
				label.hexpand = true;
				attach(label, 1, ++line, 1, 1);
				var spin = new Gtk.SpinButton.with_range (1, 65535, 1);
				spin.value = port;
				spin.hexpand = false;
				spin.halign = Gtk.Align.CENTER;
				spin.notify["value"].connect_after(on_spin_value_changed);
				attach(spin, 2, line, 1, 1);
				while (iter.next("(ssb)", out address, out name, out enabled))
				{
					line++;
					label = new Gtk.Label(name);
					label.hexpand = true;
					attach(label, 1, line, 1, 1);
					label = new Gtk.Label(address);
					label.selectable = true;
					label.hexpand = true;
					attach(label, 2, line, 1, 1);
					var toggle = new Gtk.Switch();
					toggle.set_data<string>("address", (owned) address);
					toggle.notify["active"].connect_after(on_switch_switched);
					toggle.active = enabled;
					attach(toggle, 0, line, 1, 1);
				}
				show_all();
			}
			catch (GLib.Error e)
			{
				warning("Failed to get addresses. %s", e.message);
			}
		}
		
		private void on_switch_switched(GLib.Object o, ParamSpec p)
		{
			var toggle = o as Gtk.Switch;
			unowned string address = o.get_data<string>("address");
			try
			{
				ipc_bus.master.call("/nuvola/httpremotecontrol/set-address-enabled", new Variant("(sb)", address, toggle.active));
			}
			catch (GLib.Error e)
			{
				warning("Failed to set address enabled. %s", e.message);
			}
		}
		
		private void on_spin_value_changed(GLib.Object o, ParamSpec p)
		{
			var spin = o as Gtk.SpinButton;
			try
			{
				ipc_bus.master.call("/nuvola/httpremotecontrol/set-port", new Variant("(i)", spin.get_value_as_int()));
			}
			catch (GLib.Error e)
			{
				warning("Failed to set address enabled. %s", e.message);
			}
		}
	}
}

} // namespace Nuvola.HttpRemoteControl
#endif
