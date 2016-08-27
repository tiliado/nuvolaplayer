/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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
	var buffer = new StringBuilder("cz.fenryxo.NuvolaApp");
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

public string build_ui_runner_ipc_id(string web_app_id)
{
	return "%s.%s.%s".printf(Nuvola.get_app_id(), web_app_id, "uirunner");
}

public string build_web_worker_ipc_id(string web_app_id)
{
	return "%s.%s.%s".printf(Nuvola.get_app_id(), web_app_id, "webworker");
}

public abstract class RunnerApplication: Diorite.Application
{
	public Diorite.Storage storage {get; private set;}
	public Config config {get; protected set; default = null;}
	public Connection connection {get; protected set;}
	public WebAppWindow? main_window {get; protected set; default = null;}
	public WebAppMeta web_app {get; protected set;}
	
	public RunnerApplication(string web_app_id, string web_app_name, Diorite.Storage storage)
	{
		var dashed_id = build_dashed_id(web_app_id);
		base(
			build_camel_id(web_app_id),
			web_app_name,
			"%s.desktop".printf(dashed_id),
			dashed_id);
		this.storage = storage;
		icon = Nuvola.get_app_icon();
		version = Nuvola.get_version();
	}
}

public class AppRunnerController : RunnerApplication
{
	public WebAppStorage app_storage {get; private set;}
	private WebWorker web_worker;
	public WebEngine web_engine {get; private set;}
	public Diorite.KeyValueStorage master_config {get; private set;}
	public Bindings bindings {get; private set;}
	public ApiBus server {get; private set; default=null;}
	public ActionsHelper actions_helper {get; private set; default = null;}
	private GlobalKeybindings global_keybindings;
	private static const int MINIMAL_REMEMBERED_WINDOW_SIZE = 300;
	private uint configure_event_cb_id = 0;
	private MenuBar menu_bar;
	private Diorite.Form? init_form = null;
	private FormatSupportCheck format_support = null;
	private Tiliado.Account tiliado_account = null;
	private Diorite.SingleList<Component> components = null;
	
	public AppRunnerController(Diorite.Storage storage, WebAppMeta web_app, WebAppStorage app_storage)
	{
		base(web_app.id, web_app.name, storage);
		this.app_storage = app_storage;
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
		/* Disable GStreamer plugin helper because it is shown too often and quite annoying.  */
		Environment.set_variable("GST_INSTALL_PLUGINS_HELPER", "/bin/true", true);
		
		set_up_communication(); // Now we have WebWorker
		
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
		
		actions_helper = new ActionsHelper(actions, config);
		main_window = new WebAppWindow(this);
		main_window.can_destroy.connect(on_can_quit);
		
		fatal_error.connect(on_fatal_error);
		show_error.connect(on_show_error);
		show_warning.connect(on_show_warning);
		
		connection = new Connection(new Soup.Session(), app_storage.cache_dir.get_child("conn"), config);
		WebEngine.init_web_context(app_storage);
		web_engine = new WebEngine(this, server, web_app, app_storage, config, connection.proxy_uri);
		web_engine.init_form.connect(on_init_form);
		web_engine.notify.connect_after(on_web_engine_notify);
		web_engine.show_alert_dialog.connect(on_show_alert_dialog);
		actions.action_changed.connect(on_action_changed);
		var widget = web_engine.widget;
		widget.hexpand = widget.vexpand = true;
		
		append_actions();
		menu_bar = new MenuBar(actions);
		menu_bar.update();
		menu_bar.set_menus(this);
		
		var gakb = new ActionsKeyBinderClient(server.master);
		global_keybindings = new GlobalKeybindings(gakb, actions);
		
		load_extensions();
		
		web_engine.set_user_agent(web_app.user_agent);
		if (!web_engine.load())
			return;
		main_window.grid.add(widget);
		widget.show();
		
		int x = (int) config.get_int64(ConfigKey.WINDOW_X);
		int y = (int) config.get_int64(ConfigKey.WINDOW_Y);
		if (x >= 0 && y >= 0)
			main_window.move(x, y);
			
		int win_width = (int) config.get_int64(ConfigKey.WINDOW_WIDTH);
		int win_height = (int) config.get_int64(ConfigKey.WINDOW_HEIGHT);
		if (win_width > MINIMAL_REMEMBERED_WINDOW_SIZE && win_height > MINIMAL_REMEMBERED_WINDOW_SIZE)
			main_window.resize(win_width, win_height);
		
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
		main_window.sidebar_position = (int) config.get_int64(ConfigKey.WINDOW_SIDEBAR_POS);
		var sidebar_page = config.get_string(ConfigKey.WINDOW_SIDEBAR_PAGE);
		if (sidebar_page != null)
			main_window.sidebar.page = sidebar_page;
		main_window.notify["sidebar-position"].connect_after((o, p) => config.set_int64(ConfigKey.WINDOW_SIDEBAR_POS, (int64) main_window.sidebar_position));
		main_window.sidebar.notify["visible"].connect_after(on_sidebar_visibility_changed);
		main_window.sidebar.page_changed.connect(on_sidebar_page_changed);
		main_window.create_menu_button({Actions.ZOOM_IN, Actions.ZOOM_OUT, Actions.ZOOM_RESET, "|", Actions.TOGGLE_SIDEBAR});
		toggle_donate_button(false);
		
		format_support = new FormatSupportCheck(
			new FormatSupport(storage.get_data_file("audio/audiotest.mp3").get_path()), this, storage, config,
			web_worker, web_engine);
		format_support.check();
		
		tiliado_account = new Tiliado.Account(connection.session, master_config, "https://tiliado.eu", "nuvolaplayer");
		tiliado_account.refresh.begin((o, res) => {
			try
			{
				tiliado_account.refresh.end(res);
				message("Logged in as %s", tiliado_account.tiliado.current_user.to_string());
			}
			catch (Tiliado.ApiError e)
			{
				warning("Api Error: %s", e.message);
			}
			
			if (!tiliado_account.is_patron)
			{
				toggle_donate_button(true);
				Timeout.add_seconds(2 * 60 * 60, () => {
					if (!tiliado_account.is_patron)
						show_donation_bar.begin();
					return false;
				});
			}
			
			tiliado_account.notify["is-patron"].connect_after(on_is_patron_changed);
		});
	}
	
	private void do_format_support()
	{
		format_support.show_dialog(FormatSupportDialog.Tab.MP3);
	}
	
	private void append_actions()
	{
		unowned ActionsHelper ah = actions_helper;
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		ah.simple_action("main", "app", Actions.ACTIVATE, "Activate main window", null, null, null, do_activate),
		ah.simple_action("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		ah.simple_action("main", "app", Actions.FORMAT_SUPPORT, "Format Support", "_Format support", null, null, do_format_support),
		ah.simple_action("main", "app", Actions.ABOUT, "About", "_About", null, null, do_about),
		ah.simple_action("main", "app", Actions.HELP, "Help", "_Help", null, "F1", do_help),
		ah.simple_action("main", "app", Actions.DONATE, "Donate", null, "emblem-favorite", null, do_donate),
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
	
	private void set_up_communication()
	{
		assert(server == null);
		
		try
		{
			var bus_name = build_ui_runner_ipc_id(web_app.id);
			Environment.set_variable("NUVOLA_IPC_UI_RUNNER", bus_name, true);
			server = new ApiBus(bus_name);
			server.add_handler("Nuvola.Browser.downloadFileAsync", "(ssd)", handle_download_file_async);
			server.start();
			
			bus_name = Environment.get_variable("NUVOLA_IPC_MASTER");
			assert(bus_name != null);
			server.connect_master(bus_name);
		}
		catch (Diorite.IOError e)
		{
			warning("Master server error: %s", e.message);
			quit();
		}
		
		try
		{
			var response = server.master.send_message("runner_started", new Variant("(ss)", web_app.id, "<undefined>"));
			assert(response.equal(new Variant.boolean(true)));
		}
		catch (GLib.Error e)
		{
			error("Communication with master process failed: %s", e.message);
		}
		
		var storage_client = new Diorite.KeyValueStorageClient(server.master);
		master_config = storage_client.get_proxy("master.config", 5000);
		web_worker = new RemoteWebWorker(server);
	}
	
	private void do_quit()
	{
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
		dialog.add_tab("Network", new NetworkSettings(connection));
		dialog.add_tab("Components", new ComponentsManager(components));
		var account_form = new Tiliado.AccountForm(tiliado_account);
		account_form.valign = account_form.halign = Gtk.Align.CENTER;
		var scroll = new Gtk.ScrolledWindow(null, null);
		scroll.add(account_form);
		scroll.show_all();
		dialog.add_tab("Tiliado Account", scroll);
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
	
	private void do_help()
	{
		show_uri(Nuvola.HELP_URL);
	}
	
	private void load_extensions()
	{	
		var api = server.api;
		bindings = new Bindings();
		bindings.add_binding(new ActionsBinding(api, web_worker));
		bindings.add_binding(new NotificationsBinding(api, web_worker));
		bindings.add_binding(new NotificationBinding(api, web_worker));
		bindings.add_binding(new LauncherBinding(api, web_worker));
		bindings.add_binding(new MediaKeysBinding(api, web_worker));
		bindings.add_binding(new MenuBarBinding(api, web_worker));
		bindings.add_binding(new MediaPlayerBinding(api, web_worker, new MediaPlayer(actions)));
		bindings.add_object(actions_helper);
		
		components = new Diorite.SingleList<Component>();
		components.prepend(new TrayIconComponent(this, bindings, config));
		#if UNITY
		components.prepend(new UnityLauncherComponent(this, bindings, config));
		#endif
		components.prepend(new NotificationsComponent(this, bindings, actions_helper));
		// TODO: MediaKeysComponent
		var media_keys = new MediaKeysClient(web_app.id, server.master);
		media_keys.manage();
		bindings.add_object(media_keys);
		bindings.add_object(menu_bar);
		components.prepend(new AudioScrobblerComponent(this, bindings, master_config, config, connection.session));
		components.prepend(new MPRISComponent(this, bindings, config));
		components.prepend(new LyricsComponent(this, bindings, config));
		components.prepend(new DeveloperComponent(this, bindings, config));
		components.reverse();
		
		server.add_handler("Nuvola.Core.getComponentInfo", "(s)", handle_get_component_info);
		
		foreach (var component in components)
		{
			debug("Component %s (%s) %s", component.id, component.name, component.enabled ? "enabled": "not enabled");
			component.notify["enabled"].connect_after(on_component_enabled_changed);
		}
	}
	
	private async void show_donation_bar()
	{
		try
		{
			var reached = yield tiliado_account.tiliado.is_fundraiser_goal_reached(
				tiliado_account.project_id);
			if (!reached)
			{
				var versions = Nuvola.get_versions();
				var text = yield tiliado_account.tiliado.get_donation_text(
					tiliado_account.project_id, versions[0], versions[1], versions[2]);
				if (text != null && text != "" && text != "null")
				{
					var info_bar = new Gtk.InfoBar();
					info_bar.message_type = Gtk.MessageType.INFO;
					var label = new Gtk.Label(text);
					label.use_markup = true;
					label.set_line_wrap(true);
					label.show();
					info_bar.get_content_area().add(label);
					info_bar.show_close_button = true;
					info_bar.response.connect(on_donation_bar_response);
					info_bar.add_button("Donate", Gtk.ResponseType.ACCEPT);
					info_bar.show();
					main_window.info_bars.add(info_bar);
				}
				else
				{
					toggle_donate_button(true);
				}
			}
		}
		catch (Tiliado.ApiError e)
		{
			toggle_donate_button(true);
			warning("Tiliado API error: %s", e.message);
		}
	}
	
	private void toggle_donate_button(bool visible)
	{
		if (visible)
			main_window.create_toolbar({Actions.GO_BACK, Actions.GO_FORWARD, Actions.GO_RELOAD, Actions.GO_HOME, " ", Actions.DONATE});
		else
			main_window.create_toolbar({Actions.GO_BACK, Actions.GO_FORWARD, Actions.GO_RELOAD, Actions.GO_HOME});
		
	}
	
	private void on_is_patron_changed(GLib.Object? o, ParamSpec p)
	{
		toggle_donate_button(!tiliado_account.is_patron);
	}
	
	private void on_donation_bar_response(Gtk.InfoBar bar, int response_id)
	{
		if (response_id == Gtk.ResponseType.ACCEPT)
			do_donate();
		else
			toggle_donate_button(true);
		
		var parent = bar.get_parent() as Gtk.Container;
		if (parent != null)
			parent.remove(bar);
	}
	
	private void do_donate()
	{
		show_uri("%s/%s/funding/".printf(tiliado_account.server, tiliado_account.project_id));
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
			var response = server.master.send_message("runner_activated", new Variant.string(web_app.id));
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
			web_worker.call_function("Nuvola.core.emit", ref payload);
		}
		catch (GLib.Error e)
		{
			warning("Communication with web worker failed: %s", e.message);
		}
	}
	
	private Variant? handle_download_file_async(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
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
				var payload = new Variant(
					"(dbusss)", cb_id, result, msg.status_code, msg.reason_phrase, file.get_path(), file.get_uri());
				web_worker.call_function("Nuvola.browser._downloadDone", ref payload);
			}
			catch (GLib.Error e)
			{
				warning("Communication failed: %s", e.message);
			}
		});
		
		return null;
	}
	
	private Variant? handle_get_component_info(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		string? id = null;
		data.get("(s)", &id);
		return_val_if_fail(id != null && id[0] != '\0', null);
		
		foreach (var component in components)
		{
			if (id == component.id)
			{
				var builder = new VariantBuilder(new VariantType("a{smv}"));
				builder.add("{smv}", "name", new Variant.string(component.name));
				builder.add("{smv}", "found", new Variant.boolean(true));
				builder.add("{smv}", "loaded", new Variant.boolean(component.enabled));
				return builder.end();
			}
		}
		
		var builder = new VariantBuilder(new VariantType("a{smv}"));
		builder.add("{smv}", "name", new Variant.string(""));
		builder.add("{smv}", "found", new Variant.boolean(false));
		builder.add("{smv}", "loaded", new Variant.boolean(false));
		return builder.end();
	}
	
	private void on_action_changed(Diorite.Action action, ParamSpec p)
	{
		if (p.name != "enabled")
			return;
		try
		{
			var payload = new Variant("(ssb)", "ActionEnabledChanged", action.name, action.enabled);
			web_worker.call_function("Nuvola.actions.emit", ref payload);
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
		
		try
		{
			var payload = new Variant("(ss)", "ConfigChanged", key);
			web_worker.call_function("Nuvola.config.emit", ref payload);
		}
		catch (GLib.Error e)
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
	
	private void on_can_quit(ref bool can_quit)
	{
		try
		{
			can_quit = web_worker.send_data_request_bool("QuitRequest", "approved", can_quit);
		}
		catch (GLib.Error e)
		{
			warning("QuitRequest failed in web worker: %s", e.message);
		}
		try
		{
			can_quit = web_engine.send_data_request_bool("QuitRequest", "approved", can_quit);
		}
		catch (GLib.Error e)
		{
			warning("QuitRequest failed in web engine: %s", e.message);
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

} // namespace Nuvola
