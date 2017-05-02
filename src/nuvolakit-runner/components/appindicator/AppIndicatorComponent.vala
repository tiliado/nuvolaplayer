/*
 * Copyright 2014-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

#if APPINDICATOR
namespace Nuvola
{

public class AppIndicatorComponent: Component
{
	public bool always_close_to_tray {get; public set; default = false;}
	private AppRunnerController controller;
	private Bindings bindings;
	private Appindicator indicator = null;
	
	public AppIndicatorComponent(AppRunnerController controller, Bindings bindings, Diorite.KeyValueStorage config)
	{
		base("appindicator", "AppIndicator (experimental)", "Small icon with menu shown in the Unity notification area.");
		this.has_settings = true;
		this.bindings = bindings;
		this.controller = controller;
		config.bind_object_property("component.appindicator.", this, "always_close_to_tray")
			.set_default(true).update_property();
		config.bind_object_property("component.appindicator.", this, "enabled")
			.set_default(false).update_property();
		enabled_set = true;
		if (enabled)
			load();
	}
	
	protected override bool activate()
	{
		indicator = new Appindicator(controller, bindings.get_model<LauncherModel>());
		controller.main_window.can_destroy.connect(on_can_quit);
		return true;
	}
	
	protected override bool deactivate()
	{
		controller.main_window.can_destroy.disconnect(on_can_quit);
		indicator = null;
		return false;
	}
	
	public override Gtk.Widget? get_settings()
	{		
		var grid = new Gtk.Grid();
		grid.orientation = Gtk.Orientation.HORIZONTAL;
		var label = new Gtk.Label("Always close main window to tray icon");
		label.vexpand = false;
		label.hexpand = true;
		grid.add(label);
		var close_to_tray_switch = new Gtk.Switch();
		close_to_tray_switch.active = always_close_to_tray;
		close_to_tray_switch.notify["active"].connect_after(on_close_to_tray_switch_changed);
		grid.add(close_to_tray_switch);
		grid.show_all();
		return grid;
	}
	
	private void on_close_to_tray_switch_changed(GLib.Object object, ParamSpec p)
	{
		var close_to_tray_switch = object as Gtk.Switch;
		return_if_fail(close_to_tray_switch != null);
		always_close_to_tray = close_to_tray_switch.active;
	}
	
	private void on_can_quit(ref bool can_quit)
	{
		if (always_close_to_tray && indicator != null && indicator.visible)
			can_quit = false;
	}
}

} // namespace Nuvola
#endif
