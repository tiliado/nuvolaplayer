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
	private WebAppController controller;
	private Diorite.ActionsRegistry actions_reg;
	private WebEngine web_engine;
	private Gtk.StatusIcon? icon;
	private string[] actions = {};
	private Gtk.Menu? menu = null;
	
	/**
	 * {@inheritDoc}
	 */
	public override void load(WebAppController controller) throws ExtensionError
	{
		this.controller = controller;
		this.actions_reg = controller.actions;
		this.web_engine = controller.web_engine;
		icon = new Gtk.StatusIcon.from_icon_name(controller.icon);
		icon.title = controller.app_name;
		set_tooltip(controller.app_name);
		icon.popup_menu.connect(on_popup_menu);
		icon.activate.connect(() => {controller.activate();});
		web_engine.message_received.connect(on_message_received);
	}
	
	public void set_tooltip(string tooltip)
	{
		icon.tooltip_text = tooltip;
	}
	
	public void clear_actions()
	{
		actions = {};
	}
	
	public void set_actions(string[] actions)
	{
		this.actions = actions;
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void unload()
	{
		web_engine.message_received.disconnect(on_message_received);
		clear_actions();
		icon.visible = false;
		icon = null;
		if (menu != null)
			menu.detach();
		menu = null;
	}
	
	private void on_popup_menu(uint button, uint time)
	{
		var model = actions_reg.build_menu(actions, false, true);
		if (menu != null)
			menu.detach();
		menu = new Gtk.Menu.from_model(model);
		menu.attach_to_widget(controller.main_window, null);
		menu.show_all();
		menu.popup(null, null, icon.position_menu, button, time);
	}
	
	private void on_message_received(WebEngine engine, string name, Variant? data)
	{
		if (name == "Nuvola.TrayIcon.setTooltip")
		{
			string text = null;
			if (data != null)
			{
				data.get("(s)", &text);
				set_tooltip(text);
			}
			engine.message_handled();
		}
		else if (name == "Nuvola.TrayIcon.setActions")
		{
			if (data != null && data.is_container())
			{
				string[] actions = new string[data.n_children()];
				int i = 0;
				VariantIter iter = null;
				data.get("(av)", &iter);
				Variant item = null;
				while (iter.next("v", &item))
					actions[i++] = item.get_string();
				set_actions((owned) actions);
			}
			engine.message_handled();
		}
		else if (name == "Nuvola.TrayIcon.clearActions")
		{
			clear_actions();
			engine.message_handled();
		}
	}
}

} // namespace Nuvola.Extensions.TrayIcon
