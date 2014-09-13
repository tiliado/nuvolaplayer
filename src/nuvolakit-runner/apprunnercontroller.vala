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
	public const string WINDOW_SIDEBAR_POS = "nuvola.window.sidebar.position";
	public const string WINDOW_SIDEBAR_VISIBLE = "nuvola.window.sidebar.visible";
	public const string WINDOW_SIDEBAR_PAGE = "nuvola.window.sidebar.page";
	public const string DARK_THEME = "nuvola.dark_theme";
}

namespace Actions
{
	public const string GO_HOME = "go-home";
	public const string GO_BACK = "go-back";
	public const string GO_FORWARD = "go-forward";
	public const string GO_RELOAD = "go-reload";
	public const string KEYBINDINGS = "keybindings";
	public const string PREFERENCES = "preferences";
	public const string TOGGLE_SIDEBAR = "toggle-sidebar";
}

public static string build_camel_id(string web_app_id)
{
	var buffer = new StringBuilder(Nuvola.get_app_uid());
	foreach (var part in web_app_id.split("_"))
	{
		buffer.append_c(part[0].toupper());
		if (part.length > 1)
			buffer.append(part.substring(1));
	}
	return buffer.str;
}

public static string build_dashed_id(string web_app_id)
{
	return "%s-%s".printf(Nuvola.get_app_id(), web_app_id.replace("_", "-"));
}
	
public class AppRunnerController : Diorite.Application
{
	private static const string UI_RUNNER_SUFFIX = ".uirunner";
	public WebAppWindow? main_window {get; private set; default = null;}
	public Diorite.Storage? storage {get; private set; default = null;}
	public Diorite.ActionsRegistry? actions {get; private set; default = null;}
	public WebAppMeta web_app {get; private set;}
	public WebAppStorage app_storage {get; private set;}
	public WebEngine web_engine {get; private set;}
	public weak Gtk.Settings gtk_settings {get; private set;}
	public Config config {get; private set;}
	public ExtensionsManager extensions {get; private set;}
	public ComponentsManager components {get; private set;}
	public Connection connection {get; private set;}
	public GlobalKeybinder keybinder {get; private set;}
	public Diorite.Ipc.MessageServer server {get; private set; default=null;}
	public ActionsHelper actions_helper {get; private set; default = null;}
	private GlobalKeybindings global_keybindings;
	private static const int MINIMAL_REMEMBERED_WINDOW_SIZE = 300;
	private uint configure_event_cb_id = 0;
	private MenuBar menu_bar;
	private bool hide_on_close = false;
	private Diorite.Form? init_form = null;
	private Diorite.Ipc.MessageClient master = null;
	
	public AppRunnerController(Diorite.Storage? storage, WebAppMeta web_app, WebAppStorage app_storage)
	{
		var app_id = web_app.id;
		var dashed_id = build_dashed_id(app_id);
		base(build_camel_id(app_id),
		"%s - %s".printf(web_app.name, Nuvola.get_app_name()),
		"%s.desktop".printf(dashed_id),
		dashed_id);
		icon = Nuvola.get_app_icon();
		version = Nuvola.get_version();
		this.app_storage = app_storage;
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
		set_up_communication();
		
		gtk_settings = Gtk.Settings.get_default();
		var default_config = new HashTable<string, Variant>(str_hash, str_equal);
		default_config.insert(ConfigKey.WINDOW_X, new Variant.int64(-1));
		default_config.insert(ConfigKey.WINDOW_Y, new Variant.int64(-1));
		default_config.insert(ConfigKey.WINDOW_SIDEBAR_POS, new Variant.int64(-1));
		default_config.insert(ConfigKey.WINDOW_SIDEBAR_VISIBLE, new Variant.boolean(true));
		default_config.insert(ConfigKey.DARK_THEME, new Variant.boolean(false));
		config = new Config(app_storage.config_dir.get_child("config.json"), default_config);
		config.config_changed.connect(on_config_changed);
		Gtk.Settings.get_default().gtk_application_prefer_dark_theme = config.get_bool(ConfigKey.DARK_THEME);
		
		actions = new Diorite.ActionsRegistry(this, null);
		actions_helper = new ActionsHelper(actions, config);
		main_window = new WebAppWindow(this);
		main_window.can_destroy.connect(on_can_quit);
		fatal_error.connect(on_fatal_error);
		show_error.connect(on_show_error);
		connection = new Connection(new Soup.SessionAsync(), app_storage.cache_dir.get_child("conn"));
		connection.session.add_feature_by_type(typeof(Soup.ProxyResolverDefault));
		
		web_engine = new WebEngine(this, web_app, app_storage, config);
		web_engine.init_form.connect(on_init_form);
		web_engine.notify.connect_after(on_web_engine_notify);
		actions.action_changed.connect(on_action_changed);
		var widget = web_engine.widget;
		widget.hexpand = widget.vexpand = true;
		
		append_actions();
		menu_bar = new MenuBar(actions, app_menu_shown && !menubar_shown);
		menu_bar.update();
		menu_bar.set_menus(this);
		keybinder = new GlobalKeybinder();
		global_keybindings = new GlobalKeybindings(keybinder, config, actions);
		
		load_extensions();
		
		if (!web_engine.load())
			return;
		main_window.grid.add(widget);
		widget.show();
		
		int x = (int) config.get_int(ConfigKey.WINDOW_X);
		int y = (int) config.get_int(ConfigKey.WINDOW_Y);
		if (x >= 0 && y >= 0)
			main_window.move(x, y);
			
		int w = (int) config.get_int(ConfigKey.WINDOW_WIDTH);
		int h = (int) config.get_int(ConfigKey.WINDOW_HEIGHT);
		main_window.resize(w > MINIMAL_REMEMBERED_WINDOW_SIZE ? w: 1010, h > MINIMAL_REMEMBERED_WINDOW_SIZE ? h : 600);
		
		if (config.get_bool(ConfigKey.WINDOW_MAXIMIZED))
			main_window.maximize();
		
		main_window.sidebar.add_page.connect_after(on_sidebar_page_added);
		main_window.sidebar.remove_page.connect_after(on_sidebar_page_removed);
		main_window.present();
		main_window.window_state_event.connect(on_window_state_event);
		main_window.configure_event.connect(on_configure_event);
		main_window.notify["is-active"].connect_after(on_window_is_active_changed);
		
		if (config.get_bool(ConfigKey.WINDOW_SIDEBAR_VISIBLE))
			main_window.sidebar.show();
		else
			main_window.sidebar.hide();
		main_window.sidebar_position = (int) config.get_int(ConfigKey.WINDOW_SIDEBAR_POS);
		var sidebar_page = config.get_string(ConfigKey.WINDOW_SIDEBAR_PAGE);
		if (sidebar_page != null)
			main_window.sidebar.page = sidebar_page;
		main_window.notify["sidebar-position"].connect_after((o, p) => config.set_int(ConfigKey.WINDOW_SIDEBAR_POS, (int64) main_window.sidebar_position));
		main_window.sidebar.notify["visible"].connect_after(on_sidebar_visibility_changed);
		main_window.sidebar.page_changed.connect(on_sidebar_page_changed);
	}
	
	
	
	private void append_actions()
	{
		unowned ActionsHelper ah = actions_helper;
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		ah.simple_action("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		ah.simple_action("main", "app", Actions.KEYBINDINGS, "Keyboard shortcuts", "_Keyboard shortcuts", null, null, do_keybindings),
		ah.simple_action("main", "app", Actions.PREFERENCES, "Preferences", "_Preferences", null, null, do_preferences),
		ah.toggle_action("main", "win", Actions.TOGGLE_SIDEBAR, "Show sidebar", "Show _sidebar", null, null, do_toggle_sidebar, config.get_value(ConfigKey.WINDOW_SIDEBAR_VISIBLE)),
		ah.simple_action("go", "app", Actions.GO_HOME, "Home", "_Home", "go-home", "<alt>Home", web_engine.go_home),
		ah.simple_action("go", "app", Actions.GO_BACK, "Back", "_Back", "go-previous", "<alt>Left", web_engine.go_back),
		ah.simple_action("go", "app", Actions.GO_FORWARD, "Forward", "_Forward", "go-next", "<alt>Right", web_engine.go_forward),
		ah.simple_action("go", "app", Actions.GO_RELOAD, "Reload", "_Reload", "view-refresh", null, web_engine.reload)
		};
		actions.add_actions(actions_spec);
	}
	
	private void set_up_communication()
	{
		assert(server == null);
		
		var server_name = app_id + UI_RUNNER_SUFFIX;
		Environment.set_variable("NUVOLA_IPC_UI_RUNNER", server_name, true);
		try
		{
			server = new Diorite.Ipc.MessageServer(server_name);
			server.add_handler("Nuvola.setHideOnClose", handle_set_hide_on_close);
			server.add_handler("Nuvola.Browser.downloadFileAsync", handle_download_file_async);
			server.start_service();
		}
		catch (Diorite.IOError e)
		{
			warning("Master server error: %s", e.message);
			quit();
		}
		
		var master_name = Environment.get_variable("NUVOLA_IPC_MASTER");
		assert(master_name != null);
		master = new Diorite.Ipc.MessageClient(master_name, 5000);
		assert(master.wait_for_echo(1000));
		try
		{
			var response = master.send_message("runner_started", new Variant("(ss)", web_app.id, server_name));
			assert(response.equal(new Variant.boolean(true)));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			error("Communication with master process failed: %s", e.message);
		}
	}
	
	private void do_quit()
	{
		quit();
	}
	
	private void do_keybindings()
	{
		var dialog = new KeybindingsDialog(this, main_window, actions, config, global_keybindings);
		dialog.run();
		dialog.destroy();
	}
	
	private void do_preferences()
	{
		var values = new HashTable<string, Variant>(str_hash, str_equal);
		values.insert(ConfigKey.DARK_THEME, config.get_value(ConfigKey.DARK_THEME));
		Diorite.Form form;
		try
		{
			form = Diorite.Form.create_from_spec(values, new Variant.tuple({
				new Variant.tuple({new Variant.string("header"), new Variant.string("Basic settings")}),
				new Variant.tuple({new Variant.string("bool"), new Variant.string(ConfigKey.DARK_THEME), new Variant.string("Prefer dark theme")})
			}));
		}
		catch (Diorite.FormError e)
		{
			show_error("Preferences form error",
				"Preferences form hasn't been shown because of malformed form specification: %s"
				.printf(e.message));
			return;
		}
		
		try
		{
			Variant? extra_values = null;
			Variant? extra_entries = null;
			web_engine.get_preferences(out extra_values, out extra_entries);
			form.add_values(Diorite.variant_to_hashtable(extra_values));
			form.add_entries(extra_entries);
		}
		catch (Diorite.FormError e)
		{
			show_error("Preferences form error",
				"Some entries of the Preferences form haven't been shown because of malformed form specification: %s"
				.printf(e.message));
		}
		
		var dialog = new PreferencesDialog(this, main_window, form);
		var response = dialog.run();
		if (response == Gtk.ResponseType.OK)
		{
			var new_values = form.get_values();
			foreach (var key in new_values.get_keys())
			{
				var new_value = new_values.get(key);
				if (new_value == null)
					critical("New value '%s' not found", key);
				else
					config.set_value(key, new_value);
			}
		}
		// Don't destroy dialog before form data are retrieved
		dialog.destroy();
	}
	
	private void do_toggle_sidebar()
	{
		var sidebar = main_window.sidebar;
		if (sidebar.visible)
			sidebar.hide();
		else
			sidebar.show();
	}
	
	private void load_extensions()
	{
		extensions = new ExtensionsManager(this);
		var available_extensions = extensions.available_extensions;
		foreach (var key in available_extensions.get_keys())
		{
			var enabled = config.get_value(ConfigKey.EXTENSION_ENABLED.printf(key)) ?? new Variant.boolean(available_extensions.lookup(key).autoload);
			if (enabled.get_boolean())
				extensions.load(key);
		}
		
		components = new ComponentsManager(this);
		
		components.add_component(new ActionsComponent(this));
		components.add_implementation(actions_helper);
		
		components.add_component(new LauncherComponent(this));
		components.add_implementation(new TrayIcon(this));
		#if UNITY
		components.add_implementation(new UnityLauncher(this));
		#endif
		
		components.add_component(new NotificationsComponent(this));
		components.add_implementation(new Notifications(this));
		
		components.add_component(new MediaKeysComponent(this));
		components.add_implementation(new MediaKeys(this));
		
		components.add_component(new MenuBarComponent(this));
		components.add_implementation(menu_bar);
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
	
	private void on_window_is_active_changed(Object o, ParamSpec p)
	{
		if (!main_window.is_active)
			return;
		
		try
		{
			var response = master.send_message("runner_activated", new Variant.string(web_app.id));
			warn_if_fail(response.equal(new Variant.boolean(true)));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Communication with master process failed: %s", e.message);
		}
	}
	
	private void save_config()
	{
		try
		{
			message(config.file.get_path());
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
	
	private Variant? handle_set_hide_on_close(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(b)");
		data.get("(b)", &hide_on_close);
		return null;
	}
	
	private Variant? handle_download_file_async(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(ssd)");
		string? uri = null;
		string? basename = null;
		double cb_id = 0.0;
		data.get("(ssd)", &uri, &basename, &cb_id);
		return_val_if_fail(uri != null, null);
		return_val_if_fail(basename != null, null);
		var file = connection.cache_dir.get_child(basename);
		connection.download_file.begin(uri, file, (obj, res) =>
		{
			Soup.Message msg = null;
			var result = connection.download_file.end(res, out msg);
			try
			{
				web_engine.call_function("Nuvola.browser._downloadDone", new Variant("(dbusss)", cb_id, result, msg.status_code, msg.reason_phrase, file.get_path(), file.get_uri()));
			}
			catch (Diorite.Ipc.MessageError e)
			{
				warning("Communication failed: %s", e.message);
			}
		});
		
		return null;
	}
	
	private void on_action_changed(Diorite.Action action, ParamSpec p)
	{
		if (p.name != "enabled")
			return;
		try
		{
			web_engine.call_function("Nuvola.actions.emit", new Variant("(ssb)", "ActionEnabledChanged", action.name, action.enabled));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			if (e is Diorite.Ipc.MessageError.NOT_READY)
				debug("Communication failed: %s", e.message);
			else
				warning("Communication failed: %s", e.message);
		}
	}
	
	private void on_config_changed(string key)
	{
		switch (key)
		{
		case ConfigKey.DARK_THEME:
			Gtk.Settings.get_default().gtk_application_prefer_dark_theme = config.get_bool(ConfigKey.DARK_THEME);
			break;
		}
		
		save_config();
		
		try
		{
			web_engine.call_function("Nuvola.config.emit", new Variant("(ss)", "ConfigChanged", key));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Communication failed: %s", e.message);
		}
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
	
	private void on_init_form(HashTable<string, Variant> values, Variant entries)
	{
		if (init_form != null)
		{
			main_window.overlay.remove(init_form);
			init_form = null;
		}
		
		try
		{
			init_form = Diorite.Form.create_from_spec(values, entries);
			init_form.check_toggles();
			init_form.expand = false;
			init_form.valign = init_form.halign = Gtk.Align.CENTER;
			init_form.show();
			var button = new Gtk.Button.with_label("OK");
			button.margin = 10;
			button.show();
			button.clicked.connect(on_init_form_button_clicked);
			init_form.attach_next_to(button, null, Gtk.PositionType.BOTTOM, 2, 1);
			main_window.overlay.add_overlay(init_form);
		}
		catch (Diorite.FormError e)
		{
			show_error("Initialization form error",
				"Initialization form hasn't been shown because of malformed form specification: %s"
				.printf(e.message));
		}
	}
	
	private void on_init_form_button_clicked(Gtk.Button button)
	{
		button.clicked.disconnect(on_init_form_button_clicked);
		main_window.overlay.remove(init_form);
		var new_values = init_form.get_values();
		init_form = null;
		
		foreach (var key in new_values.get_keys())
		{
			var new_value = new_values.get(key);
			if (new_value == null)
				critical("New values '%s'' not found", key);
			else
				config.set_value(key, new_value);
		}
		
		web_engine.load();
	}
	
	private void on_sidebar_visibility_changed(GLib.Object o, ParamSpec p)
	{
		var visible = main_window.sidebar.visible;
		config.set_bool(ConfigKey.WINDOW_SIDEBAR_VISIBLE, visible);
		if (visible)
			main_window.sidebar_position = (int) config.get_int(ConfigKey.WINDOW_SIDEBAR_POS);
		
		actions.get_action(Actions.TOGGLE_SIDEBAR).state = new Variant.boolean(visible);
	}
	
	private void on_sidebar_page_changed()
	{
		var page = main_window.sidebar.page;
		if (page != null)
			config.set_string(ConfigKey.WINDOW_SIDEBAR_PAGE, page);
	}
	
	private void on_sidebar_page_added(Sidebar sidebar, string name, string label, Gtk.Widget child)
	{
		actions.get_action(Actions.TOGGLE_SIDEBAR).enabled = !sidebar.is_empty();
	}
	
	private void on_sidebar_page_removed(Sidebar sidebar, Gtk.Widget child)
	{
		actions.get_action(Actions.TOGGLE_SIDEBAR).enabled = !sidebar.is_empty();
	}
}

} // namespace Nuvola
