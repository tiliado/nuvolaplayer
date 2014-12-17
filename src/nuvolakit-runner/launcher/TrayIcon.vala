/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola
{

public static string[] slist_strings_to_array(SList<string> list)
{
	string[] array = new string[list.length()];
	int i = 0;
	unowned SList<string> cursor = list;
	while (cursor != null)
	{
		array[i++] = cursor.data;
		cursor = cursor.next;
	}
	return (owned) array;
}

/**
 * Tray icon is used to control playback when the main window is not visible
 * (it's minimized, hidden or covered by other windows) and to bring the hidden main
 * window to foreground.
 */
public class TrayIcon: GLib.Object
{
	private AppRunnerController controller;
	private Diorite.ActionsRegistry actions_reg;
	private LauncherModel model;
	private Gtk.Menu? menu = null;
	#if APPINDICATOR
	private AppIndicator.Indicator? indicator = null;
	#else
	private Gtk.StatusIcon? icon;
	#endif
	
	public TrayIcon(AppRunnerController controller, LauncherModel model)
	{
		this.controller = controller;
		this.actions_reg = controller.actions;
		this.model = model;
		model.notify.connect_after(on_model_changed);
		#if APPINDICATOR
		critical("AppIndicator support is incomplete");
		indicator = new AppIndicator.Indicator(controller.path_name, controller.icon, AppIndicator.IndicatorCategory.APPLICATION_STATUS);
		indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE);
		create_menu();
		#else
		icon = new Gtk.StatusIcon.from_icon_name(controller.icon);
		icon.visible = false;
		icon.title = controller.app_name;
		icon.tooltip_text = model.tooltip;
		create_menu();
		icon.popup_menu.connect(on_popup_menu);
		icon.activate.connect(() => {controller.activate();});
		unset_number();
		Bus.watch_name(BusType.SESSION, "org.gnome.Shell", BusNameWatcherFlags.NONE,
			on_gnome_shell_dbus_appeared, on_gnome_shell_dbus_vanished);
		#endif
	}
	
	public void unset_number()
	{
		set_number(-1);
	}
	
	public void set_number(int number)
	{
		#if !APPINDICATOR
		var icon_name = controller.icon;
		var icon_pixbuf = load_icon({icon_name, icon_name[0:icon_name.length - 1]}, icon.size);
		if (icon_pixbuf == null)
		{
			warning("Cannot load icon for StatusIcon");
		}
		else
		{
			render_number(number, ref icon_pixbuf);
			icon.set_from_pixbuf(icon_pixbuf);
		}
		#endif
	}
	
	private static void render_number(int number, ref Gdk.Pixbuf pixbuf)
	{
		if (number <= 0)
			return;
		
		var padding = 1.0;
		assert(pixbuf.width == pixbuf.height);
		var size = pixbuf.width;
		string text;
		double font_size;
		if (number < 100)
		{
			text = number.to_string();
			font_size = 0.5 * size;
		}
		else
		{
			text = "∞";
			font_size = 0.8 * size;
		}
		var format = pixbuf.has_alpha ? Cairo.Format.ARGB32 : Cairo.Format.RGB24;
		var surface = new Cairo.ImageSurface(format, size, size);
		var cairo = new Cairo.Context(surface);
		Gdk.cairo_set_source_pixbuf(cairo, pixbuf, 0.0, 0.0);
		cairo.paint();
		
		cairo.move_to(0, 0);
		cairo.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
		cairo.set_font_size(font_size);
		Cairo.TextExtents extents;
		cairo.text_extents(text, out extents);
		var text_x = Math.round(extents.x_bearing);
		var text_y = Math.round(extents.y_bearing);
		var text_width = Math.round(extents.width);
		var text_height = Math.round(extents.height);
		
		cairo.set_source_rgba (1, 1, 1, 0.6);
		var width = text_width + 2 * padding;
		var height = text_height + 2 * padding;
		cairo.rectangle(Math.floor(0.5 * (size - width)), Math.floor(0.5 * (size - height)), width, height);
		cairo.fill();
		
		cairo.set_source_rgba(1, 0, 0, 1.0);
		var x = Math.floor(0.5 * (size - text_width) - text_x);
		var y = Math.floor(0.5 * (size - text_height) - text_y);
		cairo.move_to(x, y);
		cairo.show_text(text);
		pixbuf = Gdk.pixbuf_get_from_surface (surface, 0, 0, size, size);
	}
	
	public static Gdk.Pixbuf? load_icon(string[] names, int size)
	{
		foreach (var name in names)
		{
			try
			{
				return Gtk.IconTheme.get_default().load_icon(name, size, 0);
			}
			catch (Error e)
			{
			}
		}
		
		return null;
	}
	
	private void on_model_changed(GLib.Object o, ParamSpec p)
	{
		switch (p.name)
		{
		case "tooltip":
			#if !APPINDICATOR
			icon.tooltip_text = model.tooltip;
			#endif
			break;
		case "actions":
			create_menu();
			break;
		}
	}
	
	~TrayIcon()
	{
		#if APPINDICATOR
		indicator = null;
		#else
		if (menu != null)
			menu.detach();
		icon.visible = false;
		icon = null;
		#endif
		
		menu = null;
	}
	
	private void create_menu()
	{
		#if !APPINDICATOR
		if (menu != null)
			menu.detach();
		#endif
		
		var model = actions_reg.build_menu(slist_strings_to_array(model.actions), false, true);
		menu = new Gtk.Menu.from_model(model);
		
		#if APPINDICATOR
		indicator.set_menu(menu);
		#else
		menu.attach_to_widget(controller.main_window, null);
		#endif
	}
	
	#if !APPINDICATOR
	private void on_popup_menu(uint button, uint time)
	{
		return_if_fail(menu != null);
		
		menu.show_all();
		menu.popup(null, null, icon.position_menu, button, time);
	}
	#endif
	
	private void on_gnome_shell_dbus_appeared(DBusConnection connection, string name, string name_owner)
	{
		if (icon != null)
			icon.visible = false;
	}
	
	private void on_gnome_shell_dbus_vanished(DBusConnection connection, string name)
	{
		if (icon != null)
			icon.visible = true;
	}
}

} // namespace Nuvola
