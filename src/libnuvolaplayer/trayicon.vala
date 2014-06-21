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

namespace Nuvola.Extensions.TrayIcon
{

public Nuvola.ExtensionInfo get_info()
{
	return
	{
		/// Name of a plugin providing scrobbling to Last.fm
		_("Tray Icon"),
		Nuvola.get_version(),
		/// Extension descriptiom
		_("<p>This plugin shows tray icon with menu. Tray icon may be required for <i>hide on close</i> feature.</p>"),
		"Jiří Janoušek",
		typeof(Extension),
		true
	};
}

/**
 * Tray icon is used to control playback when the main window is not visible
 * (it's minimized, hidden or covered by other windows) and to bring the hidden main
 * window to foreground.
 */
public class Extension: Nuvola.Extension
{
	private AppRunnerController controller;
	private Diorite.ActionsRegistry actions_reg;
	private WebEngine web_engine;
	
	private string[] actions = {};
	private Gtk.Menu? menu = null;
	#if APPINDICATOR
	private AppIndicator.Indicator? indicator = null;
	#else
	private Gtk.StatusIcon? icon;
	#endif
	
	/**
	 * {@inheritDoc}
	 */
	public override void load(AppRunnerController controller) throws ExtensionError
	{
		this.controller = controller;
		this.actions_reg = controller.actions;
		this.web_engine = controller.web_engine;
		#if APPINDICATOR
		critical("AppIndicator support is incomplete");
		indicator = new AppIndicator.Indicator(controller.path_name, controller.icon, AppIndicator.IndicatorCategory.APPLICATION_STATUS);
		indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE);
		create_menu();
		#else
		icon = new Gtk.StatusIcon.from_icon_name(controller.icon);
		icon.title = controller.app_name;
		set_tooltip(controller.app_name);
		create_menu();
		icon.popup_menu.connect(on_popup_menu);
		icon.activate.connect(() => {controller.activate();});
		#endif
		var server = controller.server;
		server.add_handler("Nuvola.TrayIcon.setTooltip", handle_set_tooltip);
		server.add_handler("Nuvola.TrayIcon.setActions", handle_set_actions);
		server.add_handler("Nuvola.TrayIcon.clearActions", handle_clear_actions);
	}
	
	public void set_tooltip(string tooltip)
	{
		#if !APPINDICATOR
		icon.tooltip_text = tooltip;
		#endif
	}
	
	public void clear_actions()
	{
		actions = {};
		create_menu();
	}
	
	public void set_actions(string[] actions)
	{
		this.actions = actions;
		create_menu();
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void unload()
	{
		var server = controller.server;
		server.remove_handler("Nuvola.TrayIcon.setTooltip");
		server.remove_handler("Nuvola.TrayIcon.setActions");
		server.remove_handler("Nuvola.TrayIcon.clearActions");
		clear_actions();
		
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
	
	private Variant? handle_set_tooltip(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(s)");
		string text;
		data.get("(s)", out text);
		set_tooltip(text);
		return null;
	}
	
	private Variant? handle_set_actions(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(av)");
		
		int i = 0;
		VariantIter iter = null;
		data.get("(av)", &iter);
		string[] actions = new string[iter.n_children()];
		Variant item = null;
		while (iter.next("v", &item))
			actions[i++] = item.get_string();
		
		set_actions((owned) actions);
		
		return null;
	}
	
	private Variant? handle_clear_actions(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		clear_actions();
		return null;
	}
}

} // namespace Nuvola.Extensions.TrayIcon
