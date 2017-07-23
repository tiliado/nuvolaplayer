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

public class TrayIconComponent: Component
{
	private const string NAMESPACE = "component.tray_icon.";
	public bool always_close_to_tray {get; set; default = false;}
	public bool use_x11_icon {get; set; default = false;}
	public bool use_appindicator {get; set; default = false;}
	private AppRunnerController controller;
	private Bindings bindings;
	private TrayIcon x11_icon = null;
	private Appindicator appindicator = null;
	
	public TrayIconComponent(AppRunnerController controller, Bindings bindings, Drt.KeyValueStorage config)
	{
		base("tray_icon", "Tray Icon", "Small icon with menu shown in the notification area.");
		this.has_settings = true;
		this.bindings = bindings;
		this.controller = controller;
		config.bind_object_property(NAMESPACE, this, "always_close_to_tray")
			.set_default(true).update_property();
		config.bind_object_property(NAMESPACE, this, "use_x11_icon")
			.set_default(false).update_property();
		config.bind_object_property(NAMESPACE, this, "use_appindicator")
			.set_default(false).update_property();
		config.bind_object_property(NAMESPACE, this, "enabled")
			.set_default(false).update_property();
		enabled_set = true;
		if (enabled)
			load();
	}
	
	protected override bool activate()
	{
		update();
		controller.main_window.can_destroy.connect(on_can_quit);
		notify["use-x11-icon"].connect_after(update);
		notify["use-appindicator"].connect_after(update);
		return true;
	}
	
	protected override bool deactivate()
	{
		controller.main_window.can_destroy.disconnect(on_can_quit);
		notify["use-x11-icon"].disconnect(update);
		notify["use-appindicator"].disconnect(update);
		x11_icon = null;
		appindicator = null;
		return true;
	}
	
	private void update()
	{
		if (use_x11_icon && x11_icon == null)
			x11_icon = new TrayIcon(controller, bindings.get_model<LauncherModel>());
		if (!use_x11_icon && x11_icon != null)
			x11_icon = null;
		if (use_appindicator && appindicator == null)
			appindicator = new Appindicator(controller, bindings.get_model<LauncherModel>());
		if (!use_appindicator && appindicator != null)
			appindicator = null;
	}
	
	public override Gtk.Widget? get_settings()
	{		
		return new TrayIconSettings(this);
	}
	
	private bool is_visible()
	{
		return x11_icon != null && x11_icon.visible || appindicator != null && appindicator.visible;
	}
	
	private void on_can_quit(ref bool can_quit)
	{
		if (always_close_to_tray && is_visible())
			can_quit = false;
	}
}


public class TrayIconSettings : Gtk.Grid
{
	private Gtk.Switch close_to_tray_switch;
	private Gtk.Switch x11_icon_switch;
	private Gtk.Switch appindicator_switch;
	
	public TrayIconSettings(TrayIconComponent component)
	{
		orientation = Gtk.Orientation.VERTICAL;
		row_spacing = 10;
		column_spacing = 10;
		var line = 0;
		var label = Drt.Labels.header("Variants");
		label.hexpand = true;
		label.show();
		attach(label, 0, line, 2, 1);
		line++;
		var bind_flags = BindingFlags.BIDIRECTIONAL|BindingFlags.SYNC_CREATE;
		
		label = Drt.Labels.markup("<span size='medium'><b>%s</b></span>", "AppIndicator icon");
		attach(label, 1, line, 1, 1);
		label.show();
		appindicator_switch = new Gtk.Switch();
		component.bind_property("use-appindicator", appindicator_switch, "active", bind_flags);
		attach(appindicator_switch, 0, line, 1, 1);
		appindicator_switch.show();
		line++;
		label = Drt.Labels.markup(
			"It should work in Unity, elementaryOS and GNOME (with "
			+ "<a href=\"https://extensions.gnome.org/extension/615/appindicator-support\">AppIndicator extension</a>)"
			+ " but does not work in other environments.");
		attach(label, 1, line, 1, 1);
		label.show();
		line++;
		
		label = Drt.Labels.markup("<span size='medium'><b>%s</b></span>", "Legacy X11 icon");
		attach(label, 1, line, 1, 1);
		label.show();
		x11_icon_switch = new Gtk.Switch();
		component.bind_property("use-x11-icon", x11_icon_switch, "active", bind_flags);
		attach(x11_icon_switch, 0, line, 1, 1);
		x11_icon_switch.show();
		line++;
		label = Drt.Labels.plain("It should work in XFCE, LXDE, Mate and GNOME (X11) but does not work in Unity.", true);
		attach(label, 1, line, 1, 1);
		label.show();
		line++;
		
		label = Drt.Labels.header("Options");
		label.hexpand = true;
		label.show();
		attach(label, 0, line, 2, 1);
		line++;
		
		label = Drt.Labels.plain("Always close main window to tray icon");
		attach(label, 1, line, 1, 1);
		label.show();
		close_to_tray_switch = new Gtk.Switch();
		component.bind_property("always_close_to_tray", close_to_tray_switch, "active", bind_flags);
		attach(close_to_tray_switch, 0, line, 1, 1);
		close_to_tray_switch.show();
	}
}

} // namespace Nuvola
#endif
