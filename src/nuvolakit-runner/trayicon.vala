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

/**
 * Tray icon is used to control playback when the main window is not visible
 * (it's minimized, hidden or covered by other windows) and to bring the hidden main
 * window to foreground.
 */
public class TrayIcon: GLib.Object, LauncherInterface
{
	private AppRunnerController controller;
	private Diorite.ActionsRegistry actions_reg;
	
	private string[] actions = {};
	private Gtk.Menu? menu = null;
	#if APPINDICATOR
	private AppIndicator.Indicator? indicator = null;
	#else
	private Gtk.StatusIcon? icon;
	#endif
	
	public TrayIcon(AppRunnerController controller)
	{
		this.controller = controller;
		this.actions_reg = controller.actions;
		#if APPINDICATOR
		critical("AppIndicator support is incomplete");
		indicator = new AppIndicator.Indicator(controller.path_name, controller.icon, AppIndicator.IndicatorCategory.APPLICATION_STATUS);
		indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE);
		create_menu();
		#else
		var icon_name = controller.icon;
		icon = new Gtk.StatusIcon.from_icon_name(icon_name);
		icon.title = controller.app_name;
		set_tooltip(controller.app_name);
		create_menu();
		icon.popup_menu.connect(on_popup_menu);
		icon.activate.connect(() => {controller.activate();});
		
		var icon_pixbuf = load_icon({icon_name, icon_name[0:icon_name.length - 1]}, icon.size);
		if (icon_pixbuf == null)
		{
			warning("Cannot load icon for StatusIcon");
		}
		else
		{
			icon.set_from_pixbuf(icon_pixbuf);
		}
		#endif
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
	
	public void set_tooltip(string tooltip)
	{
		#if !APPINDICATOR
		icon.tooltip_text = tooltip;
		#endif
	}
	
	public void remove_actions()
	{
		actions = {};
		create_menu();
	}
	
	public void add_action(string action)
	{
		actions += action;
		create_menu();
	}
	
	public void remove_action(string action)
	{
		var index = -1;
		for (var i = 0; i < actions.length; i++)
		{
			if (action == actions[i])
			{
				index = i;
				break;
			}
		}
		
		if (index >= 0)
		{
			var new_actions = new string[actions.length - 1];
			for (var i = 0; i < actions.length; i++)
			{
				if (i < index)
					new_actions[i] = actions[i];
				else if (i > index)
					new_actions[i - 1] = actions[i];
			}
			
			set_actions((owned) new_actions);
		}
	}
	
	public void set_actions(string[] actions)
	{
		this.actions = actions;
		create_menu();
	}
	
	~TrayIcon()
	{
		remove_actions();
		
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
		
		var model = actions_reg.build_menu(actions, false, true);
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
}

} // namespace Nuvola
