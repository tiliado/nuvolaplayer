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
	public const string ABOUT = "about";
	public const string HELP = "help";
	public const string DONATE = "donate";
	public const string ACTIVATE = "activate";
	public const string GO_HOME = "go-home";
	public const string GO_BACK = "go-back";
	public const string GO_FORWARD = "go-forward";
	public const string GO_RELOAD = "go-reload";
	public const string FORMAT_SUPPORT = "format-support";
	public const string PREFERENCES = "preferences";
	public const string TOGGLE_SIDEBAR = "toggle-sidebar";
	public const string ZOOM_IN = "zoom-in";
	public const string ZOOM_OUT = "zoom-out";
	public const string ZOOM_RESET = "zoom-reset";
}

public static string build_camel_id(string web_app_id)
{
	return build_uid(Nuvola.get_app_uid() + "App", web_app_id);
}

public static string build_dbus_id(string web_app_id)
{
	return build_uid(Nuvola.get_dbus_id() + "App", web_app_id);
}

private static string build_uid(string base_id, string web_app_id)
{
	var buffer = new StringBuilder(base_id);
	foreach (var part in web_app_id.split("_"))
	{
		buffer.append_c(part[0].toupper());
		if (part.length > 1)
			buffer.append(part.substring(1));
	}
	return buffer.str;
}

public string build_ui_runner_ipc_id(string web_app_id)
{
	return "N3" + web_app_id.replace("_", "");
}

public abstract class RunnerApplication: Diorite.Application
{
	public Diorite.Storage storage {get; private set;}
	public Config config {get; protected set; default = null;}
	public Connection connection {get; protected set;}
	public WebAppWindow? main_window {get; protected set; default = null;}
	public WebApp web_app {get; protected set;}
	public WebAppStorage app_storage {get; protected set;}
	public string dbus_id {get; private set;}

	
	public RunnerApplication(string web_app_id, string web_app_name, string version, Diorite.Storage storage)
	{
		var uid = build_camel_id(web_app_id);
		var dbus_id = build_dbus_id(web_app_id);
		base(uid, web_app_name, dbus_id);
		this.storage = storage;
		this.dbus_id = dbus_id;
		icon = uid;
		this.version = version;
	}
}

public class AppRunnerController : RunnerApplication
{	
	public WebEngine web_engine {get; private set;}
	public Diorite.KeyValueStorage master_config {get; private set;}
	public Bindings bindings {get; private set;}
	public IpcBus ipc_bus {get; private set; default=null;}
	private AppDbusApi? dbus_api = null;
	private uint dbus_api_id = 0;
	public ActionsHelper actions_helper {get; private set; default = null;}
	private GlobalKeybindings global_keybindings;
	private const int MINIMAL_REMEMBERED_WINDOW_SIZE = 300;
	private uint configure_event_cb_id = 0;
	private MenuBar menu_bar;
	private Diorite.Form? init_form = null;
	private FormatSupportCheck format_support = null;
	private Drt.Lst<Component> components = null;
	private string? api_token = null;
	private bool use_nuvola_dbus = false;
	private HashTable<string, Variant>? web_worker_data = null;
	
	public AppRunnerController(
		Diorite.Storage storage, WebApp web_app, WebAppStorage app_storage,
		string? api_token, bool use_nuvola_dbus=false)
	{
		base(web_app.id, web_app.name, "%d.%d".printf(web_app.version_major, web_app.version_minor), storage);
		this.app_storage = app_storage;
		this.web_app = web_app;
		this.api_token = api_token;
		this.use_nuvola_dbus = use_nuvola_dbus;
	}
	
	public override bool dbus_register(DBusConnection conn, string object_path)
		throws GLib.Error
	{
		if (!base.dbus_register(conn, object_path))
			return false;
		dbus_api = new AppDbusApi(this);
		dbus_api_id = conn.register_object(object_path, dbus_api);
		return true;
	}
	
	public override void dbus_unregister(DBusConnection conn, string object_path)
	{
		if (dbus_api_id > 0)
		{
			conn.unregister_object(dbus_api_id);
			dbus_api_id = 0;
		}
		base.dbus_unregister(conn, object_path);
	}
	
	private  void start()
	{
		init_settings();
		init_ipc();
		init_gui();
		init_web_engine();
		format_support = new FormatSupportCheck(
			new FormatSupport(storage.require_data_file("audio/audiotest.mp3").get_path()), this, storage, config,
			web_engine.web_worker, web_engine, web_app);
		format_support.check();
	}
	
	private void init_settings()
	{
		/* Disable GStreamer plugin helper because it is shown too often and quite annoying.  */
		Environment.set_variable("GST_INSTALL_PLUGINS_HELPER", "/bin/true", true);
		web_worker_data = new HashTable<string, Variant>(str_hash, str_equal);
		
		var gtk_settings = Gtk.Settings.get_default();
		var default_config = new HashTable<string, Variant>(str_hash, str_equal);
		default_config.insert(ConfigKey.WINDOW_X, new Variant.int64(-1));
		default_config.insert(ConfigKey.WINDOW_Y, new Variant.int64(-1));
		default_config.insert(ConfigKey.WINDOW_SIDEBAR_POS, new Variant.int64(-1));
		default_config.insert(ConfigKey.WINDOW_SIDEBAR_VISIBLE, new Variant.boolean(false));
		default_config.insert(
			ConfigKey.DARK_THEME, new Variant.boolean(gtk_settings.gtk_application_prefer_dark_theme));
		config = new Config(app_storage.config_dir.get_child("config.json"), default_config);
		config.changed.connect(on_config_changed);
		gtk_settings.gtk_application_prefer_dark_theme = config.get_bool(ConfigKey.DARK_THEME);
	}
	
	private void init_ipc()
	{	
		try
		{
			var bus_name = build_ui_runner_ipc_id(web_app.id);
			web_worker_data["WEB_APP_ID"] = web_app.id;
			web_worker_data["RUNNER_BUS_NAME"] = bus_name;
			ipc_bus = new IpcBus(bus_name);
			ipc_bus.start();
			if (use_nuvola_dbus)
			{
				var nuvola_api = Bus.get_proxy_sync<DbusIfce>(
					BusType.SESSION, Nuvola.get_dbus_id(), Nuvola.get_dbus_path(),
					DBusProxyFlags.DO_NOT_CONNECT_SIGNALS|DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
				GLib.Socket socket;
				nuvola_api.get_connection(this.web_app.id, this.dbus_id, out socket, out api_token);
				if (socket == null)
				{
					warning("Master server refused conection.");
					quit();
					return;
				}
				ipc_bus.connect_master_socket(socket, api_token);
			}
			else
			{
				bus_name = Environment.get_variable("NUVOLA_IPC_MASTER");
				assert(bus_name != null);
				ipc_bus.connect_master(bus_name, api_token);
			}
		}
		catch (GLib.Error e)
		{
			warning("Master server error: %s", e.message);
			if (use_nuvola_dbus)
				on_show_error(
					"Failed to connect to Nuvola service",
					#if FLATPAK
					"Make sure Nuvola runtime flatpak is installed.\n\n" +
					#endif
					"Error message:\n%s".printf(e.message),
				false
				);
			quit();
			return;
		}
		
		ipc_bus.router.add_method(IpcApi.CORE_GET_METADATA, Drt.ApiFlags.READABLE|Drt.ApiFlags.PRIVATE,
			"Get web app metadata.", handle_get_metadata, null);
		
		try
		{
			var response = ipc_bus.master.call_sync("/nuvola/core/runner-started", new Variant("(ss)", web_app.id, ipc_bus.router.hex_token));
			assert(response.equal(new Variant.boolean(true)));
		}
		catch (GLib.Error e)
		{
			error("Communication with master process failed: %s", e.message);
		}
		var storage_client = new Diorite.KeyValueStorageClient(ipc_bus.master);
		master_config = storage_client.get_proxy("master.config");
		ipc_bus.router.add_method("/nuvola/core/get-component-info", Drt.ApiFlags.READABLE,
			"Get info about component.",
			handle_get_component_info, {
			new Drt.StringParam("name", true, false, null, "Component name.")
			});
		ipc_bus.router.add_method("/nuvola/core/toggle-component-active", Drt.ApiFlags.WRITABLE|Drt.ApiFlags.PRIVATE,
			"Set whether the component is active.",
			handle_toggle_component_active, {
			new Drt.StringParam("name", true, false, null, "Component name."),
			new Drt.BoolParam("name", true, false, "Component active state.")
			});
	}
	
	private void init_gui()
	{
		#if FLATPAK
		Graphics.ensure_gl_extension_mounted(main_window);
		#endif
		actions_helper = new ActionsHelper(actions, config);
		unowned ActionsHelper ah = actions_helper;
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		ah.simple_action("main", "app", Actions.ACTIVATE, "Activate main window", null, null, null, do_activate),
		ah.simple_action("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		ah.simple_action("main", "app", Actions.ABOUT, "About", "_About", null, null, do_about),
		ah.simple_action("main", "app", Actions.HELP, "Help", "_Help", null, "F1", do_help),
		};
		actions.add_actions(actions_spec);
				
		menu_bar = new MenuBar(this);
		menu_bar.update();
		set_app_menu_items({Actions.HELP, Actions.ABOUT, Actions.QUIT});
		
		main_window = new WebAppWindow(this);
		main_window.can_destroy.connect(on_can_quit);
		var x = (int) config.get_int64(ConfigKey.WINDOW_X);
		var y = (int) config.get_int64(ConfigKey.WINDOW_Y);
		if (x >= 0 && y >= 0)
			main_window.move(x, y);
		var win_width = (int) config.get_int64(ConfigKey.WINDOW_WIDTH);
		var win_height = (int) config.get_int64(ConfigKey.WINDOW_HEIGHT);
		if (win_width > MINIMAL_REMEMBERED_WINDOW_SIZE && win_height > MINIMAL_REMEMBERED_WINDOW_SIZE)
			main_window.resize(win_width, win_height);
		if (config.get_bool(ConfigKey.WINDOW_MAXIMIZED))
			main_window.maximize();
		
		main_window.present();
		main_window.window_state_event.connect(on_window_state_event);
		main_window.configure_event.connect(on_configure_event);
		main_window.notify["is-active"].connect_after(on_window_is_active_changed);
		main_window.sidebar.hide();
		
		fatal_error.connect(on_fatal_error);
		show_error.connect(on_show_error);
		show_warning.connect(on_show_warning);
	}
	
	private void init_web_engine()
	{
		connection = new Connection(new Soup.Session(), app_storage.cache_dir.get_child("conn"), config);
		WebEngine.init_web_context(app_storage);
		web_engine = new WebEngine(this, ipc_bus, web_app, app_storage, config, connection, web_worker_data);
		web_engine.set_user_agent(web_app.user_agent);
		
		web_engine.init_form.connect(on_init_form);
		web_engine.notify.connect_after(on_web_engine_notify);
		web_engine.show_alert_dialog.connect(on_show_alert_dialog);
		actions.action_changed.connect(on_action_changed);
		var widget = web_engine.widget;
		widget.hexpand = widget.vexpand = true;
		main_window.grid.add(widget);
		widget.show();
		web_engine.init_finished.connect(init_app_runner);
		web_engine.app_runner_ready.connect(load_app);
		web_engine.init();
	}
	
	private void init_app_runner()
	{
		append_actions();
		var gakb = new ActionsKeyBinderClient(ipc_bus.master);
		global_keybindings = new GlobalKeybindings(gakb, actions);
		load_extensions();
		web_engine.widget.hide();
		main_window.sidebar.hide();
		web_engine.init_app_runner();
	}
	
	private void load_app()
	{
		set_app_menu_items({Actions.FORMAT_SUPPORT, Actions.PREFERENCES, Actions.HELP, Actions.ABOUT, Actions.QUIT});
		main_window.set_menu_button_items({Actions.ZOOM_IN, Actions.ZOOM_OUT, Actions.ZOOM_RESET, "|", Actions.TOGGLE_SIDEBAR});
		main_window.create_toolbar({Actions.GO_BACK, Actions.GO_FORWARD, Actions.GO_RELOAD, Actions.GO_HOME});
		
		main_window.sidebar.add_page.connect_after(on_sidebar_page_added);
		main_window.sidebar.remove_page.connect_after(on_sidebar_page_removed);
		
		if (config.get_bool(ConfigKey.WINDOW_SIDEBAR_VISIBLE))
			main_window.sidebar.show();
		else
			main_window.sidebar.hide();
		main_window.sidebar_position = (int) config.get_int64(ConfigKey.WINDOW_SIDEBAR_POS);
		var sidebar_page = config.get_string(ConfigKey.WINDOW_SIDEBAR_PAGE);
		if (sidebar_page != null)
			main_window.sidebar.page = sidebar_page;
		main_window.notify["sidebar-position"].connect_after((o, p) =>
		{
			config.set_int64(ConfigKey.WINDOW_SIDEBAR_POS, (int64) main_window.sidebar_position);
		});
		main_window.sidebar.notify["visible"].connect_after(on_sidebar_visibility_changed);
		main_window.sidebar.page_changed.connect(on_sidebar_page_changed);
		web_engine.widget.show();
	
		menu_bar.set_menu("01_go", "_Go", {Actions.GO_HOME, Actions.GO_RELOAD, Actions.GO_BACK, Actions.GO_FORWARD});
		menu_bar.set_menu("02_view", "_View", {Actions.ZOOM_IN, Actions.ZOOM_OUT, Actions.ZOOM_RESET, "|", Actions.TOGGLE_SIDEBAR});
		web_engine.load_app();
	}
	
	public override void activate()
	{
		if (main_window == null)
			start();
		else
			main_window.present();
	}
	
	private void do_format_support()
	{
		format_support.show_dialog(FormatSupportDialog.Tab.MP3);
	}
	
	private void append_actions()
	{
		unowned ActionsHelper ah = actions_helper;
		Diorite.Action[] actions_spec = {
		ah.simple_action("main", "app", Actions.FORMAT_SUPPORT, "Format Support", "_Format support", null, null, do_format_support),
		ah.simple_action("main", "app", Actions.PREFERENCES, "Preferences", "_Preferences", null, null, do_preferences),
		ah.toggle_action("main", "win", Actions.TOGGLE_SIDEBAR, "Show sidebar", "Show _sidebar", null, null, do_toggle_sidebar, config.get_value(ConfigKey.WINDOW_SIDEBAR_VISIBLE)),
		ah.simple_action("go", "app", Actions.GO_HOME, "Home", "_Home", "go-home", "<alt>Home", web_engine.go_home),
		ah.simple_action("go", "app", Actions.GO_BACK, "Back", "_Back", "go-previous", "<alt>Left", web_engine.go_back),
		ah.simple_action("go", "app", Actions.GO_FORWARD, "Forward", "_Forward", "go-next", "<alt>Right", web_engine.go_forward),
		ah.simple_action("go", "app", Actions.GO_RELOAD, "Reload", "_Reload", "view-refresh", "<ctrl>R", web_engine.reload),
		ah.simple_action("view", "win", Actions.ZOOM_IN, "Zoom in", null, "zoom-in", "<ctrl>plus", web_engine.zoom_in),
		ah.simple_action("view", "win", Actions.ZOOM_OUT, "Zoom out", null, "zoom-out", "<ctrl>minus", web_engine.zoom_out),
		ah.simple_action("view", "win", Actions.ZOOM_RESET, "Original zoom", null, "zoom-original", "<ctrl>0", web_engine.zoom_reset),
		};
		actions.add_actions(actions_spec);
	}
	
	private void do_quit()
	{
		var windows = Gtk.Window.list_toplevels();
		foreach (var window in windows)
			window.hide();
		Timeout.add_seconds(10, () => {warning("Force quit after timeout."); GLib.Process.exit(0);});
		quit();
	}
	
	private void do_activate()
	{
		activate();
	}
	
	private void do_about()
	{
		var dialog = new AboutDialog(main_window, web_app);
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
		dialog.add_tab("Keyboard shortcuts", new KeybindingsSettings(actions, config, global_keybindings.keybinder));
		var network_settings = new NetworkSettings(connection);
		dialog.add_tab("Network", network_settings);
		dialog.add_tab("Features", new ComponentsManager(components));
		dialog.add_tab("Website Data", new WebsiteDataManager(WebEngine.get_web_context().get_website_data_manager()));
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
			NetworkProxyType type;
			string? host;
			int port;
			if (network_settings.get_proxy_settings(out type, out host, out port))
			{
				debug("New network proxy settings: %s %s %d", type.to_string(), host, port);
				connection.set_network_proxy(type, host, port);
				web_engine.apply_network_proxy(connection);
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
	
	private void do_help()
	{
		show_uri(Nuvola.HELP_URL);
	}
	
	private void load_extensions()
	{	
		var router = ipc_bus.router;
		var web_worker = web_engine.web_worker;
		bindings = new Bindings();
		bindings.add_binding(new ActionsBinding(router, web_worker));
		bindings.add_binding(new NotificationsBinding(router, web_worker));
		bindings.add_binding(new NotificationBinding(router, web_worker));
		bindings.add_binding(new LauncherBinding(router, web_worker));
		bindings.add_binding(new MediaKeysBinding(router, web_worker));
		bindings.add_binding(new MenuBarBinding(router, web_worker));
		bindings.add_binding(new MediaPlayerBinding(router, web_worker, new MediaPlayer(actions)));
		bindings.add_object(actions_helper);
		
		components = new Drt.Lst<Component>();
		#if APPINDICATOR
		components.prepend(new TrayIconComponent(this, bindings, config));
		#endif
		#if UNITY
		components.prepend(new UnityLauncherComponent(this, bindings, config));
		#endif
		components.prepend(new NotificationsComponent(this, bindings, actions_helper));
		components.prepend(new MediaKeysComponent(this, bindings, config, ipc_bus.master, web_app.id));
		
		bindings.add_object(menu_bar);
		
		#if EXPERIMENTAL
		components.prepend(new PasswordManagerComponent(config, ipc_bus, web_worker, web_app.id, web_engine));
		#endif
		components.prepend(new AudioScrobblerComponent(this, bindings, master_config, config, connection.session));
		components.prepend(new MPRISComponent(this, bindings, config));
		#if EXPERIMENTAL
		components.prepend(new HttpRemoteControl.Component(this, bindings, config, ipc_bus));
		#endif
		components.prepend(new LyricsComponent(this, bindings, config));
		components.prepend(new DeveloperComponent(this, bindings, config));
		components.reverse();
		
		foreach (var component in components)
		{
			debug("Component %s (%s) %s", component.id, component.name, component.enabled ? "enabled": "not enabled");
			component.notify["enabled"].connect_after(on_component_enabled_changed);
		}
	}
	
	private void on_fatal_error(string title, string message, bool markup)
	{
		var dialog = new Diorite.ErrorDialog(
			title,
			message + "\n\nThe application has reached an inconsistent state and will quit for that reason.",
			markup);
		dialog.run();
		dialog.destroy();
	}
	
	private void on_show_error(string title, string message, bool markup)
	{
		var dialog = new Diorite.ErrorDialog(
			title,
			message + "\n\nThe application might not function properly.",
			markup);
		dialog.run();
		dialog.destroy();
	}
	
	private void on_show_warning(string title, string message)
	{
		var info_bar = new Gtk.InfoBar();
		info_bar.show_close_button = true;
		var label = new Gtk.Label(Markup.printf_escaped("<span size='medium'><b>%s</b></span> %s", title, message));
		label.use_markup = true;
		label.vexpand = false;
		label.hexpand = true;
		label.halign = Gtk.Align.START;
		label.set_line_wrap(true);
		(info_bar.get_content_area() as Gtk.Container).add(label);
		info_bar.response.connect(on_close_warning);
		info_bar.show_all();
		main_window.info_bars.add(info_bar);
	}
	
	private void on_close_warning(Gtk.InfoBar info_bar, int response_id)
	{
		(info_bar.get_parent() as Gtk.Container).remove(info_bar);
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
			var response = ipc_bus.master.call_sync("/nuvola/core/runner-activated", new Variant("(s)", web_app.id));
			warn_if_fail(response.equal(new Variant.boolean(true)));
		}
		catch (GLib.Error e)
		{
			critical("Communication with master process failed: %s", e.message);
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
			config.set_int64(ConfigKey.WINDOW_X, (int64) x);
			config.set_int64(ConfigKey.WINDOW_Y, (int64) y);
			config.set_int64(ConfigKey.WINDOW_WIDTH, (int64) width);
			config.set_int64(ConfigKey.WINDOW_HEIGHT, (int64) height);
		}
		return false;
	}
	
	private void on_component_enabled_changed(GLib.Object object, ParamSpec param)
	{
		var component = object as Component;
		return_if_fail(component != null);
		var signal_name = component.enabled ? "ComponentLoaded" : "ComponentUnloaded";
		var payload = new Variant("(sss)", signal_name, component.id, component.name);
		try
		{
			
			web_engine.call_function("Nuvola.core.emit", ref payload);
		}
		catch (GLib.Error e)
		{
			warning("Communication with web engine failed: %s", e.message);
		}
		try
		{
			web_engine.web_worker.call_function("Nuvola.core.emit", ref payload);
		}
		catch (GLib.Error e)
		{
			warning("Communication with web worker failed: %s", e.message);
		}
	}
	
	private Variant? handle_get_metadata(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		return web_app.to_variant();
	}
	
	private Variant? handle_get_component_info(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var id = params.pop_string();
		if (components != null)
		{
			foreach (var component in components)
			{
				if (id == component.id)
				{
					var builder = new VariantBuilder(new VariantType("a{smv}"));
					builder.add("{smv}", "name", new Variant.string(component.name));
					builder.add("{smv}", "found", new Variant.boolean(true));
					builder.add("{smv}", "loaded", new Variant.boolean(component.enabled));
					builder.add("{smv}", "active", new Variant.boolean(component.active));
					return builder.end();
				}
			}
		}
		var builder = new VariantBuilder(new VariantType("a{smv}"));
		builder.add("{smv}", "name", new Variant.string(""));
		builder.add("{smv}", "found", new Variant.boolean(false));
		builder.add("{smv}", "loaded", new Variant.boolean(false));
		return builder.end();
	}
	
	private Variant? handle_toggle_component_active(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var id = params.pop_string();
		var active = params.pop_bool();
		if (components != null)
		{
			foreach (var component in components)
			{
				if (id == component.id)
					return new Variant.boolean(component.toggle_active(active));
			}
		}
		return new Variant.boolean(false);
	}
	
	private void on_action_changed(Diorite.Action action, ParamSpec p)
	{
		if (p.name != "enabled")
			return;
		try
		{
			var payload = new Variant("(ssb)", "ActionEnabledChanged", action.name, action.enabled);
			web_engine.web_worker.call_function("Nuvola.actions.emit", ref payload);
		}
		catch (GLib.Error e)
		{
			if (e is Diorite.MessageError.NOT_READY)
				debug("Communication failed: %s", e.message);
			else
				warning("Communication failed: %s", e.message);
		}
	}
	
	private void on_config_changed(string key, Variant? old_value)
	{
		switch (key)
		{
		case ConfigKey.DARK_THEME:
			Gtk.Settings.get_default().gtk_application_prefer_dark_theme = config.get_bool(ConfigKey.DARK_THEME);
			break;
		}
		
		if (web_engine.web_worker.ready)
		{
			try
			{
				var payload = new Variant("(ss)", "ConfigChanged", key);
				web_engine.web_worker.call_function("Nuvola.config.emit", ref payload);
			}
			catch (GLib.Error e)
			{
				warning("Communication failed: %s", e.message);
			}
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
	
	private void on_can_quit(ref bool can_quit)
	{
		if (web_engine != null)
		{
			try
			{
				if (web_engine.web_worker.ready)
					can_quit = web_engine.web_worker.send_data_request_bool("QuitRequest", "approved", can_quit);
				else
					debug("WebWorker not ready");
			}
			catch (GLib.Error e)
			{
				warning("QuitRequest failed in web worker: %s", e.message);
			}
			try
			{
			
				if (web_engine.ready)
					can_quit = web_engine.send_data_request_bool("QuitRequest", "approved", can_quit);
				else
					debug("WebEngine not ready");
			}
			catch (GLib.Error e)
			{
				warning("QuitRequest failed in web engine: %s", e.message);
			}
		}
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
			init_form.expand = true;
			init_form.valign = init_form.halign = Gtk.Align.CENTER;
			init_form.show();
			var button = new Gtk.Button.with_label("OK");
			button.margin = 10;
			button.show();
			button.clicked.connect(on_init_form_button_clicked);
			init_form.attach_next_to(button, null, Gtk.PositionType.BOTTOM, 2, 1);
			main_window.grid.add(init_form);
			init_form.show();
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
		main_window.grid.remove(init_form);
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
		
		web_engine.init_app_runner();
	}
	
	private void on_sidebar_visibility_changed(GLib.Object o, ParamSpec p)
	{
		var visible = main_window.sidebar.visible;
		config.set_bool(ConfigKey.WINDOW_SIDEBAR_VISIBLE, visible);
		if (visible)
			main_window.sidebar_position = (int) config.get_int64(ConfigKey.WINDOW_SIDEBAR_POS);
		
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
	
	private void on_show_alert_dialog(ref bool handled, string text)
	{
		main_window.show_overlay_alert(text);
		handled = true;
	}
}


[DBus(name="eu.tiliado.NuvolaApp")]
public class AppDbusApi: GLib.Object
{
	private unowned AppRunnerController controller;
	
	public AppDbusApi(AppRunnerController controller)
	{
		this.controller = controller;
	}
	
	public void activate()
	{
		Idle.add(() => {controller.activate(); return false;});
	}
}


[DBus(name="eu.tiliado.Nuvola")]
public interface DbusIfce: GLib.Object
{
	public abstract void get_connection(string app_id, string dbus_id, out GLib.Socket? socket, out string? token) throws GLib.Error;
}

} // namespace Nuvola
