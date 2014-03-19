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

namespace Nuvola
{

namespace ConfigKey
{
	public const string WINDOW_X = "nuvola.window.x";
	public const string WINDOW_Y = "nuvola.window.y";
	public const string WINDOW_WIDTH = "nuvola.window.width";
	public const string WINDOW_HEIGHT = "nuvola.window.height";
	public const string WINDOW_MAXIMIZED = "nuvola.window.maximized";
}

namespace Actions
{
	public const string GO_HOME = "go-home";
	public const string GO_BACK = "go-back";
	public const string GO_FORWARD = "go-forward";
	public const string GO_RELOAD = "go-reload";
}

public class WebAppController : Diorite.Application
{
	public WebAppWindow? main_window {get; private set; default = null;}
	public Diorite.Storage? storage {get; private set; default = null;}
	public Diorite.ActionsRegistry? actions {get; private set; default = null;}
	public WebApp web_app {get; private set;}
	public WebEngine web_engine {get; private set;}
	public weak Gtk.Settings gtk_settings {get; private set;}
	public Config config {get; private set;}
	public ExtensionsManager extensions {get; private set;}
	private static const int MINIMAL_REMEMBERED_WINDOW_SIZE = 300;
	private uint configure_event_cb_id = 0;
	private MenuBar menu_bar;
	private bool hide_on_close = false;
	
	public WebAppController(Diorite.Storage? storage, WebApp web_app)
	{
		var app_id = web_app.meta.id;
		base("%sX%s".printf(Nuvola.get_unique_name(), app_id),
		"%s - %s".printf(web_app.meta.name, Nuvola.get_display_name()),
		"%s-%s.desktop".printf(Nuvola.get_appname(), app_id),
		"%s-%s".printf(Nuvola.get_appname(), app_id));
		icon = Nuvola.get_app_icon();
		version = Nuvola.get_version();
		this.storage = storage;
		this.web_app = web_app;
	}
	
	public override void activate()
	{
		if (main_window == null)
			start();
		main_window.present();
	}
	
	private void start()
	{
		gtk_settings = Gtk.Settings.get_default();
		config = new Config(web_app.user_config_dir.get_child("config.json"));
		config.config_changed.connect(on_config_changed);
		actions = new Diorite.ActionsRegistry(this, null);
		main_window = new WebAppWindow(this);
		main_window.can_destroy.connect(on_can_quit);
		fatal_error.connect(on_fatal_error);
		show_error.connect(on_show_error);
		web_engine = new WebEngine(this, web_app, config);
		web_engine.async_message_received.connect(on_async_message_received);
		web_engine.sync_message_received.connect(on_sync_message_received);
		web_engine.notify.connect_after(on_web_engine_notify);
		actions.action_changed.connect(on_action_changed);
		var widget = web_engine.widget;
		widget.hexpand = widget.vexpand = true;
		
		append_actions();
		menu_bar = new MenuBar(actions, app_menu_shown && !menubar_shown);
		set_up_menus();
		
		if (!web_engine.load())
			return;
		main_window.grid.add(widget);
		
		int x = (int) config.get_int(ConfigKey.WINDOW_X, -1);
		int y = (int) config.get_int(ConfigKey.WINDOW_Y, -1);
		if (x >= 0 && y >= 0)
			main_window.move(x, y);
			
		int w = (int) config.get_int(ConfigKey.WINDOW_WIDTH);
		int h = (int) config.get_int(ConfigKey.WINDOW_HEIGHT);
		main_window.resize(w > MINIMAL_REMEMBERED_WINDOW_SIZE ? w: 1010, h > MINIMAL_REMEMBERED_WINDOW_SIZE ? h : 600);
		
		if (config.get_bool(ConfigKey.WINDOW_MAXIMIZED, false))
			main_window.maximize();
		
		main_window.show_all();
		main_window.window_state_event.connect(on_window_state_event);
		main_window.configure_event.connect(on_configure_event);
		load_extensions();
	}
	
	private void append_actions()
	{
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.Action("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		new Diorite.Action("go", "app", Actions.GO_HOME, "Home", "_Home", "go-home", "<alt>Home", web_engine.go_home),
		new Diorite.Action("go", "app", Actions.GO_BACK, "Back", "_Back", "go-previous", "<alt>Left", web_engine.go_back),
		new Diorite.Action("go", "app", Actions.GO_FORWARD, "Forward", "_Forward", "go-next", "<alt>Right", web_engine.go_forward),
		new Diorite.Action("go", "app", Actions.GO_RELOAD, "Reload", "_Reload", "view-refresh", null, web_engine.reload)
		};
		actions.add_actions(actions_spec);
		
	}
	
	private void do_quit()
	{
		quit();
	}
	
	private void load_extensions()
	{
		extensions = new ExtensionsManager(this);
		var available_extensions = extensions.available_extensions;
		foreach (var key in available_extensions.get_keys())
			if (config.get_bool(ConfigKey.EXTENSION_ENABLED.printf(key), available_extensions.lookup(key).autoload))
				extensions.load(key);
	}
	
	private void on_fatal_error(string title, string message)
	{
		var dialog = new Diorite.ErrorDialog(title, message + "\n\nThe application has reached an inconsistent state and will quit for that reason.");
		dialog.run();
		dialog.destroy();
	}
	
	private void on_show_error(string title, string message)
	{
		var dialog = new Diorite.ErrorDialog(title, message + "\n\nThe application might not function properly.");
		dialog.run();
		dialog.destroy();
	}
	
	private bool on_window_state_event(Gdk.EventWindowState event)
	{
		bool m = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
		config.set_bool(ConfigKey.WINDOW_MAXIMIZED, m);
		return false;
	}
	
	private void save_config()
	{
		try
		{
			config.save();
		}
		catch (GLib.Error e)
		{
			show_error("Failed to save configuration", "Failed to save configuration to file %s. %s".printf(config.file.get_path(), e.message));
		}
	}
	
	private bool on_configure_event(Gdk.EventConfigure event)
	{
		if (configure_event_cb_id != 0)
			Source.remove(configure_event_cb_id);
		configure_event_cb_id = Timeout.add(200, on_configure_event_cb);
		return false;
	}
	
	private bool on_configure_event_cb()
	{
		configure_event_cb_id = 0;
		if (!main_window.maximized)
		{
			int x;
			int y;
			int width;
			int height;
			main_window.get_position (out x, out y);
			main_window.get_size(out width, out height);
			config.set_int(ConfigKey.WINDOW_X, (int64) x);
			config.set_int(ConfigKey.WINDOW_Y, (int64) y);
			config.set_int(ConfigKey.WINDOW_WIDTH, (int64) width);
			config.set_int(ConfigKey.WINDOW_HEIGHT, (int64) height);
		}
		return false;
	}
	
	private void on_sync_message_received(WebEngine engine, string name, Variant? data, ref Variant? result)
	{
		switch (name)
		{
		case "Nuvola.setHideOnClose":
			return_if_fail(data != null);
			data.get("(b)", &hide_on_close);
			break;
		case "Nuvola.Actions.addAction":
			string group = null;
			string scope = null;
			string action_name = null;
			string? label = null;
			string? mnemo_label = null;
			string? icon = null;
			string? keybinding = null;
			Variant? state = null;
			if (data != null)
			{
				data.get("(sssssss@*)", &group, &scope, &action_name, &label, &mnemo_label, &icon, &keybinding, &state);
				if (label == "")
					label = null;
				if (mnemo_label == "")
					mnemo_label = null;
				if (icon == "")
					icon = null;
				if (keybinding == "")
					keybinding = null;
				
				Diorite.Action action;
				if (state == null || state.get_type_string() == "mv")
					action = new Diorite.Action(group, scope, action_name, label, mnemo_label, icon, keybinding, null);
				else if(state.is_of_type(VariantType.BOOLEAN))
					action = new Diorite.Action.toggle(group, scope, action_name, label, mnemo_label, icon, keybinding, null, state);
				else
					action = new Diorite.Action.radio(group, scope, action_name, label, mnemo_label, icon, keybinding, null, state);
				action.enabled = false;
				action.activated.connect(on_custom_action_activated);
				actions.add_action(action);
			}
			break;
		case "Nuvola.Actions.isEnabled":
			return_if_fail(data != null);
			string? action_name = null;
			data.get("(s)", &action_name);
			return_if_fail(action_name != null);
			var action = actions.get_action(action_name);
			return_if_fail(action != null);
			result = new Variant.boolean(action.enabled);
			break;
		case "Nuvola.Actions.setEnabled":
			return_if_fail(data != null);
			string? action_name = null;
			bool enabled = false;
			data.get("(sb)", &action_name, &enabled);
			return_if_fail(action_name != null);
			var action = actions.get_action(action_name);
			return_if_fail(action != null);
			action.enabled = enabled;
			break;
		case "Nuvola.Actions.getState":
			return_if_fail(data != null);
			string? action_name = null;
			data.get("(s)", &action_name);
			return_if_fail(action_name != null);
			var action = actions.get_action(action_name);
			return_if_fail(action != null);
			result = action.state;
			break;
		case "Nuvola.Actions.setState":
			return_if_fail(data != null);
			string? action_name = null;
			Variant? state = null;
			data.get("(s@*)", &action_name, &state);
			return_if_fail(action_name != null);
			var action = actions.get_action(action_name);
			return_if_fail(action != null);
			action.state = state;
			break;
		}
	}
	
	private void on_async_message_received(WebEngine engine, string name, Variant? data)
	{
		switch (name)
		{
		case "Nuvola.MenuBar.setMenu":
			return_if_fail(data != null && data.is_container());
			
			string? id = null;
			string? label = null;
			int i = 0;
			VariantIter iter = null;
			data.get("(ssav)", &id, &label, &iter);
			return_if_fail(id != null && label != null && iter != null);
			string[] actions = new string[iter.n_children()];
			Variant item = null;
			while (iter.next("v", &item))
				actions[i++] = item.get_string();
			
			menu_bar[id] = new SubMenu(label, (owned) actions);
			set_up_menus();
			break;
		case "Nuvola.Actions.activate":
			return_if_fail(data != null);
			string? action_name = null;
			data.get("(s)", &action_name);
			return_if_fail(action_name != null);
			var action = actions.get_action(action_name);
			return_if_fail(action != null);
			action.activate(null);
			break;
		}
	}
	
	private void on_action_changed(Diorite.Action action, ParamSpec p)
	{
		if (p.name != "enabled")
			return;
		try
		{
			web_engine.call_function("Nuvola.Actions.emit", new Variant("(ssb)", "enabled-changed", action.name, action.enabled));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Communication failed: %s", e.message);
		}
	}
	
	private void on_custom_action_activated(Diorite.Action action, Variant? parameter)
	{
		try
		{
			web_engine.call_function("Nuvola.Actions.emit", new Variant("(ssmv)", "action-activated", action.name, parameter));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Communication failed: %s", e.message);
		}
	}
	
	private void on_config_changed(string key)
	{
		save_config();
	}
	
	private void on_web_engine_notify(GLib.Object o, ParamSpec p)
	{
		switch (p.name)
		{
		case "can-go-forward":
			actions.get_action(Actions.GO_FORWARD).enabled = web_engine.can_go_forward;
			break;
		case "can-go-back":
			actions.get_action(Actions.GO_BACK).enabled = web_engine.can_go_back;
			break;
		}
	}
	
	private void on_can_quit(ref bool result)
	{
		if (hide_on_close)
			result = false;
	}
	
	private void set_up_menus()
	{
		Menu? app_menu_model = null;
		Menu? menu_bar_model = null;
		menu_bar.build_menus(out app_menu_model, out menu_bar_model);
		if (app_menu_model != null)
			set_app_menu(app_menu_model);
		if (menu_bar_model != null)
		{
			if (!menubar_shown)
				main_window.menu_bar = new Gtk.MenuBar.from_model(menu_bar_model);
			set_menubar(menu_bar_model);
		}
	}
}

} // namespace Nuvola
